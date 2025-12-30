/**
 * @description
 * Batch job responsible for removing CampaignMember records
 * from destination campaigns based on Source_List__c mappings.
 * Handles partial removals via Source_Lists__c CSV tracking.
 */
public with sharing class CampaignMembersRemoveBatch implements Database.Batchable<SObject>, Database.Stateful {
	/**
	 * @description
	 * Destination Campaign Id → mapping pairs.
	 */
	private Map<Id, List<SourceListService.IdPair>> destToPairs = new Map<Id, List<SourceListService.IdPair>>();

	/**
	 * @description
	 * All destination Campaign Ids involved in this batch.
	 */
	private Set<Id> destIds = new Set<Id>();

	/**
	 * @description
	 * Constructor.
	 *
	 * @param campPairs
	 * Mapping pairs defining source → destination campaigns.
	 */
	public CampaignMembersRemoveBatch(List<SourceListService.IdPair> campPairs) {
		if (campPairs == null) {
			return;
		}

		for (SourceListService.IdPair pair : campPairs) {
			if (pair == null || pair.dest == null) {
				continue;
			}

			if (!destToPairs.containsKey(pair.dest)) {
				destToPairs.put(pair.dest, new List<SourceListService.IdPair>());
			}

			destToPairs.get(pair.dest).add(pair);
			destIds.add(pair.dest);
		}
	}

	/**
	 * @description
	 * Provides the query locator for destination CampaignMember rows.
	 *
	 * @param bc
	 * Batch context.
	 *
	 * @return
	 * QueryLocator for CampaignMember records.
	 */
	public Database.QueryLocator start(Database.BatchableContext bc) {
		CampaignMemberSelector selector = new CampaignMemberSelector();

		return selector.queryLocatorByCampaignIds(destIds);
	}

	/**
	 * @description
	 * Executes removal logic for a batch scope.
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

		Map<Id, List<CampaignMember>> membersByDestination = groupByDestinationCampaign(
			scope
		);

		CampaignMemberSelector selector = new CampaignMemberSelector();

		for (Id destinationCampaignId : membersByDestination.keySet()) {
			List<SourceListService.IdPair> pairs = destToPairs.get(destinationCampaignId);

			if (pairs == null || pairs.isEmpty()) {
				continue;
			}

			Set<Id> pageContacts = collectContacts(
				membersByDestination.get(destinationCampaignId)
			);

			if (pageContacts.isEmpty()) {
				continue;
			}

			Set<Id> sourceCampaignIds = collectSourceIds(pairs);

			Map<Id, Map<Id, CampaignMember>> existingInSource = selector.selectExistingByCampaignsAndContacts(
				sourceCampaignIds,
				pageContacts
			);

			Set<Id> existsInSourceContacts = flattenContactIds(existingInSource);

			processRemovals(
				membersByDestination.get(destinationCampaignId),
				pairs,
				existsInSourceContacts
			);
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

	private static Map<Id, List<CampaignMember>> groupByDestinationCampaign(
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

	private static Set<Id> collectSourceIds(List<SourceListService.IdPair> pairs) {
		Set<Id> sourceIds = new Set<Id>();

		for (SourceListService.IdPair pair : pairs) {
			if (pair != null && pair.src != null) {
				sourceIds.add(pair.src);
			}
		}

		return sourceIds;
	}

	private static Set<Id> flattenContactIds(Map<Id, Map<Id, CampaignMember>> bySource) {
		Set<Id> contacts = new Set<Id>();

		for (Id sourceId : bySource.keySet()) {
			contacts.addAll(bySource.get(sourceId).keySet());
		}

		return contacts;
	}

	private static void processRemovals(
		List<CampaignMember> destMembers,
		List<SourceListService.IdPair> pairs,
		Set<Id> existsInSourceContacts
	) {
		List<CampaignMember> updates = new List<CampaignMember>();

		List<CampaignMember> deletes = new List<CampaignMember>();

		for (CampaignMember member : destMembers) {
			if (member == null || member.ContactId == null) {
				continue;
			}

			Boolean hadChange = false;
			String csv = (String) member.get('Source_Lists__c');

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
					deletes.add(member);
				} else {
					member.put('Source_Lists__c', csv);
					updates.add(member);
				}
				continue;
			}

			if (
				existsInSourceContacts.contains(member.ContactId) &&
				String.isBlank((String) member.get('Source_Lists__c'))
			) {
				deletes.add(member);
			}
		}

		commitChanges(updates, deletes);
	}

	private static void commitChanges(
		List<CampaignMember> updates,
		List<CampaignMember> deletes
	) {
		if (updates.isEmpty() && deletes.isEmpty()) {
			return;
		}

		fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(
			new List<Schema.SObjectType>{ CampaignMember.SObjectType }
		);

		for (SObject record : updates) {
			uow.registerDirty(record);
		}

		for (SObject record : deletes) {
			uow.registerDeleted(record);
		}

		try {
			uow.commitWork();
		} catch (Exception e) {
			LogService.logError(
				'Campaign Member Remove Batch',
				e,
				new Map<String, Object>{ 'deletes' => deletes, 'updates' => updates }
			);
		}
	}
}
