trigger ChangeCSOwnerTaskTrigger on Task (before insert, before update) {
    Set<Id> accountIds = new Set<Id>();
    Set<Id> contactIds = new Set<Id>();
    Set<Id> opportunityIds = new Set<Id>();
    Set<Id> ownerIds = new Set<Id>();

    // Collect account Ids and Owner Ids
    for (Task t : Trigger.new) {
        if (String.isNotBlank(t.WhatId) && t.WhatId.getSObjectType() == Account.SObjectType) {
            accountIds.add(t.WhatId);
        }
        if (String.isNotBlank(t.WhatId) && t.WhatId.getSObjectType() == Opportunity.SObjectType) {
            opportunityIds.add(t.WhatId);
        }
        if (t.WhoId != null) { 
            String contask = t.WhoId;
            String whoIdPrefix = contask.substring(0, 3);
            if (whoIdPrefix == '003') {
                contactIds.add(t.WhoId);
            }
        }
        ownerIds.add(t.OwnerId);       
    }

    // Query to map Account, Opportunity, and Contact owners
    Map<Id, Id> accountOwnerMap = new Map<Id, Id>();
    Map<Id, Id> opportunityOwnerMap = new Map<Id, Id>();
    Map<Id, Id> contactOwnerMap = new Map<Id, Id>();

    if (!accountIds.isEmpty()) {
        for (Account acc : [SELECT Id, OwnerId FROM Account WHERE Id IN :accountIds]) {
            accountOwnerMap.put(acc.Id, acc.OwnerId);
        }
    }
    if (!opportunityIds.isEmpty()) {
        for (Opportunity opp : [SELECT Id, Account.OwnerId FROM Opportunity WHERE Id IN :opportunityIds]) {
            if (opp.AccountId != null && opp.Account.OwnerId != null) {
                opportunityOwnerMap.put(opp.Id, opp.Account.OwnerId);
            }
        }
    }
    if (!contactIds.isEmpty()) {
        for (Contact cont : [SELECT Id, Account.OwnerId FROM Contact WHERE Id IN :contactIds]) {
            if (cont.AccountId != null && cont.Account.OwnerId != null) {
                contactOwnerMap.put(cont.Id, cont.Account.OwnerId);
            }
        }
    }

    // Map to check User profiles
    Map<Id, User> userMap = new Map<Id, User>();
    if (!ownerIds.isEmpty()) {
        userMap = new Map<Id, User>([SELECT Id, Profile.Name FROM User WHERE Id IN :ownerIds]);
    }

    // Assign new owner
    Id defaultOwnerId = UserInfo.getUserId();
    for (Task t : Trigger.new) {
        User taskOwner = userMap.get(t.OwnerId);
        if (taskOwner != null && taskOwner.Profile.Name == 'QB - Customer PS/Success') {
            if (accountOwnerMap.containsKey(t.WhatId)) {
                t.OwnerId = accountOwnerMap.get(t.WhatId);
            } else if (opportunityOwnerMap.containsKey(t.WhatId)) {
                t.OwnerId = opportunityOwnerMap.get(t.WhatId);
            } else if (contactOwnerMap.containsKey(t.WhoId)) {
                t.OwnerId = contactOwnerMap.get(t.WhoId);
            } else {
                t.OwnerId = defaultOwnerId;
            }
        }
        if (t.OwnerId == null) {
            t.OwnerId = defaultOwnerId;
        }
    }
}