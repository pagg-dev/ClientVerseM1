/**
 * @description
 * Interface for ListMemberService
 */
public interface IListMemberService {
	/**
	 * @description
	 * Enqueues asynchronous copy of list members
	 * based on Source_List__c mappings.
	 *
	 * @param mappingIds
	 * Set of Source_List__c record Ids.
	 */
	void enqueueSyncCopyMembers(Set<Id> mappingIds);

	/**
	 * @description
	 * Enqueues asynchronous removal of specific list
	 * and campaign members for mappings.
	 *
	 * @param mappingToContactIds
	 * Map of Source_List__c Id to Contact Ids to remove.
	 */
	void enqueueSyncRemoveMembers(Map<Id, Set<Id>> mappingToContactIds);
}
