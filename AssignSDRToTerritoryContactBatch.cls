public without sharing class AssignSDRToTerritoryContactBatch
    implements Database.Batchable<SObject> {

    private Map<String, Id> territoryKeyToSdrUserId;
    private Set<String> territoryValuesForQuery;

    public AssignSDRToTerritoryContactBatch(
        Map<String, Id> territoryKeyToSdrUserId,
        Set<String> territoryValuesForQuery
    ) {
        this.territoryKeyToSdrUserId = new Map<String, Id>();
        this.territoryKeyToSdrUserId.putAll(territoryKeyToSdrUserId);

        this.territoryValuesForQuery = new Set<String>();
        this.territoryValuesForQuery.addAll(territoryValuesForQuery);
    }

    public Database.QueryLocator start(Database.BatchableContext batchContext) {
        return Database.getQueryLocator([
            SELECT Id,
                   AccountId,
                   Account.Territory_Name__c,
                   SDR_Owner__c,
                   ValidationBypassDateTime__c
            FROM Contact
            WHERE AccountId != null
            AND Account.Territory_Name__c IN :territoryValuesForQuery
        ]);
    }

    public void execute(
        Database.BatchableContext batchContext,
        List<SObject> scope
    ) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        Datetime bypassDateTime = System.now();

        List<Contact> contactsToUpdate = new List<Contact>();

        for (SObject sob : scope) {
            Contact con = (Contact) sob;

            String accountTerritory =
                con.Account == null ? null : con.Account.Territory_Name__c;

            Id sdrUserId = territoryKeyToSdrUserId.get(
                normalizeTerritory(accountTerritory)
            );

            if (sdrUserId == null) {
                continue;
            }

            contactsToUpdate.add(new Contact(
                Id = con.Id,
                SDR_Owner__c = sdrUserId,
                ValidationBypassDateTime__c = bypassDateTime
            ));
        }

        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
    }

    public void finish(Database.BatchableContext batchContext) {
        // No follow-up action needed.
    }

    private static String normalizeTerritory(String territory) {
        if (String.isBlank(territory)) {
            return null;
        }

        return territory.trim().toLowerCase();
    }
}