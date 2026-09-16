@isTest(seeAllData=false)
public class CA2_CustAssetDetailStatusbatchableTest {

    @TestSetup
    static void makeData() {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User();
        u.Alias = 'tuser';
        u.Email = 'test@quickbase.com.test';
        u.EmailEncodingKey = 'UTF-8';
        u.FirstName = 'Test';
        u.LastName = 'custAssetUser';
        u.LanguageLocaleKey = 'en_US';
        u.LocaleSidKey = 'en_US';
        u.ProfileId = profile.Id;
        u.TimeZoneSidKey = 'America/Los_Angeles';
        u.Username = 'test@quickbase.com.test';
        insert u;
    }

    @isTest static void CA2_CustomerAssetDetailStatusbatchableTest() {

        User u = [SELECT Id FROM User WHERE LastName = 'custAssetUser' LIMIT 1];
        PermissionSet bypass = [SELECT Id FROM PermissionSet WHERE Name = 'Exclude_from_Flows' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = bypass.Id);


        System.runAs(u){
            Account account = new Account();
            account.Name = 'Test acctName';
            //account.BillingCountry = 'United States';
            account.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('QB Customer').getRecordTypeId();
            account.Account_Status__c = 'Approved';
            account.Account_Hierarchy_Level__c = 'Global Parent';
            insert account;

            // Create a product record
            List<Product2> productList = new List<Product2>();
            Product2 product = new Product2();
            product.ProductCode = 'product-2';
            product.Name = 'Hardware Product 2';
            product.Description = 'Hardware Product 2 Description';
            product.Family = 'HardwareFamily';
            product.QS_Generate_Asset__c = true;
            product.IsActive = true;
            product.SBQQ__SubscriptionPricing__c = 'Percent Of Total';
            product.SBQQ__SubscriptionType__c = 'Renewable';
            product.SBQQ__SubscriptionTerm__c = 12;
            product.SBQQ__QuantityEditable__c = true;
            product.SBQQ__IncludeInMaintenance__c = true;
            productList.add(product);


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
            productList.add(product1);


            Product2 product2 = new Product2();
            product2.ProductCode = 'product-3';
            product2.Name = 'Hardware Product 3';
            product2.Description = 'Hardware Product 3 Description';
            product2.Family = 'HardwareFamily';
            product2.QS_Generate_Asset__c = true;
            product2.IsActive = true;
            product2.SBQQ__SubscriptionPricing__c = 'Percent Of Total';
            product2.SBQQ__SubscriptionType__c = 'Renewable';
            product2.SBQQ__SubscriptionTerm__c = 12;
            product2.SBQQ__QuantityEditable__c = true;
            product2.SBQQ__IncludeInMaintenance__c = true;
            productList.add(product2);

            insert  productList;
            //===========================================
            Opportunity newOPp = new Opportunity();
            newOPp.Name = 'Test Opp';
            newOPp.AccountId = account.Id;
            newOpp.StageName = 'Closed Won';
            newOpp.CloseDate = Date.today();
            newOpp.QS_Sales_Forecast_Category__c = 'Commit';
            newOpp.QS_Order_Type__c = 'Commit';
            newOpp.Type ='New';
            newOpp.QS_Order_Type__c = 'New Customer';
            newOpp.QS_Finance_Checklist_Complete__c = true;
            newOpp.QS_Legal_Review__c = 'Approved';
            newOpp.QS_Finance_Status__c = 'Approved';
            insert newOpp;


            Opportunity closeLostRenewalOpp = new Opportunity();
            closeLostRenewalOpp.Name = 'Test Opp';
            closeLostRenewalOpp.AccountId = account.Id;
            closeLostRenewalOpp.StageName = 'Closed Lost';
            closeLostRenewalOpp.CloseDate = Date.today();
            closeLostRenewalOpp.QS_Sales_Forecast_Category__c = 'Commit';
            closeLostRenewalOpp.QS_Order_Type__c = 'Commit';
            closeLostRenewalOpp.Type ='Existing Customer';
            closeLostRenewalOpp.QS_Order_Type__c = 'Subscription Renewal';
            insert closeLostRenewalOpp;

            Contract cont = new Contract();
            cont.AccountId = account.Id;
            cont.SBQQ__Opportunity__c = newOPp.Id;
            cont.SBQQ__RenewalOpportunity__c = closeLostRenewalOpp.Id;
            cont.StartDate = Date.today().addDays(-380);
            cont.ContractTerm = 12;
            insert cont;


            //====================================================
            QS_Customer_Asset__c ca = new QS_Customer_Asset__c(QS_Account__c = account.Id);
            insert ca;

            // Insert a Customer Asset Detail with an OLD Start Date and FUTURE End Date
            List<QS_Customer_Asset_Detail__c> lstCadToInsert = new List<QS_Customer_Asset_Detail__c>();
            QS_Customer_Asset_Detail__c cad = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-365),QS_End_Date__c = System.today().addDays(-10));
            lstCadToInsert.add(cad);

