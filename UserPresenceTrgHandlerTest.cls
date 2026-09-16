/********************************************************************************* 
ClassName : UserPresenceTrgHandler
TestClass :UserPresenceTrgHandlerTest
==================================================================================
Automatically reassign open Cases back to the T1 Global Queue when an Omni-Channel user goes offline.

A user is considered offline when their UserServicePresence.IsCurrentState becomes false.
==================================================================================
History
---------------------------------------------------------------------------------
APIVERSION	  Developer Name	     DATE	       Jira Ticket No
    62         Anil Kumar          20-May-2026       ETE-7131
    
 
*********************************************************************************/ 


@IsTest
private class UserPresenceTrgHandlerTest {

    @testSetup
    static void setupData() {
        User currentUser = getInternalUser();

        System.runAs(currentUser) {
            Group testQueue = new Group(
                Name = 'User Presence Test Queue',
                DeveloperName = 'User_Presence_Test_Queue',
                Type = 'Queue'
            );
            insert testQueue;

            QueueSobject queueObject = new QueueSobject(
                QueueId = testQueue.Id,
                SobjectType = 'Case'
            );
            insert queueObject;
        }

        Account acc = new Account(
            Name                       = 'Holding Account [DO NOT EDIT]',
            Account_Hierarchy_Level__c = 'Global Parent'
        );
        insert acc;

        insert new List<Entitlement>{
            new Entitlement(
                Name      = 'default Entitlement',
                AccountId = acc.Id,
                StartDate = System.today(),
                EndDate   = System.today().addYears(1)
            ),
            new Entitlement(
                Name      = 'P0 Entitlement',
                AccountId = acc.Id,
                StartDate = System.today(),
                EndDate   = System.today().addYears(1)
            )
        };

        List<Contact> contacts = [
            SELECT Id
            FROM Contact
            WHERE Email = :currentUser.Email
            LIMIT 1
        ];

        if (contacts.isEmpty()) {
            insert new Contact(
                FirstName = 'User',
                LastName  = 'Presence Test Contact',
                Email     = currentUser.Email,
                AccountId = acc.Id
            );
        }
    }

