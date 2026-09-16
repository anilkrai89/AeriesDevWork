trigger ContactDeleteTrigger on Contact (after delete, after undelete) {
    Set<Id> accountIds = new Set<Id>();

    if (Trigger.isDelete) {
        for (Contact c : Trigger.old) {
            if (c.AccountId != null) {
                accountIds.add(c.AccountId);
            }
        }
    }

    if (Trigger.isUndelete) {
        for (Contact c : Trigger.new) {
            if (c.AccountId != null) {
                accountIds.add(c.AccountId);
            }
        }
    }

    AccountContactCountHandler.updateCounts(accountIds);
}