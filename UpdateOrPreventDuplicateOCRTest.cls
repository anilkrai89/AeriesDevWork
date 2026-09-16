@isTest
public class UpdateOrPreventDuplicateOCRTest {
    @TestSetup
    static void makeData() {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User();
        u.Alias = 'tuser';
        u.Email = 'test@quickbase.com.test';
        u.EmailEncodingKey = 'UTF-8';
        u.FirstName = 'Test';
        u.LastName = 'TestUserUser';
        u.LanguageLocaleKey = 'en_US';
        u.LocaleSidKey = 'en_US';
        u.ProfileId = profile.Id;
        u.TimeZoneSidKey = 'America/Los_Angeles';
        u.Username = 'test@quickbase.com.test';
        insert u;
    }
    // Utility method to create a test opportunity
    private static Opportunity createTestOpportunity(String recordTypeName) {
        RecordType rt = [SELECT Id FROM RecordType WHERE Name = :recordTypeName AND SobjectType = 'Opportunity' LIMIT 1];
        Opportunity opp = new Opportunity(Name='Test Opportunity ' + recordTypeName, StageName='01 - Discovery & Demonstration', CloseDate=Date.today().addDays(30), RecordTypeId=rt.Id);
        insert opp;
        return opp;
    }

    // Utility method to create a test contact
    private static Contact createTestContact() {
        Contact contact = new Contact(FirstName='Test', LastName='Contact', Email = 'Testocr@test.com');
        insert contact;
        return contact;
    }

    // Test updating roles
    // @isTest(SeeAllData=true)
 /*   @isTest
    static void testRoleUpdate() {
        Opportunity opp = createTestOpportunity('Software and Service');
        Contact contact = createTestContact();
        OpportunityContactRole ocr = new OpportunityContactRole(OpportunityId=opp.Id, ContactId=contact.Id, Role='Decision Maker');
        insert ocr;

        Test.startTest();
        ocr.Role = 'Catalyst';
        update ocr;
        Test.stopTest();

        OpportunityContactRole updatedOcr = [SELECT Role FROM OpportunityContactRole WHERE Id = :ocr.Id];
        System.assertEquals('Finance/Billing Contact', updatedOcr.Role, 'The role should have been updated.');
    } */

    // Test preventing duplicate role insertion
    @isTest
    static void testPreventDuplicateInsertion() {

        User u = [SELECT Id FROM User WHERE LastName = 'TestUserUser' LIMIT 1];
        PermissionSet bypass = [SELECT Id FROM PermissionSet WHERE Name = 'Exclude_from_Flows' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = bypass.Id);

        System.runAs(u){
            Account newAccount = new Account();
            newAccount.Name = 'Test acctName';
            //newAccount.BillingCountry = 'United States';
            newAccount.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('QB Customer').getRecordTypeId();
            newAccount.Account_Status__c = 'Approved';
            newAccount.Account_Hierarchy_Level__c = 'Global Parent';
            insert newAccount;

            Product2 product1 = new Product2();
            product1.ProductCode = 'product-2';
            product1.Name = 'Hardware Product 2';
            product1.Description = 'Hardware Product 2 Description';
            product1.Family = 'HardwareFamily';
            product1.QS_Generate_Asset__c = true;
            product1.IsActive = true;
            product1.SBQQ__SubscriptionPricing__c = 'Percent Of Total';
            product1.SBQQ__SubscriptionType__c = 'Renewable';
            product1.SBQQ__SubscriptionTerm__c = 12;
            product1.SBQQ__QuantityEditable__c = true;
            product1.SBQQ__IncludeInMaintenance__c = true;
            insert product1;

            Id renewalRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Renewal').getRecordTypeId();

            Opportunity renewalOpp = new Opportunity();
            renewalOpp.AccountId = newAccount.Id;
            renewalOpp.Type='Existing Business';
            renewalOpp.QS_Order_Type__c='Subscription Renewal';
            renewalOpp.StageName='Connect';
            renewalOpp.CloseDate = System.today();
            renewalOpp.Name = 'Test Renewal';
            renewalOpp.RecordTypeId = renewalRecordTypeId;
            insert renewalOpp;        
      
        
        Contact contact = createTestContact();
        OpportunityContactRole ocr = new OpportunityContactRole(OpportunityId=renewalOpp.Id, ContactId=contact.Id, Role='Catalyst');
        insert ocr;

        OpportunityContactRole newOcr = new OpportunityContactRole(OpportunityId=renewalOpp.Id, ContactId=contact.Id, Role='Catalyst');

        Test.startTest();
        Database.SaveResult sr = Database.insert(newOcr, false);
        Test.stopTest();
  }
      //  System.assertFalse(sr.isSuccess(), 'The insertion should have been prevented.');
       // System.assertEquals('An OpportunityContactRole for this Opportunity and Contact already exists. The role has been updated to the new value.', sr.getErrors()[0].getMessage(), 'Expected an error message about duplicate role.');
    }
}