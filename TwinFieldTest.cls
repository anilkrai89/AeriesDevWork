@isTest
public class TwinFieldTest {

    static testMethod void TwinFieldtest1()
    {
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
        
        Opportunity renewalOpp = new Opportunity();
        renewalOpp.AccountId = newAccount.Id;
        renewalOpp.Type='Existing Business';
        renewalOpp.QS_Order_Type__c='Subscription Renewal';    
        renewalOpp.StageName='Connect';
        renewalOpp.CloseDate = System.today();
        renewalOpp.Name = 'Test Renewal';
   
        
        insert renewalOpp;

        SBQQ__Quote__c newQuote = new SBQQ__Quote__c();
        
        newQuote.SBQQ__Type__c = 'Renewal';
        newQuote.SBQQ__ExpirationDate__c = System.today().addDays(200);
        newQuote.SBQQ__Account__c = newAccount.Id;
        newQuote.SBQQ__Opportunity2__c = renewalOpp.Id;
        newQuote.ApprovalStatus__c = 'Approved';
        newQuote.SBQQ__Primary__c = true;
        newQuote.SBQQ__SubscriptionTerm__c = 12;
        insert newQuote;

       
  
        TwinField tf = new TwinField();
        tf.initializeFieldTwinner(newQuote.Id, renewalOpp.Id);
        tf.transferValuesToTargetObject(newQuote, renewalOpp);
        

    }
}