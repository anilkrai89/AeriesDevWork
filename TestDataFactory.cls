@IsTest
public without sharing class TestDataFactory {

    public static List<Account> createAndInsertAccounts(Integer numberOfRecords) {
        List<Account> accounts = new List<Account>();
        for(Integer i=0; i<numberOfRecords; i++) {
            Account a = new Account();
            a.Name = 'Test Account ' + i;
            a.Account_Hierarchy_Level__c = 'Global Parent';     // validation rule
            a.BillingCountry = 'United States';
            accounts.add(a);
        }
        insert accounts;
        return accounts;
    }

    public static List<Order> createOrders(Integer numberOfOrders) {
        List<Order> orders = new List<Order>();
        List<Account> parentAccounts = createAndInsertAccounts(1);
        for(Account acct : parentAccounts) {
            for(Integer i=0; i<numberOfOrders; i++) {
                Order o = new Order();
                o.AccountId = acct.Id;
                o.EffectiveDate = Date.today();
                o.Pricebook2Id = Test.getStandardPricebookId();
                o.Status = 'Draft';
                orders.add(o);
            }
        }

        return orders;
    }

    public static List<OrderItem> createOrderProducts(List<Order> parentOrders, Integer numberOfOrderItemsPerOrder) {
        List<OrderItem> orderItems = new List<OrderItem>();
        List<PricebookEntry> pricebookEntries = createAndInsertPricebookEntries(numberOfOrderItemsPerOrder);
        for(Order o : parentOrders) {
            for(PricebookEntry pbe : pricebookEntries) {
                OrderItem oItem = new OrderItem();
                oItem.PricebookEntryId = pbe.Id;
                oItem.OrderId = o.Id;
                oItem.Provisioning_Status__c = OrderProductProvisioningBatch.inputProvisioningStatus[0];
                oItem.Quantity = 1;
                oItem.UnitPrice = 10;
                orderItems.add(oItem);
            }
        }

        return orderItems;
    }

    private static List<PricebookEntry> createAndInsertPricebookEntries(Integer numberOfRecords) {
        List<PricebookEntry> pricebookEntries = new List<PricebookEntry>();
        for(Product2 prod : createAndInsertProducts(numberOfRecords)) {
            PricebookEntry pbe = new PricebookEntry();
            pbe.Product2Id = prod.Id;
            pbe.IsActive = true;
            pbe.Pricebook2Id = Test.getStandardPricebookId();
            pbe.UnitPrice = 10;
            pricebookEntries.add(pbe);
        }
        insert pricebookEntries;
        return pricebookEntries;
    }

    private static List<Product2> createAndInsertProducts(Integer numberOfRecords) {
        List<Product2> products = new List<Product2>();
        for(Integer i=0; i<numberOfRecords; i++) {
            Product2 prod = new Product2();
            prod.Name = 'Test Product ' + i;
            prod.IsActive = true;
            products.add(prod);
        }
        insert products;
        return products;
    }
}