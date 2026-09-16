@isTest( SeeAllData=false )
public class SP_SalesPlanValidations_Test {

    
    public static testMethod void testAdvanceStage2() {
        
        // Set up test data
        Id PRODUCTSANDSERVRTYPE = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Software and Services').getRecordTypeId();
        Account account = new Account();
        account.Name = 'Test acctName';
        account.BillingCountry = 'United States';
        account.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('QB Customer').getRecordTypeId();
        account.Account_Status__c = 'Approved';
       insert account;
        
        Schema.DescribeFieldResult F = Opportunity.Stagename.getDescribe();
        List<Schema.PicklistEntry> P = F.getPicklistValues();  
        
        map<integer,string> pMap = new map<integer,string>();
        string firstStage = '';
        list<string> pVal = new list<string>();
        for(Schema.PicklistEntry o: P){
            pVal.add(o.getValue());   
            if(firstStage == '')
                    firstStage = o.getValue();
        }
        for(integer i = 0; i<pVal.size() ;i++){
               pMap.put(i+1,pVal[i]);
                
        }
        
       
        
        RecordType recType = [Select Id,Name From RecordType where sobjecttype = 'Opportunity' and Name <> 'Amendment' and Name <> 'Renewal' limit 1];
        String productandservice = recType.Name;
        //Opportunity opp = new Opportunity(Name = 'Test Oppty',recordTypeID=PRODUCTSANDSERVRTYPE, AccountId = acc.id, StageName = firstStage, QS_Order_Type__c = 'New', CloseDate = Date.Today());
        
        Opportunity opp = createOpportunities('TestVCGO', account.Id, 1, true)[0];
        opp.StageName = firstStage;
        opp.RecordTypeId = PRODUCTSANDSERVRTYPE;
        opp.QS_Order_Type__c = 'New';
        opp.CloseDate = Date.Today();
        update opp;
       

       
        List<QS_Opportunity_Stage__c> stgList = new List<QS_Opportunity_Stage__c>();
        Id previousStageId;
        QS_Opportunity_Stage__c previousStage;
        QS_Opportunity_Stage__c currentStage;
        for(Integer seq : pMap.keySet()) {
            currentStage = new QS_Opportunity_Stage__c(Name = pMap.get(seq), QS_Stage_Number__c = seq);
            insert currentStage;
            stgList.add(currentStage);
            if(previousStage <> null)
            {
                previousStage.QS_Next_Stage__c = currentStage.Id;
                update previousStage;
            }
            previousStage = currentStage;
            
        }
        
        
        QS_Stage_Objective__c obj1 = createOpportunityStageObjectivewithRecordType(stgList[0],pVal[1],productandservice,1,true);
        QS_Stage_Objective__c obj2 = createOpportunityStageObjectivewithRecordType(stgList[1],pVal[2],productandservice,2,true);
        QS_Stage_Objective__c obj3 = createOpportunityStageObjectivewithRecordType(stgList[2],pVal[3],productandservice,3,true);
       
        QS_Objective_Action__c act1 = createObjectiveAction(obj1, productandservice, 'Not Required Action',1, true);
        
        
        QS_Objective_Action__c act2 = createObjectiveAction(obj2, productandservice, 'Required Action',2, true);
        act2.QS_Opportunity_Order_Type__c = 'New';
        act2.QS_Action_Type__c = 'Required';
        update act2;
        
        QS_Objective_Action__c act3 = createObjectiveAction(obj2, productandservice, 'Required Action',3, true);
        act3.QS_Opportunity_Order_Type__c = 'New';
        act3.QS_Action_Type__c = 'Required';
        act3.QS_Exempt_Profiles__c='System Administrator';
        update act3;
        
        QS_Objective_Action__c act4 = createObjectiveAction(obj1, productandservice, 'Highly Recommended',1, true);
        act4.QS_Action_Type__c = 'Required';
        act4.QS_Exempt_Users__c = UserInfo.getUserId().mid(0,15);
        act3.QS_Exempt_Profiles__c='System Administrator';
        
       // Begin test
        Test.startTest();
        opp.StageName = pMap.get(1);
        update opp;
        
        //System.assertEquals(pMap.get(2), opp.StageName);
        
        opp.StageName = pMap.get(2);
        try {
            update opp;
        }
        catch (Exception e) {
            System.debug('Caught exception');
        }
        
        Opportunity getOpp = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id LIMIT 1];
        
        
        Task tsk = new Task(WhatId = opp.Id, QS_StageObjectiveID__c = obj2.Id, QS_ObjectiveActionID__c = act2.Id);
        tsk.Status = 'Completed';
        insert tsk;
        
