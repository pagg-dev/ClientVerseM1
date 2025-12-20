public with sharing class SourceListSelector extends fflib_SObjectSelector {

    public SourceListSelector() {
        super();
    }

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

    public Schema.SObjectType getSObjectType() {
        return Source_List__c.SObjectType;
    }

    public List<Source_List__c> selectByIds(Set<Id> ids) {
        return (List<Source_List__c>) selectSObjectsById(ids);
    }

    public List<Source_List__c> selectByDestinationListIds(Set<Id> destinationIds) {
        if (destinationIds == null || destinationIds.isEmpty()) {
            return new List<Source_List__c>();
        }

        fflib_QueryFactory qf = newQueryFactory();
        qf.selectFields(getSObjectFieldList());
        qf.setCondition('Destination_List__c IN :destinationIds AND Source_List__c != null');

        return (List<Source_List__c>) Database.query(qf.toSOQL());
    }

    public List<Source_List__c> selectSyncingBySourceListIds(Set<Id> sourceIds) {
        if (sourceIds == null || sourceIds.isEmpty()) {
            return new List<Source_List__c>();
        }

        fflib_QueryFactory qf = newQueryFactory();
        qf.selectFields(getSObjectFieldList());
        qf.setCondition('Sync__c = TRUE AND Source_List__c IN :sourceIds');

        return (List<Source_List__c>) Database.query(qf.toSOQL());
    }

    public List<Source_List__c> selectEdgesBounded(Set<Id> startListIds, Integer maxDepth) {
        if (startListIds == null || startListIds.isEmpty() || maxDepth == null || maxDepth <= 0) {
            return new List<Source_List__c>();
        }

        List<Source_List__c> result = new List<Source_List__c>();

        // BFS state
        Set<Id> frontier = new Set<Id>(startListIds);
        Set<Id> visited = new Set<Id>(frontier);

        for (Integer depth = 1; depth <= maxDepth; depth++) {

            if (frontier.isEmpty()) break;

            fflib_QueryFactory qf = newQueryFactory();
            qf.selectFields(getSObjectFieldList());
            qf.setCondition('Source_List__c IN :frontier AND Destination_List__c != null');

            List<Source_List__c> edges =
                (List<Source_List__c>) Database.query(qf.toSOQL());

            if (edges.isEmpty()) break;

            result.addAll(edges);

            // prepare next frontier
            Set<Id> nextFrontier = new Set<Id>();
            for (Source_List__c e : edges) {
                if (e.Destination_List__c != null && !visited.contains(e.Destination_List__c)) {
                    nextFrontier.add(e.Destination_List__c);
                }
            }

            visited.addAll(frontier);
            frontier = nextFrontier;
        }

        return result;
    }
}