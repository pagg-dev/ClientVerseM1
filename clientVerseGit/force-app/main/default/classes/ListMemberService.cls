/**
 * @description
 * Service responsible for synchronizing list and campaign members
 * based on Source_List__c mappings.
 */
public with sharing class ListMemberService implements IListMemberService {
	/**
	 * @description
	 * Context object holding all data required to evaluate and apply
	 * member removal rules during source list unmapping.
	 */
	private class RemovalContext {
		/**
		 * @description
		 * Removal snapshots representing source list unmapping
		 * and the target destination members.
		 */
		public List<Snapshot> snapshots;

		/**
		 * @description
		 * Existing List_Member__c records grouped by destination List Id.
		 */
		public Map<Id, List<List_Member__c>> listMembers;

		/**
		 * @description
		 * Existing CampaignMember records grouped by destination Campaign Id.
		 */
		public Map<Id, List<CampaignMember>> campaignMembers;

		/**
		 * @description
		 * Destination members that require Source_Lists__c updates
		 * after source list removal.
		 */
		public List<SObject> membersToUpdate = new List<SObject>();

		/**
		 * @description
		 * Destination members that should be deleted after
		 * evaluating source list attribution.
		 */
		public List<SObject> membersToDelete = new List<SObject>();
	}

	/**
	 * @description
	 * Enqueues asynchronous copy of members for mappings.
	 *
	 * @param mappingIds
	 * Source_List__c mapping Ids.
	 */
	public void enqueueSyncCopyMembers(Set<Id> mappingIds) {
		if (mappingIds == null || mappingIds.isEmpty()) {
			return;
		}

		System.enqueueJob(new SyncCopyMembersJob(mappingIds));
	}

	/**
	 * @description
	 * Enqueues asynchronous removal of members for mappings.
	 *
	 * @param mappingToContactIds
	 * Map of mapping Ids to Contact Ids to remove.
	 */
	public void enqueueSyncRemoveMembers(Map<Id, Set<Id>> mappingToContactIds) {
		if (mappingToContactIds == null || mappingToContactIds.isEmpty()) {
			return;
		}

		List<Snapshot> snapshots = buildSnapshots(mappingToContactIds);

		if (!snapshots.isEmpty()) {
			System.enqueueJob(new SyncRemoveMembersJob(snapshots));
		}
	}

	/**
	 * @description
	 * Snapshot of removal targets for async processing.
	 */
	public class Snapshot {
		public Id sourceListId;
		public Id destListId;
		public Id destCampaignId;
		public List<Id> contactIds;
	}

	/**
	 * @description
	 * Builds snapshots for async removal jobs.
	 *
	 * @param mappingToContactIds
	 * Map of mapping Ids to Contact Ids.
	 *
	 * @return
	 * List of removal snapshots.
	 */
	private static List<Snapshot> buildSnapshots(Map<Id, Set<Id>> mappingToContactIds) {
		List<Snapshot> results = new List<Snapshot>();

		List<Source_List__c> mappings = new SourceListSelector()
			.selectByIds(mappingToContactIds.keySet());

		for (Source_List__c mapping : mappings) {
			Set<Id> contacts = mappingToContactIds.get(mapping.Id);

			if (contacts == null || contacts.isEmpty()) {
				continue;
			}

			Snapshot snapshot = new Snapshot();
			snapshot.sourceListId = mapping.Source_List__c;
			snapshot.destListId = mapping.Destination_List__c;
			snapshot.destCampaignId = mapping.Destination_Campaign__c;
			snapshot.contactIds = new List<Id>(contacts);

			results.add(snapshot);
		}

		return results;
	}

	/**
	 * @description
	 * Queueable job that performs copy operations.
	 */
	public class SyncCopyMembersJob implements Queueable {
		private Set<Id> mappingIds;

		/**
		 * @description
		 * Constructor.
		 *
		 * @param mappingIds
		 * Source_List__c mapping Ids.
		 */
		public SyncCopyMembersJob(Set<Id> mappingIds) {
			this.mappingIds = mappingIds == null
				? new Set<Id>()
				: new Set<Id>(mappingIds);
		}

		/**
		 * @description
		 * Executes the copy logic.
		 *
		 * @param ctx
		 * Queueable context.
		 */
		public void execute(QueueableContext ctx) {
			SourceListService.Snapshot snapshot = new SourceListService()
				.buildSnapshot(mappingIds);

			if (!snapshot.listPairs.isEmpty()) {
				Database.executeBatch(new ListMembersCopyBatch(snapshot.listPairs), 200);
			}
		}
	}

	/**
	 * @description
	 * Queueable job that removes specific members
	 * from destination lists and campaigns.
	 */
	public class SyncRemoveMembersJob implements Queueable {
		private List<Snapshot> snapshots;

		/**
		 * @description
		 * Constructor.
		 *
		 * @param snapshots
		 * Removal snapshots.
		 */
		public SyncRemoveMembersJob(List<Snapshot> snapshots) {
			this.snapshots = snapshots == null ? new List<Snapshot>() : snapshots;
		}

		/**
		 * @description
		 * Executes the removal logic.
		 *
		 * @param ctx
		 * Queueable context.
		 */
		public void execute(QueueableContext ctx) {
			Set<Id> destListIds = new Set<Id>();
			Set<Id> destCampaignIds = new Set<Id>();
			Set<Id> allContactIds = new Set<Id>();

			collectTargets(snapshots, destListIds, destCampaignIds, allContactIds);

			if (allContactIds.isEmpty()) {
				return;
			}

			Map<Id, List<List_Member__c>> listMembers = queryListMembers(
				destListIds,
				allContactIds
			);

			Map<Id, List<CampaignMember>> campaignMembers = queryCampaignMembers(
				destCampaignIds,
				allContactIds
			);

			RemovalContext removalctx = new RemovalContext();
			removalctx.snapshots = snapshots;
			removalctx.listMembers = listMembers;
			removalctx.campaignMembers = campaignMembers;

			applyRemovalRules(removalctx);
			commitChanges(removalctx.membersToUpdate, removalctx.membersToDelete);
		}
	}

	private static void collectTargets(
		List<Snapshot> snapshots,
		Set<Id> destListIds,
		Set<Id> destCampaignIds,
		Set<Id> allContactIds
	) {
		for (Snapshot snapshot : snapshots) {
			if (snapshot.contactIds != null && !snapshot.contactIds.isEmpty()) {
				allContactIds.addAll(snapshot.contactIds);
			}

			if (snapshot.destListId != null) {
				destListIds.add(snapshot.destListId);
			}

			if (snapshot.destCampaignId != null) {
				destCampaignIds.add(snapshot.destCampaignId);
			}
		}
	}

	private static Map<Id, List<List_Member__c>> queryListMembers(
		Set<Id> destListIds,
		Set<Id> allContactIds
	) {
		Map<Id, List<List_Member__c>> result = new Map<Id, List<List_Member__c>>();

		if (destListIds.isEmpty() || allContactIds.isEmpty()) {
			return result;
		}

		final Integer chunkSize = 5000;
		List<Id> contacts = new List<Id>(allContactIds);

		for (Integer i = 0; i < contacts.size(); i += chunkSize) {
			Integer endIdx = Math.min(i + chunkSize, contacts.size());

			List<Id> slice = ListUtil.sliceIds(contacts, i, endIdx);

			for (
				List_Member__c lm : new ListMemberSelector()
					.selectByListsAndContacts(destListIds, slice)
			) {
				if (!result.containsKey(lm.List__c)) {
					result.put(lm.List__c, new List<List_Member__c>());
				}

				result.get(lm.List__c).add(lm);
			}
		}

		return result;
	}

	private static Map<Id, List<CampaignMember>> queryCampaignMembers(
		Set<Id> destCampaignIds,
		Set<Id> allContactIds
	) {
		Map<Id, List<CampaignMember>> result = new Map<Id, List<CampaignMember>>();

		if (destCampaignIds.isEmpty() || allContactIds.isEmpty()) {
			return result;
		}

		final Integer chunkSize = 5000;
		List<Id> contacts = new List<Id>(allContactIds);

		for (Integer i = 0; i < contacts.size(); i += chunkSize) {
			Integer endIdx = Math.min(i + chunkSize, contacts.size());

			List<Id> slice = ListUtil.sliceIds(contacts, i, endIdx);

			for (
				CampaignMember cm : new CampaignMemberSelector()
					.selectByCampaignsAndContacts(destCampaignIds, slice)
			) {
				if (!result.containsKey(cm.CampaignId)) {
					result.put(cm.CampaignId, new List<CampaignMember>());
				}

				result.get(cm.CampaignId).add(cm);
			}
		}

		return result;
	}

	/**
	 * @description
	 * Applies source list removal rules to destination List and
	 * Campaign members using CSV-based source attribution.
	 *
	 * @param ctx
	 * Removal context containing snapshots, queried members,
	 * and mutation collections.
	 */
	private static void applyRemovalRules(RemovalContext ctx) {
		for (Snapshot snapshot : ctx.snapshots) {
			if (snapshot.contactIds == null || snapshot.contactIds.isEmpty()) {
				continue;
			}

			Set<Id> targets = new Set<Id>(snapshot.contactIds);

			// ---- LIST MEMBERS ----
			if (
				snapshot.destListId != null &&
				ctx.listMembers.containsKey(snapshot.destListId)
			) {
				for (List_Member__c lm : ctx.listMembers.get(snapshot.destListId)) {
					if (!targets.contains(lm.Contact__c)) {
						continue;
					}

					String csv = lm.Source_Lists__c;

					if (ListUtil.csvContains(csv, snapshot.sourceListId)) {
						csv = ListUtil.csvRemove(csv, snapshot.sourceListId);
					}

					if (String.isBlank(csv)) {
						ctx.membersToDelete.add(lm);
					} else {
						lm.Source_Lists__c = csv;
						ctx.membersToUpdate.add(lm);
					}
				}
			}

			// ---- CAMPAIGN MEMBERS ----
			if (
				snapshot.destCampaignId != null &&
				ctx.campaignMembers.containsKey(snapshot.destCampaignId)
			) {
				for (
					CampaignMember cm : ctx.campaignMembers.get(snapshot.destCampaignId)
				) {
					if (targets.contains(cm.ContactId)) {
						ctx.membersToDelete.add(cm);
					}
				}
			}
		}
	}

	private static void commitChanges(List<SObject> toUpdate, List<SObject> toDelete) {
		if (toUpdate.isEmpty() && toDelete.isEmpty()) {
			return;
		}

		fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(
			new List<Schema.SObjectType>{
				List_Member__c.SObjectType,
				CampaignMember.SObjectType
			}
		);

		for (SObject r : toUpdate) {
			uow.registerDirty(r);
		}

		for (SObject r : toDelete) {
			uow.registerDeleted(r);
		}

		uow.commitWork();
	}
}
