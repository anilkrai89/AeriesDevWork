/*
Description: Custom trigger on the Custom QS_Customer_Asset_Detail__c object. Invokes Handler.
*/
trigger CA2_CustomerAssetDetailTrigger on QS_Customer_Asset_Detail__c (before insert, after Insert, before update, after update, before delete, after delete, after undelete) { 
    new CA2_CustomerAssetDetailTriggerHandler().run();
}