/**
 * @description
 * Selector class for View_Share_Config__c records.
 */
public with sharing class ViewShareConfigSelector extends fflib_SObjectSelector {
	/**
	 * @description
	 * Default constructor.
	 */
	public ViewShareConfigSelector() {
		super();
		setDataAccess(DataAccess.USER_MODE);
	}

	/**
	 * @description
	 * Returns the List Share field set for View_Share_Config__c queries.
	 *
	 * @return
	 * List of View_Share_Config__c fields.
	 */
	public List<Schema.SObjectField> getListShareSObjectFieldList() {
		return new List<Schema.SObjectField>{
			View_Share_Config__c.Id,
			View_Share_Config__c.Token__c,
			View_Share_Config__c.Tokenized_URL__c,
			View_Share_Config__c.Revoked__c,
			View_Share_Config__c.Sharing_Type__c,
			View_Share_Config__c.Expires_At__c,
			View_Share_Config__c.List__c,
			View_Share_Config__c.Shared_With__c,
			View_Share_Config__c.Token_Type__c,
			View_Share_Config__c.Access_Type__c,
			View_Share_Config__c.Type__c,
			View_Share_Config__c.CreatedById
		};
	}

	/**
	 * @description
	 * Returns the default field set for View_Share_Config__c queries.
	 *
	 * @return
	 * List of View_Share_Config__c fields.
	 */
	public List<Schema.SObjectField> getSObjectFieldList() {
		return new List<Schema.SObjectField>{
			View_Share_Config__c.Id,
			View_Share_Config__c.List__c
		};
	}

	/**
	 * @description
	 * Returns the SObject type handled by this selector.
	 *
	 * @return
	 * View_Share_Config__c SObjectType.
	 */
	public Schema.SObjectType getSObjectType() {
		return View_Share_Config__c.SObjectType;
	}

	/**
	 * @description
	 * Selects View_Share_Config__c records by Id.
	 *
	 * @param ids
	 * Set of View_Share_Config__c record Ids.
	 *
	 * @return
	 * List of matching View_Share_Config__c records.
	 */
	public List<View_Share_Config__c> selectByIds(Set<Id> ids) {
		if (ids == null || ids.isEmpty()) {
			return new List<View_Share_Config__c>();
		}

		return (List<View_Share_Config__c>) selectSObjectsById(ids);
	}

	/**
	 * @description
	 * Selects List Share Type View_Share_Config__c for given Ids.
	 *
	 * @param recordIds
	 * View_Share_Config__c Ids.
	 *
	 * @return
	 * List of View_Share_Config__c records.
	 */
	public List<View_Share_Config__c> selectListSharesByIds(Set<Id> recordIds) {
		if (recordIds == null || recordIds.isEmpty()) {
			return new List<View_Share_Config__c>();
		}

		fflib_QueryFactory queryFactory = newQueryFactory();
		queryFactory.selectFields(getListShareSObjectFieldList());
		queryFactory.setCondition('Id IN :recordIds AND Type__c = \'List Share\'');

		return (List<View_Share_Config__c>) Database.query(queryFactory.toSOQL());
	}

	/**
	 * @description
	 * Selects Single List Share Type View_Share_Config__c for given Id.
	 *
	 * @param recordId
	 * View_Share_Config__c Ids.
	 *
	 * @return
	 * List of View_Share_Config__c records.
	 */
	public View_Share_Config__c selectListSharesByIds(Id recordId) {
		if (recordId == null) {
			return null;
		}

		List<View_Share_Config__c> shares = selectListSharesByIds(
			new Set<Id>{ recordId }
		);

		if (shares == null || shares.isEmpty()) {
			return null;
		}

		return shares[0];
	}

	/**
	 * @description
	 * Selects List Share Type View_Share_Config__c for given tokens.
	 *
	 * @param tokens
	 * View_Share_Config__c tokens.
	 *
	 * @return
	 * List of View_Share_Config__c records.
	 */
	public List<View_Share_Config__c> selectListSharesByTokens(List<String> tokens) {
		if (tokens == null || tokens.isEmpty()) {
			return new List<View_Share_Config__c>();
		}

		fflib_QueryFactory queryFactory = newQueryFactory();
		queryFactory.selectFields(getListShareSObjectFieldList());
		queryFactory.setCondition('Token__c IN :tokens AND Type__c = \'List Share\'');

		return (List<View_Share_Config__c>) Database.query(queryFactory.toSOQL());
	}
}
