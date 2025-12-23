public with sharing class SharedListViewerController {
	/**
	 * Landing data DTO returned to LWC
	 */
	public class MemberDTO {
		@AuraEnabled
		public String id;
		@AuraEnabled
		public Id contactId;
		@AuraEnabled
		public String displayName;
		@AuraEnabled
		public String status;
		@AuraEnabled
		public String note;
		@AuraEnabled
		public String reason;
		@AuraEnabled
		public String title;
		@AuraEnabled
		public String company;
		@AuraEnabled
		public String initialSponsor;
	}

	public class LandingData {
		@AuraEnabled
		public String listName;
		@AuraEnabled
		public String access;
		@AuraEnabled
		public Id listId;
		@AuraEnabled
		public Id shareId;
		@AuraEnabled
		public List<MemberDTO> members;
		public LandingData() {
			members = new List<MemberDTO>();
		}
	}

	/**
	 * Resolve token, validate, and return landing data (list metadata + members)
	 * Expected by LWC: listName, access, listId, shareId, members[]
	 */
	@AuraEnabled(cacheable=true)
	public static LandingData resolveShareAccess(String token) {
		if (String.isBlank(token)) {
			throw new AuraHandledException('Missing token');
		}

		// find list share by token
		List<View_Share_Config__c> shares = new ViewShareConfigSelector()
			.selectListSharesByTokens(new List<String>{ token });

		if (shares.isEmpty()) {
			throw new AuraHandledException('Invalid token');
		}

		View_Share_Config__c share = shares[0];

		if (share.Revoked__c == true) {
			throw new AuraHandledException('This link has been revoked.');
		}

		if (share.Expires_At__c != null && share.Expires_At__c < System.now()) {
			throw new AuraHandledException('This link has expired.');
		}

		String access = String.valueOf(share.Access_Type__c);
		if (String.isBlank(access)) {
			access = 'View';
		}

		// Load the list record for name
		List<List__c> lists = [
			SELECT Id, Name
			FROM List__c
			WHERE Id = :share.List__c
			LIMIT 1
		];
		if (lists.isEmpty()) {
			throw new AuraHandledException('Parent List not found.');
		}
		List__c listRec = lists[0];

		// Query members for this list
		List<List_Member__c> lmRows = [
			SELECT
				Id,
				Contact__c,
				Contact__r.Name,
				Status__c,
				Title__c,
				Company__c,
				Initial_Sponsor__r.Name
			FROM List_Member__c
			WHERE List__c = :listRec.Id
			ORDER BY Contact__r.Name NULLS LAST
		];

		LandingData out = new LandingData();
		out.listName = listRec.Name;
		out.access = access;
		out.listId = listRec.Id;
		out.shareId = share.Id;

		for (List_Member__c lm : lmRows) {
			MemberDTO dto = new MemberDTO();
			dto.id = String.valueOf(lm.Id);
			dto.contactId = lm.Contact__c;
			dto.displayName = lm.Contact__r != null ? lm.Contact__r.Name : 'Unknown';
			dto.status = lm.Status__c;
			dto.reason = '';
			dto.title = lm.Title__c;
			dto.company = lm.Company__c;
			dto.initialSponsor = lm.Initial_Sponsor__r != null
				? lm.Initial_Sponsor__r.Name
				: '';
			out.members.add(dto);
		}

		return out;
	}

	@AuraEnabled(cacheable=true)
	public static Map<Id, String> getContactNames(List<Id> contactIds) {
		Map<Id, String> result = new Map<Id, String>();
		if (contactIds == null || contactIds.isEmpty())
			return result;

		for (Contact c : [SELECT Id, Name FROM Contact WHERE Id IN :contactIds]) {
			result.put(c.Id, c.Name);
		}
		return result;
	}

	/**
	 * Persist proposed changes as a List_Change__c record (does not apply them).
	 * Expects changesJson as JSON string (array of change objects).
	 * Returns true on success.
	 */
	@AuraEnabled
	public static Boolean submitListChanges(Id listId, Id shareId, String changesJson) {
		if (listId == null) {
			throw new AuraHandledException('listId is required.');
		}
		if (String.isBlank(changesJson)) {
			throw new AuraHandledException('No changes provided.');
		}

		try {
			// If a shareId is provided, validate the share and get Access_Type__c
			String accessLabel = null;
			View_Share_Config__c share;
			if (shareId != null) {
				List<View_Share_Config__c> shares = [
					SELECT Id, Revoked__c, Expires_At__c, Access_Type__c, CreatedById
					FROM View_Share_Config__c
					WHERE Id = :shareId
					LIMIT 1
				];
				if (shares.isEmpty()) {
					throw new SharedListViewerException('Invalid shareId.');
				}
				share = shares[0];

				if (share.Revoked__c == true) {
					throw new SharedListViewerException('This link has been revoked.');
				}
				if (share.Expires_At__c != null && share.Expires_At__c < System.now()) {
					throw new SharedListViewerException('This link has expired.');
				}

				accessLabel = String.valueOf(share.Access_Type__c);
			}

			// If this share's access is Approved Reviewer -> apply adds/deletes immediately (no List changes record)
			if (accessLabel != null && accessLabel == 'Approved Reviewer') {
				Object parsed = JSON.deserializeUntyped(changesJson);
				if (!(parsed instanceof List<Object>)) {
					throw new SharedListViewerException('Invalid changes payload.');
				}
				List<Object> payload = (List<Object>) parsed;

				Set<Id> contactIdsToInsert = new Set<Id>();
				Set<Id> memberIdsToDelete = new Set<Id>();
				// Map of contactId -> statusValue (only for new rows; last wins if duplicate in payload)
				Map<Id, String> newContactStatus = new Map<Id, String>();

				// Parse payload: collect only new-contact adds and persisted-member deletes.
				for (Object o : payload) {
					if (!(o instanceof Map<String, Object>))
						continue;
					Map<String, Object> m = (Map<String, Object>) o;

					Boolean isNew = m.containsKey('isNew')
						? (Boolean) m.get('isNew')
						: false;
					Boolean markedForRemoval = m.containsKey('markedForRemoval')
						? (Boolean) m.get('markedForRemoval')
						: false;
					String contactIdStr = m.containsKey('contactId') &&
						m.get('contactId') != null
						? String.valueOf(m.get('contactId'))
						: null;
					String idStr = m.containsKey('id') && m.get('id') != null
						? String.valueOf(m.get('id'))
						: null;
					String statusStr = m.containsKey('status') && m.get('status') != null
						? String.valueOf(m.get('status'))
						: null;

					if (isNew) {
						// add candidate (client-side new rows)
						if (contactIdStr != null) {
							try {
								Id cId = (Id) contactIdStr;
								contactIdsToInsert.add(cId);
								if (statusStr != null)
									newContactStatus.put(cId, statusStr);
							} catch (Exception ex) {
								// ignore invalid ids
							}
						}
					}

					if (markedForRemoval) {
						// deletion candidate: only if it's a real persisted SF Id (15/18 chars)
						if (
							idStr != null &&
							(idStr.length() == 15 ||
							idStr.length() == 18)
						) {
							try {
								memberIdsToDelete.add((Id) idStr);
							} catch (Exception ex) {
								// ignore invalid id formats
							}
						}
					}
				}

				Map<Id, List_Member__c> existingByContact = new Map<Id, List_Member__c>();
				Map<Id, List_Member__c> existingById = new Map<Id, List_Member__c>();

				if (!contactIdsToInsert.isEmpty() || !memberIdsToDelete.isEmpty()) {
					for (List_Member__c lm : [
						SELECT Id, Contact__c
						FROM List_Member__c
						WHERE
							List__c = :listId
							AND (Contact__c IN :contactIdsToInsert
							OR Id IN :memberIdsToDelete)
					]) {
						existingById.put(lm.Id, lm);
						if (lm.Contact__c != null)
							existingByContact.put(lm.Contact__c, lm);
					}
				}

				List<List_Member__c> toInsert = new List<List_Member__c>();
				List<List_Member__c> toDelete = new List<List_Member__c>();

				for (Id cId : contactIdsToInsert) {
					if (!existingByContact.containsKey(cId)) {
						List_Member__c lm = new List_Member__c();
						lm.List__c = listId;
						lm.Contact__c = cId;
						if (newContactStatus.containsKey(cId)) {
							lm.Status__c = newContactStatus.get(cId);
						}
						toInsert.add(lm);
					}
				}

				for (Id mid : memberIdsToDelete) {
					if (existingById.containsKey(mid)) {
						toDelete.add(new List_Member__c(Id = mid));
					}
				}

				if (!toInsert.isEmpty())
					insert toInsert;
				if (!toDelete.isEmpty())
					delete toDelete;

				return true;
			} else {
				// Default behaviour: create List_Change__c (no immediate apply)
				List_Change__c lc = new List_Change__c();
				lc.List__c = listId;
				if (shareId != null)
					lc.View_Share_Config__c = shareId;
				lc.Changes__c = changesJson;
				lc.Proposed_By__c = UserInfo.getUserId();
				lc.Proposed_At__c = System.now();
				insert lc;

				String notificationPayload = JSON.serialize(
					new Map<String, Object>{
						'ListId' => listId,
						'ProposalUser' => UserInfo.getName()
					}
				);

				String inAppTemplateKey = Notification_Template_Config__mdt.getInstance(
						'List_Change_Submitted_InApp'
					)
					.Template_Key__c;
				Notification_Request__c nrInApp = new Notification_Request__c(
					Template_Key__c = inAppTemplateKey,
					Channel__c = 'In App',
					Recipient_Type__c = 'User',
					Recipient_Id__c = share.CreatedById,
					Template_Mappings__c = notificationPayload,
					Status__c = 'Pending',
					Context_Record_Id__c = lc.Id
				);
				insert nrInApp;
				return true;
			}
		} catch (DmlException dmx) {
			throw new AuraHandledException(
				'Failed to save/apply changes: ' + dmx.getMessage()
			);
		} catch (Exception e) {
			throw new AuraHandledException(
				'Error saving/applying changes: ' + e.getMessage()
			);
		}
	}

	private class SharedListViewerException extends Exception {
	}
}
