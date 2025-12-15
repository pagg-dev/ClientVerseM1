public class FieldSetUtil {
    @AuraEnabled
    public static Map<String, String> getFieldsMapFromConfig(String uniqueId) {
        system.debug('uniqueId: '+uniqueId);
        Map<String, String> resultMap = new Map<String, String>();

        Search_Component_Config__c config = [
            SELECT Configured_Objects__c 
            FROM Search_Component_Config__c 
            WHERE Unique_ID__c = :uniqueId 
            LIMIT 1
        ];

        if (String.isBlank(config.Configured_Objects__c)) {
            throw new AuraHandledException('No configuration JSON found.');
        }

        Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(config.Configured_Objects__c);

        for (String key : configMap.keySet()) {
            if (key == 'Unique_Key') continue;

            Map<String, Object> objConfig = (Map<String, Object>) configMap.get(key);
            String objectApiName = (String) objConfig.get('apiName');
            String objectLabel = (String) objConfig.get('label');
            List<Object> displayFields = (List<Object>) objConfig.get('displayFields');
            String fieldString = '';

            for (Object fieldObj : displayFields) {
                Map<String, Object> fieldMap = (Map<String, Object>) fieldObj;
                String apiPath = (String) fieldMap.get('apiPath');
                String label = (String) fieldMap.get('label');

                Boolean isLookup = apiPath.contains('.'); // crude check; could be refined

                String fieldMeta = label + '#' + apiPath + '!' + (isLookup ? 'T' : 'F') + '!!';

                // Prioritize Name field
                if (apiPath == 'Name') {
                    fieldString = fieldMeta + ',' + fieldString;
                } else {
                    fieldString += fieldMeta + ',';
                }
            }

            resultMap.put(objectApiName, fieldString);
        }
        system.debug('resultMap: '+JSON.serialize(resultMap));
        return resultMap;
    }
}