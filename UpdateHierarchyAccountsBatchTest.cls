@IsTest
public class UpdateHierarchyAccountsBatchTest {

    private static User createUser(String uniqueKey) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User u = new User(
            ProfileId = p.Id,
            Username = 'u+' + uniqueKey + '@example.com',
            Email = 'u+' + uniqueKey + '@example.com',
            LastName = 'Tester',
            Alias = ('t' + uniqueKey).left(8),
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        return u;
    }

    @IsTest
    static void batch_updatesExpectedFields_evenIfOwnerIsOverriddenByAutomation() {
        // --- Setup-object DML isolated ---
        User runningUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        User originalOwner;
        User newOwner;
        User sdrUser;

        System.runAs(runningUser) {
            originalOwner = createUser('orig');
            newOwner      = createUser('newown');
            sdrUser       = createUser('sdr');
        }

        // Create parent + children
        Account ultimateParent = new Account(Name = 'Ultimate Parent');
        insert ultimateParent;

        // Value passed into the batch (your constructor expects String)
        String ultimateParentId = String.valueOf(ultimateParent.Id);

        // IMPORTANT: set the SAME field the batch queries: Ultimate_Parent_ID__c
        Account a1 = new Account(
            Name = 'Child 1',
            OwnerId = originalOwner.Id,
            ParentId = ultimateParentId,   // <-- FIX
            Segment__c = 'Core New',
            Territory_Name__c = '300 - Core New',
            Integration_Flag__c = null,
            SDR_Owner__c = null
        );
        Account a2 = new Account(
            Name = 'Child 2',
            OwnerId = originalOwner.Id,
            ParentId = ultimateParentId,   // <-- FIX
            Segment__c = 'Core New',
            Territory_Name__c = '301 - Core New',
            Integration_Flag__c = null,
            SDR_Owner__c = null
        );
        insert new List<Account>{ a1, a2 };

        // Non-SDR team member so it is included in the subquery filter
        insert new List<AccountTeamMember>{
            new AccountTeamMember(AccountId = a1.Id, UserId = originalOwner.Id, TeamMemberRole = 'Account Manager'),
            new AccountTeamMember(AccountId = a2.Id, UserId = originalOwner.Id, TeamMemberRole = 'Account Manager')
        };

        String segment = 'Core New';
        String territory = '300 - Core New';

        Test.startTest();
        Database.executeBatch(
            new UpdateHierarchyAccountsBatch(
                ultimateParentId,
                segment,
                territory,
                newOwner.Id,
                sdrUser.Id
            ),
            50
        );
        Test.stopTest();

        Map<Id, Account> updated = new Map<Id, Account>([
            SELECT Id, SDR_Owner__c, Segment__c, Territory_Name__c,
                   Integration_Flag__c, ValidationBypassDateTime__c
            FROM Account
            WHERE Id IN :new List<Id>{ a1.Id, a2.Id }
        ]);

        Account ua1 = updated.get(a1.Id);
        Account ua2 = updated.get(a2.Id);

        System.assertEquals(sdrUser.Id, ua1.SDR_Owner__c, 'a1 SDR owner should be updated');
        System.assertEquals(segment,    ua1.Segment__c,   'a1 segment should be updated');
        System.assertEquals(territory,  ua1.Territory_Name__c, 'a1 territory should be updated');
        System.assertEquals('UPDATE',   ua1.Integration_Flag__c, 'a1 integration flag should be set');
        System.assertNotEquals(null,    ua1.ValidationBypassDateTime__c, 'a1 bypass datetime should be set');

        System.assertEquals(sdrUser.Id, ua2.SDR_Owner__c, 'a2 SDR owner should be updated');
        System.assertEquals(segment,    ua2.Segment__c,   'a2 segment should be updated');
        System.assertEquals(territory,  ua2.Territory_Name__c, 'a2 territory should be updated');
        System.assertEquals('UPDATE',   ua2.Integration_Flag__c, 'a2 integration flag should be set');
        System.assertNotEquals(null,    ua2.ValidationBypassDateTime__c, 'a2 bypass datetime should be set');

        Integer sdrTeamCount = [
            SELECT COUNT()
            FROM AccountTeamMember
            WHERE AccountId IN :new List<Id>{ a1.Id, a2.Id }
              AND TeamMemberRole = 'Sales Development Rep'
              AND UserId = :sdrUser.Id
        ];
        System.assertEquals(2, sdrTeamCount, 'Expected SDR team member on both accounts');
    }
}
/*
*/