@isTest
private class ContractAmenderAsyncFATest {
@TestSetup
    static void makeData() {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User();
        u.Alias = 'tuser';
        u.Email = 'test@quickbase.com.test';
        u.EmailEncodingKey = 'UTF-8';
        u.FirstName = 'Test';
        u.LastName = 'ContractAmenderTest';
        u.LanguageLocaleKey = 'en_US';
        u.LocaleSidKey = 'en_US';
        u.ProfileId = profile.Id;
        u.TimeZoneSidKey = 'America/Los_Angeles';
        u.Username = 'test@quickbase.com.test';
        insert u;
    }


    static List<Contract> createContracts(Integer numberOfRecords, User u) {
        System.runAs(u) {

            List<Account> accounts = new List<Account>();
            for(Integer i=0; i<numberOfRecords; i++) {
                Account a = new Account();
                a.Name = 'Test Account ' + i;
                a.Account_Hierarchy_Level__c = 'Global Parent';     // validation rule
                a.BillingCountry = 'United States';
                accounts.add(a);
            }
            insert accounts;

      Opportunity o = new Opportunity
      (
        Name = 'Test Amendment opp', 
        AccountId = accounts[0].Id,
        StageName = 'Proposal',
        CloseDate = Date.today().addDays(7)
      );
      insert o;


            List<Contract> contractsForUpdate = new List<Contract>();
            for(Integer i=0; i<numberOfRecords; i++) {
                Contract c = new Contract();
                c.Name = 'Test Contract ' + i;
                c.AccountId = accounts[i].Id;
                c.ContractTerm = 12;
                c.StartDate = Date.today();
                c.SBQQ__AmendmentRenewalBehavior__c = 'Latest End Date';
        c.StartDate = Date.today().addDays(-1);
        c.ContractTerm = 1;

                contractsForUpdate.add(c);
            }
            insert contractsForUpdate;

      for (Contract c : [
        SELECT Id, SBQQ__RenewalOpportunity__c, SBQQ__RenewalForecast__c, StartDate , EndDate
        FROM Contract ])
      {
        system.debug(c);
      }


            return contractsForUpdate;
        }
        return null;
    }
    
    
    @isTest
    static void testPerformAsyncProcessing() {
        // Create test data
        User u = [SELECT Id FROM User WHERE LastName = 'ContractAmenderTest' LIMIT 1];
        if (u.Id == null){
            u.Id = '0055e0000072tXnAAI';
        }
        List<Contract> contractsForUpdate = createContracts(1, u);
         List<Id> contractIdList = new List<String>();
        List<ContractAmenderAsyncFA.Request> requests = new List<ContractAmenderAsyncFA.Request>();
        ContractAmenderAsyncFA.Request request = new ContractAmenderAsyncFA.Request();
        contractIdList.add(contractsForUpdate[0].Id);
        request.contractId = contractIdList;
        requests.add(request);
       
        Test.startTest();
        // Call the invocable method
        ContractAmenderAsyncFA.performAsyncProcessing(requests);
        Test.stopTest();
        
        // Add your assertions here
        // Example assertions:
        // 1. Verify that a Queueable Apex job is enqueued
       // System.assertEquals(1, Limits.getQueueableJobs());
    }
}