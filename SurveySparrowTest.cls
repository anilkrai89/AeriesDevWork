@isTest
private class SurveySparrowTest {
    @isTest static void testCallout() {
        
        Automation_Settings__c automationSetting = new Automation_Settings__c(SetupOwnerId = UserInfo.getUserId(), 
                                                                              Case_Trigger_Enabled__c = TRUE, 
                                                                              Content_Document_Link_Trigger_Enabled__c = TRUE, 
                                                                              Attachment_Trigger_Enabled__c = TRUE);
        INSERT automationSetting; 
        
        // Set mock callout class 
        Test.setMock(HttpCalloutMock.class, new SurveySparrowMockHttpResponseGenerator());
        
        Case caseObj = new Case(Subject = 'Test Case',
            Status = 'New',
            SuppliedEmail = 'test@example.com',AccountId ='0015e00000ya5nKAAQ',ContactID='003UN00000KmwW2YAJ');
        try{
        insert caseObj;
        }
        
       /* Case caseObj = new Case(Subject = 'Test Case from Test Class');
        try
        {
            insert caseObj;
        }*/
        Catch(Exception e){
            system.debug('error message'+e.getmessage());
        }
        
        caseObj.Status = 'Closed';
       
        try{
            update caseObj;
            
        }
        Catch(Exception e){
            system.debug('error message'+e.getmessage());
        }
        
}
}