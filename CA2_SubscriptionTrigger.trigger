/*
Description: Custom trigger on the SBQQ__Subscription__c object. Invokes Handler.
*/
trigger CA2_SubscriptionTrigger on SBQQ__Subscription__c (after insert, after update, before update, before insert, before delete, after delete, after undelete) {
    new CA2_SubscriptionTriggerHandler().run();
}