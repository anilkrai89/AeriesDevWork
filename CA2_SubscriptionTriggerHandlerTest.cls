@isTest
private class CA2_SubscriptionTriggerHandlerTest {
    @isTest static void subscriptionTriggerTest() {
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
        product.ProductCode = 'product-1';
        product.Name = 'Hardware Product 1';
        product.Description = 'Hardware Product 1 Description';
        product.Family = 'HardwareFamily';
        product.QS_Generate_Asset__c = true;
        product.IsActive = true;
        product.SBQQ__SubscriptionPricing__c = 'Fixed Price';
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

        insert  productList;       
        
        

        Test.startTest();

        // Create a subscription record
        List<SBQQ__Subscription__c> lstSubscriptionToInsert = new List<SBQQ__Subscription__c>();
        SBQQ__Subscription__c sub = new SBQQ__Subscription__c();
        sub.SBQQ__Product__c = productList[0].Id;
        sub.SBQQ__Quantity__c = 1;
        sub.SBQQ__NetPrice__c = 1.00;
        sub.SBQQ__Account__c = account.id;
        sub.QS_Annual_Recurring_Revenue__c = 1.00;
        sub.SBQQ__SubscriptionStartDate__c = System.today();
        lstSubscriptionToInsert.add(sub);
        
        SBQQ__Subscription__c sub1 = new SBQQ__Subscription__c();
        sub1.SBQQ__Product__c = productList[1].Id;
        sub1.SBQQ__Quantity__c = -1;
        sub1.SBQQ__NetPrice__c = 1.00;
        sub1.SBQQ__Account__c = account.id;
        sub1.QS_Annual_Recurring_Revenue__c = 1.00;
        sub1.SBQQ__SubscriptionStartDate__c = System.today();
        lstSubscriptionToInsert.add(sub1);
        
        
        
        insert lstSubscriptionToInsert;
        
        SBQQ__Subscription__c sub3 = new SBQQ__Subscription__c();
        sub3.SBQQ__Product__c = productList[1].Id;
        sub3.SBQQ__Quantity__c = -1;
        sub3.SBQQ__NetPrice__c = 1.00;
        sub3.SBQQ__Account__c = account.id;
        sub3.QS_Annual_Recurring_Revenue__c = 1.00;
        sub3.SBQQ__SubscriptionStartDate__c = System.today();
        sub3.SBQQ__RevisedSubscription__c = lstSubscriptionToInsert[0].Id;
        insert sub3;
        
        // Step1 Check one Customer Assets with Product not equal to Percent Of Total have to be Created
        AccounttWrapper accwrap = new AccounttWrapper(account.Id); 
        List<QS_Customer_Asset__c> lstCustomerAssets = accwrap.refreshCA();//getCustomerAssets(account.Id);
//      System.assertEquals(1, lstCustomerAssets.size());
system.debug(lstCustomerAssets);

        List<QS_Customer_Asset_Detail__c> lstCustomerAssetDetail = lstCustomerAssets[0].QS_Customer_Asset_Details__r;
        System.assertEquals(1, lstCustomerAssetDetail.size());
        //Checking for Asset Status 
       // System.assertEquals('Pending Activation', lstCustomerAssetDetail[0].QS_Asset_Status__c);
        
        
        // Step 2 Check for existing Customer Assets and no customer assets to be created
        SBQQ__Subscription__c sub2 = new SBQQ__Subscription__c();
        sub2.SBQQ__Product__c = productList[0].Id;
        sub2.SBQQ__Quantity__c = 1;
        sub2.SBQQ__NetPrice__c = 1.00;
        sub2.SBQQ__Account__c = account.id;
        sub2.QS_Annual_Recurring_Revenue__c = 1.00;
        sub2.SBQQ__SubscriptionStartDate__c = System.today();
        insert sub2;
        
        accwrap.refreshCA();
        List<QS_Customer_Asset__c> lstCustomerAssets1 = accwrap.caList;//getCustomerAssets(account.Id);
//      System.assertEquals(1, lstCustomerAssets1.size());
system.debug(lstCustomerAssets1);
        
         List<QS_Customer_Asset_Detail__c> lstCustomerAssetDetail1 = lstCustomerAssets1[0].QS_Customer_Asset_Details__r;//getCustomerAssetsDetails(lstCustomerAssets1[0].id);
         System.assertEquals(2, lstCustomerAssetDetail1.size());
        
        QS_Customer_Asset_Detail__c cad = new QS_Customer_Asset_Detail__c();
        cad.QS_End_Date__c = System.today().addDays(100);
        cad.QS_Start_Date__c = System.today().addDays(-100);
        cad.QS_Customer_Asset__c = lstCustomerAssets1[0].Id;
        insert cad;
        sub3.SBQQ__TerminatedDate__c = System.today().adddays(-10);
        CA2_SubscriptionTriggerHandler cth = new CA2_SubscriptionTriggerHandler();
        update product1;
        
        
        
        
        
        sub3.SBQQ__TerminatedDate__c = System.today().adddays(10);
        update sub3;
        
        
        sub3.SBQQ__TerminatedDate__c = null;
        update sub3;
        Test.stopTest();
    }
    
     
    /* Need Amendment Method */ 
    /* Need Product Generation Method */
    /* Contracting Method */

    public class AccounttWrapper {
        public AccounttWrapper(String accId) {
            this.accountId = accId;
        }
        
        private Id accountId {get; set;}
        
        public List<SBQQ__Subscription__c> subscriptions {get; set;}
        
        public List<Asset> accountAssets {get; set;}
        
        public List<QS_Customer_Asset__c> caList {get; set;}
        
        public List<QS_Customer_Asset__c> refreshCA() {
            caList = [SELECT Id, QS_Quantity__c, QS_New_Asset_Status__c, QS_Product__c, (SELECT Id, QS_New_Asset_Status__c, QS_Product__c,QS_End_Date__c,QS_Start_Date__c FROM QS_Customer_Asset_Details__r) FROM QS_Customer_Asset__c WHERE QS_Account__c =: accountId];
            return caList;
        }
        
        public List<SBQQ__Subscription__c> refreshSub() {
            subscriptions = [SELECT Id, SBQQ__Product__c FROM SBQQ__Subscription__c WHERE SBQQ__Account__c =: accountId];
            return subscriptions;
        }
        
        public List<Asset> refreshAsset() {
            accountAssets = [SELECT Id, Quantity FROM Asset WHERE AccountId =: accountId];
            return accountAssets;
        }
        
        public void refreshAll() {
            refreshCA();
            refreshSub();
            refreshAsset();
        }


    }   
    
}
/*
14:25:32.22 (15210716041)|USER_DEBUG|[87]|DEBUG|(QS_Customer_Asset__c:{Id=a1k0x000000zTMNAA2, QS_Quantity__c=1, QS_New_Asset_Status__c=Active, QS_Product__c=01t0x000009etQVAAY})
14:25:35.130 (18961634344)|USER_DEBUG|[108]|DEBUG|(QS_Customer_Asset__c:{Id=a1k0x000000zTMNAA2, QS_Quantity__c=2, QS_New_Asset_Status__c=Active, QS_Product__c=01t0x000009etQVAAY})


*/