/**
 * @description
 * Selector class for List__c records.
 */
public with sharing class ListSelector extends fflib_SObjectSelector {
	/**
	 * @description
	 * Default constructor.
	 */
	public ListSelector() {
		super();
		setDataAccess(DataAccess.USER_MODE);
	}

	/**
	 * @description
	 * Returns the default field set for List__c queries.
	 *
	 * @return
	 * List of List__c fields.
	 */
	public List<Schema.SObjectField> getSObjectFieldList() {
		return new List<Schema.SObjectField>{
			List__c.Id,
			List__c.List_Member_Mapping__c
		};
	}

	/**
	 * @description
	 * Returns the SObject type handled by this selector.
	 *
	 * @return
	 * List__c SObjectType.
	 */
	public Schema.SObjectType getSObjectType() {
		return List__c.SObjectType;
	}

	/**
	 * @description
	 * Selects List__c records by Id.
	 *
	 * @param ids
	 * Set of List__c record Ids.
	 *
	 * @return
	 * List of matching List__c records.
	 */
	public List<List__c> selectByIds(Set<Id> ids) {
		if (ids == null || ids.isEmpty()) {
			return new List<List__c>();
		}

		return (List<List__c>) selectSObjectsById(ids);
	}
}
