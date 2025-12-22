/**
 * @description
 * Aura controller for List Share actions such as
 * user search, token generation, and revocation.
 */
public with sharing class ListShareActionController {
	/**
	 * @description
	 * Searches active users by name, username, or email.
	 *
	 * @param term
	 * Search term.
	 *
	 * @return
	 * List of matching User records.
	 */
	@AuraEnabled(cacheable=true)
	public static List<User> searchUsers(String term) {
		return new UserSelector().selectActiveUsersByNameSearch(term);
	}

	/**
	 * @description
	 * Persists a List_Share__c record, generates an encrypted
	 * access token, builds the share URL, and triggers
	 * email and in-app notifications.
	 *
	 * @param listShare
	 * List_Share__c record to persist.
	 *
	 * @return
	 * Refreshed List_Share__c record.
	 */
	@AuraEnabled(cacheable=false)
	public static List_Share__c generateToken(List_Share__c listShare) {
		validateInput(listShare);

		Database.insert(listShare, AccessLevel.USER_MODE);

		String token = generateEncryptedToken(listShare);

		String shareUrl = buildShareUrl(token);

		persistToken(listShare.Id, token, shareUrl);

		enqueueNotifications(listShare, shareUrl);

		return fetchListShare(listShare.Id);
	}

	/**
	 * @description
	 * Revokes a previously generated token.
	 *
	 * @param listShareId
	 * List_Share__c Id.
	 *
	 * @return
	 * TRUE if revocation succeeded.
	 */
	@AuraEnabled(cacheable=false)
	public static Boolean revokeToken(Id listShareId) {
		if (listShareId == null) {
			return false;
		}

		try {
			Database.update(
				new List_Share__c(Id = listShareId, Revoked__c = true),
				AccessLevel.USER_MODE
			);
			return true;
		} catch (Exception ex) {
			throw new AuraHandledException('Failed to revoke access link.');
		}
	}

	private static void validateInput(List_Share__c listShare) {
		if (listShare == null) {
			throw new AuraHandledException('Share record is required.');
		}

		if (listShare.List__c == null) {
			throw new AuraHandledException('List__c (parent List Id) is required.');
		}
	}

	private static String generateEncryptedToken(List_Share__c listShare) {
		Long expiryMs = 0;
		if (listShare.Expires_At__c != null) {
			expiryMs = listShare.Expires_At__c.getTime();
		}

		String payload = JSON.serialize(
			new Map<String, Object>{
				'id' => listShare.Id,
				'exp' => expiryMs,
				'st' => listShare.Sharing_Type__c
			}
		);

		return TokenCryptoUtil.encryptToToken(payload, getEncryptionKey());
	}

	private static String buildShareUrl(String token) {
		Network community = [
			SELECT Id
			FROM Network
			WHERE Name = 'CV Marketing'
			WITH USER_MODE
			LIMIT 1
		];

		String baseUrl = Network.getLoginUrl(community.Id).replace('/login', '');

		return baseUrl + '/list-share?token=' + EncodingUtil.urlEncode(token, 'UTF-8');
	}

	private static void persistToken(Id listShareId, String token, String url) {
		Database.update(
			new List_Share__c(
				Id = listShareId,
				Token__c = token,
				Tokenized_URL__c = url,
				Revoked__c = false
			),
			AccessLevel.USER_MODE
		);
	}

	private static void enqueueNotifications(List_Share__c listShare, String shareUrl) {
		String payload = JSON.serialize(
			new Map<String, Object>{
				'ShareLink' => shareUrl,
				'ExpiryDate' => listShare.Expires_At__c != null
					? String.valueOf(listShare.Expires_At__c)
					: 'No expiry'
			}
		);

		String emailTemplateKey = Notification_Template_Config__mdt.getInstance(
				'Link_Generated_Email'
			)
			.Template_Key__c;

		String inAppTemplateKey = Notification_Template_Config__mdt.getInstance(
				'Link_Generated_In_App'
			)
			.Template_Key__c;

		List<Notification_Request__c> requests = new List<Notification_Request__c>{
			buildNotification(listShare, emailTemplateKey, 'Email', payload),
			buildNotification(listShare, inAppTemplateKey, 'In App', payload)
		};

		Database.insert(requests, AccessLevel.USER_MODE);
	}

	private static Notification_Request__c buildNotification(
		List_Share__c listShare,
		String templateKey,
		String channel,
		String payload
	) {
		return new Notification_Request__c(
			Template_Key__c = templateKey,
			Channel__c = channel,
			Recipient_Type__c = 'User',
			Recipient_Id__c = listShare.Shared_With__c,
			Template_Mappings__c = payload,
			Status__c = 'Pending',
			Context_Record_Id__c = listShare.Id
		);
	}

	private static List_Share__c fetchListShare(Id listShareId) {
		return [
			SELECT
				Id,
				Token__c,
				Tokenized_URL__c,
				Revoked__c,
				Sharing_Type__c,
				Expires_At__c,
				List__c,
				Shared_With__c,
				Token_Type__c,
				Access_Type__c
			FROM List_Share__c
			WHERE Id = :listShareId
			WITH USER_MODE
			LIMIT 1
		];
	}

	private static String getEncryptionKey() {
		Key_Vault__mdt key = Key_Vault__mdt.getInstance('List_Share_Token_Key');

		if (key == null || String.isBlank(key.Value__c)) {
			throw new AuraHandledException('Encryption key is not configured.');
		}

		return key.Value__c;
	}
}
