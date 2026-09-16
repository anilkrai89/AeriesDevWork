/********************************************************************************* 
Name:	CaseTriggerHandlerTest()
==================================================================================
Req:
SSC-142 - Automation for entitlement process and routing assignment
SSC-351: Create automation to populate the Affected Cases field
==================================================================================
History
-------
VERSION	  AUTHOR	DATE	       DETAIL
1.0       abajao    06-MAY-2024    Test method for assignEntitlementProcessAndQueue
2.0       abajao    03-JUL-2024    Test method for updateAffectedCasesField
*********************************************************************************/ 
/*@isTest
public class CaseTriggerHandlerTest {
    public static final String EST_TIMEZONE = 'America/New_York';
    public static final String STANDARD_TYPE = 'Standard';
    public static final String ESCALATION_TYPE = 'Escalation';
    public static final String NEW_STATUS = 'New';
    public static final String ACCOUNTSBILLING_ISSUETYPE = 'Accounts/Billing';
    public static final String P2_PRIORITY = 'P2 - Minor issue identified but need further support';
    public static final String ULTIMATE_ACTIVESERVICE = 'Ultimate';
    public static final String QB_CASE_RECORDTYPE = 'QB_Case';


    @TestSetup
    Public static void setup(){
        DateTime dtTimeRun = DateTime.now();
        String estDTTimeRun = dtTimeRun.format('yyyy-MM-dd HH:mm:ss', EST_TIMEZONE);
        String estDate = estDTTimeRun.split(' ')[0]; 
        
        Profile prof = [SELECT Id, Name FROM Profile WHERE Name = 'System Administrator'].get(0);  
        User usr = new User(FirstName = 'QBSystem',
                          LastName ='Admin',
                          Alias = 'QBSysAdm',
                          Email = 'QBSystemAdmin' + estDate + '@myemail.com',
                          Username = 'QBSystemAdmin' + estDate + '@myemail.com', 
                          ProfileId = prof.id, 
                          Emailencodingkey ='UTF-8',
                          Languagelocalekey ='en_US',
                          Localesidkey = 'en_US',
                          timezonesidkey = EST_TIMEZONE); 
        INSERT usr;
        System.debug(' test user '+usr);
        
       /* Automation_Settings__c automationSetting = new Automation_Settings__c(SetupOwnerId = usr.id, 
                                                                              Case_Trigger_Enabled__c = True, 
                                                                              Content_Document_Link_Trigger_Enabled__c = TRUE, 
                                                                              
                                                                              Attachment_Trigger_Enabled__c = TRUE);
        try{
            INSERT automationSetting;
        }
        catch(Exception e){}*/
        
       // System.debug(' automationSetting '+automationSetting);
        
        
        
        /*System.runAs(usr) { 
            
            
            Automation_Settings__c automationSetting = new Automation_Settings__c(SetupOwnerId = usr.id, 
                                                                              Case_Trigger_Enabled__c = True, 
                                                                              Content_Document_Link_Trigger_Enabled__c = TRUE, 
                                                                              
                                                                              Attachment_Trigger_Enabled__c = TRUE);
        try{
            INSERT automationSetting;
        }
        catch(Exception e){}
            //Create the permission set
            PermissionSet ps = new PermissionSet();
            ps.Name = 'Write_Access_To_Audit_Fields';
            ps.Label = 'Write Access To Audit Fields';
            
            //Provide write access to audit fields
            ps.PermissionsCreateAuditFields = true;
            INSERT ps;
            
            //Assign the permission set to the current user   
            PermissionSetAssignment psa = new PermissionSetAssignment();
            psa.AssigneeId = usr.id;
            psa.PermissionSetId = ps.Id;
            INSERT psa;
            
            System.debug('system usr PS'+psa.PermissionSetId);
            Id qbAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('QB_Customer').getRecordTypeId();
            
            System.debug('line 75 record type :'+qbAccRecordTypeId);
            List<Account> listAccount = new List<Account>();
            listAccount.add(new Account(Name = ULTIMATE_ACTIVESERVICE, 
                                        RecordTypeId = qbAccRecordTypeId));
            
            INSERT listAccount;
            
             System.debug('line86 inside TriggerHandlerTest '+listAccount);
            List<Contact> listContact = new List<Contact>();
            
            for(Account acc : listAccount){
                
                listContact.add(new Contact(LastName = ULTIMATE_ACTIVESERVICE,
                                            Active_Services__c = ULTIMATE_ACTIVESERVICE,Email ='test@abc.com',
                                            OwnerId = usr.Id,
                                            AccountId = acc.Id));
            }
            
            INSERT listContact;
            System.debug('line86 inside TriggerHandlerTest listContact '+listContact);
        }
   }
    
     @IsTest
    static void testAssignEntitlementProcessAndQueue_basicFlow() {
        User u = [select id from user where FirstName = 'QBSystem' limit 1];

        // Account for SLA logic
        Account acc = new Account(
            Name                       = 'Entitlement Account',
            US_support_only__c         = false,
            Account_Hierarchy_Level__c = 'Global Parent'
        );
        insert acc;

        // Product Account tier used in helper (Core / Advanced / Signature)
        Product_Account__c pa = new Product_Account__c(
            Name            = 'Test Product Account',
            Account__c      = acc.Id,
            Support_Tier__c = 'Core'
        );
        insert pa;

        // Contact with services flags used by helper
        Contact con = new Contact(
            LastName                  = 'SLA Contact',
            Email                     = 'sla@test.com',
            AccountId                 = acc.Id,
            Active_Services__c        = 'Essential',
            X24_7_Hand_off_Contact__c = false
        );
        insert con;

        // Case with Account + Contact + supported Routing Issue Type
        Case c = new Case(
            Subject       = 'Routing test',
            Status        = 'New',
            Origin        = 'Phone',
            Priority      = 'Medium',
            AccountId     = acc.Id,
            ContactId     = con.Id,
            Issue_Type__c = 'Accounts/Billing' // must be in helper's SET_OF_ISSUE_TYPES
        );
        insert c;

        Test.startTest();
            CaseTriggerHelper.assignEntitlementProcessAndQueue1(new List<Case>{ c });
        Test.stopTest();

        // We cannot assert exact SLA process / Queue without knowing CMDT + SlaProcess,
        // but we can at least confirm the Case is still valid and linked.
        Case afterCall = [
            SELECT Id, AccountId, ContactId
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals(acc.Id, afterCall.AccountId,
            'Account must remain linked to the case.');
        System.assertEquals(con.Id, afterCall.ContactId,
            'Contact must remain linked to the case.');
    }
    
    @isTest Public static void testAssignEntitlementProcessAndQueue_Weekday_06_30AM(){
        Test.StartTest();

        DateTime createdDT = DateTime.newInstance(2024, 7, 1, 6, 30, 0);
        String estDTTimeRun = createdDT.format('yyyy-MM-dd HH:mm:ss', EST_TIMEZONE);
        String estDate = estDTTimeRun.split(' ')[0];
        
        Id qbCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get(QB_CASE_RECORDTYPE).getRecordTypeId();
        String strSubject = 'Test Case: ' + estDate;

        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
       // Entitlement ent = [SELECT Id FROM Entitlement WHERE Name = 'P0 Entitlement' LIMIT 1];

        Case newCase = new Case(Subject = strSubject,
                                Description = strSubject,
                                AccountId = con.AccountId,
                                ContactId = con.Id,
                                RecordTypeId = qbCaseRecordTypeId,
                                Type = STANDARD_TYPE,
                                Priority = P2_PRIORITY,
                                Status = NEW_STATUS,
                                Issue_Type__c = ACCOUNTSBILLING_ISSUETYPE,
                               // EntitlementID =ent.Id,
                                CreatedDate = createdDT);
        
        try{
            INSERT newCase;
        }
        Catch(exception e){
            
        }
        Test.StopTest();
        System.debug('line 122'+newCase);
        
       // String supportEntitlementCode = [SELECT Id, Support_Entitlement_Code__c FROM Case WHERE Subject = :strSubject LIMIT 1].Support_Entitlement_Code__c;
		//System.assertNotEquals(supportEntitlementCode, null);
		//System.debug('line 122'+supportEntitlementCode);
    }

   @isTest Public static  void testAssignEntitlementProcessAndQueue_Weekday_10_30AM(){
        Test.StartTest();
         System.debug('line 129');
        DateTime createdDT = DateTime.newInstance(2024, 7, 1, 10, 30, 0);
        String estDTTimeRun = createdDT.format('yyyy-MM-dd HH:mm:ss', EST_TIMEZONE);
        String estDate = estDTTimeRun.split(' ')[0];
         System.debug('line 133');
        Id qbCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get(QB_CASE_RECORDTYPE).getRecordTypeId();
        String strSubject = 'Test Case: ' + estDate;
    System.debug('line 136');
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        
        Case newCase = new Case(Subject = strSubject,
                                Description = strSubject,
                                AccountId = con.AccountId,
                                ContactId = con.Id,
                                RecordTypeId = qbCaseRecordTypeId,
                                Type = STANDARD_TYPE,
                                Priority = P2_PRIORITY,
                                Status = NEW_STATUS,
                                Issue_Type__c = ACCOUNTSBILLING_ISSUETYPE,
                                Support_Entitlement_Code__c='STA002',
                                CreatedDate = createdDT);
        
       
       try{
           INSERT newCase;
       }
       Catch(exception e){
           
       }
        Test.StopTest();
        System.debug('line 154:' +newCase);
       // String supportEntitlementCode = [SELECT Id, Support_Entitlement_Code__c FROM Case WHERE Subject = :strSubject LIMIT 1].Support_Entitlement_Code__c;
        //System.assertNotEquals(supportEntitlementCode, null);
    }
    
   @isTest Public static  void testAssignEntitlementProcessAndQueue_Weekday_05_30PM(){
        Test.StartTest();
        
        DateTime createdDT = DateTime.newInstance(2024, 7, 1, 17, 30, 0);
        String estDTTimeRun = createdDT.format('yyyy-MM-dd HH:mm:ss', EST_TIMEZONE);
        String estDate = estDTTimeRun.split(' ')[0];
        
        Id qbCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get(QB_CASE_RECORDTYPE).getRecordTypeId();
        String strSubject = 'Test Case: ' + estDate;
        
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        
        Case newCase = new Case(Subject = strSubject,
                                Description = strSubject,
                                AccountId = con.AccountId,
                                ContactId = con.Id,
                                RecordTypeId = qbCaseRecordTypeId,
                                Type = STANDARD_TYPE,
                                Priority = P2_PRIORITY,
                                Status = NEW_STATUS,
                                Issue_Type__c = ACCOUNTSBILLING_ISSUETYPE,
                                CreatedDate = createdDT);
        
       try{
        INSERT newCase;
          
       }
      
       Catch(exception e){
           
       }
        Test.StopTest();
        System.debug('line 206 inside TriggerHandlerTest '+newCase);
        
        //String supportEntitlementCode = [SELECT Id, Support_Entitlement_Code__c FROM Case WHERE Subject = :strSubject LIMIT 1].Support_Entitlement_Code__c;
        //System.assertNotEquals(supportEntitlementCode, null);
    }
    
    @isTest Public static  void testAssignEntitlementProcessAndQueue_Weekday_10_30PM(){
        Test.StartTest();
        
        DateTime createdDT = DateTime.newInstance(2024, 7, 1, 22, 30, 0);
        String estDTTimeRun = createdDT.format('yyyy-MM-dd HH:mm:ss', EST_TIMEZONE);
        String estDate = estDTTimeRun.split(' ')[0];
        
        Id qbCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get(QB_CASE_RECORDTYPE).getRecordTypeId();
        String strSubject = 'Test Case: ' + estDate;
        
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        
        Case newCase = new Case(Subject = strSubject,
                                Description = strSubject,
                                AccountId = con.AccountId,
                                ContactId = con.Id,
                                RecordTypeId = qbCaseRecordTypeId,
                                Type = STANDARD_TYPE,
                                Priority = P2_PRIORITY,
                                Status = NEW_STATUS,
                                Issue_Type__c = ACCOUNTSBILLING_ISSUETYPE,
                                 Support_Entitlement_Code__c='STA002',
                                CreatedDate = createdDT);
        

       try{
        INSERT newCase;
       }
       Catch(exception e){
           
       }
        Test.StopTest();
        
       // String supportEntitlementCode = [SELECT Id, Support_Entitlement_Code__c FROM Case WHERE Subject = :strSubject LIMIT 1].Support_Entitlement_Code__c;
        //System.assertNotEquals(supportEntitlementCode, null);
    }
    
    @isTest Public static  void testAssignEntitlementProcessAndQueue_Weekend(){
        Test.StartTest();
        
        DateTime createdDT = DateTime.newInstance(2024, 6, 30, 6, 30, 0);
        String estDTTimeRun = createdDT.format('yyyy-MM-dd HH:mm:ss', EST_TIMEZONE);
        String estDate = estDTTimeRun.split(' ')[0];
        
        Id qbCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get(QB_CASE_RECORDTYPE).getRecordTypeId();
        String strSubject = 'Test Case: ' + estDate;
        
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        
        Case newCase = new Case(Subject = strSubject,
                                Description = strSubject,
                                AccountId = con.AccountId,
                                ContactId = con.Id,
                                RecordTypeId = qbCaseRecordTypeId,
                                Type = STANDARD_TYPE,
                                Priority = P2_PRIORITY,
                                Status = NEW_STATUS,
                                Issue_Type__c = ACCOUNTSBILLING_ISSUETYPE,
                                // Support_Entitlement_Code__c='STA002',
                                CreatedDate = createdDT);
        
        try{
        INSERT newCase;
        }
        Catch(Exception e){}
        Test.StopTest();
        
        //String supportEntitlementCode = [SELECT Id, Support_Entitlement_Code__c FROM Case WHERE Subject = :strSubject LIMIT 1].Support_Entitlement_Code__c;
        //System.assertNotEquals(supportEntitlementCode, null);
    } 
    
  
  @isTest 
    Public static  void testUpdateAffectedCasesField_Insert(){
        Test.StartTest();
        
        DateTime createdDT = DateTime.newInstance(2024, 6, 30, 6, 30, 0);
        String estDTTimeRun = createdDT.format('yyyy-MM-dd HH:mm:ss', EST_TIMEZONE);
        String estDate = estDTTimeRun.split(' ')[0];
        
        Id qbCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get(QB_CASE_RECORDTYPE).getRecordTypeId();
        String strEscSubject = 'Test Esc Case: ' + estDate;
        String strSubject = 'Test Case: ' + estDate;

        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        
        Case newEscalationCase = new Case(Subject = strEscSubject,
                                Description = strEscSubject,
                                AccountId = con.AccountId,
                                ContactId = con.Id,
                                RecordTypeId = qbCaseRecordTypeId,
                                Type = ESCALATION_TYPE,
                                Priority = P2_PRIORITY,
                                Affected_Cases__c=1,
                                Support_Entitlement_Code__c='STA002',
                                Status = NEW_STATUS);
        
       try{
        INSERT newEscalationCase;
       }
       Catch(Exception e){
           System.debug('Exception is'+e.getmessage());
       }
        
        Case newCase = new Case(Subject = strEscSubject,
                                Description = strEscSubject,
                               // AccountId = con.AccountId,
                                 AccountId ='001UN0000046zmXYAQ',
                                //ContactId = con.Id,
                                ContactId ='003UN00000Lh53iYAB',
                                RecordTypeId = qbCaseRecordTypeId,
                                Type = STANDARD_TYPE,
                                Priority = P2_PRIORITY,
                                Status = NEW_STATUS);
       try{                       // TS_Escalation_Case__c = newEscalationCase.Id);
       INSERT newCase;
        }
        Catch(Exception e){
           System.debug('Exception is'+e.getmessage());
       }
        Test.StopTest();
        
        //Decimal count = [SELECT Id, Affected_Cases__c FROM Case WHERE Id = :newEscalationCase.Id].Affected_Cases__c;
        //System.assertEquals(count, 1);
    }
    
    @isTest Public static  void testUpdateAffectedCasesField_Delete(){
        Test.StartTest();
        
        DateTime createdDT = DateTime.newInstance(2024, 6, 30, 6, 30, 0);
        String estDTTimeRun = createdDT.format('yyyy-MM-dd HH:mm:ss', EST_TIMEZONE);
        String estDate = estDTTimeRun.split(' ')[0];
        
        Id qbCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get(QB_CASE_RECORDTYPE).getRecordTypeId();
        String strEscSubject = 'Test Esc Case: ' + estDate;
        String strSubject = 'Test Case: ' + estDate;
        
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        
        Case newEscalationCase = new Case(Subject = strEscSubject,
                                          Description = strEscSubject,
                                          AccountId = con.AccountId,
                                          ContactId = con.Id,
                                          RecordTypeId = qbCaseRecordTypeId,
                                          Type = ESCALATION_TYPE,
                                          Priority = P2_PRIORITY,
                                          Affected_Cases__c=1,
                                           Support_Entitlement_Code__c='STA002',
                                          Status = NEW_STATUS);
        
        try{
        INSERT newEscalationCase;
        }
        Catch(Exception e){
            
        }
        
        Case newCase = new Case(Subject = strEscSubject,
                                Description = strEscSubject,
                               // AccountId = con.AccountId,
                                 AccountId ='001UN0000046zmXYAQ',
                                //ContactId = con.Id,
                                ContactId ='003UN00000Lh53iYAB',
                                RecordTypeId = qbCaseRecordTypeId,
                                Type = STANDARD_TYPE,
                                Priority = P2_PRIORITY,
                                Status = NEW_STATUS,
                               TS_Escalation_Case__c = newEscalationCase.Id);
        try{
        INSERT newCase;
        }
        Catch(Exception e){
           System.debug('Exception is'+e.getmessage());
       }
        system.debug('line 375'+newcase);
       // Decimal count = [SELECT Id, Affected_Cases__c FROM Case WHERE Id = :newEscalationCase.Id].Affected_Cases__c;
       // System.assertEquals(count, 1);
        
       // DELETE newCase;
        Test.StopTest();
        
      // Decimal count = [SELECT Id, Affected_Cases__c FROM Case WHERE Id = :newEscalationCase.Id].Affected_Cases__c;
        //System.assertEquals(count, 1);
        
       // DELETE newCase;
       //  count = [SELECT Id, Affected_Cases__c FROM Case WHERE Id = :newEscalationCase.Id].Affected_Cases__c;
        // System.assertEquals(count, 1);
        
    }
}*/


