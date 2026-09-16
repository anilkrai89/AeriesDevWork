@IsTest
private class ContactDeleteTriggerTest {

    @IsTest
    static void testAfterDeleteUpdatesAccountContactCount() {
        // Create test account
        Account acct = new Account(Name = 'Test Account');
        insert acct;

        // Create contacts
        Contact c1 = new Contact(LastName = 'Contact 1', AccountId = acct.Id, Email = 'test1@test.com');
        Contact c2 = new Contact(LastName = 'Contact 2', AccountId = acct.Id, Email = 'test2@test.com');
        insert new List<Contact>{ c1, c2 };

        // Initialize count before delete
        AccountContactCountHandler.updateCounts(new Set<Id>{ acct.Id });

        Account acctBeforeDelete = [
            SELECT Id, Count_of_Contacts__c
            FROM Account
            WHERE Id = :acct.Id
        ];
        System.assertEquals(2, acctBeforeDelete.Count_of_Contacts__c,
            'Account should initially show 2 contacts');

        Test.startTest();
        delete c1;
        Test.stopTest();

        Account acctAfterDelete = [
            SELECT Id, Count_of_Contacts__c
            FROM Account
            WHERE Id = :acct.Id
        ];
        System.assertEquals(1, acctAfterDelete.Count_of_Contacts__c,
            'Account count should be reduced to 1 after contact delete');
    }

    @IsTest
    static void testAfterUndeleteUpdatesAccountContactCount() {
        // Create test account
        Account acct = new Account(Name = 'Test Account');
        insert acct;

        // Create contact
        Contact c1 = new Contact(LastName = 'Contact 1', AccountId = acct.Id, Email = 'test3@test.com');
        insert c1;

        // Initialize count before delete
        AccountContactCountHandler.updateCounts(new Set<Id>{ acct.Id });

        Test.startTest();
        delete c1;
        undelete c1;
        Test.stopTest();

        Account acctAfterUndelete = [
            SELECT Id, Count_of_Contacts__c
            FROM Account
            WHERE Id = :acct.Id
        ];
        System.assertEquals(1, acctAfterUndelete.Count_of_Contacts__c,
            'Account count should return to 1 after contact undelete');
    }

    @IsTest
    static void testDeleteAndUndeleteWithNoAccountId() {
        // Create contact without account
        Contact c = new Contact(LastName = 'No Account Contact', Email = 'test4@test.com');
        insert c;

        Test.startTest();
        delete c;
        undelete c;
        Test.stopTest();

        System.assert(true,
            'Trigger should safely handle contacts with no AccountId');
    }
}