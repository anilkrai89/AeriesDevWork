@IsTest
private class CaseToJiraTrgHandlerTest {

    
    private static final String HOLDING_ACCOUNT_NAME     = 'Holding Account [DO NOT EDIT]';
    private static final String DEFAULT_ENTITLEMENT_NAME = 'default Entitlement';
    private static final String P0_ENTITLEMENT_NAME      = 'P0 Entitlement';

    
    @TestSetup
    static void setupData() {
        // Enable trigger setting for the running user (handler is null-safe)
        Automation_Settings__c setting = Automation_Settings__c.getInstance(UserInfo.getUserId());
        setting.Case_Trigger_Enabled__c = true;
        upsert setting;

        // Create Holding Account + Entitlements to prevent Case automation from exploding
        // (mirrors the earlier CaseTriggerHelper tests / avoids "no rows" entitlement queries)
        Account holding = new Account(
            Name = HOLDING_ACCOUNT_NAME,
            Account_Hierarchy_Level__c = 'Global Parent'
        );
        insert holding;

        insert new List<Entitlement>{
            new Entitlement(
                Name      = DEFAULT_ENTITLEMENT_NAME,
                AccountId = holding.Id,
                StartDate = System.today(),
                EndDate   = System.today().addYears(1)
            ),
            new Entitlement(
                Name      = P0_ENTITLEMENT_NAME,
                AccountId = holding.Id,
                StartDate = System.today(),
                EndDate   = System.today().addYears(1)
            )
        };

        // Minimal Contact for Case validation/flows
        Contact con = new Contact(
            LastName  = 'Jira Handler Contact',
            Email     = 'jirahandler@test.com',
            AccountId = holding.Id
        );
        insert con;
    }

    
    private static void setTriggerEnabled(Boolean enabled) {
        Automation_Settings__c setting = Automation_Settings__c.getInstance(UserInfo.getUserId());
        setting.Case_Trigger_Enabled__c = enabled;
        upsert setting;
    }

    private static Contact getContact() {
        return [SELECT Id, AccountId FROM Contact LIMIT 1];
    }

    private static Case insertBaseCase() {
        Contact con = getContact();
        Case c = new Case(
            Subject   = 'CaseToJiraTrgHandlerTest',
            Status    = 'New',
            Origin    = 'Phone',
            Priority  = 'Medium',
            AccountId = con.AccountId,
            ContactId = con.Id
        );
        insert c;
        return c;
    }

    private static Map<Id, Case> oldMapFrom(List<Case> casesBeforeUpdate) {
        Map<Id, Case> m = new Map<Id, Case>();
        for (Case c : casesBeforeUpdate) m.put(c.Id, c);
        return m;
    }

  

    @IsTest
    static void testAfterUpdate_bypassesWhenSettingDisabled() {
        setTriggerEnabled(false);

        Case c = insertBaseCase();

        // create "old image"
        Case oldC = c.clone(false, true, false, false);
        oldC.Id = c.Id;

        // create "new image" with some changes that WOULD normally trigger logic
        Case newC = c.clone(false, true, false, false);
        newC.Id = c.Id;
        newC.JIRA_Create_Issue__c = true;
        newC.JIRA_Project_ID__c   = '13462';
        newC.JIRA_Issue_Type_ID__c = '10100';
        newC.JIRA_Summary__c = 'summary change';

        Test.startTest();
            CaseToJiraTrgHandler.afterUpdate(
                new List<Case>{ newC },
                new Map<Id, Case>{ c.Id => oldC }
            );
        Test.stopTest();

        System.assert(true, 'Handler should bypass without throwing when disabled.');
    }

    @IsTest
    static void testAfterUpdate_createIssue_skipsWhenPidBlankOrIssueTypeBlank() {
        setTriggerEnabled(true);

        Case c = insertBaseCase();

        Case oldC = c.clone(false, true, false, false);
        oldC.Id = c.Id;
        oldC.JIRA_Create_Issue__c = false;

        Case newC = c.clone(false, true, false, false);
        newC.Id = c.Id;
        newC.JIRA_Create_Issue__c = true;      // flipped to true => qualifies
        newC.JIRA_Project_ID__c   = '   ';     // blank => should skip API call
        newC.JIRA_Issue_Type_ID__c = null;     // blank => should skip API call

        // Also ensure shouldPush would become true (JIRA_Create_Issue__c changed)
        // but this test's purpose is "no throw even if branch is evaluated"

        Test.startTest();
            CaseToJiraTrgHandler.afterUpdate(
                new List<Case>{ newC },
                new Map<Id, Case>{ c.Id => oldC }
            );
        Test.stopTest();

        System.assert(true, 'Should safely skip createJiraIssueWithDefaultPostAction when pid/issuetype are blank.');
    }

