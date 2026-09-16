/********************************************************************************* 
ClassName : CaseTriggerHelperTest
==================================================================================
Req: All the cases which are created by Internal User, does not get associated with
     Account and Contact and also Entitlement is not being attached.
Sol: It is designed in such a way, it will check for User Contact based on CreatedById.
     If Contact exists, same Contact will get associated. If no Contact is found,
     it will create an Internal Contact and associate it with the Case.
==================================================================================
VERSION   AUTHOR        DATE           Jira Ticket No
62        Anil Kumar    04-Dec-2024    Teams -3554
62        Anil Kumar    07-July-2025   TEAMS-4729   
62        Anil Kumar    02-Feb-2026    TEAMS -6524
62        Anil Kumar    05-May-2026    TEAMS-7236 
*********************************************************************************/ 
@IsTest
private class CaseTriggerHelperTest {

    /* ==========================================
       ============  TEST SETUP DATA  ===========
       ========================================== */

    @testSetup
    static void setupData() {
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
    }

    /* ==========================================
       ============  TEST UTILITIES  ============
       ========================================== */

    private static User getInternalUser() {
        return [
            SELECT Id, Email
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
    }

    private static Account getHoldingAccount() {
        return [
            SELECT Id
            FROM Account
            WHERE Name = 'Holding Account [DO NOT EDIT]'
            LIMIT 1
        ];
    }

    private static Entitlement getDefaultEntitlement() {
        return [
            SELECT Id
            FROM Entitlement
            WHERE Name = 'default Entitlement'
            LIMIT 1
        ];
    }

    private static Entitlement getP0Entitlement() {
        return [
            SELECT Id
            FROM Entitlement
            WHERE Name = 'P0 Entitlement'
            LIMIT 1
        ];
    }

    private static Group getT1Queue() {
        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND DeveloperName = 'T1_Global_Queue'
            LIMIT 1
        ];

        System.assert(
            !queues.isEmpty(),
            'Missing Queue metadata: T1_Global_Queue'
        );

        return queues[0];
    }