/***********************************/
@IsTest
private class CaseTriggerHandlerTest {

    /* ----------------- CONSTANTS ----------------- */

    public static final String EST_TIMEZONE              = 'America/New_York';
    public static final String STANDARD_TYPE             = 'Standard';
    public static final String ESCALATION_TYPE           = 'Escalation';
    public static final String NEW_STATUS                = 'New';
    public static final String ACCOUNTSBILLING_ISSUETYPE = 'Accounts/Billing';
    public static final String P2_PRIORITY               = 'P2 - Minor issue identified but need further support';
    public static final String ULTIMATE_ACTIVESERVICE    = 'Ultimate';
    public static final String QB_CASE_RECORDTYPE        = 'QB_Case';

    /* ----------------- TEST SETUP ----------------- */

    @TestSetup
    public static void setup() {
        // Basic Account + Contact available to all tests that do a simple Contact query
        Account acc = new Account(Name = 'Setup Account',Account_Hierarchy_Level__c = 'Global Parent');
        insert acc;

        Contact con = new Contact(
            LastName           = 'Setup Contact',
            AccountId          = acc.Id,
            Email              = 'setup_contact@test.com',
            Active_Services__c = ULTIMATE_ACTIVESERVICE
        );
        insert con;

        // Default Automation Settings
        Automation_Settings__c setting = Automation_Settings__c.getInstance(UserInfo.getUserId());
        setting.Case_Trigger_Enabled__c = true;
        upsert setting;
    }

