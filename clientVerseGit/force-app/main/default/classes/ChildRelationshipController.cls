public with sharing class ChildRelationshipController {
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getChildRelationships(String parentObjectApiName) {
        List<Map<String, Object>> childRelationshipsList = new List<Map<String, Object>>();
        
        Schema.SObjectType parentType = Schema.getGlobalDescribe().get(parentObjectApiName);
        if (parentType != null) {
            List<Schema.ChildRelationship> childRels = parentType.getDescribe().getChildRelationships();
            
            for (Schema.ChildRelationship cr : childRels) {
                Map<String, Object> childInfo = new Map<String, Object>();
                childInfo.put('relationshipName', cr.getRelationshipName());
                childInfo.put('childObject', cr.getChildSObject().getDescribe().getName());
                
                // Get child object fields
                List<Map<String, String>> childFields = new List<Map<String, String>>();
                Map<String, Schema.SObjectField> fieldsMap = cr.getChildSObject().getDescribe().fields.getMap();
                for (String fieldName : fieldsMap.keySet()) {
                    childFields.add(new Map<String, String>{
                        'label' => fieldsMap.get(fieldName).getDescribe().getLabel(),
                        'value' => fieldName
                    });
                }
                childInfo.put('fields', childFields);
                
                childRelationshipsList.add(childInfo);
            }
        }
        return childRelationshipsList;
    }
}