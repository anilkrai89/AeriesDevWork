/**
* Description: Batch job class to update the Customer Asset Transaction status records to indicate whether they are Active or Inactive
*
*/
global class CA2_CustomerAssetDetailStatusBatchable implements Database.Batchable<sObject> {
    
    Date staticdate = System.Today();
   // Date staticdate = Date.parse('03/03/2023');
    Boolean isRenewalClosedWon = false;
    Boolean isRenewalClosed = false;
    Boolean isRenewalGenerated = false;
    Boolean isLastSegment = false;
    Boolean isRenewalPastDue = false;
    Boolean isDecommRecordCreated = false;
    String query = 'SELECT Id,QS_Is_Renewal_Closed__c,QS_Is_Last_Segment__c,QS_Migrated_No_Renewal__c,QS_Customer_Asset__r.QS_Dynamic_Current_Date__c,QS_Renewed_Date__c, QS_New_Asset_Status__c, QS_Customer_Asset__c,QS_Customer_Asset__r.QS_Simulated_Current_Date__c,QS_Currently_Active__c, QS_End_Date__c,QS_Start_Date__c,QS_Terminated_Date__c FROM QS_Customer_Asset_Detail__c where QS_New_Asset_Status__c in (\'Active\',\'Reduced\',\'Pending Activation\',\'Pending Renewal\',\'Pending Reduction\',\'Pending Decommission\',\'Decommissioned\')';    
    //  String query = 'SELECT Id,QS_Is_Renewal_Closed__c,QS_Is_Last_Segment__c,QS_Migrated_No_Renewal__c,QS_Customer_Asset__r.QS_Dynamic_Current_Date__c,QS_Renewed_Date__c, QS_New_Asset_Status__c, QS_Customer_Asset__c,QS_Customer_Asset__r.QS_Simulated_Current_Date__c,QS_Currently_Active__c, QS_End_Date__c,QS_Start_Date__c,QS_Terminated_Date__c FROM QS_Customer_Asset_Detail__c where QS_Customer_Asset__r.Id =\'a0C0v000002OxZDEA0\'';    
    
    
    /**
* Batachable start method implementation.
* @param BC The BatchableContext object provided by runtime.
* @return List of Customer Assets to be updated.
*/
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(query);
    }
    
    /**
* Batchable execute method implementation.
* This method applies expiration logic and updates on Customer Asset's Detail status.
*/
    global void execute(Database.BatchableContext BC, List<QS_Customer_Asset_Detail__c> scope) {
        executeBatchJob(scope,staticdate);
    }
    
    global void executeBatchJob(List<QS_Customer_Asset_Detail__c> scope,Date dt)
    {
        dt = dt.addDays(Integer.valueOf(CA2_CustomerAssetUtil.daysFromExpiration)); 
        try{
            List<QS_Customer_Asset_Detail__c> cadforUpdate = new List<QS_Customer_Asset_Detail__c>();  
            Date effective_end_Date;      
            System.debug('In Batch Execute --->' + scope.size());
            for(QS_Customer_Asset_Detail__c cad: scope) {
                
                if(cad.QS_New_Asset_Status__c == 'Expired')
                {
                    cad.QS_Currently_Active__c = false;
                }
                else if(cad.QS_End_Date__c < dt)
                {
                    cad.QS_Currently_Active__c = false;
                }    
                else if(cad.QS_End_Date__c >= dt && cad.QS_Start_Date__c <= dt)
                {
                    cad.QS_Currently_Active__c = true;
                }
                else if(cad.QS_End_Date__c > dt && cad.QS_Start_Date__c > dt)
                {
                    cad.QS_Currently_Active__c = false;
                }
                
                
                //This is to ensure the CADs generated from Assets are always currently Active and CADs pending renewal are also set to Active.
                if(cad.QS_End_Date__c ==null // Asset Condition
                   || 
                   (cad.QS_End_Date__c < dt
                    && cad.QS_Renewed_Date__c == null
                    && cad.QS_Is_Renewal_Closed__c == false
                    && cad.QS_Migrated_No_Renewal__c == false
                    && cad.QS_Is_Last_Segment__c == true
                    && cad.QS_New_Asset_Status__c <> 'Decommissioned'
                    && cad.QS_Terminated_Date__c == null
                   )) //Pending Renewal Condition
                {
                    cad.QS_Currently_Active__c = true;
                }
                
                cadforUpdate.add(cad);
            }
            if(cadforUpdate.size() > 0){
                update cadforUpdate;            
            }
        }
        catch(Exception ex)
        {
            QS_Helper.logException('Exception', 'batch job - automatic - updating CAD', 'CA2_CustomerAssetDetailStatusBatchable', 'executeBatchJob', 'Customer Asset Detail', userInfo.getUserId(), 
                                   ex.getLineNumber(), ex.getTypeName(), string.valueOf(ex.getCause()), ex.getMessage(), ex.getStackTraceString());
        }
    }
    
    
    
    
    /**
* Batchable finish method implementation.
* @param BC The BatchableContext object provided by runtime.
*/
    global void finish(Database.BatchableContext BC) {
    }
    
}