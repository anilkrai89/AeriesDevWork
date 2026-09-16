@IsTest
public class UpdateAccountHiearchyOpportunitiesTest {

    // ---- Helpers ----
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
    static void batch_updatesContacts_forProvidedAccounts() {
        // Isolate setup DML (User) to avoid Mixed DML if org automation assigns permission sets, etc.
        User runningUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        User acctOwner;
        User newOwner;
        User sdrUser;

        System.runAs(runningUser) {
            acctOwner = createUser('acctOwner');
            newOwner  = createUser('newOwner');
            sdrUser   = createUser('sdrOwner');
        }

        // Non-setup DML: Accounts + Contacts
        Account a1 = new Account(Name = 'A1', OwnerId = acctOwner.Id, Segment__c = 'Core New', Territory_Name__c = '300 - Core New');
        Account a2 = new Account(Name = 'A2', OwnerId = acctOwner.Id, Segment__c = 'Core New', Territory_Name__c = '301 - Core New');
        insert new List<Account>{ a1, a2 };

        Opportunity o1 = new Opportunity(Name = 'O1', AccountId = a1.Id, OwnerId = acctOwner.Id, StageName = '00 - Prospecting', Opportunity_Segment__c = 'Core New', Opportunity_Territory__c = '300 - Core New', CloseDate = System.today());
        Opportunity o2 = new Opportunity(Name = 'O2', AccountId = a1.Id, OwnerId = acctOwner.Id, StageName = '00 - Prospecting', Opportunity_Segment__c = 'Core New', Opportunity_Territory__c = '301 - Core New', CloseDate = System.today());
        insert new List<Opportunity>{ o1, o2 };

        // Run batch for a1 only
        Set<Id> updatedOppIds = new Set<Id>{ o1.Id };

        Test.startTest();
        Database.executeBatch(
            new UpdateHiearchyAccountOpportunitiesBatch(acctOwner.Id, a1.Territory_Name__c, a1.Id, a1.Segment__c),
           
            50
        );
        Test.stopTest();

/*
        // Requery contacts
        Map<Id, Contact> afterMap = new Map<Id, Contact>([
            SELECT Id, AccountId, OwnerId, SDR_Owner__c, ValidationBypassDateTime__c
            FROM Contact
            WHERE Id IN :new List<Id>{ c1.Id, c2.Id, c3.Id }
        ]);

        // Contacts on a1 should be updated
        System.assertEquals(newOwner.Id, afterMap.get(c1.Id).OwnerId, 'c1 owner should be updated');
        System.assertEquals(sdrUser.Id,  afterMap.get(c1.Id).SDR_Owner__c, 'c1 SDR owner should be updated');
        System.assertNotEquals(null,     afterMap.get(c1.Id).ValidationBypassDateTime__c, 'c1 bypass dt should be set');

        System.assertEquals(newOwner.Id, afterMap.get(c2.Id).OwnerId, 'c2 owner should be updated');
        System.assertEquals(sdrUser.Id,  afterMap.get(c2.Id).SDR_Owner__c, 'c2 SDR owner should be updated');
        System.assertNotEquals(null,     afterMap.get(c2.Id).ValidationBypassDateTime__c, 'c2 bypass dt should be set');

        // Contact on a2 should NOT be updated
        System.assertEquals(acctOwner.Id, afterMap.get(c3.Id).OwnerId, 'c3 owner should remain unchanged');
        System.assertEquals(null,         afterMap.get(c3.Id).SDR_Owner__c, 'c3 SDR owner should remain unchanged');
        System.assertEquals(null,         afterMap.get(c3.Id).ValidationBypassDateTime__c, 'c3 bypass dt should remain unchanged');
    }

    @IsTest
    static void batch_withEmptyAccountSet_updatesNothing() {
        // Setup users
        User runningUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        User acctOwner;
        User newOwner;
        User sdrUser;

        System.runAs(runningUser) {
            acctOwner = createUser('empty_acctOwner');
            newOwner  = createUser('empty_newOwner');
            sdrUser   = createUser('empty_sdrOwner');
        }

        Account a1 = new Account(Name = 'A1', OwnerId = acctOwner.Id);
        insert a1;

        Contact c1 = new Contact(LastName = 'C1', AccountId = a1.Id, OwnerId = acctOwner.Id, Email = 'test@test.com');
        insert c1;

        Test.startTest();
        Database.executeBatch(
            new UpdateAccountHiearchyContactsBatch(new Set<Id>(), newOwner.Id, sdrUser.Id, a1.Territory_Name__c, a1.Id),
            50
        );
        Test.stopTest();

        Contact afterC1 = [
            SELECT Id, OwnerId, SDR_Owner__c, ValidationBypassDateTime__c
            FROM Contact
            WHERE Id = :c1.Id
        ];

        System.assertEquals(acctOwner.Id, afterC1.OwnerId);
        System.assertEquals(null, afterC1.SDR_Owner__c);
        System.assertEquals(null, afterC1.ValidationBypassDateTime__c);
    }*/
}}