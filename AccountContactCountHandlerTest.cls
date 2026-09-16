@IsTest
private class AccountContactCountHandlerTest {

    @IsTest
    static void testUpdateCounts_WithContactsAndWithoutContacts() {
        // Create test accounts
        Account acct1 = new Account(Name = 'Test Account 1');
        Account acct2 = new Account(Name = 'Test Account 2');
        Account acct3 = new Account(Name = 'Test Account 3');
        insert new List<Account>{ acct1, acct2, acct3 };

        // Create contacts related to accounts
        Contact c1 = new Contact(LastName = 'Contact 1', AccountId = acct1.Id, Email = 'test1@test.com');
        Contact c2 = new Contact(LastName = 'Contact 2', AccountId = acct1.Id, Email = 'test2@test.com');
        Contact c3 = new Contact(LastName = 'Contact 3', AccountId = acct2.Id, Email = 'test3@test.com');
        insert new List<Contact>{ c1, c2, c3 };

        Test.startTest();
        AccountContactCountHandler.updateCounts(new Set<Id>{ acct1.Id, acct2.Id, acct3.Id });
        Test.stopTest();

        // Query updated accounts
        Map<Id, Account> results = new Map<Id, Account>([
            SELECT Id, Count_of_Contacts__c
            FROM Account
            WHERE Id IN :new Set<Id>{ acct1.Id, acct2.Id, acct3.Id }
        ]);

        System.assertEquals(2, results.get(acct1.Id).Count_of_Contacts__c,
            'Account 1 should have 2 related contacts');
        System.assertEquals(1, results.get(acct2.Id).Count_of_Contacts__c,
            'Account 2 should have 1 related contact');
        System.assertEquals(0, results.get(acct3.Id).Count_of_Contacts__c,
            'Account 3 should have 0 related contacts');
    }

    @IsTest
    static void testUpdateCounts_EmptySet() {
        Test.startTest();
        AccountContactCountHandler.updateCounts(new Set<Id>());
        Test.stopTest();

        System.assert(true, 'Method should safely handle an empty set');
    }

    @IsTest
    static void testUpdateCounts_NullSet() {
        Test.startTest();
        AccountContactCountHandler.updateCounts(null);
        Test.stopTest();

        System.assert(true, 'Method should safely handle a null set');
    }
}