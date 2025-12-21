/**
 * @description
 * Domain class for Source_List__c.
 * Orchestrates validation and synchronization
 * during record lifecycle events.
 */
public with sharing class SourceListDomain extends fflib_SObjectDomain {
	/**
	 * @description
	 * Constructor invoked by fflib domain layer.
	 *
	 * @param sObjects
	 * Trigger context records.
	 */
	public SourceListDomain(List<SObject> sObjects) {
		super(sObjects);
	}

	/**
	 * @description
	 * After insert handler.
	 * Enqueues copy synchronization for newly created mappings.
	 */
	public override void onAfterInsert() {
		Set<Id> mappingIds = collectRecordIds(records);

		if (!mappingIds.isEmpty()) {
			SourceListServiceFactory.getService().enqueueCopy(mappingIds);
		}
	}

	/**
	 * @description
	 * Before delete handler.
	 * Enqueues removal synchronization for deleted mappings.
	 */
	public override void onBeforeDelete() {
		Set<Id> mappingIds = collectRecordIds(records);

		if (!mappingIds.isEmpty()) {
			SourceListServiceFactory.getService().enqueueRemove(mappingIds);
		}
	}

	/**
	 * @description
	 * Before insert handler.
	 * Validates Source_List__c mappings for
	 * cycles, depth, and member limits.
	 */
	public override void onBeforeInsert() {
		if (records == null || records.isEmpty()) {
			return;
		}

		SourceListService.validateSourceListInserts(castToSourceLists(records));
	}

	/**
	 * @description
	 * Collects record Ids from trigger context.
	 *
	 * @param sourceRecords
	 * Trigger context records.
	 *
	 * @return
	 * Set of Source_List__c record Ids.
	 */
	private static Set<Id> collectRecordIds(List<SObject> sourceRecords) {
		Set<Id> ids = new Set<Id>();

		if (sourceRecords == null || sourceRecords.isEmpty()) {
			return ids;
		}

		for (SObject sObj : sourceRecords) {
			Source_List__c record = (Source_List__c) sObj;

			if (record != null && record.Id != null) {
				ids.add(record.Id);
			}
		}

		return ids;
	}

	/**
	 * @description
	 * Casts trigger records to Source_List__c.
	 *
	 * @param sourceRecords
	 * Trigger context records.
	 *
	 * @return
	 * List of Source_List__c records.
	 */
	private static List<Source_List__c> castToSourceLists(List<SObject> sourceRecords) {
		List<Source_List__c> results = new List<Source_List__c>();

		for (SObject sObj : sourceRecords) {
			results.add((Source_List__c) sObj);
		}

		return results;
	}
}
