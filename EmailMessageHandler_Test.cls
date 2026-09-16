/********************************************************************************* 
ClassName : EmailMessageHandler
Test Class : EmailMessageHandler_Test
==================================================================================
Req: Solution to prevent reopening Support cases after 30 days.
Sol : Any Closed Post 30 days will not be Opened and Create a new case by copying
      all the details from Closed Case.
==================================================================================
History
---------------------------------------------------------------------------------
APIVERSION    AUTHOR         DATE          Jira Ticket No
62            Anil Kumar     04-Mar-2026   Teams -6629
*********************************************************************************/
@IsTest
public class EmailMessageHandler_Test {
    
    

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
            LastName  = 'EmailMessageHandler_Test Contact',
            Email     = 'emailmessagehandlertest@test.com',
            AccountId = holding.Id
        );
        insert con;

        insert new EmailMessageTrigger__c(
            Name = 'Activate',
            IsActive__c = true
        );
    }

    private static Account getHoldingAccount() {
      
        return [SELECT Id, Name FROM Account WHERE Name = :HOLDING_ACCOUNT_NAME LIMIT 1];
    }

    private static Contact getHoldingContact(Id accountId) {
        
        return [SELECT Id, AccountId, Email FROM Contact WHERE AccountId = :accountId LIMIT 1];
    }

    private static Case createClosedParentCase(Id accountId, Id contactId, String subjectText) {
      
        Case c = new Case(
            Subject                    = subjectText,
            Status                     = 'Closed',
            Origin                     = 'Phone',
            Priority                   = 'Medium',
            AccountId                  = accountId,
            ContactId                  = contactId,
            Issue_Type__c              = 'Mobile',
            Mobile_Operating_System__c = 'Android',
            JIRA_Create_Issue__c       = false,
            Type                       = 'Problem'
        );
        insert c;
        return [
            SELECT Id, CaseNumber, ContactId, AccountId, Subject, Priority,
                   RecordTypeId, OwnerId, FollowUpCaseCreated__c, Issue_Type__c,
                   Type, TS_Escalation_Case__c, ClosedDate, IsClosed
            FROM Case
            WHERE Id = :c.Id
        ];
    }

    @IsTest
    static void test_beforeInsert_createsFollowupAndReparentsEmail() {
       
        Account holding = getHoldingAccount();
        Contact con = getHoldingContact(holding.Id);
        Case parentC = createClosedParentCase(holding.Id, con.Id, 'Parent Closed Case');

        EmailMessage em = new EmailMessage(
            Incoming    = true,
            ParentId    = parentC.Id,
            Subject     = 'Customer reply',
            FromAddress = 'customer@test.com',
            ToAddress   = 'support@test.com',
            TextBody    = 'Reopening'
        );

        Test.startTest();
        EmailMessageHandler.testDaysSinceClosedOverride = 31;
        EmailMessageHandler.handleClosedCaseEmailsBefore(new List<EmailMessage>{ em });
        insert em;
        Test.stopTest();

        List<Case> children = [
            SELECT Id, ParentId, IsClosed, Status, Subject, Origin, Issue_Type__c
            FROM Case
            WHERE ParentId = :parentC.Id
            ORDER BY CreatedDate DESC
        ];
        System.assertEquals(1, children.size(), 'A follow-up case should have been created');

        Case child = children[0];
        System.assertEquals(false, child.IsClosed);
        System.assertEquals('New', child.Status);
        System.assertEquals(parentC.Id, child.ParentId);
        System.assertEquals('Email', child.Origin);
        System.assertEquals(parentC.Issue_Type__c, child.Issue_Type__c);

        EmailMessage emReload = [SELECT Id, ParentId FROM EmailMessage WHERE Id = :em.Id];
        System.assertEquals(child.Id, emReload.ParentId);

        Case parentReload = [SELECT FollowUpCaseCreated__c FROM Case WHERE Id = :parentC.Id];
        System.assertEquals(true, parentReload.FollowUpCaseCreated__c);
    }

    @IsTest
    static void test_beforeInsert_reusesExistingOpenChild() {
       
        Account holding = getHoldingAccount();
        Contact con = getHoldingContact(holding.Id);
        Case parentC = createClosedParentCase(holding.Id, con.Id, 'Parent Closed Case Reuse');

        Case existingChild = new Case(
            Subject                    = 'Existing Child',
            Status                     = 'New',
            Origin                     = 'Email',
            Priority                   = 'Medium',
            AccountId                  = holding.Id,
            ContactId                  = con.Id,
            ParentId                   = parentC.Id,
            Issue_Type__c              = 'Mobile',
            Mobile_Operating_System__c = 'Android',
            JIRA_Create_Issue__c       = false
        );
        insert existingChild;

        EmailMessage em = new EmailMessage(
            Incoming    = true,
            ParentId    = parentC.Id,
            Subject     = 'Customer reply again',
            FromAddress = 'customer@test.com',
            ToAddress   = 'support@test.com',
            TextBody    = 'Reuse child'
        );

        Test.startTest();
        EmailMessageHandler.testDaysSinceClosedOverride = 31;
        EmailMessageHandler.handleClosedCaseEmailsBefore(new List<EmailMessage>{ em });
        insert em;
        Test.stopTest();

        List<Case> children = [
            SELECT Id, ParentId
            FROM Case
            WHERE ParentId = :parentC.Id
        ];
        System.assertEquals(1, children.size(), 'Should reuse existing open child and not create another');

        EmailMessage emReload = [SELECT Id, ParentId FROM EmailMessage WHERE Id = :em.Id];
        System.assertEquals(existingChild.Id, emReload.ParentId);
    }

    @IsTest
    static void test_afterInsert_copiesFilesFromEmailToFollowupCase() {
       
        Account holding = getHoldingAccount();
        Contact con = getHoldingContact(holding.Id);
        Case parentC = createClosedParentCase(holding.Id, con.Id, 'Parent Closed Case (Files)');

        EmailMessage em = new EmailMessage(
            Incoming    = true,
            ParentId    = parentC.Id,
            Subject     = 'Customer reply with attachment',
            FromAddress = 'customer@test.com',
            ToAddress   = 'support@test.com',
            TextBody    = 'See attached'
        );

        Test.startTest();
        EmailMessageHandler.testDaysSinceClosedOverride = 31;
        EmailMessageHandler.handleClosedCaseEmailsBefore(new List<EmailMessage>{ em });
        insert em;

        List<Case> children = [
            SELECT Id, ParentId
            FROM Case
            WHERE ParentId = :parentC.Id
            ORDER BY CreatedDate DESC
        ];
        System.assertEquals(1, children.size(), 'A follow-up case should have been created');
        Case child = children[0];

        ContentVersion cv = new ContentVersion(
            Title        = 'TestFile',
            PathOnClient = 'TestFile.txt',
            VersionData  = Blob.valueOf('Hello')
        );
        insert cv;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        insert new ContentDocumentLink(
            LinkedEntityId    = em.Id,
            ContentDocumentId = docId,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );

        EmailMessageHandler.copyFilesToParentCaseAfter(
            [SELECT Id, ParentId, Incoming FROM EmailMessage WHERE Id = :em.Id]
        );
        Test.stopTest();

        Integer cnt = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :child.Id
              AND ContentDocumentId = :docId
        ];
        System.assertEquals(1, cnt, 'File should be linked to the follow-up case');
    }

    @IsTest
    static void test_afterInsert_doesNotDuplicateFileLinks() {
       
        Account holding = getHoldingAccount();
        Contact con = getHoldingContact(holding.Id);
        Case parentC = createClosedParentCase(holding.Id, con.Id, 'Parent Closed Case Duplicate File');

        EmailMessage em = new EmailMessage(
            Incoming    = true,
            ParentId    = parentC.Id,
            Subject     = 'Customer reply duplicate file',
            FromAddress = 'customer@test.com',
            ToAddress   = 'support@test.com',
            TextBody    = 'Attachment'
        );

        Test.startTest();
        EmailMessageHandler.testDaysSinceClosedOverride = 31;
        EmailMessageHandler.handleClosedCaseEmailsBefore(new List<EmailMessage>{ em });
        insert em;

        Case child = [
            SELECT Id
            FROM Case
            WHERE ParentId = :parentC.Id
            LIMIT 1
        ];

        ContentVersion cv = new ContentVersion(
            Title        = 'TestFile2',
            PathOnClient = 'TestFile2.txt',
            VersionData  = Blob.valueOf('Hello Again')
        );
        insert cv;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        insert new ContentDocumentLink(
            LinkedEntityId    = em.Id,
            ContentDocumentId = docId,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );

        insert new ContentDocumentLink(
            LinkedEntityId    = child.Id,
            ContentDocumentId = docId,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );

        EmailMessageHandler.copyFilesToParentCaseAfter(
            [SELECT Id, ParentId, Incoming FROM EmailMessage WHERE Id = :em.Id]
        );
        Test.stopTest();

        Integer cnt = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :child.Id
              AND ContentDocumentId = :docId
        ];
        System.assertEquals(1, cnt, 'Duplicate file link should not be created');
    }

    @IsTest
    static void test_beforeInsert_skipsNonEligibleCases() {
       
        Account holding = getHoldingAccount();
        Contact con = getHoldingContact(holding.Id);

        Case parentC = new Case(
            Subject                    = 'Escalation Case',
            Status                     = 'Closed',
            Origin                     = 'Phone',
            Priority                   = 'Medium',
            AccountId                  = holding.Id,
            ContactId                  = con.Id,
            Issue_Type__c              = 'Mobile',
            Mobile_Operating_System__c = 'Android',
            JIRA_Create_Issue__c       = false,
            Type                       = 'Escalation'
        );
        insert parentC;

        EmailMessage em = new EmailMessage(
            Incoming    = true,
            ParentId    = parentC.Id,
            Subject     = 'Customer reply',
            FromAddress = 'customer@test.com',
            ToAddress   = 'support@test.com',
            TextBody    = 'Do not reopen'
        );

        Test.startTest();
        EmailMessageHandler.testDaysSinceClosedOverride = 31;
        EmailMessageHandler.handleClosedCaseEmailsBefore(new List<EmailMessage>{ em });
        insert em;
        Test.stopTest();

        Integer childCount = [
            SELECT COUNT()
            FROM Case
            WHERE ParentId = :parentC.Id
        ];
        System.assertEquals(0, childCount);

        EmailMessage emReload = [SELECT Id, ParentId FROM EmailMessage WHERE Id = :em.Id];
        System.assertEquals(parentC.Id, emReload.ParentId);
    }
}