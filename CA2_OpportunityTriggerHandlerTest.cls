/******************************************************************************
 * Test class for the OpportunityTrigger and it's supporting classes 
 *
 */
@isTest( SeeAllData=false )
private class CA2_OpportunityTriggerHandlerTest 
{
    @TestSetup
    static void makeData() {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User();
        u.Alias = 'tuser';
        u.Email = 'test@quickbase.com.test';
        u.EmailEncodingKey = 'UTF-8';
        u.FirstName = 'Test';
        u.LastName = 'TestUserUser';
        u.LanguageLocaleKey = 'en_US';
        u.LocaleSidKey = 'en_US';
        u.ProfileId = profile.Id;
        u.TimeZoneSidKey = 'America/Los_Angeles';
        u.Username = 'test@quickbase.com.test';
        insert u;
    }

    static testMethod void  test_Process0QuantityOpportunityLineItems()
    {
        User u = [SELECT Id FROM User WHERE LastName = 'TestUserUser' LIMIT 1];
        PermissionSet bypass = [SELECT Id FROM PermissionSet WHERE Name = 'Exclude_from_Flows' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = bypass.Id);

        System.runAs(u){
            Account newAccount = new Account();
            newAccount.Name = 'Test acctName';
            //newAccount.BillingCountry = 'United States';
            newAccount.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('QB Customer').getRecordTypeId();
            newAccount.Account_Status__c = 'Approved';
            newAccount.Account_Hierarchy_Level__c = 'Global Parent';
            insert newAccount;

            Product2 product1 = new Product2();
            product1.ProductCode = 'product-2';
            product1.Name = 'Hardware Product 2';
            product1.Description = 'Hardware Product 2 Description';
            product1.Family = 'HardwareFamily';
            product1.QS_Generate_Asset__c = true;
            product1.IsActive = true;
            product1.SBQQ__SubscriptionPricing__c = 'Percent Of Total';
            product1.SBQQ__SubscriptionType__c = 'Renewable';
            product1.SBQQ__SubscriptionTerm__c = 12;
            product1.SBQQ__QuantityEditable__c = true;
            product1.SBQQ__IncludeInMaintenance__c = true;
            insert product1;

            Id renewalRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Renewal').getRecordTypeId();

            Opportunity renewalOpp = new Opportunity();
            renewalOpp.AccountId = newAccount.Id;
            renewalOpp.Type='Existing Business';
            renewalOpp.QS_Order_Type__c='Subscription Renewal';
            renewalOpp.StageName='Connect';
            renewalOpp.CloseDate = System.today();
            renewalOpp.Name = 'Test Renewal';
            renewalOpp.RecordTypeId = renewalRecordTypeId;
            insert renewalOpp;

            SBQQ__Quote__c newQuote = new SBQQ__Quote__c();

            newQuote.SBQQ__Type__c = 'Renewal';
            newQuote.SBQQ__ExpirationDate__c = System.today().addDays(200);
            newQuote.SBQQ__Account__c = newAccount.Id;
            newQuote.SBQQ__Opportunity2__c = renewalOpp.Id;
            //newQuote.ApprovalStatus__c = 'Approved';
            newQuote.SBQQ__Primary__c = true;
            insert newQuote;

            SBQQ__QuoteLine__c newQuoteLine = new  SBQQ__QuoteLine__c();
            newQuoteLine.SBQQ__Product__c = product1.Id;
            newQuoteLine.SBQQ__Quantity__c = 0;
            // newQuoteLine.QS_Account__c = newAccount.Id;
            newQuoteLine.SBQQ__Quote__c = newQuote.Id;
            insert newQuoteLine;

            QS_Customer_Asset__c ca = new QS_Customer_Asset__c();
            ca.QS_Account__c = newAccount.Id;
            ca.QS_Product__c = product1.Id;
            insert ca;

            QS_Customer_Asset_Detail__c cad = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-365),QS_End_Date__c = System.today().addDays(+5));
            cad.QS_Product__c = product1.Id;
            insert cad;
            renewalOpp.SBQQ__PrimaryQuote__c = newQuote.Id;
            renewalOpp.StageName = 'Closed Won';
            // update renewalOpp;

            CA2_OpportunityTriggerHandler thl = new CA2_OpportunityTriggerHandler();
            List<Opportunity> listOfOpp = new List<Opportunity>();
            listOfOpp.add(renewalOpp);
            thl.addDecommissionRecordsForZeroedOutProducts(listOfOpp);
            thl.processZeroedOutQuoteLines(listOfOpp);
            thl.getDecommissionRecordByQuoteLine(newQuoteLine, ca);
            thl.UpdateHistoricalCadsPendingRenewal(listOfOpp);
        }
    }
}// /END Test Class