public with sharing class ListSelector extends fflib_SObjectSelector {

    public ListSelector() {
        super();
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            List__c.Id,
            List__c.List_Member_Mapping__c
        };
    }

    public Schema.SObjectType getSObjectType() {
        return List__c.SObjectType;
    }

    public List<List__c> selectByIds(Set<Id> ids) {
        return (List<List__c>) selectSObjectsById(ids);
    }
}