@IsTest
private class AccountContactRelationTriggerTest {

    @TestSetup
    static void setupData() {
        Account primaryAccount = new Account(Name = 'Primary Account');
        Account relatedAccount = new Account(Name = 'Related Account');
        insert new List<Account>{ primaryAccount, relatedAccount };

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'test.contact@example.com',
            AccountId = primaryAccount.Id
        );
        insert con;
    }

    @IsTest
    static void testAfterInsertAndDeleteAccountContactRelation() {
        Account relatedAccount = [
            SELECT Id
            FROM Account
            WHERE Name = 'Related Account'
            LIMIT 1
        ];

        Contact con = [
            SELECT Id
            FROM Contact
            WHERE Email = 'test.contact@example.com'
            LIMIT 1
        ];

        AccountContactRelation acr = new AccountContactRelation(
            AccountId = relatedAccount.Id,
            ContactId = con.Id,
            IsActive = true
        );

        Test.startTest();
        insert acr;
        delete acr;
        Test.stopTest();

        Account acctAfterDelete = [
            SELECT Id, Count_of_Contacts__c
            FROM Account
            WHERE Id = :relatedAccount.Id
        ];

        System.assertEquals(
            0,
            acctAfterDelete.Count_of_Contacts__c,
            'Related account should have 0 contacts after ACR delete'
        );
    }

    @IsTest
    static void testAfterInsertAccountContactRelation() {
        Account relatedAccount = [
            SELECT Id
            FROM Account
            WHERE Name = 'Related Account'
            LIMIT 1
        ];

        Contact con = [
            SELECT Id
            FROM Contact
            WHERE Email = 'test.contact@example.com'
            LIMIT 1
        ];

        AccountContactRelation acr = new AccountContactRelation(
            AccountId = relatedAccount.Id,
            ContactId = con.Id,
            IsActive = true
        );

        Test.startTest();
        insert acr;
        Test.stopTest();

        Account acctAfterInsert = [
            SELECT Id, Count_of_Contacts__c
            FROM Account
            WHERE Id = :relatedAccount.Id
        ];

        System.assertEquals(
            1,
            acctAfterInsert.Count_of_Contacts__c,
            'Related account should have 1 contact after ACR insert'
        );
    }

    @IsTest
    static void testBulkInsertAndDeleteAccountContactRelation() {
        Contact con = [
            SELECT Id
            FROM Contact
            WHERE Email = 'test.contact@example.com'
            LIMIT 1
        ];

        Account acct2 = new Account(Name = 'Bulk Related Account 1');
        Account acct3 = new Account(Name = 'Bulk Related Account 2');
        insert new List<Account>{ acct2, acct3 };

        List<AccountContactRelation> acrs = new List<AccountContactRelation>{
            new AccountContactRelation(
                AccountId = acct2.Id,
                ContactId = con.Id,
                IsActive = true
            ),
            new AccountContactRelation(
                AccountId = acct3.Id,
                ContactId = con.Id,
                IsActive = true
            )
        };

        Test.startTest();
        insert acrs;
        delete acrs;
        Test.stopTest();

        Map<Id, Account> acctMap = new Map<Id, Account>([
            SELECT Id, Count_of_Contacts__c
            FROM Account
            WHERE Id IN :new Set<Id>{ acct2.Id, acct3.Id }
        ]);

        System.assertEquals(
            0,
            acctMap.get(acct2.Id).Count_of_Contacts__c,
            'Bulk Related Account 1 should have 0 contacts after delete'
        );
        System.assertEquals(
            0,
            acctMap.get(acct3.Id).Count_of_Contacts__c,
            'Bulk Related Account 2 should have 0 contacts after delete'
        );
    }
}