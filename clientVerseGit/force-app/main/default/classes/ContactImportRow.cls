public class ContactImportRow {
    @AuraEnabled public String firstName { get; set; }
    @AuraEnabled public String lastName { get; set; }
    @AuraEnabled public String title { get; set; }
    @AuraEnabled public String company { get; set; }
    @AuraEnabled public String email { get; set; }

    @AuraEnabled public Id matchedContactId { get; set; }
    @AuraEnabled public Decimal matchScore { get; set; }
    @AuraEnabled public String matchType { get; set; }
    @AuraEnabled public String error { get; set; }
    @AuraEnabled public Boolean isDuplicate { get; set; }

}