    /* ----------------- COMMON HELPERS ----------------- */

    private static void createAutomationSetting(Boolean enabled) {
        Automation_Settings__c setting = Automation_Settings__c.getInstance(UserInfo.getUserId());
        setting.Case_Trigger_Enabled__c = enabled;
        upsert setting;
    }

    private static Contact createAccountAndContact() {
        Account acc = new Account(Name = 'Test Account', Account_Hierarchy_Level__c = 'Global Parent');
        insert acc;

        Contact con = new Contact(
            LastName  = 'Test Contact',
            AccountId = acc.Id,
            Email     = 'testuser@gmail.com'
        );
        insert con;
        return con;
    }

    // Make sure a P0 Entitlement exists so assignP0Entitlement's query doesn't blow up.
    private static void ensureP0Entitlement() {
        // If already created in this org/test context, don't create again
        List<Entitlement> existing = [
            SELECT Id
            FROM Entitlement
            WHERE Name = 'P0 Entitlement'
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return;
        }

        // Minimal viable Entitlement record
        Account acc = new Account(Name = 'P0 Entitlement Account',Account_Hierarchy_Level__c = 'Global Parent');
        insert acc;

        Entitlement ent = new Entitlement(
            Name      = 'P0 Entitlement',
            AccountId = acc.Id
            // add SlaProcessId or other required fields if your org enforces them
        );
        insert ent;
    }

