public class UpdateAccountOwnersBatch implements Database.Batchable<SObject>,Database.Stateful {

    private String territoryName;
    private Id newOwnerId;
    private Set<Id> updatedAccountIds = new Set<Id>();
    
    public UpdateAccountOwnersBatch(String territoryName, Id newOwnerId) {
        this.territoryName = territoryName;
        this.newOwnerId = newOwnerId;
        
        System.debug('territoryName'+territoryName);
    }
    

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Id, OwnerId, 
                (SELECT Id, TeamMemberRole, UserId FROM AccountTeamMembers WHERE User.IsActive = TRUE)
            FROM Account
            WHERE Territory_Name__c = :territoryName
        ]);
    }

    public void execute(Database.BatchableContext BC, List<Account> scope) {
        List<Account> accountsToUpdate = new List<Account>();
        List<AccountTeamMember> teamMembersToReinsert = new List<AccountTeamMember>();

        for (Account acct : scope) {
            // Store team members before ownership change
            if (acct.AccountTeamMembers != null) {
                for (AccountTeamMember atm : acct.AccountTeamMembers) {
                    AccountTeamMember newATM = new AccountTeamMember();
                    newATM.AccountId = acct.Id;
                    newATM.UserId = atm.UserId;
                    newATM.TeamMemberRole = atm.TeamMemberRole;
                    teamMembersToReinsert.add(newATM);
                }
            }

            // Update the owner

       
            updatedAccountIds.add(acct.Id);
            System.debug('set has' +updatedAccountIds);
            acct.OwnerId = newOwnerId;
            acct.Integration_Flag__c = 'UPDATE';
            acct.ValidationBypassDateTime__c = Datetime.now();
            accountsToUpdate.add(acct);
           
        }
        System.debug(' line 52 set has' +updatedAccountIds);

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }

        if (!teamMembersToReinsert.isEmpty()) {
            try {
                insert teamMembersToReinsert;
            } catch (DmlException e) {
                // Optionally log or handle duplicate inserts
                System.debug('Error reinserting AccountTeamMembers: ' + e.getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext BC) {
        
        System.debug('line 70 set has' +updatedAccountIds);
        
       UpdateAccountContactsBatch contactBatch = new UpdateAccountContactsBatch(updatedAccountIds, newOwnerId, territoryName);
         Database.executeBatch(contactBatch, 100);
    
    }
}