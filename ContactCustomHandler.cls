public class ContactCustomHandler {
    public static void updateQBDomain(List<Contact> newRecords, Map<Id, Contact> oldMap) {
        for (Contact newRecord : newRecords) {
            // Get old record if it's an update
            Contact oldRecord = oldMap != null ? oldMap.get(newRecord.Id) : null;

            // Initialize a Set to track the domains
            Set<String> newDomains = new Set<String>();

            // Determine new domain based on QB_Instance__c
            if (newRecord.QB_Instance__c != null) {
                if (newRecord.QB_Instance__c.contains('.eu.')) {
                    newDomains.add('EU');
                } else {
                    newDomains.add('US');
                }
            }

            // Check and update existing domains
            Set<String> existingDomains = new Set<String>();
            if (newRecord.QB_Domain__c != null) {
                existingDomains.addAll(newRecord.QB_Domain__c.split(';'));
            }

            // Handle the multi-select picklist value
            if (oldRecord != null && oldRecord.QB_Instance__c != null) {
                // Determine previous domain based on old QB_Instance__c
                if (oldRecord.QB_Instance__c.contains('.eu.')) {
                    existingDomains.add('EU');
                } else {
                    existingDomains.add('US');
                }
            }

            // Add new domain if not already present
            existingDomains.addAll(newDomains);

            // Prepare the final multi-select picklist value
            String domainString = '';
            for (String domain : existingDomains) {
                if (domainString.length() > 0) {
                    domainString += ';';
                }
                domainString += domain;
            }

            // Update the QB_Domain__c field
            if (newRecord.QB_Instance__c == null) {
                newRecord.QB_Domain__c = null;
            } else {
                newRecord.QB_Domain__c = domainString;
            }
        }
    }
}