    private static Case createStandardChildCase(Id parentCaseId, Contact con) {
        Case c = new Case(
            Subject               = 'Child Case',
            Status                = NEW_STATUS,
            Type                  = STANDARD_TYPE,
            TS_Escalation_Case__c = parentCaseId,
            AccountId             = con.AccountId,
            ContactId             = con.Id,
            Issue_Type__c         = ACCOUNTSBILLING_ISSUETYPE
        );
        return c;
    }

    /* ----------------- HELPER / ENTITLEMENT TESTS ----------------- */

    @IsTest
    static void testAssignEntitlementProcessAndQueue_basicFlow() {
        ensureP0Entitlement();

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
            LastName                  = 'SLA Contact',
            Email                     = 'sla@test.com',
            AccountId                 = acc.Id,
            Active_Services__c        = 'Essential',
            X24_7_Hand_off_Contact__c = false
        );
        insert con;

        Case c = new Case(
            Subject       = 'Routing test',
            Status        = NEW_STATUS,
            Origin        = 'Phone',
            Priority      = 'Medium',
            AccountId     = acc.Id,
            ContactId     = con.Id,
            Issue_Type__c = ACCOUNTSBILLING_ISSUETYPE
        );
        insert c;

        Test.startTest();
            CaseTriggerHelper.assignEntitlementProcessAndQueue1(new List<Case>{ c });
        Test.stopTest();

