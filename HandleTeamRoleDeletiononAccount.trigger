trigger HandleTeamRoleDeletiononAccount on AccountTeamMember (after delete) {

    Set<Id> accountsWithSalesRepDeletion = new Set<Id>();
    Set<Id> accountsWithRenewalSpecDeletion = new Set<Id>();
    Set<Id> accountsWithExecCSMDeletion = new Set<Id>();
    
    // Check deleted members for specific roles and collect their Account IDs
    for (AccountTeamMember deletedMember : Trigger.old) {
        if (deletedMember.TeamMemberRole == 'Sales Development Rep') {
            accountsWithSalesRepDeletion.add(deletedMember.AccountId);
        } else if (deletedMember.TeamMemberRole == 'Renewal Specialist') {
            accountsWithRenewalSpecDeletion.add(deletedMember.AccountId);
        }else if (deletedMember.TeamMemberRole == 'Executive CSM') {
            accountsWithExecCSMDeletion.add(deletedMember.AccountId);
        }
    }

    // Map to decide which fields to clear based on remaining roles
    Map<Id, Boolean> clearSalesRep = new Map<Id, Boolean>();
    Map<Id, Boolean> clearRenewalSpec = new Map<Id, Boolean>();
    Map<Id, Boolean> clearExecCSMSpec = new Map<Id, Boolean>();
    
    // Initialize maps assuming that fields need to be cleared
    for (Id accountId : accountsWithSalesRepDeletion) {
        clearSalesRep.put(accountId, true);
    }
    for (Id accountId : accountsWithRenewalSpecDeletion) {
        clearRenewalSpec.put(accountId, true);
    }
    for (Id accountId : accountsWithExecCSMDeletion) {
        clearExecCSMSpec.put(accountId, true);
    }
    // Query remaining Account Team Members in affected accounts
    List<AccountTeamMember> remainingMembers = [SELECT AccountId, TeamMemberRole FROM AccountTeamMember WHERE (AccountId IN :accountsWithSalesRepDeletion OR AccountId IN :accountsWithRenewalSpecDeletion OR AccountId IN :accountsWithExecCSMDeletion) AND Ready_for_Delete__c = false];
    for (AccountTeamMember member : remainingMembers) {
        if (member.TeamMemberRole == 'Sales Development Rep' && clearSalesRep.containsKey(member.AccountId)) {
            clearSalesRep.put(member.AccountId, false); // Another SalesRep exists, do not clear
        }
        if (member.TeamMemberRole == 'Renewal Specialist' && clearRenewalSpec.containsKey(member.AccountId)) {
            clearRenewalSpec.put(member.AccountId, false); // Another Renewal Specialist exists, do not clear
        }
        if (member.TeamMemberRole == 'Executive CSM' && clearExecCSMSpec.containsKey(member.AccountId)) {
            clearExecCSMSpec.put(member.AccountId, false); // Another ECSM exists, do not clear
        }
        
    }

    // Retrieve and update Accounts as necessary
    List<Account> accountsToUpdate = [SELECT Id, SDR_Owner__c, Primary_Renewal_Specialist__c, Primary_CSM__c FROM Account WHERE Id IN :clearSalesRep.keySet() OR Id IN :clearRenewalSpec.keySet()OR Id IN :clearExecCSMSpec.keySet()];
    for (Account acc : accountsToUpdate) {
        if (clearSalesRep.containsKey(acc.Id) && clearSalesRep.get(acc.Id)) {
            acc.SDR_Owner__c = null;
        }
        if (clearRenewalSpec.containsKey(acc.Id) && clearRenewalSpec.get(acc.Id)) {
            acc.Primary_Renewal_Specialist__c = null;
        }
        if (clearExecCSMSpec.containsKey(acc.Id) && clearExecCSMSpec.get(acc.Id)) {
            acc.Primary_CSM__c = null;
        }        
    }

    // Perform the update operation if there are accounts to update
    if (!accountsToUpdate.isEmpty()) {
        update accountsToUpdate;
    }
}