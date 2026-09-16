@isTest
private class UpdateAccountContactsBatchTest {

    @isTest
    static void testUpdateAccountContactsBatch() {

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User oldOwner = new User(
            Alias = 'AEChang1',
            Email = 'AEChang1@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User123',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'AEChang1@example.com'
        );
        insert oldOwner;

        User newOwner = new User(
            Alias = 'AEChang2',
            Email = 'AEChang2@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User456',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'AEChang2@example.com'
        );
        insert newOwner;

    
        Account acc = new Account(
            Name = 'AE Change Test Account',
            Territory_Name__c = '317 - Core New',
            Segment__c = 'Core New',
            Account_Hierarchy_Level__c = 'Global Parent',
            OwnerId = oldOwner.Id
        );
        insert acc;

     
        Contact con = new Contact(
            FirstName = 'AE Change Contact',
            LastName = 'Testing Batch Class',
            Email = 'AEChang3@example.com',
            AccountId = acc.Id,
            OwnerId = oldOwner.Id
        );
        insert con;

        Set<Id> accountIds = new Set<Id>{acc.Id};
        UpdateAccountContactsBatch batch = new UpdateAccountContactsBatch(accountIds, newOwner.Id, '317 - Core New');

       
        Test.startTest();
        Database.executeBatch(batch, 100);
        Test.stopTest();

       
        Contact updatedCon = [SELECT OwnerId, ValidationBypassDateTime__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals(newOwner.Id, updatedCon.OwnerId, 'Contact OwnerId should be updated');
        System.assertNotEquals(null, updatedCon.ValidationBypassDateTime__c, 'ValidationBypassDateTime__c should be set');
    }
}