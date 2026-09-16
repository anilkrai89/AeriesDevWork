@isTest
public class SP_ObjectiveActionTriggerHandlerTest {
    
    testmethod static void testSalesPlanActionDeletion()
    {
        Id PRODUCTSANDSERVRTYPE = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Software and Services').getRecordTypeId();
        Account account = new Account();
        account.Name = 'Test acctName';
        account.BillingCountry = 'United States';
        account.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('QB Customer').getRecordTypeId();
        account.Account_Status__c = 'Approved';
        insert account;
        
        Opportunity opp = new Opportunity(Name='asdasd',RecordTypeId=PRODUCTSANDSERVRTYPE,stagename='1 - Plan', closedate=Date.today(), AccountId=account.Id);
        system.debug('@opp'+opp);
        insert opp;
        
        QS_Opportunity_Stage__c opStage = new QS_Opportunity_Stage__c();
        opStage.Name = 'Disqualified';
        INSERT opStage;
        
        QS_Stage_Objective__c testStageObject = new QS_Stage_Objective__c(name='1 - Plan');
        testStageObject.QS_Opportunity_Record_Type__c = 'Products and Services';
        testStageObject.QS_Opportunity_Stage__c = opStage.Id;
        insert testStageObject;
        
        QS_Objective_Action__c testObjectiveAction = new QS_Objective_Action__c();
        testObjectiveAction.Name = 'ActionToDelete';
        testObjectiveAction.QS_Stage_Objective__c = testStageObject.Id;
        testObjectiveAction.QS_Opportunity_Record_Type__c = 'Products and Services';
        testObjectiveAction.Name = 'Discover?';
        insert testObjectiveAction;
        
        Task tk = new Task(subject='test', ActivityDate=Date.today(), OwnerId=UserInfo.getUserId(), priority='Normal', status='Not Started');
        tk.whatId = opp.Id;
        tk.QS_StageObjectiveID__c = testStageObject.Id;
        tk.QS_ObjectiveActionID__c = testObjectiveAction.Id;
        INSERT tk;
        
        Test.startTest();
        try{delete testObjectiveAction;}catch(Exception ex){}
        Test.stopTest();
    }
    
}