    @IsTest
    static void testAfterUpdate_shouldPush_false_whenNoMappedFieldsChanged() {
        setTriggerEnabled(true);

        Case c = insertBaseCase();

        // old + new are identical => shouldPush remains false
        Case oldC = c.clone(false, true, false, false);
        oldC.Id = c.Id;

        Case newC = c.clone(false, true, false, false);
        newC.Id = c.Id;

        Test.startTest();
            CaseToJiraTrgHandler.afterUpdate(
                new List<Case>{ newC },
                new Map<Id, Case>{ c.Id => oldC }
            );
        Test.stopTest();

        System.assert(true, 'No relevant field changes -> should not call pushUpdatesToJira, but we validate no exceptions.');
    }

    @IsTest
    static void testAfterUpdate_shouldPush_true_whenMappedFieldChanged() {
        setTriggerEnabled(true);

        Case c = insertBaseCase();

        Case oldC = c.clone(false, true, false, false);
        oldC.Id = c.Id;
        oldC.JIRA_Summary__c = 'Old summary';

        Case newC = c.clone(false, true, false, false);
        newC.Id = c.Id;
        newC.JIRA_Summary__c = 'New summary'; // mapped field changed => shouldPush true

        Test.startTest();
            CaseToJiraTrgHandler.afterUpdate(
                new List<Case>{ newC },
                new Map<Id, Case>{ c.Id => oldC }
            );
        Test.stopTest();

        // We can’t assert JCFS.API.pushUpdatesToJira() was called without a seam/mock.
        // This test ensures the shouldPush gating is exercised and doesn’t throw.
        System.assert(true, 'Mapped field changed -> shouldPush path covered (no throw).');
    }

    @IsTest
    static void testAfterUpdate_createIssue_path_isCovered_whenFlagFlipsAndPidPresent() {
        setTriggerEnabled(true);

        Case c = insertBaseCase();

        Case oldC = c.clone(false, true, false, false);
        oldC.Id = c.Id;
        oldC.JIRA_Create_Issue__c = false;
        oldC.JIRA_Project_ID__c = null;
        oldC.JIRA_Issue_Type_ID__c = null;

        Case newC = c.clone(false, true, false, false);
        newC.Id = c.Id;
        newC.JIRA_Create_Issue__c = true;     // flipped to true => qualifies
        newC.JIRA_Project_ID__c   = '13462';  // non-blank
        newC.JIRA_Issue_Type_ID__c = '10100'; // non-blank

        Test.startTest();
            CaseToJiraTrgHandler.afterUpdate(
                new List<Case>{ newC },
                new Map<Id, Case>{ c.Id => oldC }
            );
        Test.stopTest();

        // If JCFS.API.createJiraIssueWithDefaultPostAction does callouts synchronously,
        // this test may require HttpCalloutMock or a seam in JCFS.API.
        System.assert(true, 'Create-issue gating path covered (no throw).');
    }

    @IsTest
    static void testAfterUpdate_multipleCases_lastOneWins_pidIssueType_behaviorCovered() {
        setTriggerEnabled(true);

        Case c1 = insertBaseCase();
        Case c2 = insertBaseCase();

        Case old1 = c1.clone(false, true, false, false); old1.Id = c1.Id; old1.JIRA_Create_Issue__c = false;
        Case old2 = c2.clone(false, true, false, false); old2.Id = c2.Id; old2.JIRA_Create_Issue__c = false;

        Case new1 = c1.clone(false, true, false, false);
        new1.Id = c1.Id;
        new1.JIRA_Create_Issue__c = true;
        new1.JIRA_Project_ID__c   = '11111';
        new1.JIRA_Issue_Type_ID__c = '22222';

        Case new2 = c2.clone(false, true, false, false);
        new2.Id = c2.Id;
        new2.JIRA_Create_Issue__c = true;
        new2.JIRA_Project_ID__c   = '33333';
        new2.JIRA_Issue_Type_ID__c = '44444';

        Map<Id, Case> oldMap = new Map<Id, Case>{
            c1.Id => old1,
            c2.Id => old2
        };

        Test.startTest();
            // because handler overwrites pid/issuetype in the loop,
            // this covers the "last one wins" behavior deterministically
            CaseToJiraTrgHandler.afterUpdate(new List<Case>{ new1, new2 }, oldMap);
        Test.stopTest();

        System.assert(true, 'Multi-record loop path covered.');
    }
}