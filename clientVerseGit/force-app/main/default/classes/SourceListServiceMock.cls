@IsTest
public class SourceListServiceMock implements ISourceListService {
	/**
	 * @description
	 * Stores the most recent mapping Ids passed to enqueueCopy.
	 */
	public Set<Id> lastCopyIds = new Set<Id>();

	/**
	 * @description
	 * Stores the most recent mapping Ids passed to enqueueRemove.
	 */
	public Set<Id> lastRemoveIds = new Set<Id>();

	/**
	 * @description
	 * Captures mapping Ids provided for copy operations.
	 *
	 * @param mappingIds
	 * Set of Source_List__c mapping Ids.
	 */
	public void enqueueCopy(Set<Id> mappingIds) {
		if (mappingIds == null) {
			lastCopyIds = new Set<Id>();
			return;
		}

		lastCopyIds = new Set<Id>(mappingIds);
	}

	/**
	 * @description
	 * Captures mapping Ids provided for remove operations.
	 *
	 * @param mappingIds
	 * Set of Source_List__c mapping Ids.
	 */
	public void enqueueRemove(Set<Id> mappingIds) {
		if (mappingIds == null) {
			lastRemoveIds = new Set<Id>();
			return;
		}

		lastRemoveIds = new Set<Id>(mappingIds);
	}
}
