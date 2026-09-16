trigger QuoteLineTrigger on SBQQ__QuoteLine__c (before delete, before insert) {
    if (Trigger.isBefore) {
        if (Trigger.isDelete) {
            QuoteLineTriggerHandler.handleBeforeDelete(Trigger.old);
        }
        if(Trigger.isInsert){
            QuoteLineTriggerHandler.populateInitialARROnRenewal(Trigger.new);
        }
    }
}