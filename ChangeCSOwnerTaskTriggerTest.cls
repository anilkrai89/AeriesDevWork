@IsTest
public class ChangeCSOwnerTaskTriggerTest {

    // Utility method to create a User with a specific profile name
    private static User createUser(String profileName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        User u = new User(
            UserName = profileName.toLowerCase().replace(' ', '') + '@test.com',
            LastName = profileName,
            Email = 'test@test.com',
            Alias = 'standin',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        return u;
    }

    // Utility method to create an Account with a specified owner
    private static Account createAccount(Id ownerId) {
        Account acc = new Account(Name = 'Test Account', Account_Hierarchy_Level__c = 'Global Parent', OwnerId = ownerId);
        insert acc;
        return acc;
    }

    // Utility method to create an Opportunity with a specified account and owner
    private static Opportunity createOpportunity(Id accId, Id ownerId) {
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            CloseDate = System.today() + 30,
            StageName = '01 - Discovery & Demonstration',
            AccountId = accId
        );
        insert opp;
        return opp;
    }

    // Utility method to create a Contact with a specified account
    private static Contact createContact(Id accountId) {
        Contact cont = new Contact(
            LastName = 'Test Contact',
            Email = 'test12345@test.com',
            AccountId = accountId
        );
        insert cont;
        return cont;
    }

    @IsTest
    static void testChangeOwnerOnTaskForAccount() {
        // Setup data
        User csUser = createUser('QB - Customer PS/Success');
        //User defaultUser = createUser('Default User');
        Account acc = createAccount(csUser.Id);
        Contact cont1 = createContact(acc.Id);
        Opportunity opp1 = createOpportunity(acc.Id, csUser.Id);
        List<Task> tasklist = new List<Task>();
        Task t = new Task(
            Subject = 'Test Task',
            WhatId = acc.Id
           // OwnerId = csUser.Id
        );
tasklist.add(t);
        
        Task t1 = new Task(
            Subject = 'Test Task1',
            WhoId = cont1.Id
           // OwnerId = csUser.Id
        );
tasklist.add(t1);

        Task t2 = new Task(
            Subject = 'Test Task 2',
            WhatId = opp1.Id
           // OwnerId = csUser.Id
        );
tasklist.add(t2);        
        // Test
        Test.startTest();
        insert tasklist;
        Test.stopTest();

        // Verify
        t = [SELECT OwnerId FROM Task WHERE Id = :t.Id];
       // System.assertEquals(csUser.Id, t.OwnerId, 'The owner should be changed to the account owner.');
    }

  
}