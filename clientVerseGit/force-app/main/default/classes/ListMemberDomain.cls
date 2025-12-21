/**
 * @description
 * Domain class for List_Member__c.
 */
public with sharing class ListMemberDomain extends fflib_SObjectDomain {
	/**
	 * @description
	 * Constructor invoked by fflib domain layer.
	 *
	 * @param sObjects
	 * Trigger context records.
	 */
	public ListMemberDomain(List<SObject> sObjects) {
		super(sObjects);
	}

	/**
	 * @description
	 * Applies static field mappings from List__c
	 * before List_Member__c records are inserted.
	 */
	public override void onBeforeInsert() {
		if (records == null || records.isEmpty()) {
			return;
		}

		Map<Id, List<List_Member__c>> membersByListId = groupMembersByList(records);

		if (membersByListId.isEmpty()) {
			return;
		}

		applyMappings(membersByListId);
	}

	/**
	 * @description
	 * Enqueues downstream sync copy operations
	 * after List_Member__c records are inserted.
	 */
	public override void onAfterInsert() {
		if (records == null || records.isEmpty()) {
			return;
		}

		Set<Id> sourceListIds = extractListIds(records);

		if (sourceListIds.isEmpty()) {
			return;
		}

		enqueueCopySync(sourceListIds);
	}

	/**
	 * @description
	 * Enqueues downstream sync remove operations
	 * before List_Member__c records are deleted.
	 */
	public override void onBeforeDelete() {
		if (records == null || records.isEmpty()) {
			return;
		}

		Map<Id, Set<Id>> listToContacts = collectContactsByList(records);

		if (listToContacts.isEmpty()) {
			return;
		}

		enqueueRemoveSync(listToContacts);
	}

	/**
	 * @description
	 * Treats undelete the same as insert
	 * for synchronization purposes.
	 */
	public override void onAfterUndelete() {
		onAfterInsert();
	}

	/* =========================
       Helper Methods
       ========================= */

	/**
	 * @description
	 * Groups List_Member__c records by their parent List__c.
	 *
	 * @param sourceRecords
	 * Trigger context records.
	 *
	 * @return
	 * Map of List__c Id to associated List_Member__c records.
	 */
	private static Map<Id, List<List_Member__c>> groupMembersByList(
		List<SObject> sourceRecords
	) {
		Map<Id, List<List_Member__c>> result = new Map<Id, List<List_Member__c>>();

		for (SObject sObj : sourceRecords) {
			List_Member__c member = (List_Member__c) sObj;

			if (member.List__c == null) {
				continue;
			}

			if (!result.containsKey(member.List__c)) {
				result.put(member.List__c, new List<List_Member__c>());
			}

			result.get(member.List__c).add(member);
		}

		return result;
	}

	/**
	 * @description
	 * Applies JSON-defined mappings from List__c
	 * to incoming List_Member__c records.
	 *
	 * @param membersByListId
	 * Grouped List_Member__c records by List__c.
	 */
	private void applyMappings(Map<Id, List<List_Member__c>> membersByListId) {
		List<List__c> lists = new ListSelector().selectByIds(membersByListId.keySet());

		for (List__c listRec : lists) {
			if (String.isBlank(listRec.List_Member_Mapping__c)) {
				continue;
			}

			Map<String, Object> mapping = parseMappingJson(
				listRec.List_Member_Mapping__c
			);

			if (mapping.isEmpty()) {
				continue;
			}

			List<List_Member__c> members = membersByListId.get(listRec.Id);

			if (members == null || members.isEmpty()) {
				continue;
			}

			applyMappingToMembers(mapping, members);
		}
	}

	/**
	 * @description
	 * Safely parses mapping JSON into a key-value map.
	 *
	 * @param jsonStr
	 * Raw JSON string stored on List__c.
	 *
	 * @return
	 * Parsed mapping values or an empty map if invalid.
	 */
	private static Map<String, Object> parseMappingJson(String jsonStr) {
		try {
			return (Map<String, Object>) JSON.deserializeUntyped(jsonStr);
		} catch (Exception ex) {
			return new Map<String, Object>();
		}
	}

	/**
	 * @description
	 * Applies a parsed mapping to multiple List_Member__c records.
	 *
	 * @param mapping
	 * Parsed field-value mapping.
	 *
	 * @param members
	 * Target List_Member__c records.
	 */
	private static void applyMappingToMembers(
		Map<String, Object> mapping,
		List<List_Member__c> members
	) {
		for (List_Member__c member : members) {
			applySingleMapping(mapping, member);
		}
	}

	/**
	 * @description
	 * Applies mapping fields to a single List_Member__c record.
	 *
	 * @param mapping
	 * Parsed field-value mapping.
	 *
	 * @param member
	 * Target List_Member__c record.
	 */
	private static void applySingleMapping(
		Map<String, Object> mapping,
		List_Member__c member
	) {
		for (String fieldApi : mapping.keySet()) {
			if (String.isBlank(fieldApi)) {
				continue;
			}

			String normalized = fieldApi.trim();

			if (isImmutableField(normalized)) {
				continue;
			}

			try {
				member.put(normalized, mapping.get(fieldApi));
			} catch (Exception ex) {
				continue;
			}
		}
	}

	/**
	 * @description
	 * Determines whether a field should not be modified.
	 *
	 * @param fieldApi
	 * API name of the field.
	 *
	 * @return
	 * True if the field is immutable.
	 */
	private static Boolean isImmutableField(String fieldApi) {
		return fieldApi.equalsIgnoreCase('Id') ||
			fieldApi.equalsIgnoreCase('CreatedDate') ||
			fieldApi.equalsIgnoreCase('LastModifiedDate');
	}

	/**
	 * @description
	 * Extracts parent List__c Ids from trigger records.
	 *
	 * @param sourceRecords
	 * Trigger context records.
	 *
	 * @return
	 * Set of List__c Ids.
	 */
	private static Set<Id> extractListIds(List<SObject> sourceRecords) {
		Set<Id> listIds = new Set<Id>();

		for (SObject sObj : sourceRecords) {
			List_Member__c member = (List_Member__c) sObj;

			if (member.List__c != null) {
				listIds.add(member.List__c);
			}
		}

		return listIds;
	}

	/**
	 * @description
	 * Enqueues sync copy jobs for downstream lists.
	 *
	 * @param sourceListIds
	 * Source List__c Ids.
	 */
	private static void enqueueCopySync(Set<Id> sourceListIds) {
		List<Source_List__c> mappings = new SourceListSelector()
			.selectSyncingBySourceListIds(sourceListIds);

		Set<Id> mappingIds = new Set<Id>();

		for (Source_List__c mapping : mappings) {
			mappingIds.add(mapping.Id);
		}

		if (!mappingIds.isEmpty()) {
			ListMemberServiceFactory.getService().enqueueSyncCopyMembers(mappingIds);
		}
	}

	/**
	 * @description
	 * Collects Contact__c values grouped by List__c.
	 *
	 * @param sourceRecords
	 * Trigger context records.
	 *
	 * @return
	 * Map of List__c Id to Contact Ids.
	 */
	private static Map<Id, Set<Id>> collectContactsByList(List<SObject> sourceRecords) {
		Map<Id, Set<Id>> result = new Map<Id, Set<Id>>();

		for (SObject sObj : sourceRecords) {
			List_Member__c member = (List_Member__c) sObj;

			if (member.Contact__c == null) {
				continue;
			}

			if (!result.containsKey(member.List__c)) {
				result.put(member.List__c, new Set<Id>());
			}

			result.get(member.List__c).add(member.Contact__c);
		}

		return result;
	}

	/**
	 * @description
	 * Enqueues sync remove jobs for downstream lists.
	 *
	 * @param listToContacts
	 * Map of source List__c Ids to Contact Ids.
	 */
	private static void enqueueRemoveSync(Map<Id, Set<Id>> listToContacts) {
		List<Source_List__c> mappings = new SourceListSelector()
			.selectSyncingBySourceListIds(listToContacts.keySet());

		Map<Id, Set<Id>> mappingToContacts = new Map<Id, Set<Id>>();

		for (Source_List__c mapping : mappings) {
			Set<Id> contacts = listToContacts.get(mapping.Source_List__c);

			if (contacts != null && !contacts.isEmpty()) {
				mappingToContacts.put(mapping.Id, contacts);
			}
		}

		if (!mappingToContacts.isEmpty()) {
			ListMemberServiceFactory.getService()
				.enqueueSyncRemoveMembers(mappingToContacts);
		}
	}
}
