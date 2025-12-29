/**
 * @description
 * Controller backing Shared List Viewer (secure external list access).
 */
public with sharing class SharedListViewerController {
	/**
	 * @description Members data DTO returned to LWC
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

	/**
	 * @description Landing data DTO returned to LWC
	 */
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

		/**
		 * @description default constructor
		 */
		public LandingData() {
			members = new List<MemberDTO>();
		}
	}

	/**
	 * @description Resolves a shared list token and returns landing data for the viewer.
	 * @param token Secure share token.
	 * @return LandingData containing list metadata and members.
	 */
	@AuraEnabled(cacheable=true)
	public static LandingData resolveShareAccess(String token) {
		validateToken(token);

		View_Share_Config__c share = getShareByToken(token);
		List__c listRec = getList(share.List__c);

		LandingData data = new LandingData();
		data.listName = listRec.Name;
		data.access = normalizeAccess(share.Access_Type__c);
		data.listId = listRec.Id;
		data.shareId = share.Id;

		data.members = buildMemberDtos(listRec.Id);
		return data;
	}

	/**
	 * @description
	 * Returns a map of Contact Id to Contact Name.
	 *
	 * @param contactIds List of Contact record Ids.
	 * @return Map of Contact Id to Name.
	 */
	@AuraEnabled(cacheable=true)
	public static Map<Id, String> getContactNames(List<Id> contactIds) {
		Map<Id, String> result = new Map<Id, String>();

		if (contactIds == null || contactIds.isEmpty()) {
			return result;
		}

		for (Contact c : new ContactSelector().selectByIds(contactIds)) {
			result.put(c.Id, c.Name);
		}

		return result;
	}

	/**
	 * @description
	 * Submits proposed list changes. Applies changes immediately
	 * for Approved Reviewers, otherwise creates a List_Change__c proposal.
	 *
	 * @param listId Target List Id.
	 * @param shareId Optional View_Share_Config__c Id.
	 * @param changesJson JSON payload of proposed changes.
	 * @return TRUE if the request was processed successfully.
	 */
	@AuraEnabled
	public static Boolean submitListChanges(Id listId, Id shareId, String changesJson) {
		validateChangeRequest(listId, changesJson);

		View_Share_Config__c share = (shareId == null) ? null : getShareById(shareId);

		String access = (share == null) ? null : normalizeAccess(share.Access_Type__c);

		if (isApprovedReviewer(access)) {
			applyApprovedReviewerChanges(listId, changesJson);
		} else {
			createChangeProposal(listId, share, changesJson);
		}

		return true;
	}

	private static void applyApprovedReviewerChanges(Id listId, String changesJson) {
		ChangePayload payload = parseChangePayload(changesJson);

		Map<Id, List_Member__c> existing = loadExistingMembers(listId, payload);

		List<List_Member__c> inserts = buildInsertRecords(listId, payload, existing);

		List<List_Member__c> deletes = buildDeleteRecords(payload, existing);

		if (!inserts.isEmpty()) {
			Database.insert(inserts, AccessLevel.USER_MODE);
		}
		if (!deletes.isEmpty()) {
			Database.delete(deletes, AccessLevel.USER_MODE);
		}

		Task activity = new Task(
			Subject = 'List Changed By Approved Reviewer',
			WhatId = listId,
			ActivityDate = System.today(),
			OwnerId = UserInfo.getUserId(),
			Status = 'Completed'
		);

		Database.insert(activity, AccessLevel.USER_MODE);
	}

	private class ChangePayload {
		public Set<Id> contactsToInsert = new Set<Id>();
		public Set<Id> memberIdsToDelete = new Set<Id>();
		public Map<Id, String> statusByContact = new Map<Id, String>();
	}

	private static ChangePayload parseChangePayload(String jsonStr) {
		Object parsed = JSON.deserializeUntyped(jsonStr);
		if (!(parsed instanceof List<Object>)) {
			throw new AuraHandledException('Invalid changes payload.');
		}

		ChangePayload payload = new ChangePayload();

		for (Object rowObj : (List<Object>) parsed) {
			parseSingleRow(payload, rowObj);
		}

		return payload;
	}

	private static void parseSingleRow(ChangePayload payload, Object rowObj) {
		if (!(rowObj instanceof Map<String, Object>)) {
			return;
		}

		Map<String, Object> row = (Map<String, Object>) rowObj;

		if (isNewRow(row)) {
			handleInsertRow(payload, row);
		}

		if (isDeleteRow(row)) {
			handleDeleteRow(payload, row);
		}
	}

	private static Boolean isNewRow(Map<String, Object> row) {
		return row.containsKey('isNew') && row.get('isNew') == true;
	}

	private static Boolean isDeleteRow(Map<String, Object> row) {
		return row.containsKey('markedForRemoval') && row.get('markedForRemoval') == true;
	}

	private static void handleInsertRow(ChangePayload payload, Map<String, Object> row) {
		Id contactId = tryParseId(row.get('contactId'));
		if (contactId == null) {
			return;
		}

		payload.contactsToInsert.add(contactId);

		if (row.get('status') != null) {
			payload.statusByContact.put(contactId, String.valueOf(row.get('status')));
		}
	}

	private static void handleDeleteRow(ChangePayload payload, Map<String, Object> row) {
		Id memberId = tryParseId(row.get('id'));
		if (memberId != null) {
			payload.memberIdsToDelete.add(memberId);
		}
	}

	private static Map<Id, List_Member__c> loadExistingMembers(
		Id listId,
		ChangePayload payload
	) {
		Map<Id, List_Member__c> result = new Map<Id, List_Member__c>();

		if (payload.contactsToInsert.isEmpty() && payload.memberIdsToDelete.isEmpty()) {
			return result;
		}

		for (List_Member__c lm : [
			SELECT Id, Contact__c
			FROM List_Member__c
			WHERE
				List__c = :listId
				AND (Contact__c IN :payload.contactsToInsert
				OR Id IN :payload.memberIdsToDelete)
			WITH USER_MODE
		]) {
			result.put(lm.Id, lm);
			if (lm.Contact__c != null) {
				result.put(lm.Contact__c, lm);
			}
		}

		return result;
	}

	private static List<List_Member__c> buildInsertRecords(
		Id listId,
		ChangePayload payload,
		Map<Id, List_Member__c> existing
	) {
		List<List_Member__c> inserts = new List<List_Member__c>();

		for (Id contactId : payload.contactsToInsert) {
			if (!existing.containsKey(contactId)) {
				inserts.add(
					new List_Member__c(
						List__c = listId,
						Contact__c = contactId,
						Status__c = payload.statusByContact.get(contactId)
					)
				);
			}
		}

		return inserts;
	}

	private static List<List_Member__c> buildDeleteRecords(
		ChangePayload payload,
		Map<Id, List_Member__c> existing
	) {
		List<List_Member__c> deletes = new List<List_Member__c>();

		for (Id memberId : payload.memberIdsToDelete) {
			if (existing.containsKey(memberId)) {
				deletes.add(new List_Member__c(Id = memberId));
			}
		}

		return deletes;
	}

	private static void createChangeProposal(
		Id listId,
		View_Share_Config__c share,
		String changesJson
	) {
		List_Change__c change = new List_Change__c(
			List__c = listId,
			View_Share_Config__c = share != null ? share.Id : null,
			Changes__c = changesJson,
			Proposed_By__c = UserInfo.getUserId(),
			Proposed_At__c = System.now()
		);
		Database.insert(change, AccessLevel.USER_MODE);

		Database.insert(buildNotification(change, listId, share), AccessLevel.USER_MODE);

		Task activity = new Task(
			Subject = 'List Change Proposal Submitted',
			WhatId = listId,
			ActivityDate = System.today(),
			OwnerId = UserInfo.getUserId(),
			Status = 'Completed'
		);

		Database.insert(activity, AccessLevel.USER_MODE);
	}

	private static Notification_Request__c buildNotification(
		List_Change__c change,
		Id listId,
		View_Share_Config__c share
	) {
		return new Notification_Request__c(
			Template_Key__c = Notification_Template_Config__mdt.getInstance(
					'List_Change_Submitted_InApp'
				)
				.Template_Key__c,
			Channel__c = 'In App',
			Recipient_Type__c = 'User',
			Recipient_Id__c = share.CreatedById,
			Template_Mappings__c = JSON.serialize(
				new Map<String, Object>{
					'ListId' => listId,
					'ProposalUser' => UserInfo.getName()
				}
			),
			Status__c = 'Pending',
			Context_Record_Id__c = change.Id
		);
	}

	private static List<MemberDTO> buildMemberDtos(Id listId) {
		List<MemberDTO> result = new List<MemberDTO>();

		for (
			List_Member__c lm : new ListMemberSelector()
				.selectByListOrderedByContactName(listId)
		) {
			result.add(mapToDTO(lm));
		}

		return result;
	}

	private static MemberDTO mapToDTO(List_Member__c lm) {
		MemberDTO dto = new MemberDTO();
		dto.id = String.valueOf(lm.Id);
		dto.contactId = lm.Contact__c;
		dto.displayName = lm.Contact__r != null ? lm.Contact__r.Name : 'Unknown';
		dto.status = lm.Status__c;
		dto.title = lm.Title__c;
		dto.company = lm.Company__c;
		dto.initialSponsor = lm.Initial_Sponsor__r != null
			? lm.Initial_Sponsor__r.Name
			: '';
		return dto;
	}

	private static void validateToken(String token) {
		if (String.isBlank(token)) {
			throw new AuraHandledException('Missing token.');
		}
	}

	private static void validateChangeRequest(Id listId, String json) {
		if (listId == null) {
			throw new AuraHandledException('listId is required.');
		}
		if (String.isBlank(json)) {
			throw new AuraHandledException('No changes provided.');
		}
	}

	private static Boolean isApprovedReviewer(String access) {
		return access == 'Approved Reviewer';
	}

	private static View_Share_Config__c getShareByToken(String token) {
		List<View_Share_Config__c> shares = new ViewShareConfigSelector()
			.selectListSharesByTokens(new List<String>{ token });

		if (shares == null || shares.isEmpty()) {
			throw new AuraHandledException('Invalid token.');
		}

		View_Share_Config__c share = shares[0];
		validateShare(share);
		return share;
	}

	private static View_Share_Config__c getShareById(Id shareId) {
		List<View_Share_Config__c> shares = new ViewShareConfigSelector()
			.selectListSharesByIds(new Set<Id>{ shareId });

		if (shares == null || shares.isEmpty()) {
			throw new AuraHandledException('Invalid shareId.');
		}

		View_Share_Config__c share = shares[0];
		validateShare(share);
		return share;
	}

	private static void validateShare(View_Share_Config__c share) {
		if (share.Revoked__c) {
			throw new AuraHandledException('This link has been revoked.');
		}
		if (share.Expires_At__c != null && share.Expires_At__c < System.now()) {
			throw new AuraHandledException('This link has expired.');
		}
	}

	private static List__c getList(Id listId) {
		List<List__c> lists = new ListSelector().selectByIds(new Set<Id>{ listId });

		if (lists.isEmpty()) {
			throw new AuraHandledException('Parent List not found.');
		}
		return lists[0];
	}

	private static String normalizeAccess(Object accessType) {
		String access = String.valueOf(accessType);
		return String.isBlank(access) ? 'View' : access;
	}

	private static Id tryParseId(Object val) {
		try {
			return val == null ? null : (Id) String.valueOf(val);
		} catch (Exception ex) {
			return null;
		}
	}
}
