/*
*QS_SubscriptionTrigger
*Created:
* 01.13.2020: Ved Swaminathan: Added functionality to apply product grouping from the Assets/Quoteline to the Account.
* Function name: applyProductGroupingfromAssets
*/

trigger QS_AssetTrigger on Asset (after insert, after update) {
    QS_Console__mdt currentConsoleSettings = [select Id, QS_Enable_Product_Grouping__c from QS_Console__mdt where MasterLabel =: System.Label.QS_Console_Master_Label LIMIT 1 ];
      if(currentConsoleSettings.QS_Enable_Product_Grouping__c){
        if(Trigger.IsAfter && (Trigger.IsInsert || Trigger.IsUpdate))
        {
            QS_AssetTriggerHandler ath = new QS_AssetTriggerHandler();
            ath.applyProductGroupingfromAssets((List<Asset>)Trigger.new);
            
        }
    }
    
    
    
}