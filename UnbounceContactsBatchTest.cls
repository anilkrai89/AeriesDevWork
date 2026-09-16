@IsTest
private class UnbounceContactsBatchTest {

    @testSetup
    static void setupTestData() {
        // Step 1: Create a Profile for the User
        Profile userProfile = [SELECT Id FROM Profile WHERE Name = 'QB Community Login User' LIMIT 1];

        // Step 2: Create a Parent Account
        Account testParentAccount = new Account(
            Name = 'Test Parent Account',
            Account_Hierarchy_Level__c = 'Global Parent'
        );        
        insert testParentAccount;

        // Step 3: Create a Child Account linked to the Parent Account
        Account acc = new Account(
            Name = 'Test Account', 
            ParentId = testParentAccount.Id
        );
        insert acc;
        
        // Step 4: Create a Product_Account__c record linked to the Account
        Product_Account__c productAccount = new Product_Account__c(
            Realm_ID__c = '12345678',
            Account__c = acc.Id
        );
        insert productAccount;
        
        // Step 5: Create Contacts linked to the Account
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 5; i++) {
            contacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact' + i,
                Email = 'test' + i + '@example.com',
                EmailBouncedReason = 'Bounced due to invalid email',
                AccountId = acc.Id,
                QB_Instance__c = 'QB123'
            ));
        }
        insert contacts;

        // Step 6: Create Users linked to Contacts
        List<User> users = new List<User>();
        for (Integer i = 0; i < contacts.size(); i++) {
            users.add(new User(
                FirstName = 'Test',
                LastName = 'User' + i,
                Email = 'user' + i + '@example.com',
                Username = 'user' + i + '@example.com.qb',
                Alias = 'test' + i,
                ProfileId = userProfile.Id,
                ContactId = contacts[i].Id,
                FederationIdentifier = 'user' + i + '@example.com',
                TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US',
                LanguageLocaleKey = 'en_US',
                EmailEncodingKey = 'UTF-8'
            ));
        }
        insert users;
    }

    @IsTest
    static void testBatchExecution() {
        // Standard processing of contacts
        UnbounceContactsBatch batch = new UnbounceContactsBatch();
        Test.startTest();
        Database.executeBatch(batch, 50);
        Test.stopTest();

        // Verify that the EmailBouncedReason field has been cleared for all contacts
        List<Contact> updatedContacts = [SELECT Id, EmailBouncedReason FROM Contact];
        for (Contact contact : updatedContacts) {
            System.assertEquals(null, contact.EmailBouncedReason, 'EmailBouncedReason should be null after batch execution');
        }
    }

    @IsTest
    static void testEmptyBatchProcessing() {
        // Clear EmailBouncedReason for all contacts to simulate no records to process
        List<Contact> contactsToClear = [SELECT Id FROM Contact];
        for (Contact contact : contactsToClear) {
            contact.EmailBouncedReason = null;
        }
        update contactsToClear;

        // Run the batch
        Test.startTest();
        UnbounceContactsBatch batch = new UnbounceContactsBatch();
        Database.executeBatch(batch, 50);
        Test.stopTest();

        // Verify there are no contacts with non-null EmailBouncedReason
        List<Contact> noContacts = [SELECT Id FROM Contact WHERE EmailBouncedReason != null];
        System.assertEquals(0, noContacts.size(), 'There should be no contacts to process');
    }
}