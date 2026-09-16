/********************************************************************************* 
ClassName : ContactUtilsTest
==================================================================================
Description :This Utils Class will look for Internal Contact based on CreatedByID and If not found will create and return the values to HelperClass.
==================================================================================
History
-------
VERSION	  AUTHOR	     DATE	       Jira Ticket No
1.0       Anil Kumar    04-Dec-2024     Teams -3554
 
*********************************************************************************/ 


/*@isTest
private class ContactUtilsTest {

    @isTest
    static void testGetOrCreateContact() {
        // Step 1: Create a Parent Account
        Account parentAccount = new Account(Name ='Holding Account [DO NOT EDIT]',
                                            Account_Hierarchy_Level__c = 'Global Parent'
                                            // Add any other necessary fields for the Parent Account
                                           );
        insert parentAccount;
        
        // Step 3: Create Users (one or more)
        User testUser1 = new User(
            Alias = 'tuser1', 
            Email = 'testuser1@example.com', 
            FirstName = 'John', 
            LastName = 'Doe', 
            ProfileId = UserInfo.getProfileId(), 
            Username = 'QBTestUser1@example.com', 
            TimeZoneSidKey = 'America/New_York', 
            LocaleSidKey = 'en_US', 
            EmailEncodingKey = 'UTF-8', 
            LanguageLocaleKey = 'en_US'
        );
        try{
        insert testUser1;
        }
        catch(exception e){
            system.debug(e.getmessage());
        }
        // Step 4: Create a Set of User IDs
        Set<Id> userIds = new Set<Id>{testUser1.Id};
            
            // Step 5: Call the method from the ContactUtils class
            Test.startTest();
        List<Contact> createdContacts = ContactUtils.getOrCreateContact(userIds);
        Test.stopTest();
        
        // Step 6: Assert that contacts were created
       // System.assertNotEquals(0, createdContacts.size(), 'Contacts should have been created.');
        
        // Step 7: Verify contact details
        for (Contact c : createdContacts) {
            System.assertNotEquals(null, c.FirstName, 'FirstName should not be null');
            System.assertNotEquals(null, c.LastName, 'LastName should not be null');
            System.assertNotEquals(null, c.Email, 'Email should not be null');
            System.assertEquals(parentAccount.Id, c.AccountId, 'Contact should be linked to the correct Account');
            System.assertEquals('Essential', c.Active_services__c, 'Active_services__c should be set to "Essential"');
        }
    }

    @isTest
    static void testNoUsersFound() {
        // Step 1: Create a Parent Account
        Account parentAccount = new Account(
            Name = 'Holding Account [DO NOT EDIT]',Account_Hierarchy_Level__c ='Global Parent'
            // Add any other necessary fields for the Parent Account
        );
        insert parentAccount;
 

        // Step 2: Create an empty Set of User IDs (no users to process)
        Set<Id> emptyUserIds = new Set<Id>();

        // Step 3: Call the method
        Test.startTest();
        List<Contact> createdContacts = ContactUtils.getOrCreateContact(emptyUserIds);
        Test.stopTest();

        // Step 4: Assert that no contacts were created
        System.assertEquals(0, createdContacts.size(), 'No contacts should be created when no user IDs are provided.');
    }

    @isTest
    static void testDmlExceptionHandling() {
  
        Account parentAccount = new Account(Name = 'Holding Account [DO NOT EDIT]',Account_Hierarchy_Level__c ='Global Parent'
                                           );
        insert parentAccount;

        // Create a User with a duplicate email (to trigger DML exception)
        User testUser1 = new User(
            Alias = 'tuser1', 
            Email = 'duplicateuser@example.com', 
            FirstName = 'John', 
            LastName = 'Doe', 
            ProfileId = UserInfo.getProfileId(), 
            Username = 'duplicateuser@example.com', 
            TimeZoneSidKey = 'America/New_York', 
            LocaleSidKey = 'en_US', 
            EmailEncodingKey = 'UTF-8', 
            LanguageLocaleKey = 'en_US'
        );
       
        // Attempt to insert and capture the exception
        try {
            insert testUser1;
            // This will cause a DML exception due to the duplicate email
        } catch (DmlException e) {
            System.debug('DML Exception: ' + e.getMessage());
        }

        // Step 1: Create a Set of User IDs
        Set<Id> userIds = new Set<Id>{testUser1.Id};

        // Step 2: Call the method to verify that it gracefully handles DML exceptions
        Test.startTest();
        List<Contact> createdContacts = ContactUtils.getOrCreateContact(userIds);
        Test.stopTest();

        // Step 3: Assert that some contacts were created (since the trigger handles the exception)
        System.assertNotEquals(0, createdContacts.size(), 'Contacts should have been created despite the exception.');
    }
}*/
@IsTest
private class ContactUtilsTest {

