@IsTest
public class CaseUpdatedTriggerTest {

    private static final String HOLDING_ACCOUNT_NAME     = 'Holding Account [DO NOT EDIT]';
    private static final String DEFAULT_ENTITLEMENT_NAME = 'default Entitlement';
    private static final String P0_ENTITLEMENT_NAME      = 'P0 Entitlement';

    @TestSetup
    static void setup() {
        Automation_Settings__c setting = Automation_Settings__c.getInstance(UserInfo.getUserId());
        setting.Case_Trigger_Enabled__c = true;
        upsert setting;

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

        Contact con = new Contact(
            LastName  = 'CaseUpdatedTriggerTest Contact',
            Email     = 'caseupdatedtriggertest@test.com',
            AccountId = holding.Id
        );
        insert con;

        Case c = new Case(
            Subject                  = 'Test Case from Test Class',
            Status                   = 'New',
            Origin                   = 'Phone',
            Priority                 = 'Medium',
            AccountId                = holding.Id,
            ContactId                = con.Id,
            Issue_Type__c            = 'Mobile',
            Mobile_Operating_System__c = 'Android',
            JIRA_Create_Issue__c     = false
        );
        insert c;
    }

    private static void setTriggerEnabled(Boolean enabled) {
        Automation_Settings__c setting = Automation_Settings__c.getInstance(UserInfo.getUserId());
        setting.Case_Trigger_Enabled__c = enabled;
        upsert setting;
    }
 @isTest
    static void testJiraIssue() {
        List<Case> cases = [SELECT Id, JIRA_Create_Issue__c, JIRA_Project_ID__c, JIRA_Issue_Type_ID__c FROM Case];
        for (Case c : cases) {
            c.JIRA_Create_Issue__c = true;
        }
        Test.startTest();
        update cases;
        Test.stopTest();
        for (Case c : cases) {
            system.debug(c.JIRA_Create_Issue__c);
            //System.assertEquals(true, c.JIRA_Create_Issue__c, 'JIRA_Create_Issue__c should be set to true.');
        }
    }
    
     @isTest
    static void testNoJiraIssue() {
        List<Case> cases = [SELECT Id, JIRA_Create_Issue__c, JIRA_Project_ID__c, JIRA_Issue_Type_ID__c FROM Case];
        Test.startTest();
        update cases;
        Test.stopTest();
        for (Case c : cases) {
            system.debug(c.JIRA_Create_Issue__c);
           // System.assertEquals(false, c.JIRA_Create_Issue__c, 'JIRA_Create_Issue__c should still be false.');
        }
    }  

}