/**
 * @description
 * list and campaign synchronization operations.
 */
public interface ISourceListService {
	/**
	 * @description
	 * Enqueues asynchronous copy of members based on
	 * Source_List__c mappings.
	 *
	 * @param mappingIds
	 * Set of Source_List__c record Ids.
	 */
	void enqueueCopy(Set<Id> mappingIds);

	/**
	 * @description
	 * Enqueues asynchronous removal of members based on
	 * Source_List__c mappings.
	 *
	 * @param mappingIds
	 * Set of Source_List__c record Ids.
	 */
	void enqueueRemove(Set<Id> mappingIds);
}