            QS_Customer_Asset_Detail__c cad1 = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Product__c = productList[0].id, QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-365),QS_End_Date__c = System.today().addDays(+10));
            lstCadToInsert.add(cad1);

            QS_Customer_Asset_Detail__c cad2 = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Product__c = productList[1].id, QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-30),QS_End_Date__c = System.today().addDays(+15));
            lstCadToInsert.add(cad2);

            QS_Customer_Asset_Detail__c cad3 = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Product__c = productList[2].id, QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-30),QS_End_Date__c = System.today().addDays(+15));
            lstCadToInsert.add(cad3);

            QS_Customer_Asset_Detail__c cad4 = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Product__c = productList[2].id, QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-30),QS_End_Date__c = System.today().addDays(+15));
            lstCadToInsert.add(cad4);

            QS_Customer_Asset_Detail__c cadWithRenewal = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Product__c = productList[2].id, QS_Currently_Active__c=False,QS_Start_Date__c = System.today(),QS_End_Date__c = System.today().addDays(-16));
            cadWithRenewal.QS_Contract__c = cont.Id;
            lstCadToInsert.add(cadWithRenewal);
            QS_Customer_Asset_Detail__c cadReducedCurrent = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Product__c = productList[2].id, QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-30),QS_End_Date__c = System.today().addDays(+15));
            lstCadToInsert.add(cadReducedCurrent);

            QS_Customer_Asset_Detail__c cadReducedExpired = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Product__c = productList[2].id, QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-90),QS_End_Date__c = System.today().addDays(-35));
            lstCadToInsert.add(cadReducedExpired);

            QS_Customer_Asset_Detail__c cadPendingRenewal = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Product__c = productList[1].id, QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-30),QS_End_Date__c = System.today().addDays(+15));
            cadPendingRenewal.QS_Contract__c = cont.Id;
            lstCadToInsert.add(cadPendingRenewal);
            insert lstCadToInsert;

            QS_Console__mdt cASettings = [select Id,QS_Enable_Manual_Batch_Run__c from QS_Console__mdt where MasterLabel=: System.Label.QS_Console_Master_Label];
            DateTime future = system.now().addMinutes(1);
            Integer year = future.year();
            Integer month = future.month();
            Integer day = future.day();
            Integer hour = future.hour();
            Integer minute = future.minute();
            Integer second = future.second();
            String cron_exp = second + ' ' + minute + ' ' + hour + ' ' + day + ' ' + month + ' ?' + ' ' + year;

            Test.startTest();

            // Create an instance of CA2_CustomerAssetDetailStatusbatchable
            CA2_CustomerAssetDetailStatusSchedule scheduler = new CA2_CustomerAssetDetailStatusSchedule();

            // Schedule the job using System's scheduler
            String jobId = System.schedule('testBasicScheduledApex', cron_exp, scheduler);

            // Get the information from the CronTrigger API object
            CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered,
                    NextFireTime
            FROM CronTrigger WHERE id = :jobId];

            // Verify the expressions are the same
            System.assertEquals(cron_exp, ct.CronExpression);

            // Verify the job has not run
            System.assertEquals(0, ct.TimesTriggered);

            CA2_CustomerAssetDetailStatusBatchable batch = new CA2_CustomerAssetDetailStatusBatchable();
            batch.executeBatchJob(lstCadToInsert, System.today());
            Test.stopTest();
        }
    }  
    
    @isTest static void CA2_CustomerAssetDetailStatusbatchableTestManual() {

        User u = [SELECT Id FROM User WHERE LastName = 'custAssetUser' LIMIT 1];
        PermissionSet bypass = [SELECT Id FROM PermissionSet WHERE Name = 'Exclude_from_Flows' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = bypass.Id);

        System.runAs(u){
            Account account = new Account();
            account.Name = 'Test acctName';
            //account.BillingCountry = 'United States';
            account.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('QB Customer').getRecordTypeId();
            account.Account_Status__c = 'Approved';
            account.Account_Hierarchy_Level__c = 'Global Parent';
            insert account;

            // Create a product record
            List<Product2> productList = new List<Product2>();
            Product2 product = new Product2();
            product.ProductCode = 'product-2';
            product.Name = 'Hardware Product 2';
            product.Description = 'Hardware Product 2 Description';
            product.Family = 'HardwareFamily';
            product.QS_Generate_Asset__c = true;
            product.IsActive = true;
            product.SBQQ__SubscriptionPricing__c = 'Percent Of Total';
            product.SBQQ__SubscriptionType__c = 'Renewable';
            product.SBQQ__SubscriptionTerm__c = 12;
            product.SBQQ__QuantityEditable__c = true;
            product.SBQQ__IncludeInMaintenance__c = true;
            productList.add(product);


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
            productList.add(product1);


            Product2 product2 = new Product2();
            product2.ProductCode = 'product-3';
            product2.Name = 'Hardware Product 3';
            product2.Description = 'Hardware Product 3 Description';
            product2.Family = 'HardwareFamily';
            product2.QS_Generate_Asset__c = true;
            product2.IsActive = true;
            product2.SBQQ__SubscriptionPricing__c = 'Percent Of Total';
            product2.SBQQ__SubscriptionType__c = 'Renewable';
            product2.SBQQ__SubscriptionTerm__c = 12;
            product2.SBQQ__QuantityEditable__c = true;
            product2.SBQQ__IncludeInMaintenance__c = true;

            productList.add(product2);

            insert  productList;
            //===========================================
            Opportunity newOPp = new Opportunity();
            newOPp.Name = 'Test Opp';
            newOPp.AccountId = account.Id;
            newOpp.StageName = 'Closed Won';
            newOpp.CloseDate = Date.today();
            newOpp.QS_Sales_Forecast_Category__c = 'Commit';
            newOpp.QS_Order_Type__c = 'Commit';
            newOpp.Type ='New';
            newOpp.QS_Order_Type__c = 'New Customer';
            newOpp.QS_Finance_Checklist_Complete__c = true;
            newOpp.QS_Legal_Review__c = 'Approved' ;
            newOpp.QS_Finance_Status__c = 'Approved' ;
            insert newOPp;


            Opportunity closeLostRenewalOpp = new Opportunity();
            closeLostRenewalOpp.Name = 'Test Opp';
            closeLostRenewalOpp.AccountId = account.Id;
            closeLostRenewalOpp.StageName = 'Closed Lost';
            closeLostRenewalOpp.CloseDate = Date.today();
            closeLostRenewalOpp.QS_Sales_Forecast_Category__c = 'Commit';
            closeLostRenewalOpp.QS_Order_Type__c = 'Commit';
            closeLostRenewalOpp.Type ='Existing Customer';
            closeLostRenewalOpp.QS_Order_Type__c = 'Subscription Renewal';
            insert closeLostRenewalOpp;

            Contract cont = new Contract();
            cont.AccountId = account.Id;
            cont.SBQQ__Opportunity__c = newOPp.Id;
            cont.SBQQ__RenewalOpportunity__c = closeLostRenewalOpp.Id;
            cont.StartDate = Date.today().addDays(-380);
            cont.ContractTerm = 12;
            insert cont;


            //====================================================
            QS_Customer_Asset__c ca = new QS_Customer_Asset__c(QS_Account__c = account.Id);
            insert ca;

            // Insert a Customer Asset Detail with an OLD Start Date and FUTURE End Date
            List<QS_Customer_Asset_Detail__c> lstCadToInsert = new List<QS_Customer_Asset_Detail__c>();
            QS_Customer_Asset_Detail__c cad = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-365),QS_End_Date__c = System.today().addDays(-10));
            cad.QS_Process_By_Manual_Run__c = true;
            lstCadToInsert.add(cad);

            QS_Customer_Asset_Detail__c cad1 = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Product__c = productList[0].id, QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-365),QS_End_Date__c = System.today().addDays(+10));
            cad1.QS_Process_By_Manual_Run__c = true;
            lstCadToInsert.add(cad1);

            QS_Customer_Asset_Detail__c cad2 = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Product__c = productList[1].id, QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-30),QS_End_Date__c = System.today().addDays(+15));
            cad2.QS_Process_By_Manual_Run__c = true;
            lstCadToInsert.add(cad2);


            QS_Customer_Asset_Detail__c cad3 = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Product__c = productList[2].id, QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-30),QS_End_Date__c = System.today().addDays(+15));
            cad3.QS_Process_By_Manual_Run__c = true;
            lstCadToInsert.add(cad3);

            QS_Customer_Asset_Detail__c cad4 = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Product__c = productList[2].id, QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-30),QS_End_Date__c = System.today().addDays(+15));
            cad4.QS_Process_By_Manual_Run__c = true;
            lstCadToInsert.add(cad4);

            QS_Customer_Asset_Detail__c cadWithRenewal = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Product__c = productList[2].id, QS_Currently_Active__c=False,QS_Start_Date__c = System.today(),QS_End_Date__c = System.today().addDays(-16));
            cadWithRenewal.QS_Contract__c = cont.Id;
            cadWithRenewal.QS_Process_By_Manual_Run__c = true;
            lstCadToInsert.add(cadWithRenewal);


            QS_Customer_Asset_Detail__c cadReducedCurrent = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Product__c = productList[2].id, QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-30),QS_End_Date__c = System.today().addDays(+15));
            cadReducedCurrent.QS_Process_By_Manual_Run__c = true;
            lstCadToInsert.add(cadReducedCurrent);

            QS_Customer_Asset_Detail__c cadReducedExpired = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Product__c = productList[2].id, QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-90),QS_End_Date__c = System.today().addDays(-35));
            cadReducedExpired.QS_Process_By_Manual_Run__c = true;
            lstCadToInsert.add(cadReducedExpired);

            QS_Customer_Asset_Detail__c cadPendingRenewal = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Product__c = productList[1].id, QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-30),QS_End_Date__c = null);
            cadPendingRenewal.QS_Contract__c = cont.Id;
            cadPendingRenewal.QS_Process_By_Manual_Run__c = true;
            lstCadToInsert.add(cadPendingRenewal);
            insert lstCadToInsert;

            CA2_CustomerAssetDetailBatchable_Manual mn = new CA2_CustomerAssetDetailBatchable_Manual();
            mn.start(null);
            mn.execute(null, lstCadToInsert);
            mn.finish(null);
        }

    }  
    
    
}