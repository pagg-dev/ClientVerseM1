/**
 * @description
 * Selector class for Source_List__c records.
 * Provides reusable query methods for source/destination
 */
public with sharing class SourceListSelector extends fflib_SObjectSelector {
	/**
	 * @description
	 * Default constructor.
	 */
	public SourceListSelector() {
		super();
		setDataAccess(DataAccess.USER_MODE);
	}

	/**
	 * @description
	 * Returns the default field set for Source_List__c queries.
	 *
	 * @return
	 * List of Source_List__c fields.
	 */
	public List<Schema.SObjectField> getSObjectFieldList() {
		return new List<Schema.SObjectField>{
			Source_List__c.Id,
			Source_List__c.Source_List__c,
			Source_List__c.Destination_List__c,
			Source_List__c.Source_Campaign__c,
			Source_List__c.Destination_Campaign__c,
			Source_List__c.Source_List_Type__c
		};
	}

	/**
	 * @description
	 * Returns the SObject type handled by this selector.
	 *
	 * @return
	 * Source_List__c SObjectType.
	 */
	public Schema.SObjectType getSObjectType() {
		return Source_List__c.SObjectType;
	}

	/**
	 * @description
	 * Selects Source_List__c records by Id.
	 *
	 * @param ids
	 * Set of Source_List__c record Ids.
	 *
	 * @return
	 * List of matching Source_List__c records.
	 */
	public List<Source_List__c> selectByIds(Set<Id> ids) {
		if (ids == null || ids.isEmpty()) {
			return new List<Source_List__c>();
		}

		return (List<Source_List__c>) selectSObjectsById(ids);
	}

	/**
	 * @description
	 * Selects mappings whose destination list is in the given set.
	 *
	 * @param destinationIds
	 * Destination List__c Ids.
	 *
	 * @return
	 * List of Source_List__c records.
	 */
	public List<Source_List__c> selectByDestinationListIds(Set<Id> destinationIds) {
		if (destinationIds == null || destinationIds.isEmpty()) {
			return new List<Source_List__c>();
		}

		fflib_QueryFactory queryFactory = newQueryFactory();
		configureBaseQuery(queryFactory);
		queryFactory.setCondition(
			'Destination_List__c IN :destinationIds ' + 'AND Source_List__c != null'
		);

		return (List<Source_List__c>) Database.query(queryFactory.toSOQL());
	}

	/**
	 * @description
	 * Selects syncing Source_List__c mappings for given source lists.
	 *
	 * @param sourceIds
	 * Source List__c Ids.
	 *
	 * @return
	 * List of syncing Source_List__c records.
	 */
	public List<Source_List__c> selectSyncingBySourceListIds(Set<Id> sourceIds) {
		if (sourceIds == null || sourceIds.isEmpty()) {
			return new List<Source_List__c>();
		}

		fflib_QueryFactory queryFactory = newQueryFactory();
		configureBaseQuery(queryFactory);
		queryFactory.setCondition('Sync__c = TRUE AND Source_List__c IN :sourceIds');

		return (List<Source_List__c>) Database.query(queryFactory.toSOQL());
	}

	/**
	 * @description
	 * Traverses source list edges up to a maximum depth.
	 *
	 * @param startListIds
	 * Starting List__c Ids.
	 *
	 * @param maxDepth
	 * Maximum traversal depth.
	 *
	 * @return
	 * List of Source_List__c edges discovered.
	 */
	public List<Source_List__c> selectEdgesBounded(
		Set<Id> startListIds,
		Integer maxDepth
	) {
		if (
			startListIds == null ||
			startListIds.isEmpty() ||
			maxDepth == null ||
			maxDepth <= 0
		) {
			return new List<Source_List__c>();
		}

		List<Source_List__c> results = new List<Source_List__c>();
		Set<Id> frontier = new Set<Id>(startListIds);
		Set<Id> visited = new Set<Id>(frontier);

		for (Integer depth = 1; depth <= maxDepth; depth++) {
			if (frontier.isEmpty()) {
				break;
			}

			List<Source_List__c> edges = queryEdgesFromFrontier(frontier);

			if (edges.isEmpty()) {
				break;
			}

			results.addAll(edges);
			frontier = buildNextFrontier(edges, visited);
			visited.addAll(frontier);
		}

		return results;
	}

	/* =========================
       Helper Methods
       ========================= */

	/**
	 * @description
	 * Configures base query settings.
	 *
	 * @param queryFactory
	 * QueryFactory instance.
	 */
	private void configureBaseQuery(fflib_QueryFactory queryFactory) {
		queryFactory.selectFields(getSObjectFieldList());
	}

	/**
	 * @description
	 * Queries outgoing edges from the current frontier.
	 *
	 * @param frontier
	 * Current traversal frontier.
	 *
	 * @return
	 * List of Source_List__c edges.
	 */
	private List<Source_List__c> queryEdgesFromFrontier(Set<Id> frontier) {
		fflib_QueryFactory queryFactory = newQueryFactory();
		configureBaseQuery(queryFactory);
		queryFactory.setCondition(
			'Source_List__c IN :frontier ' + 'AND Destination_List__c != null'
		);

		return (List<Source_List__c>) Database.query(queryFactory.toSOQL());
	}

	/**
	 * @description
	 * Builds the next traversal frontier from discovered edges.
	 *
	 * @param edges
	 * Discovered Source_List__c edges.
	 *
	 * @param visited
	 * Already visited List__c Ids.
	 *
	 * @return
	 * Next frontier List__c Ids.
	 */
	private static Set<Id> buildNextFrontier(
		List<Source_List__c> edges,
		Set<Id> visited
	) {
		Set<Id> nextFrontier = new Set<Id>();

		for (Source_List__c edge : edges) {
			if (edge == null) {
				continue;
			}

			Id destinationId = edge.Destination_List__c;

			if (destinationId != null && !visited.contains(destinationId)) {
				nextFrontier.add(destinationId);
			}
		}

		return nextFrontier;
	}
}
