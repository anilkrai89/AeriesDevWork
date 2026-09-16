@isTest
private class CA2_AssetHandlerTest {
    @isTest static void CA2_AssetHandlerTestNegativeQuantity() {
        Account account = new Account();
        account.Name = 'Test acctName';
        //account.BillingCountry = 'United States';
        account.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('QB Customer').getRecordTypeId();
        account.Account_Status__c = 'Approved';
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
        
        Asset newAsset = new Asset();
        newAsset.AccountId = account.Id;
        newAsset.Name = productList[0].Name;
        newAsset.Product2Id = productList[0].id;
        newAsset.Price = 0;
        newAsset.Quantity = -10;
        
        insert newAsset;
        
        Test.startTest();
        
        // Create a subscription record
        List<SBQQ__Subscription__c> lstSubscriptionToInsert = new List<SBQQ__Subscription__c>();
        SBQQ__Subscription__c sub = new SBQQ__Subscription__c();
        sub.SBQQ__Product__c = productList[0].Id;
        sub.SBQQ__Quantity__c = 0;
        sub.SBQQ__NetPrice__c = 0.00;
        sub.SBQQ__Account__c = account.id;
        sub.QS_Annual_Recurring_Revenue__c = 1.00;
        sub.SBQQ__SubscriptionStartDate__c = System.today();
        lstSubscriptionToInsert.add(sub);
        
        insert lstSubscriptionToInsert;
        
        SBQQ__Subscription__c sub1 = new SBQQ__Subscription__c();
        sub1.SBQQ__Product__c = productList[0].Id;
        sub1.SBQQ__Quantity__c = 0;
        sub1.SBQQ__NetPrice__c = 1.00;
        sub1.SBQQ__Account__c = account.id;
        sub1.QS_Annual_Recurring_Revenue__c = 1.00;
        sub1.SBQQ__SubscriptionStartDate__c = System.today();
        sub1.SBQQ__RevisedSubscription__c = lstSubscriptionToInsert[0].Id;
        insert sub1;
        //sub1.QS_Annual_Recurring_Revenue__c = 2;
        //sub1.QS_Maintain_Line__c = true;
        
        SBQQ__SubscribedAsset__c sbSubAsset = new SBQQ__SubscribedAsset__c();
        sbSubAsset.SBQQ__Active__c = true;
        sbSubAsset.SBQQ__Asset__c = newAsset.Id;
        sbSubAsset.SBQQ__Subscription__c = lstSubscriptionToInsert[0].Id;
        insert sbSubAsset;
        
        QS_Customer_Asset__c ca = new QS_Customer_Asset__c(QS_Account__c = account.Id);
        insert ca; 
        
        // Insert a Customer Asset Detail with an OLD Start Date and FUTURE End Date
        QS_Customer_Asset_Detail__c cad = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Annual_Recurring_Revenue__c = 2,QS_Quantity__c = 2,QS_Maintain_Line__c = true,QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-365));
        insert cad; 
        Map<String,Decimal> mapIdToQuantity = new Map<String,Decimal>();
        mapIdToQuantity.put('Test',12);
        CA2_CustomerAssetUtil.queryCAByUniqueId(new Set<String>{'test'});
        CA2_CustomerAssetUtil.Subscription_CAUniqueId(lstSubscriptionToInsert);
        CA2_CustomerAssetUtil.getMatchingKeys(new List<Asset>{newAsset});
        CA2_CustomerAssetUtil.getMatchingKeys(new List<SBQQ__SubscribedAsset__c>{sbSubAsset});
        CA2_CustomerAssetUtil.CustomerAssetDetailStatus(cad,ca,productList[0],mapIdToQuantity);
        CA2_CustomerAssetUtil.CustomerAssetDetailStatus(sub1,cad,ca,productList[0],mapIdToQuantity);
        
        
        CA2_CustomerAssetUtil.CustomerAssetDetailStatus(lstSubscriptionToInsert[0],cad,ca,productList[0],mapIdToQuantity);
        cad.QS_Quantity__c = 0;
        cad.QS_Maintain_Line__c = false;
        cad.QS_Start_Date__c = System.today().addDays(-10);
        CA2_CustomerAssetUtil.CustomerAssetDetailStatus(sub1,cad,ca,productList[0],mapIdToQuantity);
        cad.QS_Quantity__c = 0;
        sub1.SBQQ__RevisedSubscription__c = null;
        CA2_CustomerAssetUtil.CustomerAssetDetailStatus(sub1,cad,ca,productList[0],mapIdToQuantity);
        
        CA2_AssetTriggerHandler cath = new CA2_AssetTriggerHandler();
        // cath.getAssetDetailStatusFromNegativeQuantity(cad,newAsset);
        
        
        Test.stopTest();
    }
    
    @isTest static void CA2_AssetHandlerTestPositiveQuantity() {
        Account account = new Account();
        account.Name = 'Test acctName';
        //account.BillingCountry = 'United States';
        account.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('QB Customer').getRecordTypeId();
        account.Account_Status__c = 'Approved';
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
        
        Asset newAsset = new Asset();
        newAsset.AccountId = account.Id;
        newAsset.Name = productList[0].Name;
        newAsset.Product2Id = productList[0].id;
        newAsset.Price = 0;
        newAsset.Quantity = -10;
        
        insert newAsset;
        
        Test.startTest();
        
        // Create a subscription record
        List<SBQQ__Subscription__c> lstSubscriptionToInsert = new List<SBQQ__Subscription__c>();
        SBQQ__Subscription__c sub = new SBQQ__Subscription__c();
        sub.SBQQ__Product__c = productList[0].Id;
        sub.SBQQ__Quantity__c = 10;
        sub.SBQQ__NetPrice__c = 0.00;
        sub.SBQQ__Account__c = account.id;
        sub.QS_Annual_Recurring_Revenue__c = 1.00;
        sub.SBQQ__SubscriptionStartDate__c = System.today();
        lstSubscriptionToInsert.add(sub);
        
        insert lstSubscriptionToInsert;
        
        SBQQ__Subscription__c sub1 = new SBQQ__Subscription__c();
        sub1.SBQQ__Product__c = productList[0].Id;
        sub1.SBQQ__Quantity__c = 10;
        sub1.SBQQ__NetPrice__c = 1.00;
        sub1.SBQQ__Account__c = account.id;
        sub1.QS_Annual_Recurring_Revenue__c = 1.00;
        sub1.SBQQ__SubscriptionStartDate__c = System.today();
        sub1.SBQQ__RevisedSubscription__c = lstSubscriptionToInsert[0].Id;
        insert sub1;
        //sub1.QS_Annual_Recurring_Revenue__c = 2;
        //sub1.QS_Maintain_Line__c = true;
        
        SBQQ__SubscribedAsset__c sbSubAsset = new SBQQ__SubscribedAsset__c();
        sbSubAsset.SBQQ__Active__c = true;
        sbSubAsset.SBQQ__Asset__c = newAsset.Id;
        sbSubAsset.SBQQ__Subscription__c = lstSubscriptionToInsert[0].Id;
        sbSubAsset.QS_Created_By_Apex__c = true;
        insert sbSubAsset;
        
        QS_Customer_Asset__c ca = new QS_Customer_Asset__c(QS_Account__c = account.Id);
        insert ca; 
        
        // Insert a Customer Asset Detail with an OLD Start Date and FUTURE End Date
        QS_Customer_Asset_Detail__c cad = new QS_Customer_Asset_Detail__c(QS_Customer_Asset__c = ca.id,QS_Annual_Recurring_Revenue__c = 2,QS_Quantity__c = 2,QS_Maintain_Line__c = true,QS_Currently_Active__c=False,QS_Start_Date__c = System.today().addDays(-365));
        insert cad; 
        Map<String,Decimal> mapIdToQuantity = new Map<String,Decimal>();
        mapIdToQuantity.put('Test',12);
        CA2_CustomerAssetUtil.queryCAByUniqueId(new Set<String>{'test'});
        CA2_CustomerAssetUtil.Subscription_CAUniqueId(lstSubscriptionToInsert);
        CA2_CustomerAssetUtil.getMatchingKeys(new List<Asset>{newAsset});
        CA2_CustomerAssetUtil.getMatchingKeys(new List<SBQQ__SubscribedAsset__c>{sbSubAsset});
        CA2_CustomerAssetUtil.CustomerAssetDetailStatus(cad,ca,productList[0],mapIdToQuantity);
        CA2_CustomerAssetUtil.CustomerAssetDetailStatus(sub1,cad,ca,productList[0],mapIdToQuantity);
        
        
        CA2_CustomerAssetUtil.CustomerAssetDetailStatus(lstSubscriptionToInsert[0],cad,ca,productList[0],mapIdToQuantity);
        cad.QS_Quantity__c = 0;
        cad.QS_Maintain_Line__c = false;
        cad.QS_Start_Date__c = System.today().addDays(-10);
        CA2_CustomerAssetUtil.CustomerAssetDetailStatus(sub1,cad,ca,productList[0],mapIdToQuantity);
        cad.QS_Quantity__c = 0;
        sub1.SBQQ__RevisedSubscription__c = null;
        CA2_CustomerAssetUtil.CustomerAssetDetailStatus(sub1,cad,ca,productList[0],mapIdToQuantity);
        
        CA2_AssetTriggerHandler cath = new CA2_AssetTriggerHandler();
        // cath.getAssetDetailStatusFromNegativeQuantity(cad,newAsset);
        
        delete sbSubAsset;
        Test.stopTest();
    }
    
}