/* 
* Function: addDecommissionRecordsForZeroedOutProducts
* Description: For any closed opportunities, that are either won or lost, 
* this function identifies the 0 quantity quote line items, identifies the Customer Assets and Details related to 
* those and sets them to Expired and also creates a decommission record for the Assets. 
* For closed Lost opportunities, all of the decommissioned CAD records are created for all QLs in the Quote. 
* For Closed Won opportunities only the zeroed out Quote lines have CADs created
* 
* 
* 
* 
* Function: UpdateHistoricalCadsPendingRenewal
* Description: For any closed renewal, any historical CADs associated with the contracts of the previous opportunity are set to Expired.
*/


public class CA2_OpportunityTriggerHandler {
    public CA2_OpportunityTriggerHandler() {
        
    }
    
    
    
    Public void addDecommissionRecordsForZeroedOutProducts(List<Opportunity> oppList)
    {
        List<Opportunity> listOfClosedOpportunities = new List<Opportunity>();
        List<Opportunity> listOfClosedRenewals = new List<Opportunity>();
        System.debug('OPP LIST SIZE' + oppList.size());
        for(Opportunity opp : oppList)
        {
            string recordtypename = Schema.SObjectType.Opportunity.getRecordTypeInfosById().get(opp.recordtypeid).getname();
            if(opp.IsClosed)
                listOfClosedOpportunities.add(opp);
            
            if(recordtypename.contains('Renewal') && opp.IsClosed)
            {
                listOfClosedRenewals.add(opp);
            }
            System.debug('listOfClosedRenewals' + listOfClosedRenewals);    
        }
        
        if(listOfClosedOpportunities.size()>0)
            processZeroedOutQuoteLines(listOfClosedOpportunities);
        
        if(listOfClosedRenewals.size()>0)
            UpdateHistoricalCadsPendingRenewal(listOfClosedRenewals);
    }
    