    /* ==========================================
       ============  TEST SETUP DATA  ============
       ========================================== */

    @testSetup
    static void setupData() {
        // Parent / Holding account used by ContactUtils
        Account parentAccount = new Account(
            Name                       = 'Holding Account [DO NOT EDIT]',
            Account_Hierarchy_Level__c = 'Global Parent'
        );
        insert parentAccount;
    }

    private static Account getHoldingAccount() {
        return [
            SELECT Id
            FROM Account
            WHERE Name = 'Holding Account [DO NOT EDIT]'
            LIMIT 1
        ];
    }

    // Use the current running user instead of inserting a new one
    private static User getInternalUser() {
        return [
            SELECT Id, FirstName, LastName, Email
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
    }

    /* ==========================================
       ======  testGetOrCreateContact()   =======
       ========================================== */

    @IsTest
    static void testGetOrCreateContact() {
        Account parentAccount = getHoldingAccount();
        User u = getInternalUser();

        // Make sure the user has an email; if not, set expectations accordingly
        System.assertNotEquals(null, u.Email, 'Running user must have an email for this test.');

        // Prepare user Ids set
        Set<Id> userIds = new Set<Id>{ u.Id };

        Test.startTest();
        List<Contact> createdContacts = ContactUtils.getOrCreateContact(userIds);
        Test.stopTest();

        System.assertNotEquals(0, createdContacts.size(),
            'Contacts should have been created for the provided user.');

        for (Contact c : createdContacts) {
            System.assertNotEquals(null, c.FirstName, 'FirstName should not be null');
            System.assertNotEquals(null, c.LastName,  'LastName should not be null');
            System.assertNotEquals(null, c.Email,     'Email should not be null');
            System.assertEquals(parentAccount.Id, c.AccountId,
                'Contact should be linked to the Holding Account.');
            // Adjust field name to match your org (case sensitive!)
            System.assertEquals('Essential', c.Active_Services__c,
                'Active_Services__c should be set to "Essential".');
        }
    }

    /* ==========================================
       ======  testNoUsersFound()         =======
       ========================================== */

    @IsTest
    static void testNoUsersFound() {
        // Empty set of user Ids
        Set<Id> emptyUserIds = new Set<Id>();

        Test.startTest();
        List<Contact> createdContacts = ContactUtils.getOrCreateContact(emptyUserIds);
        Test.stopTest();

        System.assertEquals(0, createdContacts.size(),
            'No contacts should be created when no user IDs are provided.');
    }

    /* ==========================================
       == testInvalidUserIdHandledGracefully() ==
       ========================================== */

    @IsTest
    static void testInvalidUserIdHandledGracefully() {
        // Create a set with an invalid / non-existent user Id to simulate bad data
        // (You can also include null if your method guards against it.)
        Set<Id> badUserIds = new Set<Id>{
            (Id) '005000000000000AAA'    // likely not a real user in a scratch/test org
        };

        Test.startTest();
        List<Contact> createdContacts = ContactUtils.getOrCreateContact(badUserIds);
        Test.stopTest();

        // The key behavior we want: the method shouldn't throw a DmlException or crash.
        // It should simply return an empty list or skip invalid users.
        System.assertEquals(0, createdContacts.size(),
            'Contacts list should be empty when user IDs do not resolve to real users (graceful handling).');
    }
}