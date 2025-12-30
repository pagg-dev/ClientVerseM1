/**
 * @description
 * Batch job responsible for copying List_Member__c records
 * from source lists to destination lists based on
 * Source_List__c mappings.
 */
public with sharing class ListMembersCopyBatch implements Database.Batchable<SObject>, Database.Stateful {
	/**
	 * @description
	 * Source list Id → mapping pairs.
	 */
	private Map<Id, List<SourceListService.IdPair>> srcToPairs = new Map<Id, List<SourceListService.IdPair>>();

	/**
	 * @description
	 * All source list Ids involved in this batch.
	 */
	private Set<Id> srcIds = new Set<Id>();

	/**
	 * @description
	 * Constructor.
	 *
	 * @param listPairs
	 * Mapping pairs defining source → destination lists.
	 */
	public ListMembersCopyBatch(List<SourceListService.IdPair> listPairs) {
		if (listPairs == null) {
			return;
		}

		for (SourceListService.IdPair pair : listPairs) {
			if (pair == null || pair.src == null) {
				continue;
			}

			if (!srcToPairs.containsKey(pair.src)) {
				srcToPairs.put(pair.src, new List<SourceListService.IdPair>());
			}

			srcToPairs.get(pair.src).add(pair);
			srcIds.add(pair.src);
		}
	}

	/**
	 * @description
	 * Provides the query locator for source list members.
	 *
	 * @param bc
	 * Batch context.
	 *
	 * @return
	 * QueryLocator for source List_Member__c rows.
	 */
	public Database.QueryLocator start(Database.BatchableContext bc) {
		ListMemberSelector selector = new ListMemberSelector();

		return selector.queryLocatorByListIds(srcIds);
	}

	/**
	 * @description
	 * Executes copy logic for a batch scope.
	 *
	 * @param bc
	 * Batch context.
	 *
	 * @param scope
	 * Current batch of List_Member__c records.
	 */
	public void execute(Database.BatchableContext bc, List<List_Member__c> scope) {
		if (scope == null || scope.isEmpty()) {
			return;
		}

		Map<Id, List<List_Member__c>> membersBySource = groupBySourceList(scope);

		ListMemberSelector selector = new ListMemberSelector();

		for (Id sourceListId : membersBySource.keySet()) {
			List<SourceListService.IdPair> pairs = srcToPairs.get(sourceListId);

			if (pairs == null || pairs.isEmpty()) {
				continue;
			}

			Set<Id> pageContacts = collectContacts(membersBySource.get(sourceListId));

			if (pageContacts.isEmpty()) {
				continue;
			}

			Set<Id> destinationListIds = collectDestinationIds(pairs);

			if (destinationListIds.isEmpty()) {
				continue;
			}

			Map<Id, Map<Id, List_Member__c>> existingByDestAndContact = selector.selectExistingByListsAndContacts(
				destinationListIds,
				pageContacts
			);

			processPairs(pairs, pageContacts, existingByDestAndContact);
		}
	}

	/**
	 * @description
	 * Finish method (no-op).
	 *
	 * @param bc
	 * Batch context.
	 */
	public void finish(Database.BatchableContext bc) {
		// No post-processing required
	}

	private static Map<Id, List<List_Member__c>> groupBySourceList(
		List<List_Member__c> members
	) {
		Map<Id, List<List_Member__c>> result = new Map<Id, List<List_Member__c>>();

		for (List_Member__c member : members) {
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

	private static Set<Id> collectContacts(List<List_Member__c> members) {
		Set<Id> contacts = new Set<Id>();

		for (List_Member__c member : members) {
			if (member.Contact__c != null) {
				contacts.add(member.Contact__c);
			}
		}

		return contacts;
	}

	private static Set<Id> collectDestinationIds(List<SourceListService.IdPair> pairs) {
		Set<Id> destinationIds = new Set<Id>();

		for (SourceListService.IdPair pair : pairs) {
			if (pair != null && pair.dest != null) {
				destinationIds.add(pair.dest);
			}
		}

		return destinationIds;
	}

	private static void processPairs(
		List<SourceListService.IdPair> pairs,
		Set<Id> pageContacts,
		Map<Id, Map<Id, List_Member__c>> existingByDestAndContact
	) {
		List<List_Member__c> inserts = new List<List_Member__c>();

		List<List_Member__c> updates = new List<List_Member__c>();

		for (SourceListService.IdPair pair : pairs) {
			if (pair == null || pair.dest == null) {
				continue;
			}

			Map<Id, List_Member__c> existingForDest = existingByDestAndContact.containsKey(
					pair.dest
				)
				? existingByDestAndContact.get(pair.dest)
				: new Map<Id, List_Member__c>();

			for (Id contactId : pageContacts) {
				if (!existingForDest.containsKey(contactId)) {
					inserts.add(buildNewMember(pair, contactId));
				} else {
					List_Member__c existing = existingForDest.get(contactId);

					if (!ListUtil.csvContains(existing.Source_Lists__c, pair.src)) {
						existing.Source_Lists__c = ListUtil.csvAdd(
							existing.Source_Lists__c,
							pair.src
						);

						if ('Inclusion' == pair.sourceListType) {
							existing.Status__c = 'Included';
						}

						updates.add(existing);
					}
				}
			}
		}

		commitChanges(inserts, updates);
	}

	private static List_Member__c buildNewMember(
		SourceListService.IdPair pair,
		Id contactId
	) {
		List_Member__c record = new List_Member__c(
			List__c = pair.dest,
			Contact__c = contactId,
			Source_Lists__c = String.valueOf(pair.src)
		);

		if (pair.sourceListType != null) {
			record.Status__c = pair.sourceListType == 'Exclusion'
				? 'Excluded'
				: 'Included';
		}

		return record;
	}

	private static void commitChanges(
		List<List_Member__c> inserts,
		List<List_Member__c> updates
	) {
		if (inserts.isEmpty() && updates.isEmpty()) {
			return;
		}

		fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(
			new List<Schema.SObjectType>{ List_Member__c.SObjectType }
		);

		for (SObject record : inserts) {
			uow.registerNew(record);
		}

		for (SObject record : updates) {
			uow.registerDirty(record);
		}

		try {
			uow.commitWork();
		} catch (Exception e) {
			LogService.logError(
				'List Member Copy Batch',
				e,
				new Map<String, Object>{ 'inserts' => inserts, 'updates' => updates }
			);
		}
	}
}