    public void processZeroedOutQuoteLines(List<Opportunity> closedOpps)
    {
        try{
            Set<Id> primaryQuoteIds = new Set<Id>();
            List<SBQQ__QuoteLine__c> lstOfDecmmProcessedQL = new List<SBQQ__QuoteLine__c>();
            for(Opportunity opp : closedOpps)
            {
                primaryQuoteIds.add(opp.SBQQ__PrimaryQuote__c);
            }
            System.debug('VCG Debug ===> Primary Quote Ids' + primaryQuoteIds);
            
            List<SBQQ__QuoteLine__c> quoteLineItems = [select Id,QS_Related_Customer_Asset_Id__c,
                                                       SBQQ__Product__c,
                                                       SBQQ__Product__r.SBQQ__SubscriptionPricing__c,
                                                       QS_Account_Id__c,SBQQ__Quantity__c, 
                                                       QS_Quote_Type__c,SBQQ__Quote__r.SBQQ__StartDate__c,
                                                       SBQQ__Quote__r.SBQQ__Opportunity2__r.SBQQ__RenewedContract__c,
                                                       SBQQ__Quote__r.SBQQ__Opportunity2__r.StageName,
                                                       SBQQ__Quote__r.SBQQ__Opportunity2__r.IsWon,
                                                       SBQQ__Quote__r.SBQQ__Opportunity2__r.CloseDate,
                                                       SBQQ__RenewedSubscription__r.QS_Parent_Customer_Asset_Id__c,
                                                       SBQQ__RenewedSubscription__r.QS_Customer_Asset_Unique_Id__c,
                                                       QS_Booking_Date__c,CurrencyIsoCode,QS_Decomm_On_Renewal_Processed__c
                                                       from SBQQ__QuoteLine__c 
                                                       where SBQQ__Quote__c in: primaryQuoteIds];
            
            
            Set<String> relatedCustomerAssetIds = new Set<String>();            
            Set<Id> setOfProcessedCustomerAssets = new Set<Id>();
            
            System.debug('VCG Debug ===> Quote Line Count' + quoteLineItems.size());
            
            List<QS_Customer_Asset_Detail__c> listOfCADRecordsToExpire = new List<QS_Customer_Asset_Detail__c>();
            List<QS_Customer_Asset_Detail__c> listOfDecommRecordsToInsert = new List<QS_Customer_Asset_Detail__c>();        
            for(SBQQ__QuoteLine__c ql : quoteLineItems)
            {
                if(
                    ( 
                        ((ql.SBQQ__Quantity__c == 0 && ql.SBQQ__Quote__r.SBQQ__Opportunity2__r.IsWon && CA2_CustomerAssetUtil.NoCADCreationFromOpp == false) 
                         || (!ql.SBQQ__Quote__r.SBQQ__Opportunity2__r.IsWon))
                    )
                    && ql.QS_Quote_Type__c=='Renewal' 
                )
                {
                    if(ql.SBQQ__Product__r.SBQQ__SubscriptionPricing__c == 'Percent of Total') //For Percentage of total products, we tie Decommission record to the Parent Asset
                    {
                        relatedCustomerAssetIds.add(ql.SBQQ__RenewedSubscription__r.QS_Parent_Customer_Asset_Id__c);
                    }else
                    {
                        relatedCustomerAssetIds.add(ql.SBQQ__RenewedSubscription__r.QS_Customer_Asset_Unique_Id__c );
                    }
                }
                
                
            }
            
            System.debug('VCG Debug ===> Customer asset list' + relatedCustomerAssetIds);
            List<QS_Customer_Asset__c> listOfCustomerAssetsToAddDecommissionRecords = [select Id, QS_Product__c,QS_Account__c,CurrencyIsoCode,
                                                                                       QS_Customer_Asset_Unique_Id__c,
                                                                                       (
                                                                                           select Id,
                                                                                           QS_New_Asset_Status__c,
                                                                                           QS_Currently_Active__c,
                                                                                           QS_Product__c,
                                                                                           QS_Start_Date__c,
                                                                                           QS_Booking_Date__c,
                                                                                           QS_End_Date__c,
                                                                                           QS_Terminated_Date__c,
                                                                                           QS_Contract__r.StartDate,
                                                                                           QS_Contract__r.EndDate,
                                                                                           CurrencyIsoCode
                                                                                           FROM QS_Customer_Asset_Details__r 
                                                                                       ) FROM QS_Customer_Asset__c 
                                                                                       where QS_Customer_Asset_Unique_Id__c in: 
                                                                                       relatedCustomerAssetIds ];
            
            
            
            System.debug('listOfCustomerAssetsToAddDecommissionRecords ' + listOfCustomerAssetsToAddDecommissionRecords.size());
            if(listOfCustomerAssetsToAddDecommissionRecords.size() > 0)
            {
                
                for(SBQQ__QuoteLine__c currentLine : quoteLineItems)
                {
                    for(QS_Customer_Asset__c customerAsset : listOfCustomerAssetsToAddDecommissionRecords)
                    {
                        if(
                            (customerAsset.QS_Customer_Asset_Unique_Id__c == currentLine.SBQQ__RenewedSubscription__r.QS_Parent_Customer_Asset_Id__c )
                            ||
                            (customerAsset.QS_Customer_Asset_Unique_Id__c == currentLine.SBQQ__RenewedSubscription__r.QS_Customer_Asset_Unique_Id__c)
                        )
                        {
                            listOfDecommRecordsToInsert.add(getDecommissionRecordByQuoteLine(currentLine,customerAsset));
                        }
                        
                    }
                    currentLine.QS_Decomm_On_Renewal_Processed__c = true;
                    lstOfDecmmProcessedQL.add(currentLine);
                    
                }
                
                System.debug('List of Decommission Records to Insert' + listOfDecommRecordsToInsert);     
                insert listOfDecommRecordsToInsert;
                update listOfCADRecordsToExpire;
                update lstOfDecmmProcessedQL;   
                
            }
        }catch(Exception ex)
        {
            QS_Helper.logException('Exception', 'Processing of Quotelines for decomm record creation', 'CA2_OpportunityTriggerHandler', 'processZeroedOutQuoteLines', 'Opportunity', userInfo.getUserId(), 
                                   ex.getLineNumber(), ex.getTypeName(), string.valueOf(ex.getCause()), ex.getMessage(), ex.getStackTraceString());
        }
    }
    
