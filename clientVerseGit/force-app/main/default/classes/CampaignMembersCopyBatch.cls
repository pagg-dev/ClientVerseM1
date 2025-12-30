/**
 * @description
 * Batch job responsible for copying CampaignMember records
 * from source campaigns to destination campaigns based on
 * Source_List__c mappings.
 */
public with sharing class CampaignMembersCopyBatch implements Database.Batchable<SObject>, Database.Stateful {
	/**
	 * @description
	 * Source Campaign Id → mapping pairs.
	 */
	private Map<Id, List<SourceListService.IdPair>> srcToPairs = new Map<Id, List<SourceListService.IdPair>>();

	/**
	 * @description
	 * All source Campaign Ids involved in this batch.
	 */
	private Set<Id> srcIds = new Set<Id>();

	/**
	 * @description
	 * Constructor.
	 *
	 * @param campPairs
	 * Mapping pairs defining source → destination campaigns.
	 */
	public CampaignMembersCopyBatch(List<SourceListService.IdPair> campPairs) {
		if (campPairs == null) {
			return;
		}

		for (SourceListService.IdPair pair : campPairs) {
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
	 * Provides the query locator for source CampaignMember rows.
	 *
	 * @param bc
	 * Batch context.
	 *
	 * @return
	 * QueryLocator for CampaignMember records.
	 */
	public Database.QueryLocator start(Database.BatchableContext bc) {
		CampaignMemberSelector selector = new CampaignMemberSelector();

		return selector.queryLocatorByCampaignIds(srcIds);
	}

	/**
	 * @description
	 * Executes copy logic for a batch scope.
	 *
	 * @param bc
	 * Batch context.
	 *
	 * @param scope
	 * Current batch of CampaignMember records.
	 */
	public void execute(Database.BatchableContext bc, List<CampaignMember> scope) {
		if (scope == null || scope.isEmpty()) {
			return;
		}

		Map<Id, List<CampaignMember>> membersBySource = groupBySourceCampaign(scope);

		CampaignMemberSelector selector = new CampaignMemberSelector();

		for (Id sourceCampaignId : membersBySource.keySet()) {
			List<SourceListService.IdPair> pairs = srcToPairs.get(sourceCampaignId);

			if (pairs == null || pairs.isEmpty()) {
				continue;
			}

			Set<Id> contactIds = collectContacts(membersBySource.get(sourceCampaignId));

			if (contactIds.isEmpty()) {
				continue;
			}

			Set<Id> destinationCampaignIds = collectDestinationIds(pairs);

			if (destinationCampaignIds.isEmpty()) {
				continue;
			}

			Map<Id, Map<Id, CampaignMember>> existingByDestAndContact = selector.selectExistingByCampaignsAndContacts(
				destinationCampaignIds,
				contactIds
			);

			processPairs(pairs, contactIds, existingByDestAndContact);
		}
	}

	/**
	 * @description
	 * Finish method (no-op).
	 *
	 * @param bc
	 * Batch context.
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock')
	public void finish(Database.BatchableContext bc) {
		// No post-processing required
	}

	private static Map<Id, List<CampaignMember>> groupBySourceCampaign(
		List<CampaignMember> members
	) {
		Map<Id, List<CampaignMember>> result = new Map<Id, List<CampaignMember>>();

		for (CampaignMember member : members) {
			if (member == null || member.CampaignId == null || member.ContactId == null) {
				continue;
			}

			if (!result.containsKey(member.CampaignId)) {
				result.put(member.CampaignId, new List<CampaignMember>());
			}

			result.get(member.CampaignId).add(member);
		}

		return result;
	}

	private static Set<Id> collectContacts(List<CampaignMember> members) {
		Set<Id> contacts = new Set<Id>();

		for (CampaignMember member : members) {
			if (member.ContactId != null) {
				contacts.add(member.ContactId);
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
		Set<Id> contactIds,
		Map<Id, Map<Id, CampaignMember>> existingByDestAndContact
	) {
		List<CampaignMember> inserts = new List<CampaignMember>();

		List<CampaignMember> updates = new List<CampaignMember>();

		for (SourceListService.IdPair pair : pairs) {
			if (pair == null || pair.dest == null) {
				continue;
			}

			Map<Id, CampaignMember> existingForDest = existingByDestAndContact.containsKey(
					pair.dest
				)
				? existingByDestAndContact.get(pair.dest)
				: new Map<Id, CampaignMember>();

			for (Id contactId : contactIds) {
				if (!existingForDest.containsKey(contactId)) {
					inserts.add(buildNewMember(pair, contactId));
				} else {
					CampaignMember existing = existingForDest.get(contactId);

					if (
						!ListUtil.csvContains(
							(String) existing.get('Source_Lists__c'),
							pair.src
						)
					) {
						existing.put(
							'Source_Lists__c',
							ListUtil.csvAdd(
								(String) existing.get('Source_Lists__c'),
								pair.src
							)
						);

						if ('Inclusion' == pair.sourceListType) {
							existing.put('Status', 'Included');
						}

						updates.add(existing);
					}
				}
			}
		}

		commitChanges(inserts, updates);
	}

	private static CampaignMember buildNewMember(
		SourceListService.IdPair pair,
		Id contactId
	) {
		CampaignMember record = new CampaignMember(
			CampaignId = pair.dest,
			ContactId = contactId
		);

		record.put('Source_Lists__c', String.valueOf(pair.src));

		if (pair.sourceListType != null) {
			if (pair.sourceListType == 'Exclusion') {
				record.put('Status', 'Excluded');
			} else if (pair.sourceListType == 'Inclusion') {
				record.put('Status', 'Included');
			}
		}

		return record;
	}

	private static void commitChanges(
		List<CampaignMember> inserts,
		List<CampaignMember> updates
	) {
		if (inserts.isEmpty() && updates.isEmpty()) {
			return;
		}

		fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(
			new List<Schema.SObjectType>{ CampaignMember.SObjectType }
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
				'Campaign Member Copy Batch',
				e,
				new Map<String, Object>{ 'inserts' => inserts, 'updates' => updates }
			);
		}
	}
}
