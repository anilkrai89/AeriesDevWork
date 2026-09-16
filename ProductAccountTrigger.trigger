trigger ProductAccountTrigger on Product_Account__c (
    after insert, after update, after delete, after undelete
) {
    ProductAccountTriggerHandler.handle();
}