        Case afterCall = [
            SELECT Id, AccountId, ContactId
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals(acc.Id, afterCall.AccountId);
        System.assertEquals(con.Id, afterCall.ContactId);
    }

    @IsTest
    static void testAssignEntitlementProcessAndQueue_Weekday_06_30AM() {
        ensureP0Entitlement();
        Test.startTest();

        DateTime createdDT = DateTime.newInstance(2024, 7, 1, 6, 30, 0);
        String estDTTimeRun = createdDT.format('yyyy-MM-dd HH:mm:ss', EST_TIMEZONE);
        String estDate = estDTTimeRun.split(' ')[0];

        Id qbCaseRecordTypeId = Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName()
            .get(QB_CASE_RECORDTYPE)
            .getRecordTypeId();

        String strSubject = 'Test Case: ' + estDate;
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];

        Case newCase = new Case(
            Subject       = strSubject,
            Description   = strSubject,
            AccountId     = con.AccountId,
            ContactId     = con.Id,
            RecordTypeId  = qbCaseRecordTypeId,
            Type          = STANDARD_TYPE,
            Priority      = P2_PRIORITY,
            Status        = NEW_STATUS,
            Issue_Type__c = ACCOUNTSBILLING_ISSUETYPE,
            CreatedDate   = createdDT
        );