    private static User getInternalUser() {
        return [
            SELECT Id, Email
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
    }

    private static Group getTestQueue() {
        return [
            SELECT Id, DeveloperName
            FROM Group
            WHERE Type = 'Queue'
            AND DeveloperName = 'User_Presence_Test_Queue'
            LIMIT 1
        ];
    }

    private static Case createCaseForUser(
        Id ownerId,
        String subjectValue,
        Boolean reassignToQueue
    ) {
        Case c = new Case(
            Subject            = subjectValue,
            Status             = 'New',
            Origin             = 'Phone',
            Priority           = 'Medium',
            ReAssignToQueue__c = reassignToQueue
        );
        insert c;

        c.OwnerId = ownerId;
        c.ReAssignToQueue__c = reassignToQueue;
        update c;

        return [
            SELECT Id, OwnerId, ReAssignToQueue__c, IsClosed
            FROM Case
            WHERE Id = :c.Id
            LIMIT 1
        ];
    }

    private static void setPresenceTestData(
        List<Id> userIds,
        List<Boolean> newStates,
        List<Boolean> oldStates
    ) {
        UserPresenceTrgHandler.useTestPresenceData = true;
        UserPresenceTrgHandler.testUserIds = userIds;
        UserPresenceTrgHandler.testNewStates = newStates;
        UserPresenceTrgHandler.testOldStates = oldStates;
        UserPresenceTrgHandler.testT1QueueId = getTestQueue().Id;
    }

    @IsTest
    static void testHandleAfter_testInsertOffline_movesCase() {
        UserPresenceTrgHandler.resetTestData();

        User u  = getInternalUser();
        Group q = getTestQueue();

        Case c = createCaseForUser(
            u.Id,
            'Injected insert offline',
            true
        );

        setPresenceTestData(
            new List<Id>{ u.Id },
            new List<Boolean>{ false },
            null
        );

        Test.startTest();
        UserPresenceTrgHandler.handleAfter(
            new List<UserServicePresence>(),
            null
        );
        Test.stopTest();

        Case result = [
            SELECT OwnerId
            FROM Case
            WHERE Id = :c.Id
            LIMIT 1
        ];

        System.assertEquals(
            q.Id,
            result.OwnerId,
            'Injected offline insert should move case.'
        );

        UserPresenceTrgHandler.resetTestData();
    }

    @IsTest
    static void testHandleAfter_testInsertOnline_doesNothing() {
        UserPresenceTrgHandler.resetTestData();

        User u = getInternalUser();

        Case c = createCaseForUser(
            u.Id,
            'Injected insert online',
            true
        );

        setPresenceTestData(
            new List<Id>{ u.Id },
            new List<Boolean>{ true },
            null
        );

        Test.startTest();
        UserPresenceTrgHandler.handleAfter(
            new List<UserServicePresence>(),
            null
        );
        Test.stopTest();

        Case result = [
            SELECT OwnerId
            FROM Case
            WHERE Id = :c.Id
            LIMIT 1
        ];

        System.assertEquals(
            u.Id,
            result.OwnerId,
            'Injected online insert should not move case.'
        );

        UserPresenceTrgHandler.resetTestData();
    }

    @IsTest
    static void testHandleAfter_testUpdateTrueToFalse_movesCase() {
        UserPresenceTrgHandler.resetTestData();

        User u  = getInternalUser();
        Group q = getTestQueue();

        Case c = createCaseForUser(
            u.Id,
            'Injected update true to false',
            true
        );

        setPresenceTestData(
            new List<Id>{ u.Id },
            new List<Boolean>{ false },
            new List<Boolean>{ true }
        );

        Test.startTest();
        UserPresenceTrgHandler.handleAfter(
            new List<UserServicePresence>(),
            null
        );
        Test.stopTest();

        Case result = [
            SELECT OwnerId
            FROM Case
            WHERE Id = :c.Id
            LIMIT 1
        ];

        System.assertEquals(
            q.Id,
            result.OwnerId,
            'Injected true to false update should move case.'
        );

        UserPresenceTrgHandler.resetTestData();
    }

    @IsTest
    static void testHandleAfter_testUpdateFalseToFalse_doesNothing() {
        UserPresenceTrgHandler.resetTestData();

        User u = getInternalUser();

        Case c = createCaseForUser(
            u.Id,
            'Injected update false to false',
            true
        );

        setPresenceTestData(
            new List<Id>{ u.Id },
            new List<Boolean>{ false },
            new List<Boolean>{ false }
        );

        Test.startTest();
        UserPresenceTrgHandler.handleAfter(
            new List<UserServicePresence>(),
            null
        );
        Test.stopTest();

        Case result = [
            SELECT OwnerId
            FROM Case
            WHERE Id = :c.Id
            LIMIT 1
        ];

        System.assertEquals(
            u.Id,
            result.OwnerId,
            'Injected false to false update should not move case.'
        );

        UserPresenceTrgHandler.resetTestData();
    }

    @IsTest
    static void testHandleAfter_testBulkMixedStates() {
        UserPresenceTrgHandler.resetTestData();

        User u  = getInternalUser();
        Group q = getTestQueue();

        Case eligibleCase = createCaseForUser(
            u.Id,
            'Injected bulk eligible',
            true
        );

        setPresenceTestData(
            new List<Id>{ u.Id, u.Id, u.Id },
            new List<Boolean>{ true, false, false },
            new List<Boolean>{ true, true, false }
        );

        Test.startTest();
        UserPresenceTrgHandler.handleAfter(
            new List<UserServicePresence>(),
            null
        );
        Test.stopTest();

        Case result = [
            SELECT OwnerId
            FROM Case
            WHERE Id = :eligibleCase.Id
            LIMIT 1
        ];

        System.assertEquals(
            q.Id,
            result.OwnerId,
            'Bulk injected data should move when one state changes true to false.'
        );

        UserPresenceTrgHandler.resetTestData();
    }

    @IsTest
    static void testMoveCasesToT1Queue_nullSet() {
        UserPresenceTrgHandler.resetTestData();

        Test.startTest();
        UserPresenceTrgHandler.moveCasesToT1Queue(null);
        Test.stopTest();

        System.assert(true, 'No exception expected.');
    }

    @IsTest
    static void testMoveCasesToT1Queue_emptySet() {
        UserPresenceTrgHandler.resetTestData();

        Test.startTest();
        UserPresenceTrgHandler.moveCasesToT1Queue(new Set<Id>());
        Test.stopTest();

        System.assert(true, 'No exception expected.');
    }

    @IsTest
    static void testMoveCasesToT1Queue_flagFalseDoesNotMove() {
        UserPresenceTrgHandler.resetTestData();

        User u = getInternalUser();

        Case c = createCaseForUser(
            u.Id,
            'Flag false direct test',
            false
        );

        UserPresenceTrgHandler.testT1QueueId = getTestQueue().Id;

        Test.startTest();
        UserPresenceTrgHandler.moveCasesToT1Queue(new Set<Id>{ u.Id });
        Test.stopTest();

        Case result = [
            SELECT OwnerId
            FROM Case
            WHERE Id = :c.Id
            LIMIT 1
        ];

        System.assertEquals(
            u.Id,
            result.OwnerId,
            'Case should not move when ReAssignToQueue__c is false.'
        );

        UserPresenceTrgHandler.resetTestData();
    }
   //
   //
   @IsTest
static void testTriggerInsertCoverage() {
    List<ServicePresenceStatus> statuses = [
        SELECT Id
        FROM ServicePresenceStatus
        LIMIT 1
    ];

    if (statuses.isEmpty()) {
        System.assert(true, 'No ServicePresenceStatus found.');
        return;
    }

    UserServicePresence usp = new UserServicePresence(
        UserId = UserInfo.getUserId(),
        ServicePresenceStatusId = statuses[0].Id
    );

    Test.startTest();
    insert usp;
    Test.stopTest();

    System.assertNotEquals(null, usp.Id);
}
}