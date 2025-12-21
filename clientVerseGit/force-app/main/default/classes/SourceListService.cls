/**
 * @description
 * Service responsible for managing Source_List__c synchronization,
 * validation, and batch orchestration.
 */
public with sharing class SourceListService implements ISourceListService {
	private static final Integer MAX_DEPTH = 3;
	private static final Integer MEMBER_LIMIT = 50000;

	/**
	 * @description
	 * Enqueues batch jobs to copy list and campaign members.
	 *
	 * @param mappingIds
	 * Set of Source_List__c record Ids.
	 */
	public void enqueueCopy(Set<Id> mappingIds) {
		if (mappingIds == null || mappingIds.isEmpty()) {
			return;
		}

		Snapshot snapshot = buildSnapshot(mappingIds);

		enqueueListCopy(snapshot);
		enqueueCampaignCopy(snapshot);
	}

	/**
	 * @description
	 * Enqueues batch jobs to remove list and campaign members.
	 *
	 * @param mappingIds
	 * Set of Source_List__c record Ids.
	 */
	public void enqueueRemove(Set<Id> mappingIds) {
		if (mappingIds == null || mappingIds.isEmpty()) {
			return;
		}

		Snapshot snapshot = buildSnapshot(mappingIds);

		enqueueListRemove(snapshot);
		enqueueCampaignRemove(snapshot);
	}

	/**
	 * @description
	 * Simple source → destination pairing model.
	 */
	public class IdPair {
		public Id src;
		public Id dest;
		public String sourceListType;

		/**
		 * @description
		 * Default constructor.
		 */
		public IdPair() {
		}

		/**
		 * @description
		 * Constructs an IdPair.
		 *
		 * @param s
		 * Source Id.
		 *
		 * @param d
		 * Destination Id.
		 *
		 * @param type
		 * Source list type.
		 */
		public IdPair(Id s, Id d, String type) {
			this.src = s;
			this.dest = d;
			this.sourceListType = type;
		}
	}

	/**
	 * @description
	 * Snapshot of all derived source → destination relationships.
	 */
	public class Snapshot {
		public List<IdPair> listPairs = new List<IdPair>();
		public List<IdPair> campPairs = new List<IdPair>();

		/**
		 * @description
		 * Default constructor.
		 */
		public Snapshot() {
		}
	}

	/**
	 * @description
	 * Builds a snapshot of source/destination list and campaign pairs.
	 *
	 * @param mappingIds
	 * Source_List__c Ids.
	 *
	 * @return
	 * Snapshot containing derived Id pairs.
	 */
	public Snapshot buildSnapshot(Set<Id> mappingIds) {
		Snapshot snapshot = new Snapshot();

		if (mappingIds == null || mappingIds.isEmpty()) {
			return snapshot;
		}

		List<Source_List__c> mappings = new SourceListSelector().selectByIds(mappingIds);

		for (Source_List__c mapping : mappings) {
			addListPair(mapping, snapshot);
			addCampaignPair(mapping, snapshot);
		}

		return snapshot;
	}

	private static void addListPair(Source_List__c mapping, Snapshot snapshot) {
		if (mapping == null) {
			return;
		}

		if (mapping.Source_List__c != null && mapping.Destination_List__c != null) {
			snapshot.listPairs.add(
				new IdPair(
					mapping.Source_List__c,
					mapping.Destination_List__c,
					mapping.Source_List_Type__c
				)
			);
		}
	}

	private static void addCampaignPair(Source_List__c mapping, Snapshot snapshot) {
		if (mapping == null) {
			return;
		}

		if (
			mapping.Source_Campaign__c != null &&
			mapping.Destination_Campaign__c != null
		) {
			snapshot.campPairs.add(
				new IdPair(
					mapping.Source_Campaign__c,
					mapping.Destination_Campaign__c,
					mapping.Source_List_Type__c
				)
			);
		}
	}

	private static void enqueueListCopy(Snapshot snapshot) {
		if (!snapshot.listPairs.isEmpty()) {
			Database.executeBatch(new ListMembersCopyBatch(snapshot.listPairs), 200);
		}
	}

	private static void enqueueCampaignCopy(Snapshot snapshot) {
		if (!snapshot.campPairs.isEmpty()) {
			Database.executeBatch(new CampaignMembersCopyBatch(snapshot.campPairs), 200);
		}
	}

	private static void enqueueListRemove(Snapshot snapshot) {
		if (!snapshot.listPairs.isEmpty()) {
			Database.executeBatch(new ListMembersRemoveBatch(snapshot.listPairs), 200);
		}
	}

	private static void enqueueCampaignRemove(Snapshot snapshot) {
		if (!snapshot.campPairs.isEmpty()) {
			Database.executeBatch(
				new CampaignMembersRemoveBatch(snapshot.campPairs),
				200
			);
		}
	}

	/**
	 * @description
	 * Validates Source_List__c inserts for cycles, depth,
	 * and member count limits.
	 *
	 * @param newRecords
	 * Incoming Source_List__c records.
	 */
	public static void validateSourceListInserts(List<Source_List__c> newRecords) {
		if (newRecords == null || newRecords.isEmpty()) {
			return;
		}

		Set<Id> involvedListIds = collectInvolvedListIds(newRecords);

		if (involvedListIds.isEmpty()) {
			return;
		}

		List<Source_List__c> edges = collectAllEdges(involvedListIds, newRecords);

		Map<Id, Set<Id>> adjForward = buildForwardAdjacency(edges);

		Map<Id, Set<Id>> adjReverse = buildReverseAdjacency(edges);

		Map<Id, Integer> memberCounts = new ListMemberSelector()
			.selectMemberCounts(involvedListIds);

		validateEachRecord(newRecords, adjForward, adjReverse, memberCounts);
	}

	private static Set<Id> collectInvolvedListIds(List<Source_List__c> records) {
		Set<Id> ids = new Set<Id>();

		for (Source_List__c record : records) {
			if (record == null) {
				continue;
			}

			if (record.Source_List__c != null) {
				ids.add(record.Source_List__c);
			}

			if (record.Destination_List__c != null) {
				ids.add(record.Destination_List__c);
			}
		}

		return ids;
	}

	private static List<Source_List__c> collectAllEdges(
		Set<Id> involvedListIds,
		List<Source_List__c> newRecords
	) {
		List<Source_List__c> edges = new List<Source_List__c>();

		edges.addAll(
			new SourceListSelector().selectEdgesBounded(involvedListIds, MAX_DEPTH)
		);

		edges.addAll(selectReverseEdgesBounded(involvedListIds, MAX_DEPTH));

		for (Source_List__c record : newRecords) {
			if (record != null) {
				edges.add(record);
			}
		}

		return edges;
	}

	private static void validateEachRecord(
		List<Source_List__c> records,
		Map<Id, Set<Id>> adjForward,
		Map<Id, Set<Id>> adjReverse,
		Map<Id, Integer> memberCounts
	) {
		for (Source_List__c record : records) {
			if (record == null) {
				continue;
			}

			Id src = record.Source_List__c;
			Id dest = record.Destination_List__c;

			if (src == null || dest == null) {
				continue;
			}

			if (wouldCreateCycle(adjForward, src, dest)) {
				record.addError('This mapping would create a cycle (loop).');
				continue;
			}

			Integer depth = computeCombinedDepth(adjForward, adjReverse, src, dest);

			if (depth > MAX_DEPTH) {
				record.addError(
					'This mapping exceeds the maximum depth of ' + MAX_DEPTH + '.'
				);
				continue;
			}

			Integer projected =
				getMemberCount(memberCounts, src) + getMemberCount(memberCounts, dest);

			if (projected >= MEMBER_LIMIT) {
				record.addError(
					'Combined member count exceeds limit of ' + MEMBER_LIMIT + '.'
				);
			}
		}
	}

	private static Integer getMemberCount(Map<Id, Integer> counts, Id listId) {
		if (counts == null || !counts.containsKey(listId)) {
			return 0;
		}

		return counts.get(listId);
	}

	private static List<Source_List__c> selectReverseEdgesBounded(
		Set<Id> startListIds,
		Integer maxDepth
	) {
		List<Source_List__c> results = new List<Source_List__c>();

		if (
			startListIds == null ||
			startListIds.isEmpty() ||
			maxDepth == null ||
			maxDepth <= 0
		) {
			return results;
		}

		Set<Id> frontier = new Set<Id>(startListIds);
		Set<Id> visited = new Set<Id>(frontier);

		SourceListSelector selector = new SourceListSelector();

		for (Integer level = 1; level <= maxDepth; level++) {
			if (frontier.isEmpty()) {
				break;
			}

			List<Source_List__c> preds = selector.selectByDestinationListIds(frontier);

			if (preds == null || preds.isEmpty()) {
				break;
			}

			results.addAll(preds);

			Set<Id> nextFrontier = new Set<Id>();

			for (Source_List__c edge : preds) {
				if (edge == null) {
					continue;
				}

				if (
					edge.Source_List__c != null && !visited.contains(edge.Source_List__c)
				) {
					nextFrontier.add(edge.Source_List__c);
				}
			}

			visited.addAll(frontier);
			frontier = nextFrontier;
		}

		return results;
	}

	private static Map<Id, Set<Id>> buildForwardAdjacency(List<Source_List__c> edges) {
		Map<Id, Set<Id>> adj = new Map<Id, Set<Id>>();

		if (edges == null || edges.isEmpty()) {
			return adj;
		}

		for (Source_List__c edge : edges) {
			if (
				edge == null ||
				edge.Source_List__c == null ||
				edge.Destination_List__c == null
			) {
				continue;
			}

			if (!adj.containsKey(edge.Source_List__c)) {
				adj.put(edge.Source_List__c, new Set<Id>());
			}

			adj.get(edge.Source_List__c).add(edge.Destination_List__c);
		}

		return adj;
	}

	private static Map<Id, Set<Id>> buildReverseAdjacency(List<Source_List__c> edges) {
		Map<Id, Set<Id>> adj = new Map<Id, Set<Id>>();

		if (edges == null || edges.isEmpty()) {
			return adj;
		}

		for (Source_List__c edge : edges) {
			if (
				edge == null ||
				edge.Source_List__c == null ||
				edge.Destination_List__c == null
			) {
				continue;
			}

			if (!adj.containsKey(edge.Destination_List__c)) {
				adj.put(edge.Destination_List__c, new Set<Id>());
			}

			adj.get(edge.Destination_List__c).add(edge.Source_List__c);
		}

		return adj;
	}

	private static Boolean wouldCreateCycle(
		Map<Id, Set<Id>> adjForward,
		Id src,
		Id dest
	) {
		if (src == null || dest == null || adjForward == null || adjForward.isEmpty()) {
			return false;
		}

		Set<Id> visited = new Set<Id>{ dest };
		List<Id> queue = new List<Id>{ dest };

		while (!queue.isEmpty()) {
			Id current = queue.remove(0);

			if (current == src) {
				return true;
			}

			if (!adjForward.containsKey(current)) {
				continue;
			}

			for (Id nextId : adjForward.get(current)) {
				if (nextId == null || visited.contains(nextId)) {
					continue;
				}

				visited.add(nextId);
				queue.add(nextId);
			}
		}

		return false;
	}

	private static Integer computeCombinedDepth(
		Map<Id, Set<Id>> adjForward,
		Map<Id, Set<Id>> adjReverse,
		Id src,
		Id dest
	) {
		Integer ancestors = bfsDepth(adjReverse, src);

		Integer descendants = bfsDepth(adjForward, dest);

		return ancestors + 1 + descendants;
	}

	private static Integer bfsDepth(Map<Id, Set<Id>> adj, Id start) {
		if (start == null || adj == null || adj.isEmpty()) {
			return 0;
		}

		Set<Id> visited = new Set<Id>();
		Map<Id, Integer> depths = new Map<Id, Integer>();
		List<Id> queue = new List<Id>();

		visited.add(start);
		depths.put(start, 0);
		queue.add(start);

		Integer maxDepth = 0;

		while (!queue.isEmpty()) {
			Id current = queue.remove(0);
			Integer depth = depths.get(current);

			if (depth > maxDepth) {
				maxDepth = depth;
			}

			if (!adj.containsKey(current)) {
				continue;
			}

			for (Id nextId : adj.get(current)) {
				if (nextId == null || visited.contains(nextId)) {
					continue;
				}

				visited.add(nextId);
				depths.put(nextId, depth + 1);
				queue.add(nextId);
			}
		}

		return maxDepth;
	}
}
