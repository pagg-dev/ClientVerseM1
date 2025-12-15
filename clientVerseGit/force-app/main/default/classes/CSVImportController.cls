public with sharing class CSVImportController {

    @AuraEnabled(cacheable=false)
    public static List<ContactImportRow> parseCsv(String csvBody, Id listId) {

        // Parse CSV first
        List<CSVParser.Row> rawRows = CSVParser.parse(csvBody);

        Map<String, Id> existingListEmails = CSVImportService.getExistingListMembers(listId);

        List<ContactImportRow> results = CSVImportService.processRows(rawRows);

        // Add duplicate flag AFTER processRows assigns email field
        for (ContactImportRow dto : results) {
            System.debug(dto);
            System.debug(dto.email);
            System.debug(existingListEmails);
            if (!String.isBlank(dto.email) &&
                existingListEmails.containsKey(dto.email.toLowerCase())) {
                System.debug('in');
                dto.matchType = 'Member already linked with the list';
                dto.isDuplicate = true;  
            }
            System.debug(dto);
        }

        return results;
    }

    @AuraEnabled
    public static void importRowsWithFile(List<ContactImportRow> rows, Id listId, 
                                          Map<String, Object> defaultFields,
                                          String fileName, String fileContent) 
    {
        ContentVersion cv = new ContentVersion(
            Title        = fileName,
            PathOnClient = fileName,
            VersionData  = Blob.valueOf(fileContent)
        );
        insert cv;

        Id fileId = [
            SELECT ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :cv.Id
        ].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = fileId,
            LinkedEntityId    = listId,
            ShareType         = 'V'
        );
        insert cdl;

        CSVImportService.importConfirmedRows(rows, listId, defaultFields, fileId, fileName);
    }
}