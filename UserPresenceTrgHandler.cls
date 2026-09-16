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
/*public class UserPresenceTrgHandler {

    @TestVisible
    private static Boolean useTestPresenceData = false;

    @TestVisible
    private static List<Id> testUserIds;

    @TestVisible
    private static List<Boolean> testNewStates;

    @TestVisible
    private static List<Boolean> testOldStates;

    public static void handleAfter(
        List<UserServicePresence> newList,
        Map<Id, UserServicePresence> oldMap
    ) {
        // used to stop the trigger from custom setting
        Map<String, UserPresenceTrg__c> Usr = UserPresenceTrg__c.getAll();
        if (!Test.isRunningTest() && !(Usr.size() > 0 && Usr.get('MakeActive').Activate__c)) {
            return;
        }
  
        Set<Id> offlineUserIds = new Set<Id>();

        if (Test.isRunningTest() && useTestPresenceData) {
            for (Integer i = 0; i < testUserIds.size(); i++) {
                Boolean newState = testNewStates[i];
                Boolean oldState = testOldStates == null ? null : testOldStates[i];

                if (newState == false && (oldState == null || oldState == true)) {
                    offlineUserIds.add(testUserIds[i]);
                }
            }
        } else {
            for (UserServicePresence usp : newList) {
                UserServicePresence oldUsp = oldMap == null ? null : oldMap.get(usp.Id);

                if (
                    usp.IsCurrentState == false &&
                    (oldUsp == null || oldUsp.IsCurrentState == true)
                ) {
                    offlineUserIds.add(usp.UserId);
                }
            }
        }

        moveCasesToT1Queue(offlineUserIds);
    }

    @TestVisible
    private static void moveCasesToT1Queue(Set<Id> offlineUserIds) {
        if (offlineUserIds == null || offlineUserIds.isEmpty()) {
            return;
        }

        Group t1Queue = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND DeveloperName = 'T1_Global_Queue'
            LIMIT 1
        ];

        List<Case> casesToMove = [
            SELECT Id, OwnerId
            FROM Case
            WHERE OwnerId IN :offlineUserIds
            AND ReAssignToQueue__c = true
            AND IsClosed = false
        ];

        List<Case> casesToUpdate = new List<Case>();

        for (Case c : casesToMove) {
            casesToUpdate.add(new Case(
                Id = c.Id,
                OwnerId = t1Queue.Id
            ));
        }

        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }

    @TestVisible
    private static void resetTestData() {
        useTestPresenceData = false;
        testUserIds = null;
        testNewStates = null;
        testOldStates = null;
    }
}*/

public class UserPresenceTrgHandler {

    @TestVisible
    private static Boolean useTestPresenceData = false;

    @TestVisible
    private static List<Id> testUserIds;

    @TestVisible
    private static List<Boolean> testNewStates;

    @TestVisible
    private static List<Boolean> testOldStates;

    @TestVisible
    private static Id testT1QueueId;

    public static void handleAfter(
        List<UserServicePresence> newList,
        Map<Id, UserServicePresence> oldMap
    ) {
        Map<String, UserPresenceTrg__c> usrSettings = UserPresenceTrg__c.getAll();
        UserPresenceTrg__c makeActive = usrSettings.get('MakeActive');

        if (
            !Test.isRunningTest() &&
            (makeActive == null || makeActive.Activate__c != true)
        ) {
            return;
        }

        Set<Id> offlineUserIds = new Set<Id>();

        if (Test.isRunningTest() && useTestPresenceData) {
            if (testUserIds == null || testNewStates == null) {
                return;
            }

            for (Integer i = 0; i < testUserIds.size(); i++) {
                Boolean newState = testNewStates[i];
                Boolean oldState = testOldStates == null ? null : testOldStates[i];

                if (newState == false && (oldState == null || oldState == true)) {
                    offlineUserIds.add(testUserIds[i]);
                }
            }
        } else {
            for (UserServicePresence usp : newList) {
                UserServicePresence oldUsp = oldMap == null ? null : oldMap.get(usp.Id);

                if (
                    usp.IsCurrentState == false &&
                    (oldUsp == null || oldUsp.IsCurrentState == true)
                ) {
                    offlineUserIds.add(usp.UserId);
                }
            }
        }

        moveCasesToT1Queue(offlineUserIds);
    }

    @TestVisible
    private static void moveCasesToT1Queue(Set<Id> offlineUserIds) {
        if (offlineUserIds == null || offlineUserIds.isEmpty()) {
            return;
        }

        Id t1QueueId;

        if (Test.isRunningTest() && testT1QueueId != null) {
            t1QueueId = testT1QueueId;
        } else {
            List<Group> queues = [
                SELECT Id
                FROM Group
                WHERE Type = 'Queue'
                AND DeveloperName = 'T1_Global_Queue'
                LIMIT 1
            ];

            if (queues.isEmpty()) {
                return;
            }

            t1QueueId = queues[0].Id;
        }

        List<Case> casesToMove = [
            SELECT Id
            FROM Case
            WHERE OwnerId IN :offlineUserIds
            AND ReAssignToQueue__c = true
            AND IsClosed = false
        ];

        List<Case> casesToUpdate = new List<Case>();

        for (Case c : casesToMove) {
            casesToUpdate.add(new Case(
                Id = c.Id,
                OwnerId = t1QueueId
            ));
        }

        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }

    @TestVisible
    private static void resetTestData() {
        useTestPresenceData = false;
        testUserIds = null;
        testNewStates = null;
        testOldStates = null;
        testT1QueueId = null;
    }
}