    private static Case getCaseForAssignContactAndAccount(Id caseId) {
        return [
            SELECT Id,
                   CreatedById,
                   AccountId,
                   ContactId,
                   OwnerId,
                   EntitlementId,
                   Origin,
                   SuppliedEmail,
                   SuppliedName,
                   Type
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
    }

    /* ==========================================
       == TESTS FOR assignContactAndAccount() ===
       ========================================== */

    @IsTest
    static void testAssignContactAndAccount_withExistingContact() {
        User u        = getInternalUser();
        Account acc   = getHoldingAccount();
        Entitlement e = getDefaultEntitlement();
        Group q       = getT1Queue();

        Contact con = new Contact(
            FirstName = 'John',
            LastName  = 'Internal User Contact',
            Email     = u.Email,
            AccountId = acc.Id
        );
        insert con;

        Case c;

        System.runAs(u) {
            c = new Case(
                Subject  = 'Test Assign existing contact',
                Status   = 'New',
                Origin   = 'Phone',
                Priority = 'Medium'
            );
            insert c;
        }

        Case caseForHelper = getCaseForAssignContactAndAccount(c.Id);

        Test.startTest();
            CaseTriggerHelper.assignContactAndAccount(new List<Case>{ caseForHelper });
        Test.stopTest();

        Case result = [
            SELECT ContactId, AccountId, OwnerId, EntitlementId
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals(
            con.Id,
            result.ContactId,
            'ContactId must be set from matching Contact email.'
        );

        System.assertEquals(
            acc.Id,
            result.AccountId,
            'AccountId must be taken from the matched Contact.'
        );

        System.assertEquals(
            e.Id,
            result.EntitlementId,
            'EntitlementId must be set to the default Entitlement record.'
        );

        System.assertEquals(
            q.Id,
            result.OwnerId,
            'OwnerId must be set to T1_Global_Queue for non-escalation cases.'
        );
    }

    @IsTest
    static void testAssignContactAndAccount_noMatchingContact() {
        User u      = getInternalUser();
        Account acc = getHoldingAccount();
        Group q     = getT1Queue();

        List<Contact> existingContacts = [
            SELECT Id
            FROM Contact
            WHERE Email = :u.Email
        ];

        if (!existingContacts.isEmpty()) {
            delete existingContacts;
        }

        Case c;

        System.runAs(u) {
            c = new Case(
                Subject  = 'Test No Contact',
                Status   = 'New',
                Origin   = 'Phone',
                Priority = 'Medium'
            );
            insert c;
        }

        Case caseForHelper = getCaseForAssignContactAndAccount(c.Id);

        Test.startTest();
            CaseTriggerHelper.assignContactAndAccount(new List<Case>{ caseForHelper });
        Test.stopTest();

        Case result = [
            SELECT ContactId, AccountId, OwnerId, EntitlementId
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertNotEquals(
            null,
            result.ContactId,
            'Should have created and linked a Contact.'
        );

        System.assertNotEquals(
            null,
            result.AccountId,
            'Case should be linked to an Account.'
        );

        System.assertEquals(
            q.Id,
            result.OwnerId,
            'Owner should be the T1 queue.'
        );

        Contact createdCon = [
            SELECT Email, AccountId
            FROM Contact
            WHERE Id = :result.ContactId
            LIMIT 1
        ];

        System.assertEquals(
            u.Email,
            createdCon.Email,
            'New Contact email should match CreatedBy user email.'
        );

        System.assertEquals(
            acc.Id,
            createdCon.AccountId,
            'New Contact should be linked to holding account.'
        );
    }

    /* ==========================================
       == TESTS FOR assignP0Entitlement() =======
       ========================================== */

    @IsTest
    static void testAssignP0Entitlement_assignOnInProgressP0() {
        Case c = new Case(
            Subject  = 'P0 case',
            Status   = 'New',
            Origin   = 'Phone',
            Priority = 'Medium'
        );
        insert c;

        Case oldCase = new Case(
            Id       = c.Id,
            Status   = 'New',
            Priority = 'Medium'
        );

        Case newCase = new Case(
            Id       = c.Id,
            Status   = 'In Progress',
            Priority = 'P0 - Critical Customer Issue - No workaround'
        );

        Map<Id, Case> oldMap = new Map<Id, Case>{
            c.Id => oldCase
        };

        Map<Id, Case> newMap = new Map<Id, Case>{
            c.Id => newCase
        };

        Test.startTest();
            CaseTriggerHelper.assignP0Entitlement(newMap, oldMap);
        Test.stopTest();

        Entitlement p0Ent = getP0Entitlement();

        Case updated = [
            SELECT Id, EntitlementId
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals(
            p0Ent.Id,
            updated.EntitlementId,
            'P0 Entitlement should be attached when the case becomes P0 and moves to In Progress.'
        );
    }

    @IsTest
    static void testAssignP0Entitlement_removeOnLeavingInProgress() {
        Entitlement p0Ent = getP0Entitlement();

        Case c = new Case(
            Subject       = 'P0 leaving In Progress',
            Status        = 'In Progress',
            Origin        = 'Phone',
            Priority      = 'P0 - Critical Customer Issue - No workaround',
            EntitlementId = p0Ent.Id
        );
        insert c;

        Case oldCase = new Case(
            Id       = c.Id,
            Status   = 'In Progress',
            Priority = 'P0 - Critical Customer Issue - No workaround'
        );

        Case newCase = new Case(
            Id       = c.Id,
            Status   = 'Waiting for Customer',
            Priority = 'P0 - Critical Customer Issue - No workaround'
        );

        Map<Id, Case> oldMap = new Map<Id, Case>{
            c.Id => oldCase
        };

        Map<Id, Case> newMap = new Map<Id, Case>{
            c.Id => newCase
        };

        Test.startTest();
            CaseTriggerHelper.assignP0Entitlement(newMap, oldMap);
        Test.stopTest();

        Case updated = [
            SELECT Id, EntitlementId
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals(
            null,
            updated.EntitlementId,
            'P0 Entitlement should be cleared when a P0 case leaves In Progress.'
        );
    }

    /* ======================================================
       == TEST FOR assignEntitlementProcessAndQueue1() ======
       ====================================================== */

    @IsTest
    static void testAssignEntitlementProcessAndQueue_basicFlow() {
        User u = getInternalUser();

        Account acc = new Account(
            Name                       = 'Entitlement Account',
            US_support_only__c         = false,
            Account_Hierarchy_Level__c = 'Global Parent'
        );
        insert acc;

        Product_Account__c pa = new Product_Account__c(
            Name            = 'Test Product Account',
            Account__c      = acc.Id,
            Support_Tier__c = 'Core'
        );
        insert pa;

        Contact con = new Contact(
            LastName                   = 'SLA Contact',
            Email                      = 'sla@test.com',
            AccountId                  = acc.Id,
            Active_Services__c         = 'Essential',
           // Premium_Support_Contact__c = false,
            X24_7_Hand_off_Contact__c  = false
        );
        insert con;

        Account_Subscription__c sub = new Account_Subscription__c(
            Account__c    = acc.Id,
            Subscriber__c = u.Id,
            Active__c     = true
        );
        insert sub;

        Case c = new Case(
            Subject       = 'Routing test',
            Status        = 'New',
            Origin        = 'Phone',
            Priority      = 'Medium',
            AccountId     = acc.Id,
            ContactId     = con.Id,
            Issue_Type__c = 'Accounts/Billing'
        );
        insert c;

        Case caseForHelper = [
            SELECT Id,
                   AccountId,
                   ContactId,
                   Issue_Type__c,
                   Routing_Issue_Type__c,
                   CreatedById,
                   Origin,
                   SuppliedEmail,
                   SuppliedName,
                   Type
            FROM Case
            WHERE Id = :c.Id
            LIMIT 1
        ];

        Test.startTest();
            CaseTriggerHelper.assignEntitlementProcessAndQueue1(
                new List<Case>{ caseForHelper }
            );
        Test.stopTest();

        Case afterCall = [
            SELECT Id, AccountId, ContactId
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals(
            acc.Id,
            afterCall.AccountId,
            'Account must remain linked to the case.'
        );

        System.assertEquals(
            con.Id,
            afterCall.ContactId,
            'Contact must remain linked to the case.'
        );
    }
}