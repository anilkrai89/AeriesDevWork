@isTest public class AttachmentTriggerTest {
    @isTest static void caseAfterInsertTest() {
        Automation_Settings__c automationSetting = new Automation_Settings__c(SetupOwnerId = UserInfo.getUserId(), 
                                                                              Case_Trigger_Enabled__c = TRUE, 
                                                                              Content_Document_Link_Trigger_Enabled__c = TRUE, 
                                                                              Attachment_Trigger_Enabled__c = TRUE);
        INSERT automationSetting;
        
        Case randomCase = new Case(Subject = 'AttachmentTriggerTest');
        insert randomCase;
        Attachment randomAttachment = new Attachment(ParentId = randomCase.Id, Name = 'test.txt', Body = Blob.valueOf('Test'));
        JCFS.JiraTriggerTestHelper.testAfterInsert(randomAttachment);
    }
}