public with sharing class ListMemberSelector extends fflib_SObjectSelector {
	public ListMemberSelector() {
		super();
	}

	public List<Schema.SObjectField> getSObjectFieldList() {
		return new List<Schema.SObjectField>{
			List_Member__c.Id,
			List_Member__c.List__c,
			List_Member__c.Contact__c,
			List_Member__c.Source_Lists__c,
			List_Member__c.Status__c
		};
	}

	public Schema.SObjectType getSObjectType() {
		return List_Member__c.SObjectType;
	}

	public List<List_Member__c> selectByListIds(Set<Id> listIds) {
		if (listIds == null || listIds.isEmpty())
			return new List<List_Member__c>();

		fflib_QueryFactory qf = newQueryFactory();
		qf.setCondition('List__c IN :listIds AND Contact__c != null');

		return (List<List_Member__c>) Database.query(qf.toSOQL());
	}

	public Database.QueryLocator queryLocatorByListIds(Set<Id> listIds) {
		if (listIds == null || listIds.isEmpty())
			return null;

		fflib_QueryFactory qf = newQueryFactory();
		qf.setCondition('List__c IN :listIds AND Contact__c != null');
		qf.setOrdering(
			new fflib_QueryFactory.Ordering(
				List_Member__c.Id,
				fflib_QueryFactory.SortOrder.ASCENDING,
				false
			)
		);

		return Database.getQueryLocator(qf.toSOQL());
	}

	public List<List_Member__c> selectPage(
		Id listId,
		Id lastSeenId,
		Integer size,
		Boolean contactsOnly
	) {
		if (listId == null)
			return new List<List_Member__c>();
		Integer limitSize = (size == null) ? 2000 : size;

		fflib_QueryFactory qf = new fflib_QueryFactory(List_Member__c.SObjectType);
		qf.selectFields(getSObjectFieldList());

		String cond = 'List__c = :listId';
		if (lastSeenId != null)
			cond += ' AND Id > :lastSeenId';
		if (contactsOnly != null && contactsOnly)
			cond += ' AND Contact__c != null';
		qf.setCondition(cond);

		// deterministic paging by ordering on Id ascending
		qf.setOrdering(
			new fflib_QueryFactory.Ordering(
				List_Member__c.Id,
				fflib_QueryFactory.SortOrder.ASCENDING,
				false
			)
		);
		qf.setLimit(limitSize);

		return (List<List_Member__c>) Database.query(qf.toSOQL());
	}

	public List<List_Member__c> selectByListAndContacts(Id listId, Set<Id> contactIds) {
		if (listId == null || contactIds == null || contactIds.isEmpty())
			return new List<List_Member__c>();

		fflib_QueryFactory qf = new fflib_QueryFactory(List_Member__c.SObjectType);
		qf.selectFields(getSObjectFieldList());
		qf.setCondition('List__c = :listId AND Contact__c IN :contactIds');

		return (List<List_Member__c>) Database.query(qf.toSOQL());
	}

	public Map<Id, Integer> selectMemberCounts(Set<Id> listIds) {
		Map<Id, Integer> result = new Map<Id, Integer>();
		if (listIds == null || listIds.isEmpty())
			return result;

		for (AggregateResult ar : [
			SELECT List__c listId, COUNT(Id) cnt
			FROM List_Member__c
			WHERE List__c IN :listIds
			GROUP BY List__c
		]) {
			result.put((Id) ar.get('listId'), ((Decimal) ar.get('cnt')).intValue());
		}
		return result;
	}

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
		)
			return result;

        fflib_QueryFactory qf = new fflib_QueryFactory(List_Member__c.SObjectType);
		qf.selectFields(getSObjectFieldList());
        qf.setCondition('List__c IN :listIds AND Contact__c IN :contactIds');

        List<List_Member__c> lms = Database.query(qf.toSOQL());

		for (List_Member__c lm : lms) {
			if (lm.List__c == null || lm.Contact__c == null)
				continue;
			if (!result.containsKey(lm.List__c))
				result.put(lm.List__c, new Map<Id, List_Member__c>());
			result.get(lm.List__c).put(lm.Contact__c, lm);
		}
		return result;
	}
}