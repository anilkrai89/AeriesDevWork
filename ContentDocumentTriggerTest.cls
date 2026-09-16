@isTest public class ContentDocumentTriggerTest {
    @isTest static void caseAfterInsertTest() {
        Automation_Settings__c automationSetting = new Automation_Settings__c(SetupOwnerId = UserInfo.getUserId(), 
                                                                              Case_Trigger_Enabled__c = TRUE, 
                                                                              Content_Document_Link_Trigger_Enabled__c = TRUE, 
                                                                              Attachment_Trigger_Enabled__c = TRUE);
        INSERT automationSetting;
        
        Case randomCase = new Case(Subject = 'ContentDocumentTriggerTest');
        insert randomCase;
        ContentVersion contentVersion = new ContentVersion(PathOnClient = 'PathOnClient', VersionData = Blob.valueOf('Test'));
        insert contentVersion;
        ContentVersion createdContentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id];
        ContentDocumentLink randomContentDocumentLink = 
            new ContentDocumentLink(
                ContentDocumentId = createdContentVersion.ContentDocumentId, 
                LinkedEntityId = randomCase.Id,
                ShareType = 'V'
            );
        JCFS.JiraTriggerTestHelper.testAfterInsert(randomContentDocumentLink);
    }
}