        Task tsk2 = new Task(WhatId = opp.Id, QS_StageObjectiveID__c = obj1.Id, QS_ObjectiveActionID__c = act1.Id);
        tsk2.Status = 'Completed';
        insert tsk2;
        Task tsk3 = new Task(WhatId = opp.Id, QS_StageObjectiveID__c = obj2.Id, QS_ObjectiveActionID__c = act1.Id);
        tsk3.Status = 'Completed';
        insert tsk3;
        
        Task tsk4 = new Task(WhatId = opp.Id, QS_StageObjectiveID__c = obj1.Id, QS_ObjectiveActionID__c = act2.Id);
        tsk4.Status = 'Completed';
        insert tsk4;

        opp.Amount = 6000;
        update opp;
        
        getOpp = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id LIMIT 1];

        
        SP_SalesPlanValidations.loadOpportunityStageAndPreviousStageByRecordType(recType.Id,recType.Name,opp.StageName);
        Test.stopTest();
    }

    public static testMethod void testAdvanceStage() {
        
        // Set up test data
        Account account = new Account();
        account.Name = 'Test acctName';
        account.BillingCountry = 'United States';
        account.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('QB Customer').getRecordTypeId();
        account.Account_Status__c = 'Approved';
        insert account;
        
        Schema.DescribeFieldResult F = Opportunity.Stagename.getDescribe();
        List<Schema.PicklistEntry> P = F.getPicklistValues();  
        
        map<integer,string> pMap = new map<integer,string>();
        string firstStage = '';
        list<string> pVal = new list<string>();
        for(Schema.PicklistEntry o: P){
            pVal.add(o.getValue());   
            if(firstStage == '')
                    firstStage = o.getValue();
        }
        for(integer i = 0; i<pVal.size() ;i++){
               pMap.put(i+1,pVal[i]);
                
        }
        
        RecordType recType = [Select Id,Name From RecordType where sobjecttype = 'Opportunity' and Name <> 'Amendment' and Name <> 'Renewal' limit 1];
        Id PRODUCTSANDSERVRTYPE = recType.Id;
        String productandservice = recType.Name;
        Opportunity opp = new Opportunity(Name = 'Test Oppty',recordTypeID=PRODUCTSANDSERVRTYPE, AccountId = account.id, StageName = firstStage, QS_Order_Type__c = 'New', CloseDate = Date.Today());
     
        insert opp;
        
       

       
        List<QS_Opportunity_Stage__c> stgList = new List<QS_Opportunity_Stage__c>();
        Id previousStageId;
        QS_Opportunity_Stage__c previousStage;
        QS_Opportunity_Stage__c currentStage;
        for(Integer seq : pMap.keySet()) {
            currentStage = new QS_Opportunity_Stage__c(Name = pMap.get(seq), QS_Stage_Number__c = seq);
            insert currentStage;
            stgList.add(currentStage);
            if(previousStage <> null)
            {
                previousStage.QS_Next_Stage__c = currentStage.Id;
                update previousStage;
            }
            previousStage = currentStage;
            
        }
        
        
        QS_Stage_Objective__c obj1 = new QS_Stage_Objective__c(Name = pVal[1], QS_Opportunity_Stage__c = stgList[0].Id, QS_Order__c = 1);
        obj1.QS_Opportunity_Record_Type__c = productandservice;
        QS_Stage_Objective__c obj2 = new QS_Stage_Objective__c(Name = pVal[2], QS_Opportunity_Stage__c = stgList[1].Id, QS_Order__c = 2);
        obj2.QS_Opportunity_Record_Type__c = productandservice;
        QS_Stage_Objective__c obj3 = new QS_Stage_Objective__c(Name = pVal[3], QS_Opportunity_Stage__c = stgList[2].Id, QS_Order__c = 3);
        obj3.QS_Opportunity_Record_Type__c = productandservice;
        List<QS_Stage_Objective__c> objList = new List<QS_Stage_Objective__c>();
        objList.add(obj1);
        objList.add(obj2);
        objList.add(obj3);
        insert objList;
        
        QS_Objective_Action__c act1 = new QS_Objective_Action__c(Name = 'Not Required Action', QS_Order__c = 1, QS_Stage_Objective__c = obj1.Id);
        QS_Objective_Action__c act2 = new QS_Objective_Action__c(Name = 'Required Action', QS_Order__c = 2, QS_Stage_Objective__c = obj2.Id, QS_Action_Type__c = 'Required', QS_Opportunity_Order_Type__c = 'New');
        act2.QS_Opportunity_Record_Type__c = productandservice;
        act1.QS_Opportunity_Record_Type__c = productandservice;
        List<QS_Objective_Action__c> actList = new List<QS_Objective_Action__c>();
        actList.add(act1);
        actList.add(act2);
        insert actList;
        
        createSalesPlanTask(opp, obj1, act1, true);
        createSalesPlanTask(opp, obj2, act2, true);
        
        // Begin test
        Test.startTest();
        opp.StageName = pMap.get(1);
        update opp;
        
        //System.assertEquals(pMap.get(2), opp.StageName);
        
        opp.StageName = pMap.get(2);
        try {
            update opp;
        }
        catch (Exception e) {
            System.debug('Caught exception');
        }
        
        Opportunity getOpp = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id LIMIT 1];
        //System.assertNotEquals(pMap.get(3), getOpp.StageName);
        
        Task tsk = new Task(WhatId = opp.Id, QS_StageObjectiveID__c = obj2.Id, QS_ObjectiveActionID__c = act2.Id);
        tsk.Status = 'Completed';
        insert tsk;


        opp.Amount = 6000;
        update opp;
        
        getOpp = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id LIMIT 1];
    //  System.assertEquals(pMap.get(3), getOpp.StageName);
        
        Test.stopTest();
    }
    

    
    public static List<Opportunity> createOpportunities(String strName, Id acctId, Integer intCnt, Boolean insertRecords)
    {
        return createOpportunities(strName, 'TQL', System.Today(), acctId, intCnt, insertRecords);
    }
    
    public static QS_Objective_Action__c createObjectiveAction(QS_Stage_Objective__c testStageObject,string recordType, string actionName, Integer ordernumber, Boolean insertrecord){
        
        
        QS_Objective_Action__c testObjectiveAction = new QS_Objective_Action__c();
        testObjectiveAction.QS_Stage_Objective__c = testStageObject.Id;
        testObjectiveAction.QS_Opportunity_Record_Type__c = recordType;
        testObjectiveAction.Name = actionName;
        testObjectiveAction.QS_Exempt_Profiles__c = 'System Administrator';
        if(insertrecord)
            insert testObjectiveAction;
        
        return testObjectiveAction;
        
    }
    
    public static Task createSalesPlanTask(Opportunity opp, QS_Stage_Objective__c testStageObject,QS_Objective_Action__c testObjectiveAction, Boolean insertrecord )
    {
        
        Task tk = new Task(subject='test', ActivityDate=Date.today(), OwnerId=UserInfo.getUserId(), priority='Normal', status='Not Started');
        tk.whatId = opp.Id;
        tk.QS_StageObjectiveID__c = testStageObject.Id;
        tk.QS_ObjectiveActionID__c = testObjectiveAction.Id;
        if(insertrecord)
            insert tk;
        
        return tk;
    }
    
    public static List<Opportunity> createOpportunities(String strName, String strStageName, Date dtCloseDate, Id acctId, Integer intCnt, Boolean insertRecords)
    {
        
        List<Opportunity> lstOpps = new List<Opportunity>();
        
        while (intCnt > 0)
        {
            Opportunity currOpp = new Opportunity();
            currOpp.Name = strName + ' #'+intCnt;
            currOpp.StageName = strStageName;
            currOpp.CloseDate = dtCloseDate;
            if (acctId != null)
                currOpp.AccountId = acctId;
            lstOpps.add(currOpp);
            intCnt --;
        }
        
        if (insertRecords)
            insert lstOpps;
        
        return lstOpps;
    }
    
    public static QS_Stage_Objective__c createOpportunityStageObjectivewithRecordType(QS_Opportunity_Stage__c stage,string stageName,string recType,Integer order, Boolean insertrecord){
        
        QS_Stage_Objective__c opStage = new QS_Stage_Objective__c();
         opStage.QS_Opportunity_Stage__c = stage.Id;
        opStage.Name = stageName;
        opStage.QS_Opportunity_Record_Type__c = recType;
         opStage.QS_Order__c = order;
        if(insertrecord)
            INSERT opStage;
        
        return opStage;
    }
}