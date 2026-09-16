trigger AccountContactRelationTrigger on AccountContactRelation (after insert, after delete) {
    Set<Id> accountIds = new Set<Id>();

    if (Trigger.isInsert) {
        for (AccountContactRelation acr : Trigger.new) {
            if (acr.AccountId != null) {
                accountIds.add(acr.AccountId);
            }
        }
    }

    if (Trigger.isDelete) {
        for (AccountContactRelation acr : Trigger.old) {
            if (acr.AccountId != null) {
                accountIds.add(acr.AccountId);
            }
        }
    }

    AccountContactCountHandler.updateCounts(accountIds);
}