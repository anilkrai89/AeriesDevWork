/*
Description: Custom trigger on the Custom SBQQ__SubscribedAsset__c object. Invokes Handler.
*/
trigger CA2_SubscribedAssetTrigger on SBQQ__SubscribedAsset__c (before insert, after update, after insert, after delete) {
	
    if(Trigger.isBefore && Trigger.isInsert) {
        for(SBQQ__SubscribedAsset__c sa: Trigger.new) {
            sa.QS_UpsertKey__c = sa.SBQQ__Subscription__c + '' + sa.SBQQ__Asset__c;
        }
    }
    if(Trigger.isAfter && Trigger.isInsert) {
        if(!CA2_CustomerAssetUtil.ByPassTrigger || Test.isRunningTest()){
            CA2_AssetTriggerHandler.createCustomerAssets(Trigger.new);
        }
    }
    
    if(Trigger.isUpdate && Trigger.isAfter) {
        if(!CA2_CustomerAssetUtil.ByPassTrigger || Test.isRunningTest()){
            CA2_AssetTriggerHandler.createCustomerAssets(Trigger.new);
        }
            
    }
    
    
    

    
    
}