    public QS_Customer_Asset_Detail__c getDecommissionRecordByQuoteLine(SBQQ__QuoteLine__c quoteLine,QS_Customer_Asset__c customerAsset)
    {
        try
        {
            System.debug('In createDecommissionedRecord');
            QS_Customer_Asset_Detail__c decommRecordToBeCreated = new QS_Customer_Asset_Detail__c();
            decommRecordToBeCreated.QS_Start_Date__c = quoteLine.SBQQ__Quote__r.SBQQ__StartDate__c;
            decommRecordToBeCreated.QS_End_Date__c = quoteLine.SBQQ__Quote__r.SBQQ__StartDate__c;
            decommRecordToBeCreated.QS_Booking_Date__c = quoteLine.QS_Booking_Date__c;
            decommRecordToBeCreated.QS_Quantity__c = 0;
            decommRecordToBeCreated.QS_Annual_Recurring_Revenue__c = 0;
            decommRecordToBeCreated.QS_Product__c = quoteLine.SBQQ__Product__c;
            decommRecordToBeCreated.QS_Customer_Asset__c = customerAsset.Id;
            decommRecordToBeCreated.QS_Quote_Line__c = quoteLine.Id;
            decommRecordToBeCreated.QS_Previous_Contract__c = quoteLine.SBQQ__Quote__r.SBQQ__Opportunity2__r.SBQQ__RenewedContract__c;
            decommRecordToBeCreated.QS_Apex_Created_Decommission_Record__c = true;
            decommRecordToBeCreated.CurrencyIsoCode = quoteLine.CurrencyIsoCode;
            return decommRecordToBeCreated;
            
            
        }
        Catch(Exception ex)
        {
            QS_Helper.logException('Exception', 'Retrieving a Decomm Record created from QL', 'CA2_OpportunityTriggerHandler', 'getDecommissionRecordByQuoteLine', 'Opportunity', userInfo.getUserId(), 
                                   ex.getLineNumber(), ex.getTypeName(), string.valueOf(ex.getCause()), ex.getMessage(), ex.getStackTraceString());
            
            return null;    
        }
        
    }
    
    public void UpdateHistoricalCadsPendingRenewal(List<Opportunity> closedRenewalOpps)
    {
        try
        {
            
            System.debug('In update historicals');
            //Identify Contract for which these opps are these renewals
            Set<Id> setOfOpportunityIds = (new Map<Id,SObject>(closedRenewalOpps)).keySet();
            System.debug('setOfOpportunityIds' + setOfOpportunityIds);
            List<Contract> contractListWithRenewalOpps = [select Id from Contract where SBQQ__RenewalOpportunity__c in: setOfOpportunityIds];
            Set<Id> setOfContractIds = (new Map<Id,SObject>(contractListWithRenewalOpps)).keySet();
            System.debug('setOfContractIds' + setOfContractIds);
            
            List<QS_Customer_Asset_Detail__c> lstOfCadsRelatedToClosedContracts 
                = [select Id, QS_New_Asset_Status__c,QS_Currently_Active__c from QS_Customer_Asset_Detail__c 
                   where QS_Contract__c in: setOfContractIds and QS_New_Asset_Status__c = 'Pending Renewal'];
            List<QS_Customer_Asset_Detail__c> listOfCADsForUpdate = new List<QS_Customer_Asset_Detail__c>();
            for(QS_Customer_Asset_Detail__c currentCAD : lstOfCadsRelatedToClosedContracts)
            {
                currentCAD.QS_Currently_Active__c = false;
                listOfCADsForUpdate.add(currentCAD);            
            }
            update listOfCADsForUpdate;
            
        }
        Catch(Exception ex)
        {
            QS_Helper.logException('Exception', 'Updating Historical CADs Pending Renewal', 'CA2_OpportunityTriggerHandler', 'UpdateHistoricalCadsPendingRenewal', 'Opportunity', userInfo.getUserId(), 
                                   ex.getLineNumber(), ex.getTypeName(), string.valueOf(ex.getCause()), ex.getMessage(), ex.getStackTraceString());
            
        }
        
    }
    
}