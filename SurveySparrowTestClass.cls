@isTest
private class SurveySparrowTestClass {
    
    @isTest static void testCallout() {
        
        Case caseObj = new Case(Subject = 'Test Case',
            Status = 'New',
            SuppliedEmail = 'test@example.com',AccountId =System.label.TestAccount,ContactID=System.label.TestContact);
        try{
        insert caseObj;
        }
         Catch(Exception e){
            system.debug('error message'+e.getmessage());
        }
        
        // Set mock callout class 
        Test.setMock(HttpCalloutMock.class, new SurveySparrowMockHttpResponseGenerator());
        
       /* Case caseObj = new Case(Subject = 'Test Case from Test Class');
        try{
        insert caseObj;
        }
         Catch(Exception e){
            system.debug('error message'+e.getmessage());
        }*/
        caseObj.Status = 'Closed';
        try{
        update caseObj;
        }
        
         Catch(Exception e){
            system.debug('error message'+e.getmessage());
        }
        //System.assertEquals('Closed', [SELECT Status FROM Case WHERE Id = :caseObj.Id].Status);
        
    }
}