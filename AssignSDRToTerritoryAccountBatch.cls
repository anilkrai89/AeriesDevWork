public without sharing class AssignSDRToTerritoryAccountBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    private static final String SDR_TEAM_ROLE = 'Sales Development Rep';

    private static final String ACCESS_READ = 'Read';
    private static final String ACCESS_EDIT = 'Edit';

    private static final Integer ACCOUNT_BATCH_SIZE = 100;
    private static final Integer CONTACT_BATCH_SIZE = 200;

    private Map<String, Id> territoryKeyToSdrUserId;
    private Set<String> territoryValuesForQuery;

    private Integer accountRowsSeen = 0;

    public class Request {
        @InvocableVariable(
            label='Account Territory'
            description='Territory value used to match Sales_Territories__c.Territory__c and Account.Territory_Name__c.'
            required=true
        )
        public String accountTerritory;

        @InvocableVariable(
            label='SDR User Id'
            description='User Id to assign as the SDR owner.'
            required=true
        )
        public Id sdrUserId;
    }

    public class AssignSDRException extends Exception {}

    public AssignSDRToTerritoryAccountBatch(
        Map<String, Id> territoryKeyToSdrUserId,
        Set<String> territoryValuesForQuery
    ) {
        this.territoryKeyToSdrUserId = new Map<String, Id>();
        this.territoryKeyToSdrUserId.putAll(territoryKeyToSdrUserId);

        this.territoryValuesForQuery = new Set<String>();
        this.territoryValuesForQuery.addAll(territoryValuesForQuery);
    }

    @InvocableMethod(
        label='Assign SDR to Territory - Start Account Batch'
        description='Starts a batch process that updates Sales Territory, Accounts, Account Team Members, and then related Contacts.'
    )
    public static void startFromFlow(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }

        Map<String, Id> territoryKeyToSdrUserId = new Map<String, Id>();
        Set<String> territoryValuesForQuery = new Set<String>();

        for (Request req : requests) {
            if (
                req == null ||
                String.isBlank(req.accountTerritory) ||
                req.sdrUserId == null
            ) {
                throw new AssignSDRException(
                    'Each Flow request must include Account Territory and SDR User Id.'
                );
            }

            String trimmedTerritory = req.accountTerritory.trim();
            String territoryKey = normalizeTerritory(trimmedTerritory);

            if (
                territoryKeyToSdrUserId.containsKey(territoryKey) &&
                territoryKeyToSdrUserId.get(territoryKey) != req.sdrUserId
            ) {
                throw new AssignSDRException(
                    'The same Account Territory was provided with multiple SDR User Id values: ' +
                    trimmedTerritory
                );
            }

            territoryKeyToSdrUserId.put(territoryKey, req.sdrUserId);
            territoryValuesForQuery.add(trimmedTerritory);
        }

        Database.executeBatch(
            new AssignSDRToTerritoryAccountBatch(
                territoryKeyToSdrUserId,
                territoryValuesForQuery
            ),
            ACCOUNT_BATCH_SIZE
        );
    }

    public Database.QueryLocator start(Database.BatchableContext batchContext) {
        updateSalesTerritories();

        return Database.getQueryLocator([
            SELECT Id,
                   Territory_Name__c,
                   SDR_Owner__c,
                   ValidationBypassDateTime__c
            FROM Account
            WHERE Territory_Name__c IN :territoryValuesForQuery
        ]);
    }

    public void execute(
        Database.BatchableContext batchContext,
        List<SObject> scope
    ) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        accountRowsSeen += scope.size();

        Datetime bypassDateTime = System.now();

        Map<Id, Id> accountIdToSdrUserId = new Map<Id, Id>();
        List<Account> accountsToUpdate = new List<Account>();

        for (SObject sob : scope) {
            Account acct = (Account) sob;

            Id sdrUserId = getSdrUserIdForTerritory(acct.Territory_Name__c);

            if (sdrUserId == null) {
                continue;
            }

            accountsToUpdate.add(new Account(
                Id = acct.Id,
                SDR_Owner__c = sdrUserId,
                ValidationBypassDateTime__c = bypassDateTime
            ));

            accountIdToSdrUserId.put(acct.Id, sdrUserId);
        }

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }

        if (!accountIdToSdrUserId.isEmpty()) {
            replaceAccountTeamMembers(accountIdToSdrUserId);
        }
    }

    public void finish(Database.BatchableContext batchContext) {
        if (accountRowsSeen > 0) {
            Database.executeBatch(
                new AssignSDRToTerritoryContactBatch(
                    territoryKeyToSdrUserId,
                    territoryValuesForQuery
                ),
                CONTACT_BATCH_SIZE
            );
        }
    }

    private void updateSalesTerritories() {
        List<Sales_Territories__c> salesTerritoriesToUpdate =
            new List<Sales_Territories__c>();

        for (Sales_Territories__c salesTerritory : [
            SELECT Id,
                   Territory__c,
                   Outbound_SDR__c
            FROM Sales_Territories__c
            WHERE Territory__c IN :territoryValuesForQuery
        ]) {
            Id sdrUserId = getSdrUserIdForTerritory(salesTerritory.Territory__c);

            if (sdrUserId == null) {
                continue;
            }

            salesTerritoriesToUpdate.add(new Sales_Territories__c(
                Id = salesTerritory.Id,
                Outbound_SDR__c = sdrUserId
            ));
        }

        if (!salesTerritoriesToUpdate.isEmpty()) {
            update salesTerritoriesToUpdate;
        }
    }

    private void replaceAccountTeamMembers(
        Map<Id, Id> accountIdToSdrUserId
    ) {
        Set<Id> accountIds = new Set<Id>();
        accountIds.addAll(accountIdToSdrUserId.keySet());

        Set<Id> sdrUserIds = new Set<Id>();
        sdrUserIds.addAll(accountIdToSdrUserId.values());

        List<AccountTeamMember> existingSdrTeamMembers = [
            SELECT Id
            FROM AccountTeamMember
            WHERE AccountId IN :accountIds
            AND TeamMemberRole = :SDR_TEAM_ROLE
        ];

        if (!existingSdrTeamMembers.isEmpty()) {
            delete existingSdrTeamMembers;
        }

        Map<String, AccountTeamMember> existingTargetMembersByKey =
            new Map<String, AccountTeamMember>();

        for (AccountTeamMember existingMember : [
            SELECT Id,
                   AccountId,
                   UserId,
                   TeamMemberRole,
                   AccountAccessLevel,
                   OpportunityAccessLevel,
                   ContactAccessLevel,
                   CaseAccessLevel
            FROM AccountTeamMember
            WHERE AccountId IN :accountIds
            AND UserId IN :sdrUserIds
        ]) {
            existingTargetMembersByKey.put(
                accountUserKey(existingMember.AccountId, existingMember.UserId),
                existingMember
            );
        }

        List<AccountTeamMember> teamMembersToUpdate =
            new List<AccountTeamMember>();

        List<AccountTeamMember> teamMembersToInsert =
            new List<AccountTeamMember>();

        for (Id accountId : accountIds) {
            Id sdrUserId = accountIdToSdrUserId.get(accountId);

            String key = accountUserKey(accountId, sdrUserId);

            if (existingTargetMembersByKey.containsKey(key)) {
                AccountTeamMember existingMember =
                    existingTargetMembersByKey.get(key);

                applySdrTeamMemberValues(existingMember);
                teamMembersToUpdate.add(existingMember);
            } else {
                AccountTeamMember newMember = new AccountTeamMember(
                    AccountId = accountId,
                    UserId = sdrUserId
                );

                applySdrTeamMemberValues(newMember);
                teamMembersToInsert.add(newMember);
            }
        }

        if (!teamMembersToUpdate.isEmpty()) {
            update teamMembersToUpdate;
        }

        if (!teamMembersToInsert.isEmpty()) {
            insert teamMembersToInsert;
        }
    }

    private static void applySdrTeamMemberValues(
        AccountTeamMember teamMember
    ) {
        teamMember.TeamMemberRole = SDR_TEAM_ROLE;
        teamMember.CaseAccessLevel = ACCESS_EDIT;
        teamMember.ContactAccessLevel = ACCESS_READ;
        teamMember.AccountAccessLevel = ACCESS_READ;
        teamMember.OpportunityAccessLevel = ACCESS_READ;
    }

    private Id getSdrUserIdForTerritory(String territory) {
        return territoryKeyToSdrUserId.get(normalizeTerritory(territory));
    }

    private static String normalizeTerritory(String territory) {
        if (String.isBlank(territory)) {
            return null;
        }

        return territory.trim().toLowerCase();
    }

    private static String accountUserKey(Id accountId, Id userId) {
        return String.valueOf(accountId) + ':' + String.valueOf(userId);
    }
}