public class AccountTeamMemberHandler {
    // Change these to match your org
    private static final String TAM_ROLE = 'Technical Account Manager';
    private static final String FLAG_VALUE = 'UPDATE';

    // Simple recursion guard (prevents infinite loops if other automation touches team members)
    private static Boolean isRunning = false;

    public static void markAccountsForIntegrationUpdate(
        List<AccountTeamMember> newList,
        Map<Id, AccountTeamMember> oldMap
    ) {
        
       /* Automation_Settings__c triggerSetting = Automation_Settings__c.getInstance(UserInfo.getUserId());
        System.debug('Case Trigger is Enabled: ' + triggerSetting);
        
        if (!triggerSetting.Case_Trigger_Enabled__c) {
            System.debug('Bypassed AttachmentTrigger');
            return;
        }*/
        if (isRunning) return;
        isRunning = true;

        Set<Id> accountIdsToUpdate = new Set<Id>();

        for (AccountTeamMember atm : newList) {
            if (atm.AccountId == null) continue;

            // AFTER INSERT / AFTER UNDELETE: oldMap is null
            if (oldMap == null) {
                if (atm.TeamMemberRole == TAM_ROLE) {
                    accountIdsToUpdate.add(atm.AccountId);
                    System.debug('In AccountTeamTrgHandler line 25');
                }
                continue;
            }

            // AFTER UPDATE: only act when role becomes TAM or record changes to TAM
            AccountTeamMember oldAtm = oldMap.get(atm.Id);
            Boolean becameTAM = (oldAtm == null || oldAtm.TeamMemberRole != TAM_ROLE) && (atm.TeamMemberRole == TAM_ROLE);

            if (becameTAM) {
                accountIdsToUpdate.add(atm.AccountId);
                System.debug('In AccountTeamTrgHandler line 35');
            }
        }

        if (accountIdsToUpdate.isEmpty()) return;

        // Update Accounts in bulk
        List<Account> accts = [
            SELECT Id, Integration_Flag__c
            FROM Account
            WHERE Id IN :accountIdsToUpdate
        ];

        for (Account a : accts) {
            a.Integration_Flag__c = FLAG_VALUE;
            System.debug('In AccountTeamTrgHandler line 51');
        }

        update accts;
    }
}