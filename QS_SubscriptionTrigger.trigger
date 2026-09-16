/*
*QS_SubscriptionTrigger
*Created:
* 01.13.2020: Ved Swaminathan: Added functionality to apply product grouping from the Subscription/Quoteline to the Account.
* Function name: applyProductGroupingfromSubscriptions
*/

trigger QS_SubscriptionTrigger on SBQQ__Subscription__c (after update, after insert) {
    
    QS_Console__mdt currentConsoleSettings = [select Id, QS_Enable_Product_Grouping__c from QS_Console__mdt where MasterLabel =: System.Label.QS_Console_Master_Label LIMIT 1 ];
    
    if(currentConsoleSettings.QS_Enable_Product_Grouping__c){
        if(Trigger.IsAfter && (Trigger.IsInsert || Trigger.IsUpdate))
        {
            QS_SubscriptionTriggerHandler sth = new QS_SubscriptionTriggerHandler();
            List<Id> listofSubscriptionIds = new List<Id>();
            for(sObject obj : Trigger.new)
            {
                SBQQ__Subscription__c currentSub = (SBQQ__Subscription__c)obj;
                listofSubscriptionIds.add(currentSub.Id);
            }
            
            if(System.IsBatch() == false && System.isFuture() == false){ 
                QS_SubscriptionTriggerHandler.applyProductGroupingfromSubscriptions(listofSubscriptionIds);
            }
            
            
            
            
        }
    }
    
    
    
    
    
}