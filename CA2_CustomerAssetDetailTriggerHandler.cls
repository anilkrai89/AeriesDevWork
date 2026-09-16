/**
* Handler class for Customer Asset Detail object trigger. Updates the Currently Active date on the CAT record based on the dates
*
*/
public class CA2_CustomerAssetDetailTriggerHandler extends CA2_TriggerHandler {
    
    protected override void beforeUpdate() {
        
        if(CA2_CustomerAssetUtil.Create_CA_On_Update) {
            handleBeforeUpdate(Trigger.New,null); 
        }
        
        
    }
    
    protected override void afterInsert() {
        updateStatusCustomerAssets(Trigger.New,Trigger.old); 
    }
    protected override void afterUpdate() {
        updateStatusCustomerAssets(Trigger.New,Trigger.old); 
    }
    protected override void beforeInsert() {
        if(CA2_CustomerAssetUtil.ActivateTwinFielding)
            CA2_TwinField.runTwinHelper(Trigger.new);
        setSecondaryAccount(Trigger.new);
    }
    
    
    public void UpdateStatusCustomerAssets(List<QS_Customer_Asset_Detail__c> lstTriggerCADetails,List<QS_Customer_Asset_Detail__c> lstTriggerCADetailsOldMap){
        
        try{
            
            
            List<QS_Customer_Asset_Detail__c> cadupdate = new List<QS_Customer_Asset_Detail__c>();
            Set<Id> customerAssetIds = new Set<Id>();     
            
            //loop over the Customer Asset Detail and save all the CA ids
            for(QS_Customer_Asset_Detail__c cad: lstTriggerCADetails){
                //only if the id                        
                customerAssetIds.add(cad.QS_Customer_Asset__c);                
            }
            
            
            //get Master Customer Assets
            List<QS_Customer_Asset__c> customerAssets = new List<QS_Customer_Asset__c>();
            customerAssets = [SELECT Id,QS_Quantity__c,(SELECT Id, QS_Quantity__c,Name,QS_New_Asset_Status__c,
                                                        QS_Terminated_Date__c,CreatedDate, QS_Customer_Asset__c, 
                                                        QS_Customer_Asset__r.QS_Dynamic_Current_Date__c,
                                                        QS_End_Date__c,QS_Start_Date__c FROM QS_Customer_Asset_Details__r) 
                              FROM QS_Customer_Asset__c where Id =: customerAssetIds FOR UPDATE];
            
            //get Master Customer Assets
            update customerAssets;
            
        }catch(Exception ex)
        {
            QS_Helper.logException('Exception', 'Update Customer Asset Status', 'CA2_CustomerAssetDetailTriggerHandler', 'UpdateStatusCustomerAssets', 'QS_Customer_Asset_Detail__c', userInfo.getUserId(), 
                                   ex.getLineNumber(), ex.getTypeName(), string.valueOf(ex.getCause()), ex.getMessage(), ex.getStackTraceString());
        }
    }
    
    public void handleBeforeUpdate(List<QS_Customer_Asset_Detail__c> lstTriggerCADetails, Date currentDate){      
        
        try
        {
            
            System.debug('VCG Debug: Handle BEfore Update');
            date dt = system.today();
            for(QS_Customer_Asset_Detail__c cad: lstTriggerCADetails){
                dt = cad.QS_Customer_Asset__r.QS_Dynamic_Current_Date__c;
                //update Currently Active
                if(cad.QS_New_Asset_Status__c == 'Expired')
                {
                    cad.QS_Currently_Active__c = false;
                }
                else if(cad.QS_End_Date__c < dt)
                {
                    cad.QS_Currently_Active__c = false;
                }    
                else if(cad.QS_End_Date__c > dt && cad.QS_Start_Date__c <= dt)
                {
                    cad.QS_Currently_Active__c = true;
                }
                else if(cad.QS_End_Date__c > dt && cad.QS_Start_Date__c > dt)
                {
                    cad.QS_Currently_Active__c = false;
                }
                
                if(cad.QS_End_Date__c == null)
                {
                    cad.QS_Currently_Active__c = true; //For Prepertual Licenses, there is no end date.
                }
                
            }
            
        }catch(Exception ex)
        {
            QS_Helper.logException('Exception', 'Handle before update', 'CA2_CustomerAssetDetailTriggerHandler', 'handleBeforeUpdate', 'QS_Customer_Asset_Detail__c', userInfo.getUserId(), 
                                   ex.getLineNumber(), ex.getTypeName(), string.valueOf(ex.getCause()), ex.getMessage(), ex.getStackTraceString());
        }
    }
    
    private void setSecondaryAccount(List<QS_Customer_Asset_Detail__c> records){
        Set<Id> qsCustomerAssetSubscriptionIds = new Set<Id>();
        Set<Id> qsAssetIds = new Set<Id>();

        for(QS_Customer_Asset_Detail__c qsCustomerAssetDetail : records){
            if(qsCustomerAssetDetail.QS_Subscription__c != null){
                qsCustomerAssetSubscriptionIds.add(qsCustomerAssetDetail.QS_Subscription__c);
            }
            if(qsCustomerAssetDetail.QS_Asset__c != null){
                qsAssetIds.add(qsCustomerAssetDetail.QS_Asset__c);
            }
        }


        if(!qsCustomerAssetSubscriptionIds.isEmpty() || !qsAssetIds.isEmpty()){
            Map<Id, SBQQ__Subscription__c> subscriptionMap = new Map<Id, SBQQ__Subscription__c>(
            [SELECT Id, QS_Secondary_Account_Id__c FROM SBQQ__Subscription__c WHERE Id IN:qsCustomerAssetSubscriptionIds]);

            Map<Id, Asset> assetMap = new Map<Id, Asset>(
            [SELECT Id, QS_Secondary_Account_Id__c FROM Asset WHERE Id IN:qsAssetIds]);

            for(QS_Customer_Asset_Detail__c qsCustomerAssetDetail : records){
                if(qsCustomerAssetSubscriptionIds.contains(qsCustomerAssetDetail.QS_Subscription__c)
                        && subscriptionMap.containsKey(qsCustomerAssetDetail.QS_Subscription__c)){
                    qsCustomerAssetDetail.QS_Secondary_Account__c = subscriptionMap.get(qsCustomerAssetDetail.QS_Subscription__c).QS_Secondary_Account_Id__c;
                }else if(qsAssetIds.contains(qsCustomerAssetDetail.QS_Asset__c)
                        && assetMap.containsKey(qsCustomerAssetDetail.QS_Asset__c)){
                    qsCustomerAssetDetail.QS_Secondary_Account__c = assetMap.get(qsCustomerAssetDetail.QS_Asset__c).QS_Secondary_Account_Id__c;
                }
            }
        }
    }
    
}