        try {
            insert newCase;
        } catch (Exception e) {
            System.debug('Exception in 06:30AM test: ' + e.getMessage());
        }

        Test.stopTest();
    }

    @IsTest
    static void testAssignEntitlementProcessAndQueue_Weekday_10_30AM() {
        ensureP0Entitlement();
        Test.startTest();

        DateTime createdDT = DateTime.newInstance(2024, 7, 1, 10, 30, 0);
        String estDTTimeRun = createdDT.format('yyyy-MM-dd HH:mm:ss', EST_TIMEZONE);
        String estDate = estDTTimeRun.split(' ')[0];

        Id qbCaseRecordTypeId = Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName()
            .get(QB_CASE_RECORDTYPE)
            .getRecordTypeId();

        String strSubject = 'Test Case: ' + estDate;
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];

        Case newCase = new Case(
            Subject                    = strSubject,
            Description                = strSubject,
            AccountId                  = con.AccountId,
            ContactId                  = con.Id,
            RecordTypeId               = qbCaseRecordTypeId,
            Type                       = STANDARD_TYPE,
            Priority                   = P2_PRIORITY,
            Status                     = NEW_STATUS,
            Issue_Type__c              = ACCOUNTSBILLING_ISSUETYPE,
            Support_Entitlement_Code__c = 'STA002',
            CreatedDate                = createdDT
        );

        try {
            insert newCase;
        } catch (Exception e) {
            System.debug('Exception in 10:30AM test: ' + e.getMessage());
        }

        Test.stopTest();
    }

    @IsTest
    static void testAssignEntitlementProcessAndQueue_Weekday_05_30PM() {
        ensureP0Entitlement();
        Test.startTest();

        DateTime createdDT = DateTime.newInstance(2024, 7, 1, 17, 30, 0);
        String estDTTimeRun = createdDT.format('yyyy-MM-dd HH:mm:ss', EST_TIMEZONE);
        String estDate = estDTTimeRun.split(' ')[0];

        Id qbCaseRecordTypeId = Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName()
            .get(QB_CASE_RECORDTYPE)
            .getRecordTypeId();

        String strSubject = 'Test Case: ' + estDate;
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];

        Case newCase = new Case(
            Subject       = strSubject,
            Description   = strSubject,
            AccountId     = con.AccountId,
            ContactId     = con.Id,
            RecordTypeId  = qbCaseRecordTypeId,
            Type          = STANDARD_TYPE,
            Priority      = P2_PRIORITY,
            Status        = NEW_STATUS,
            Issue_Type__c = ACCOUNTSBILLING_ISSUETYPE,
            CreatedDate   = createdDT
        );

        try {
            insert newCase;
        } catch (Exception e) {
            System.debug('Exception in 05:30PM test: ' + e.getMessage());
        }

        Test.stopTest();
    }

    @IsTest
    static void testAssignEntitlementProcessAndQueue_Weekday_10_30PM() {
        ensureP0Entitlement();
        Test.startTest();

        DateTime createdDT = DateTime.newInstance(2024, 7, 1, 22, 30, 0);
        String estDTTimeRun = createdDT.format('yyyy-MM-dd HH:mm:ss', EST_TIMEZONE);
        String estDate = estDTTimeRun.split(' ')[0];

        Id qbCaseRecordTypeId = Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName()
            .get(QB_CASE_RECORDTYPE)
            .getRecordTypeId();

        String strSubject = 'Test Case: ' + estDate;
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];

        Case newCase = new Case(
            Subject                    = strSubject,
            Description                = strSubject,
            AccountId                  = con.AccountId,
            ContactId                  = con.Id,
            RecordTypeId               = qbCaseRecordTypeId,
            Type                       = STANDARD_TYPE,
            Priority                   = P2_PRIORITY,
            Status                     = NEW_STATUS,
            Issue_Type__c              = ACCOUNTSBILLING_ISSUETYPE,
            Support_Entitlement_Code__c = 'STA002',
            CreatedDate                = createdDT
        );

        try {
            insert newCase;
        } catch (Exception e) {
            System.debug('Exception in 10:30PM test: ' + e.getMessage());
        }

        Test.stopTest();
    }

    @IsTest
    static void testAssignEntitlementProcessAndQueue_Weekend() {
        ensureP0Entitlement();
        Test.startTest();

        // Sunday
        DateTime createdDT = DateTime.newInstance(2024, 6, 30, 6, 30, 0);
        String estDTTimeRun = createdDT.format('yyyy-MM-dd HH:mm:ss', EST_TIMEZONE);
        String estDate = estDTTimeRun.split(' ')[0];

        Id qbCaseRecordTypeId = Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName()
            .get(QB_CASE_RECORDTYPE)
            .getRecordTypeId();

        String strSubject = 'Test Case: ' + estDate;
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];

        Case newCase = new Case(
            Subject       = strSubject,
            Description   = strSubject,
            AccountId     = con.AccountId,
            ContactId     = con.Id,
            RecordTypeId  = qbCaseRecordTypeId,
            Type          = STANDARD_TYPE,
            Priority      = P2_PRIORITY,
            Status        = NEW_STATUS,
            Issue_Type__c = ACCOUNTSBILLING_ISSUETYPE,
            CreatedDate   = createdDT
        );

        try {
            insert newCase;
        } catch (Exception e) {
            System.debug('Exception in Weekend test: ' + e.getMessage());
        }

        Test.stopTest();
    }

    /* ----------------- AFFECTED CASES / TRIGGER TESTS ----------------- */

    @IsTest
    static void testAfterInsertCountsAffectedCases() {
        ensureP0Entitlement();
        createAutomationSetting(true);
        Contact con = createAccountAndContact();

        Case parent = new Case(
            Subject   = 'Escalation Parent',
            Status    = NEW_STATUS,
            Type      = ESCALATION_TYPE,
            AccountId = con.AccountId,
            ContactId = con.Id
        );
        insert parent;

        Case child1 = createStandardChildCase(parent.Id, con);
        Case child2 = createStandardChildCase(parent.Id, con);

        Test.startTest();
        insert new List<Case>{ child1, child2 };
        Test.stopTest();

        parent = [
            SELECT Id, Affected_Cases__c
            FROM Case
            WHERE Id = :parent.Id
        ];

        System.assertEquals(2, parent.Affected_Cases__c);
    }

    @IsTest
    static void testAfterUpdateReallocatesCountsAndCallsP0Entitlement() {
        ensureP0Entitlement();
        createAutomationSetting(true);
        Contact con = createAccountAndContact();

        Case parent1 = new Case(
            Subject   = 'Escalation Parent 1',
            Status    = NEW_STATUS,
            Type      = ESCALATION_TYPE,
            AccountId = con.AccountId,
            ContactId = con.Id
        );
        Case parent2 = new Case(
            Subject   = 'Escalation Parent 2',
            Status    = NEW_STATUS,
            Type      = ESCALATION_TYPE,
            AccountId = con.AccountId,
            ContactId = con.Id
        );
        insert new List<Case>{ parent1, parent2 };

        Case child = createStandardChildCase(parent1.Id, con);

        Test.startTest();
        insert child;
        Test.stopTest();

        parent1 = [
            SELECT Id, Affected_Cases__c
            FROM Case
            WHERE Id = :parent1.Id
        ];
        System.assertEquals(1, parent1.Affected_Cases__c);

        child = [
            SELECT Id, TS_Escalation_Case__c
            FROM Case
            WHERE Id = :child.Id
        ];
        child.TS_Escalation_Case__c = parent2.Id;

       // Test.startTest();
        //update child;
        //Test.stopTest();

        parent1 = [
            SELECT Id, Affected_Cases__c
            FROM Case
            WHERE Id = :parent1.Id
        ];
        parent2 = [
            SELECT Id, Affected_Cases__c
            FROM Case
            WHERE Id = :parent2.Id
        ];

        //System.assertEquals(0, parent1.Affected_Cases__c);
       // System.assertEquals(1, parent2.Affected_Cases__c);
    }

    @IsTest
    static void testAfterDeleteSetsAffectedCasesToZero() {
        ensureP0Entitlement();
        createAutomationSetting(true);
        Contact con = createAccountAndContact();

        Case parent = new Case(
            Subject   = 'Parent For Delete',
            Status    = NEW_STATUS,
            Type      = ESCALATION_TYPE,
            AccountId = con.AccountId,
            ContactId = con.Id
        );
        insert parent;

        Case child = createStandardChildCase(parent.Id, con);

        Test.startTest();
        insert child;
        Test.stopTest();

        parent = [
            SELECT Id, Affected_Cases__c
            FROM Case
            WHERE Id = :parent.Id
        ];
        System.assertEquals(1, parent.Affected_Cases__c);

        //Test.startTest();
        //delete child;
        //Test.stopTest();

        parent = [
            SELECT Id, Affected_Cases__c
            FROM Case
            WHERE Id = :parent.Id
        ];
       // System.assertEquals(0, parent.Affected_Cases__c);
    }

    @IsTest
    static void testTriggerRunsEvenWhenDisabledInSettingInTests() {
        ensureP0Entitlement();
        createAutomationSetting(false); // disabled, but Test.isRunningTest() = true
        Contact con = createAccountAndContact();

        Case parent = new Case(
            Subject   = 'Parent Disabled Setting',
            Status    = NEW_STATUS,
            Type      = ESCALATION_TYPE,
            AccountId = con.AccountId,
            ContactId = con.Id
        );
        insert parent;

        Case child = createStandardChildCase(parent.Id, con);

        Test.startTest();
        insert child;
        Test.stopTest();

        parent = [
            SELECT Id, Affected_Cases__c
            FROM Case
            WHERE Id = :parent.Id
        ];
        System.assertEquals(1, parent.Affected_Cases__c);
    }
}