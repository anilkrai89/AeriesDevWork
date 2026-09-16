@isTest
private class UpdateOpportunitiesBatchTest {

    @isTest
    static void testUpdateOpportunitiesBatch() {
        
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

        
        Opportunity opp = new Opportunity(
            Name = 'AE Change ST Test Opportunity',
            StageName = '01 - Discovery & Demonstration',
            CloseDate = Date.today().addDays(30),
            OwnerId = oldOwner.Id,
            Opportunity_Territory__c = '900 - QB CRO',
            Opportunity_Segment__c = 'Quickbase Unassigned',
            Opp_Territory_Override__c = false,
            AccountId = '001UN0000046zmXYAQ',
            ValidationBypassDateTime__c = dateTime.now()
        );
        insert opp;

        
        Test.startTest();
        UpdateOpportunitiesBatch batch = new UpdateOpportunitiesBatch(newOwner.Id, '900 - QB CRO');
        Database.executeBatch(batch, 100);
        Test.stopTest();

      
        Opportunity updatedOpp = [SELECT OwnerId, ValidationBypassDateTime__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(newOwner.Id, updatedOpp.OwnerId, 'Opportunity Owner should be updated');
        System.assertNotEquals(null, updatedOpp.ValidationBypassDateTime__c, 'ValidationBypassDateTime__c should be set');
    }
}