@IsTest
private class UpdateAccountOwnersBatch_Test {

    @testSetup
    static void setupData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniq = String.valueOf(DateTime.now().getTime());

        User oldOwner = new User(
            Alias = 'AEChg1',
            Email = 'aechg1' + uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User123',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'aechg1' + uniq + '@example.com'
        );

        User newOwner = new User(
            Alias = 'AEChg2',
            Email = 'aechg2' + uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User456',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'aechg2' + uniq + '@example.com'
        );

        insert new List<User>{ oldOwner, newOwner };
    }

    @IsTest
    static void testUpdateAccountOwnersBatch() {
        // Query the users created in @testSetup
        List<User> users = [
            SELECT Id, Alias
            FROM User
            WHERE Alias IN ('AEChg1', 'AEChg2')
            ORDER BY Alias
        ];
        System.assertEquals(2, users.size(), 'Expected 2 test users');

        User oldOwner = users[0].Alias == 'AEChg1' ? users[0] : users[1];
        User newOwner = users[0].Alias == 'AEChg2' ? users[0] : users[1];

        // Do non-setup DML in runAs to avoid Mixed DML issues
        System.runAs(oldOwner) {
            Account acc = new Account(
                Name = 'AE Change Test Account',
                Territory_Name__c = '317 - Core New',
                Segment__c = 'Core New',
                Account_Hierarchy_Level__c = 'Global Parent',
                OwnerId = oldOwner.Id
            );
            insert acc;

            AccountTeamMember atm = new AccountTeamMember(
                AccountId = acc.Id,
                UserId = oldOwner.Id,
                TeamMemberRole = 'Renewal Specialist'
            );
            insert atm;

            Test.startTest();
            UpdateAccountOwnersBatch batch =
                new UpdateAccountOwnersBatch('317 - Core New', newOwner.Id);
            Database.executeBatch(batch, 100);
            Test.stopTest();

            Account updated = [
                SELECT OwnerId, Integration_Flag__c, ValidationBypassDateTime__c
                FROM Account
                WHERE Id = :acc.Id
            ];
            System.assertEquals(newOwner.Id, updated.OwnerId, 'Owner should be updated');
            System.assertEquals('UPDATE', updated.Integration_Flag__c, 'Integration flag should be updated');
            System.assertNotEquals(null, updated.ValidationBypassDateTime__c, 'Bypass datetime should be set');

            List<AccountTeamMember> atms = [
                SELECT Id
                FROM AccountTeamMember
                WHERE AccountId = :acc.Id
            ];
            System.assert(!atms.isEmpty(), 'AccountTeamMembers should exist after batch runs');
        }
    }
}