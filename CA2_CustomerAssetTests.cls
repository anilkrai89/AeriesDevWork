@IsTest
public class CA2_CustomerAssetTests {
    /* unit tests to write
    Each Test scenario should work with Assets on multiple accounts simulataneously 
    Each Scenario should test the following assets:
        Subscription, Asset, Asset + Subscription + Subscribed Asset (With Generate Asset = True)
        Subscription, Asset, Asset + Subscription + Subscribed Asset (With Generate Asset = False)

     * 1) Initial Status's for Auto Activate, Auto Deactive 
            1a) Auto Activate = true, Auto Activate = false
                1a.1) Start Date in Past
                1a.2) Start Date in Future
            1b) Auto Deactivate = true, Auto Deactivate = false
                1b.1) Start Date in Past
                1b.2) Start Date in Future


    TEST-0102 - decrease quantity of a product
        1) Full Quantity Reduction (Decommission)
            1a) Auto Activate = true + Auto Activate = false
                1a.1) Start Date in Past
                1a.2) Start Date in Future
            1b) Auto Deactivate = true + Auto Deactivate = false
                1b.1) Start Date in Past
                1b.2) Start Date in Future
        1) Partial Quantity Reduction (Reduction)
            1a) Auto Activate = true + Auto Activate = false
                1a.1) Start Date in Past
                1a.2) Start Date in Future
            1b) Auto Deactivate = true + Auto Deactivate = false
                1b.1) Start Date in Past
                1b.2) Start Date in Future

    TEST-0097 - Purchase Same Sku of Previously Decommissioned
        -Assert the Customer Asset Re-activates


    *
    */


    @TestSetup 
    private static void setupTestData() {
        /*
        Create (4) Accounts
            -Increase Quantity Test (2)
            -Net New Test (2)


        create 15 products
        Subscription GenerateAsset = false (1)
        Subscription GenerateAsset = true 
            AutoActivate, true & false (2)
            AutoDeactivate, true & false (2)

        Asset GenerateAsset = false (1)
        Asset GenerateAsset = true 
            AutoActivate, true & false (2)
            AutoDeactivate, true & false (2)
        
        POT GenerateAsset = false (1)
        POT GenerateAsset = true 
            AutoActivate, true & false (2)
            AutoDeactivate, true & false (2)
        */
    }

    /* Need Amendment Method */ 
    /* Need Product Generation Method */
    /* Contracting Method */

    public class ContractWrapper {
        public ContractWrapper(Contract c) {
            this.contract = c;
            this.accountId = c.AccountId;
        }
        
        private Id accountId {get; set;}
        
        public Contract contract{get; set;}
        
        public List<SBQQ__Subscription__c> subscriptions {get; set;}
        
        public List<Asset> accountAssets {get; set;}
        
        public List<QS_Customer_Asset__c> caList {get; set;}
        
        public List<QS_Customer_Asset__c> refreshCA() {
            caList = [SELECT Id, QS_Quantity__c, QS_New_Asset_Status__c, QS_Product__c, (SELECT Id, QS_New_Asset_Status__c, QS_Product__c FROM QS_Customer_Asset_Details__r) FROM QS_Customer_Asset__c WHERE QS_Account__c =: accountId];
            return caList;
        }
        
        public List<SBQQ__Subscription__c> refreshSub() {
            subscriptions = [SELECT Id, SBQQ__Product__c FROM SBQQ__Subscription__c WHERE SBQQ__Contract__c =: contract.Id];
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