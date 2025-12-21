/**
 * @description
 * Selector class for List_Member__c records.
 * Provides reusable query methods for list member access.
 */
public with sharing class ListMemberSelector extends fflib_SObjectSelector {
	/**
	 * @description
	 * Default constructor.
	 */
	public ListMemberSelector() {
		super();
		setDataAccess(DataAccess.USER_MODE);
	}

	/**
	 * @description
	 * Returns the default field set for List_Member__c queries.
	 *
	 * @return
	 * List of List_Member__c fields.
	 */
	public List<Schema.SObjectField> getSObjectFieldList() {
		return new List<Schema.SObjectField>{
			List_Member__c.Id,
			List_Member__c.List__c,
			List_Member__c.Contact__c,
			List_Member__c.Source_Lists__c,
			List_Member__c.Status__c
		};
	}

	/**
	 * @description
	 * Returns the SObject type handled by this selector.
	 *
	 * @return
	 * List_Member__c SObjectType.
	 */
	public Schema.SObjectType getSObjectType() {
		return List_Member__c.SObjectType;
	}

	/**
	 * @description
	 * Selects list members by List__c Ids.
	 *
	 * @param listIds
	 * List__c record Ids.
	 *
	 * @return
	 * List of matching List_Member__c records.
	 */
	public List<List_Member__c> selectByListIds(Set<Id> listIds) {
		if (listIds == null || listIds.isEmpty()) {
			return new List<List_Member__c>();
		}

		fflib_QueryFactory queryFactory = newQueryFactory();
		queryFactory.selectFields(getSObjectFieldList());
		queryFactory.setCondition('List__c IN :listIds AND Contact__c != null');

		return executeQuery(queryFactory);
	}

	/**
	 * @description
	 * Returns a QueryLocator for list members by List__c Ids.
	 *
	 * @param listIds
	 * List__c record Ids.
	 *
	 * @return
	 * QueryLocator for batch processing.
	 */
	public Database.QueryLocator queryLocatorByListIds(Set<Id> listIds) {
		if (listIds == null || listIds.isEmpty()) {
			return null;
		}

		fflib_QueryFactory queryFactory = newQueryFactory();
		queryFactory.selectFields(getSObjectFieldList());
		queryFactory.setCondition('List__c IN :listIds AND Contact__c != null');
		queryFactory.setOrdering(
			new fflib_QueryFactory.Ordering(
				List_Member__c.Id,
				fflib_QueryFactory.SortOrder.ASCENDING,
				false
			)
		);

		return Database.getQueryLocator(queryFactory.toSOQL() + ' WITH USER_MODE');
	}

	/**
	 * @description
	 * Selects a deterministic page of list members.
	 *
	 * @param listId
	 * List__c Id.
	 *
	 * @param lastSeenId
	 * Last processed List_Member__c Id.
	 *
	 * @param size
	 * Page size.
	 *
	 * @param contactsOnly
	 * Whether to include only members with Contact__c.
	 *
	 * @return
	 * Page of List_Member__c records.
	 */
	public List<List_Member__c> selectPage(
		Id listId,
		Id lastSeenId,
		Integer size,
		Boolean contactsOnly
	) {
		if (listId == null) {
			return new List<List_Member__c>();
		}

		Integer limitSize = size == null ? 2000 : size;

		fflib_QueryFactory queryFactory = new fflib_QueryFactory(
			List_Member__c.SObjectType
		);

		queryFactory.selectFields(getSObjectFieldList());

		queryFactory.setCondition(buildPagingCondition(listId, lastSeenId, contactsOnly));

		queryFactory.setOrdering(
			new fflib_QueryFactory.Ordering(
				List_Member__c.Id,
				fflib_QueryFactory.SortOrder.ASCENDING,
				false
			)
		);

		queryFactory.setLimit(limitSize);

		return executeQuery(queryFactory);
	}

	/**
	 * @description
	 * Selects list members by list and contact Ids.
	 *
	 * @param listId
	 * List__c Id.
	 *
	 * @param contactIds
	 * Contact Ids.
	 *
	 * @return
	 * List of matching List_Member__c records.
	 */
	public List<List_Member__c> selectByListAndContacts(Id listId, Set<Id> contactIds) {
		if (listId == null || contactIds == null || contactIds.isEmpty()) {
			return new List<List_Member__c>();
		}

		fflib_QueryFactory queryFactory = new fflib_QueryFactory(
			List_Member__c.SObjectType
		);

		queryFactory.selectFields(getSObjectFieldList());

		queryFactory.setCondition('List__c = :listId AND Contact__c IN :contactIds');

		return executeQuery(queryFactory);
	}

	/**
	 * @description
	 * Selects list members by multiple lists and contacts.
	 *
	 * @param listIds
	 * List__c Ids.
	 *
	 * @param contactIds
	 * Contact Ids.
	 *
	 * @return
	 * List of matching List_Member__c records.
	 */
	public List<List_Member__c> selectByListsAndContacts(
		Set<Id> listIds,
		List<Id> contactIds
	) {
		if (
			listIds == null ||
			listIds.isEmpty() ||
			contactIds == null ||
			contactIds.isEmpty()
		) {
			return new List<List_Member__c>();
		}

		fflib_QueryFactory queryFactory = new fflib_QueryFactory(
			List_Member__c.SObjectType
		);

		queryFactory.selectFields(getSObjectFieldList());

		queryFactory.setCondition('List__c IN :listIds AND Contact__c IN :contactIds');

		return executeQuery(queryFactory);
	}

	/**
	 * @description
	 * Returns member counts grouped by List__c.
	 *
	 * @param listIds
	 * List__c Ids.
	 *
	 * @return
	 * Map of List__c Id to member count.
	 */
	public Map<Id, Integer> selectMemberCounts(Set<Id> listIds) {
		Map<Id, Integer> result = new Map<Id, Integer>();

		if (listIds == null || listIds.isEmpty()) {
			return result;
		}

		for (AggregateResult ar : [
			SELECT List__c listId, COUNT(Id) cnt
			FROM List_Member__c
			WHERE List__c IN :listIds
			WITH USER_MODE
			GROUP BY List__c
		]) {
			result.put((Id) ar.get('listId'), ((Decimal) ar.get('cnt')).intValue());
		}

		return result;
	}

	/**
	 * @description
	 * Selects existing list members grouped by list and contact.
	 *
	 * @param listIds
	 * List__c Ids.
	 *
	 * @param contactIds
	 * Contact Ids.
	 *
	 * @return
	 * Map of List__c Id to Contact Id to List_Member__c.
	 */
	public Map<Id, Map<Id, List_Member__c>> selectExistingByListsAndContacts(
		Set<Id> listIds,
		Set<Id> contactIds
	) {
		Map<Id, Map<Id, List_Member__c>> result = new Map<Id, Map<Id, List_Member__c>>();

		if (
			listIds == null ||
			listIds.isEmpty() ||
			contactIds == null ||
			contactIds.isEmpty()
		) {
			return result;
		}

		fflib_QueryFactory queryFactory = new fflib_QueryFactory(
			List_Member__c.SObjectType
		);

		queryFactory.selectFields(getSObjectFieldList());

		queryFactory.setCondition('List__c IN :listIds AND Contact__c IN :contactIds');

		List<List_Member__c> members = executeQuery(queryFactory);

		for (List_Member__c member : members) {
			if (member.List__c == null || member.Contact__c == null) {
				continue;
			}

			if (!result.containsKey(member.List__c)) {
				result.put(member.List__c, new Map<Id, List_Member__c>());
			}

			result.get(member.List__c).put(member.Contact__c, member);
		}

		return result;
	}

	private static List<List_Member__c> executeQuery(fflib_QueryFactory queryFactory) {
		return (List<List_Member__c>) Database.query(queryFactory.toSOQL());
	}

	private static String buildPagingCondition(
		Id listId,
		Id lastSeenId,
		Boolean contactsOnly
	) {
		String condition = 'List__c = :listId';

		if (lastSeenId != null) {
			condition += ' AND Id > :lastSeenId';
		}

		if (contactsOnly == true) {
			condition += ' AND Contact__c != null';
		}

		return condition;
	}
}
