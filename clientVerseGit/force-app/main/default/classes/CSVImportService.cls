public class CSVImportService {

    public static List<ContactImportRow> processRows(List<CSVParser.Row> rawRows) {
        List<ContactImportRow> results = new List<ContactImportRow>();

        Set<String> emailSet = new Set<String>();
        Set<String> soslTermSet = new Set<String>();

        for (CSVParser.Row r : rawRows) {
            if (!String.isBlank(r.email)) {
                emailSet.add(r.email.toLowerCase());
            }

            if (!String.isBlank(r.firstName) && !String.isBlank(r.lastName)) {
                String combinedName = r.firstName + ' ' + r.lastName;
                soslTermSet.add('*' + combinedName + '*');
            }
        }

        Map<String, Contact> emailMap = new Map<String, Contact>();
        if (!emailSet.isEmpty()) {
            for (Contact c : [
                SELECT Id, FirstName, LastName, Email, Account.Name
                FROM Contact
                WHERE Email IN :emailSet
            ]) {
                emailMap.put(c.Email.toLowerCase(), c);
            }
        }

        List<Contact> fuzzyCandidates = new List<Contact>();
        if (!soslTermSet.isEmpty()) {
            String sosl = 'FIND {' 
                        + String.join(new List<String>(soslTermSet), ' OR ') 
                        + '} IN ALL FIELDS RETURNING ' +
                        'Contact(Id, FirstName, LastName, Email, Account.Name)';

            List<List<SObject>> searchResults = Search.query(sosl);
            if (!searchResults.isEmpty()) {
                fuzzyCandidates = (List<Contact>) searchResults[0];
            }
        }

        Map<Id, Contact> fuzzyMap = new Map<Id, Contact>();
        for (Contact c : fuzzyCandidates) {
            fuzzyMap.put(c.Id, c);
        }

        for (CSVParser.Row r : rawRows) {
            ContactImportRow dto = new ContactImportRow();
            dto.firstName = r.firstName;
            dto.lastName = r.lastName;
            dto.title = r.title;
            dto.company = r.company;
            dto.email = r.email;

            if (String.isBlank(dto.firstName) || String.isBlank(dto.lastName) || String.isBlank(dto.email)) {
                dto.error = 'Missing required fields in CSV';
                results.add(dto);
                continue;
            }

            Contact emailMatch = emailMap.get(dto.email.toLowerCase());
            if (emailMatch != null) {
                dto.matchedContactId = emailMatch.Id;
                dto.matchScore = 1;
                dto.matchType = 'EMAIL MATCH';
                results.add(dto);
                continue;
            }

            Decimal bestScore = 0;
            Contact bestMatch;

            for (Contact candidate : fuzzyCandidates) {
                Decimal score = FuzzyMatcher.combinedScore(
                    dto.firstName, 
                    dto.lastName, 
                    dto.company, 
                    candidate
                );

                if (score > bestScore) {
                    bestScore = score;
                    bestMatch = candidate;
                }
            }

            if (bestScore >= 0.7) {
                dto.matchedContactId = bestMatch.Id;
                dto.matchScore = bestScore;
                dto.matchType = 'FUZZY MATCH';
            } else {
                dto.matchType = 'NONE';
            }

            results.add(dto);
        }

        return results;
    }

    public static Map<String, Id> getExistingListMembers(Id listId) {
        Map<String, Id> existingEmails = new Map<String, Id>();
        for (List_Member__c lm : [
            SELECT Id, Contact__r.Email 
            FROM List_Member__c 
            WHERE List__c = :listId AND Contact__r.Email != NULL
        ]) {
            existingEmails.put(lm.Contact__r.Email.toLowerCase(), lm.Id);
        }
        return existingEmails;
    }


    public static void importConfirmedRows(List<ContactImportRow> rows, Id listId, Map<String, Object> defaults, Id fileId, String fileName) {
        List<List_Member__c> toInsert = new List<List_Member__c>();
        List<Contact> contactToInsert = new List<Contact>();
        Map<String, String> emailContactMap= new Map<String, String>();
        Set<String> accountCompanyToFetch = new Set<String>();
        Map<String, String> nameAccountMap= new Map<String, String>();


        for (ContactImportRow r : rows) {
            if(r.matchedContactId == null && r.company !=null){
                accountCompanyToFetch.add(r.company);
            }
        }
        for(Account a:[SELECT Id, name FROM Account WHERE Name In :accountCompanyToFetch ORDER BY LastModifiedDate DESC]){
            if(!nameAccountMap.containsKey(a.name))
                nameAccountMap.put(a.name,a.Id);
        }

        for (ContactImportRow r : rows) {
            if (r.matchedContactId == null && r.lastName !=null && r.email != null && nameAccountMap.containsKey(r.company)) 
                contactToInsert.add(new Contact(LastName=r.lastName,FirstName=r.firstName,Email=r.email,Title=r.title,AccountId=nameAccountMap.get(r.company)));
            else if (r.matchedContactId == null && r.lastName !=null && r.email != null)
                contactToInsert.add(new Contact(LastName=r.lastName,FirstName=r.firstName,Email=r.email,Title=r.title));

        }

        System.debug('Contact TO insert'+contactToInsert);
        try{
            insert contactToInsert;
        }
        catch(Exception e){
            System.debug(e);
        }
        
        for(Contact c:contactToInsert){
            if(c.Id!=null){
                emailContactMap.put(c.Email,c.Id);
            }
        }

        for (ContactImportRow r : rows) {
            System.debug(r);
            if (r.matchedContactId == null && emailContactMap.containskey(r.Email)) {
                r.matchedContactId=emailContactMap.get(r.Email);
            }

            List_Member__c lm = new List_Member__c();
            lm.List__c = listId;
            lm.Contact__c = r.matchedContactId;
            lm.Initial_Sponsor__c = r.matchedContactId;
            lm.ContentVersionId__c = fileId;

            for (String key : defaults.keySet()) {
                lm.put(key, defaults.get(key));
            }

            toInsert.add(lm);
        }

        System.debug(toInsert);
        insert toInsert;

        //Insert Audit Log
        Audit_Log_Import__c audit = new Audit_Log_Import__c();
        audit.Name = fileName;
        audit.List__c = listId;        
        audit.Audit_Result__c = String.valueOf(toInsert.size());
        insert audit;

        //Link CDL to Audit
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = fileId,
            LinkedEntityId    = audit.Id,
            ShareType         = 'V'
        );
        insert cdl;
    }
}