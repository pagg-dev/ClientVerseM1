/**
 * @description Apex invocable class for creating List Member or Campaign Member records from Flow
 */
public with sharing class CreateMembersFromFlow {
    
    /**
     * @description Input parameters for the Flow
     */
    public class FlowInput {
        @InvocableVariable(label='Target Type (List or Campaign)' required=true)
        public String targetType;
        
        @InvocableVariable(label='Target Record Id' required=true)
        public String targetRecordId;
        
        @InvocableVariable(label='Collection of Contacts' required=true)
        public List<Contact> contacts;
    }
    
    /**
     * @description Output parameters for the Flow
     */
    public class FlowOutput {
        @InvocableVariable(label='Success')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Error Message')
        public String errorMessage;
        
        @InvocableVariable(label='Number of Records Created')
        public Integer recordsCreated;
    }
    
    /**
     * @description Main invocable method called from Flow
     * @param inputs List of FlowInput parameters
     * @return List of FlowOutput results
     */
    @InvocableMethod(label='Create List or Campaign Members' 
                     description='Creates List_Member__c or CampaignMember records based on target type')
    public static List<FlowOutput> createMembers(List<FlowInput> inputs) {
        List<FlowOutput> results = new List<FlowOutput>();
        
        for (FlowInput input : inputs) {
            FlowOutput result = new FlowOutput();
            
            try {
                // Validate input
                if (String.isBlank(input.targetType) || String.isBlank(input.targetRecordId) || 
                    input.contacts == null || input.contacts.isEmpty()) {
                    throw new IllegalArgumentException('Required parameters are missing or invalid');
                }
                
                // Normalize target type
                String normalizedTargetType = input.targetType.trim().toLowerCase();
                
                Integer createdCount = 0;
                
                if (normalizedTargetType == 'list') {
                    createdCount = createListMembers(input.targetRecordId, input.contacts);
                } else if (normalizedTargetType == 'campaign') {
                    createdCount = createCampaignMembers(input.targetRecordId, input.contacts);
                } else {
                    throw new IllegalArgumentException('Target Type must be either "List" or "Campaign"');
                }
                
                result.isSuccess = true;
                result.recordsCreated = createdCount;
                result.errorMessage = '';
                
            } catch (Exception e) {
                result.isSuccess = false;
                result.errorMessage = 'Error: ' + e.getMessage() + 
                                    ' (Line: ' + e.getLineNumber() + ')';
                result.recordsCreated = 0;
                System.debug('Error creating members: ' + e.getMessage());
            }
            
            results.add(result);
        }
       system.debug('this is the value of results');
        return results;
    }
    
    /**
     * @description Creates List_Member__c records for the given list and contacts
     * @param listId The List__c record Id
     * @param contacts List of Contact records
     * @return Number of records created
     */
    private static Integer createListMembers(String listId, List<Contact> contacts) {
        List<List_Member__c> listMembers = new List<List_Member__c>();
        Set<Id> contactIds = new Set<Id>();

        for (List_Member__c lm : [
            SELECT Contact__c
            FROM List_Member__c
            WHERE List__c = : listId
        ]) {
            contactIds.add(lm.Contact__c);
        }


        
        
        for (Contact contact : contacts) {
            if(!contactIds.contains(contact.Id)){
            List_Member__c member = new List_Member__c(       
                   List__c = listId,
                	Contact__c = contact.Id    
            );
            listMembers.add(member);
            }
            
        }
        
        if (!listMembers.isEmpty()) {
            insert listMembers;
        }
        
        return listMembers.size();
    }
    
    /**
     * @description Creates CampaignMember records for the given campaign and contacts
     * @param campaignId The Campaign record Id
     * @param contacts List of Contact records
     * @return Number of records created
     */
    private static Integer createCampaignMembers(String campaignId, List<Contact> contacts) {
        List<CampaignMember> campaignMembers = new List<CampaignMember>();
        Set<Id> contactIds = new Set<Id>();

        for (CampaignMember lm : [
            SELECT ContactId
            FROM CampaignMember
            WHERE CampaignId = : campaignId
        ]) {
            contactIds.add(lm.ContactId);
        }
        
        for (Contact contact : contacts) {
            if(!contactIds.contains(contact.Id)){
            CampaignMember member = new CampaignMember(
                CampaignId = campaignId,
                ContactId = contact.Id
                
            );
            campaignMembers.add(member);
           }
        }
        
        if (!campaignMembers.isEmpty()) {
            insert campaignMembers;
        }
        
        return campaignMembers.size();
    }
}