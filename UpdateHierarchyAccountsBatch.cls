public class UpdateHierarchyAccountsBatch implements Database.Batchable<SObject>,Database.Stateful {

    private String ultimateParentId;
    private String territoryName;
    private String segment;
    private Id newOwnerId;
    private Id sdrOwnerId;
    private Set<Id> updatedAccountIds = new Set<Id>();
    
    public UpdateHierarchyAccountsBatch(String ultimateParentId, String segment, String territoryName, Id newOwnerId, Id sdrOwnerId) {
    
        this.ultimateParentId = ultimateParentId;
        this.newOwnerId = newOwnerId;
        this.territoryName = territoryName;
        this.segment = segment;
        this.sdrOwnerId = sdrOwnerId;
        
        
    }
    

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Id, OwnerId, Segment__c, Territory_Name__c, SDR_Owner__c,
                (SELECT Id, TeamMemberRole, UserId FROM AccountTeamMembers WHERE TeamMemberRole != 'Sales Development Rep' and User.IsActive = TRUE)
            FROM Account
            WHERE Ultimate_Parent_ID__c = :ultimateParentId
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
            
                    AccountTeamMember newATM = new AccountTeamMember();
                    newATM.AccountId = acct.Id;
                    newATM.UserId = sdrOwnerId;
                    newATM.TeamMemberRole = 'Sales Development Rep';
                    teamMembersToReinsert.add(newATM);
                    

            // Update the Account

       
            updatedAccountIds.add(acct.Id);
            System.debug('set has' +updatedAccountIds);
            acct.OwnerId = newOwnerId;
            acct.SDR_Owner__c = sdrOwnerId;
            acct.Segment__c = segment;
            acct.Territory_Name__c = territoryName;
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
        
       UpdateAccountHiearchyContactsBatch contactBatch = new UpdateAccountHiearchyContactsBatch(updatedAccountIds, newOwnerId, sdrOwnerId, territoryName, ultimateParentId, segment);
         Database.executeBatch(contactBatch, 100);
    
    }
}