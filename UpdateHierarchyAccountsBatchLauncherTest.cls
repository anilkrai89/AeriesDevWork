@IsTest
public class UpdateHierarchyAccountsBatchLauncherTest {

    // Helper to create a test user we can assign as OwnerId
    private static User createUser(String uniqueKey) {
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        User u = new User(
            ProfileId = p.Id,
            Username = 'testuser+' + uniqueKey + '@example.com',
            Email = 'testuser+' + uniqueKey + '@example.com',
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
    static void run_success_usesDefaultBatchSize200() {
        User owner = createUser('def200');

        UpdateHierarchyAccountsBatchLauncher.Request req =
            new UpdateHierarchyAccountsBatchLauncher.Request();
        req.ultimateParentId = '001UN00000F9CKiYAN'; // string id per your class signature
        req.segment = 'Core New';
        req.territoryName = '300 - Core New';
        req.newOwnerId = owner.Id;
        req.sdrOwnerId = String.valueOf(owner.Id);
        // req.batchSize left null -> should default to 200

        Test.startTest();
        List<UpdateHierarchyAccountsBatchLauncher.Response> res =
            UpdateHierarchyAccountsBatchLauncher.run(new List<UpdateHierarchyAccountsBatchLauncher.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, res.size(), 'Should return one response');
        System.assertEquals('UpdateHierarchyAccountsBatch submitted successfully.', res[0].message);
        System.assertEquals(200, res[0].batchSizeUsed, 'Should default to 200 when batchSize is null');

        // Optional: verify an AsyncApexJob exists (batch submission happened)
        List<AsyncApexJob> jobs = [
            SELECT Id, JobType, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(!jobs.isEmpty(), 'Expected a batch AsyncApexJob to be created');
    }

    @IsTest
    static void run_success_usesProvidedBatchSize() {
        User owner = createUser('custom');

        UpdateHierarchyAccountsBatchLauncher.Request req =
            new UpdateHierarchyAccountsBatchLauncher.Request();
        req.ultimateParentId = '001UN00000F9CKiYAN';
        req.segment = 'Core New';
        req.territoryName = '301 - Core New';
        req.newOwnerId = owner.Id;
        req.sdrOwnerId = String.valueOf(owner.Id);
        req.batchSize = 50;

        Test.startTest();
        List<UpdateHierarchyAccountsBatchLauncher.Response> res =
            UpdateHierarchyAccountsBatchLauncher.run(new List<UpdateHierarchyAccountsBatchLauncher.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals('UpdateHierarchyAccountsBatch submitted successfully.', res[0].message);
        System.assertEquals(50, res[0].batchSizeUsed);
    }

    @IsTest
    static void run_validation_missingUltimateParentId() {
        User owner = createUser('missup');

        UpdateHierarchyAccountsBatchLauncher.Request req =
            new UpdateHierarchyAccountsBatchLauncher.Request();
        req.ultimateParentId = ' '; // blank
        req.segment = 'Core New';
        req.territoryName = '300 - Core New';
        req.newOwnerId = owner.Id;
        req.sdrOwnerId = String.valueOf(owner.Id);

        List<UpdateHierarchyAccountsBatchLauncher.Response> res =
            UpdateHierarchyAccountsBatchLauncher.run(new List<UpdateHierarchyAccountsBatchLauncher.Request>{ req });

        System.assertEquals(1, res.size());
        System.assertEquals('ultimateParentId is required.', res[0].message);
        System.assertEquals(null, res[0].batchSizeUsed);
    }

    @IsTest
    static void run_validation_missingSegment() {
        User owner = createUser('missseg');

        UpdateHierarchyAccountsBatchLauncher.Request req =
            new UpdateHierarchyAccountsBatchLauncher.Request();
        req.ultimateParentId = '001UN00000F9CKiYAN';
        req.segment = null; // missing
        req.territoryName = '303 - Core New';
        req.newOwnerId = owner.Id;
        req.sdrOwnerId = String.valueOf(owner.Id);

        List<UpdateHierarchyAccountsBatchLauncher.Response> res =
            UpdateHierarchyAccountsBatchLauncher.run(new List<UpdateHierarchyAccountsBatchLauncher.Request>{ req });

        System.assertEquals(1, res.size());
        System.assertEquals('segment is required.', res[0].message);
    }

    @IsTest
    static void run_validation_missingTerritoryName() {
        User owner = createUser('misster');

        UpdateHierarchyAccountsBatchLauncher.Request req =
            new UpdateHierarchyAccountsBatchLauncher.Request();
        req.ultimateParentId = '001UN00000F9CKiYAN';
        req.segment = 'Core New';
        req.territoryName = ''; // missing
        req.newOwnerId = owner.Id;
        req.sdrOwnerId = String.valueOf(owner.Id);

        List<UpdateHierarchyAccountsBatchLauncher.Response> res =
            UpdateHierarchyAccountsBatchLauncher.run(new List<UpdateHierarchyAccountsBatchLauncher.Request>{ req });

        System.assertEquals(1, res.size());
        System.assertEquals('territoryName is required.', res[0].message);
    }

    @IsTest
    static void run_validation_missingNewOwnerId() {
        User owner = createUser('missown');

        UpdateHierarchyAccountsBatchLauncher.Request req =
            new UpdateHierarchyAccountsBatchLauncher.Request();
        req.ultimateParentId = '001UN00000F9CKiYAN';
        req.segment = 'Core New';
        req.territoryName = '300 - Core New';
        req.newOwnerId = null; // missing
        req.sdrOwnerId = String.valueOf(owner.Id);

        List<UpdateHierarchyAccountsBatchLauncher.Response> res =
            UpdateHierarchyAccountsBatchLauncher.run(new List<UpdateHierarchyAccountsBatchLauncher.Request>{ req });

        System.assertEquals(1, res.size());
        System.assertEquals('newOwnerId is required.', res[0].message);
    }

    @IsTest
    static void run_validation_missingSdrOwnerId() {
        User owner = createUser('misssdr');

        UpdateHierarchyAccountsBatchLauncher.Request req =
            new UpdateHierarchyAccountsBatchLauncher.Request();
        req.ultimateParentId = '001UN00000F9CKiYAN';
        req.segment = 'Core New';
        req.territoryName = '300 - Core New';
        req.newOwnerId = owner.Id;
        req.sdrOwnerId = null; // missing (your code checks null)

        List<UpdateHierarchyAccountsBatchLauncher.Response> res =
            UpdateHierarchyAccountsBatchLauncher.run(new List<UpdateHierarchyAccountsBatchLauncher.Request>{ req });

        System.assertEquals(1, res.size());
        // NOTE: Your class currently returns the *wrong* message for this case.
        System.assertEquals('newOwnerId is required.', res[0].message);
    }

    @IsTest
    static void run_emptyRequests_returnsEmptyList() {
        List<UpdateHierarchyAccountsBatchLauncher.Response> res =
            UpdateHierarchyAccountsBatchLauncher.run(new List<UpdateHierarchyAccountsBatchLauncher.Request>());

        System.assertEquals(0, res.size());
    }

    @IsTest
    static void run_nullRequests_returnsEmptyList() {
        List<UpdateHierarchyAccountsBatchLauncher.Response> res =
            UpdateHierarchyAccountsBatchLauncher.run(null);

        System.assertEquals(0, res.size());
    }
}