/**
 * @description
 * Batch job responsible for removing or updating List_Member__c
 * records when source list mappings are removed.
 */
public with sharing class ListMembersRemoveBatch implements Database.Batchable<SObject>, Database.Stateful {
	/**
	 * @description
	 * Destination List Id to source/destination pair mappings.
	 */
	private Map<Id, List<SourceListService.IdPair>> destToPairs = new Map<Id, List<SourceListService.IdPair>>();

	/**
	 * @description
	 * Destination List__c Ids to process.
	 */
	private Set<Id> destIds = new Set<Id>();

	/**
	 * @description
	 * Constructor initializing destination mappings.
	 *
	 * @param listPairs
	 * Source to destination list mappings.
	 */
	public ListMembersRemoveBatch(List<SourceListService.IdPair> listPairs) {
		if (listPairs == null || listPairs.isEmpty()) {
			return;
		}

		for (SourceListService.IdPair pair : listPairs) {
			registerPair(pair);
		}
	}

	/**
	 * @description
	 * Starts the batch by querying List_Member__c records
	 * for destination lists.
	 *
	 * @param bc
	 * Batch context.
	 *
	 * @return
	 * QueryLocator for List_Member__c records.
	 */
	public Database.QueryLocator start(Database.BatchableContext bc) {
		ListMemberSelector selector = new ListMemberSelector();
		return selector.queryLocatorByListIds(destIds);
	}

	/**
	 * @description
	 * Executes removal logic for a batch scope.
	 *
	 * @param bc
	 * Batch context.
	 *
	 * @param scope
	 * List_Member__c records in scope.
	 */
	public void execute(Database.BatchableContext bc, List<List_Member__c> scope) {
		if (scope == null || scope.isEmpty()) {
			return;
		}

		Map<Id, List<List_Member__c>> membersByDest = groupMembersByDestination(scope);

		ListMemberSelector selector = new ListMemberSelector();

		for (Id destId : membersByDest.keySet()) {
			processDestination(destId, membersByDest.get(destId), selector);
		}
	}

	/**
	 * @description
	 * Finish handler (no-op).
	 *
	 * @param bc
	 * Batch context.
	 */
	public void finish(Database.BatchableContext bc) {
	}

	private void registerPair(SourceListService.IdPair pair) {
		if (pair == null || pair.dest == null) {
			return;
		}

		if (!destToPairs.containsKey(pair.dest)) {
			destToPairs.put(pair.dest, new List<SourceListService.IdPair>());
		}

		destToPairs.get(pair.dest).add(pair);
		destIds.add(pair.dest);
	}

	private static Map<Id, List<List_Member__c>> groupMembersByDestination(
		List<List_Member__c> scope
	) {
		Map<Id, List<List_Member__c>> result = new Map<Id, List<List_Member__c>>();

		for (List_Member__c member : scope) {
			if (member == null || member.List__c == null || member.Contact__c == null) {
				continue;
			}

			if (!result.containsKey(member.List__c)) {
				result.put(member.List__c, new List<List_Member__c>());
			}

			result.get(member.List__c).add(member);
		}

		return result;
	}

	private void processDestination(
		Id destId,
		List<List_Member__c> members,
		ListMemberSelector selector
	) {
		List<SourceListService.IdPair> pairs = destToPairs.get(destId);

		if (pairs == null || pairs.isEmpty()) {
			return;
		}

		Set<Id> pageContacts = collectContacts(members);

		if (pageContacts.isEmpty()) {
			return;
		}

		Set<Id> srcIds = collectSourceIds(pairs);

		Map<Id, Map<Id, List_Member__c>> existsInSrc = selector.selectExistingByListsAndContacts(
			srcIds,
			pageContacts
		);

		Set<Id> existsInSrcContacts = flattenExistingContacts(existsInSrc);

		List<List_Member__c> toUpdate = new List<List_Member__c>();

		List<List_Member__c> toDelete = new List<List_Member__c>();

		evaluateMembers(members, pairs, existsInSrcContacts, toUpdate, toDelete);

		commitChanges(toUpdate, toDelete);
	}

	private static Set<Id> collectContacts(List<List_Member__c> members) {
		Set<Id> contacts = new Set<Id>();

		for (List_Member__c member : members) {
			if (member != null && member.Contact__c != null) {
				contacts.add(member.Contact__c);
			}
		}

		return contacts;
	}

	private static Set<Id> collectSourceIds(List<SourceListService.IdPair> pairs) {
		Set<Id> srcIds = new Set<Id>();

		for (SourceListService.IdPair pair : pairs) {
			if (pair != null && pair.src != null) {
				srcIds.add(pair.src);
			}
		}

		return srcIds;
	}

	private static Set<Id> flattenExistingContacts(
		Map<Id, Map<Id, List_Member__c>> existsInSrc
	) {
		Set<Id> contacts = new Set<Id>();

		for (Id srcId : existsInSrc.keySet()) {
			contacts.addAll(existsInSrc.get(srcId).keySet());
		}

		return contacts;
	}

	private static void evaluateMembers(
		List<List_Member__c> members,
		List<SourceListService.IdPair> pairs,
		Set<Id> existsInSrcContacts,
		List<List_Member__c> toUpdate,
		List<List_Member__c> toDelete
	) {
		for (List_Member__c member : members) {
			if (member == null || member.Contact__c == null) {
				continue;
			}

			Boolean hadChange = false;
			String csv = member.Source_Lists__c;

			for (SourceListService.IdPair pair : pairs) {
				if (pair == null || pair.src == null) {
					continue;
				}

				if (ListUtil.csvContains(csv, pair.src)) {
					csv = ListUtil.csvRemove(csv, pair.src);
					hadChange = true;
				}
			}

			if (hadChange) {
				if (String.isBlank(csv)) {
					toDelete.add(member);
				} else {
					member.Source_Lists__c = csv;
					toUpdate.add(member);
				}
				continue;
			}

			if (
				existsInSrcContacts.contains(member.Contact__c) &&
				String.isBlank(member.Source_Lists__c)
			) {
				toDelete.add(member);
			}
		}
	}

	private static void commitChanges(
		List<List_Member__c> toUpdate,
		List<List_Member__c> toDelete
	) {
		if (toUpdate.isEmpty() && toDelete.isEmpty()) {
			return;
		}

		fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(
			new List<Schema.SObjectType>{ List_Member__c.SObjectType }
		);

		for (SObject record : toUpdate) {
			uow.registerDirty(record);
		}

		for (SObject record : toDelete) {
			uow.registerDeleted(record);
		}

		uow.commitWork();
	}
}
