@isTest
public class ContractAmendmentBatchTest {

    // Helper method to create mock Contracts
    private static List<Contract> createTestContracts(Integer count) {
        
           List<Account> accounts = new List<Account>();
            for(Integer i=0; i<count; i++) {
                Account a = new Account();
                a.Name = 'Test Account ' + i;
                a.Account_Hierarchy_Level__c = 'Global Parent';     // validation rule
                a.BillingCountry = 'United States';
                accounts.add(a);
            }
            insert accounts;
        
      Opportunity opp1 = new Opportunity
      (
        Name = 'Test Amendment opp', 
        AccountId = accounts[0].Id,
        StageName = 'Proposal',
        CloseDate = Date.today().addDays(7)
      );
      insert opp1;
        
        List<Contract> contracts = new List<Contract>();
        for (Integer i = 0; i < count; i++) {
                Contract c = new Contract();
                c.Name = 'Test Contract ' + i;
                c.AccountId = accounts[i].Id;
                c.ContractTerm = 12;
                c.StartDate = Date.today();
                c.SBQQ__AmendmentRenewalBehavior__c = 'Latest End Date';
        c.StartDate = Date.today().addDays(-1);
        c.ContractTerm = 1;
            contracts.add(c);
        }
         insert contracts;

        if (contracts.size() > 0){
            return contracts;
        }
            else{
                return null;
            }
            
       
    }

    // Mock class for HTTP callouts
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Mock response from callout
            HTTPResponse res = new HTTPResponse();
            res.setBody('{"record":{"Id":"mockRecordId"}}');
            res.setStatusCode(200);
            return res;
        }
    }

    // Test method for batch execution
    @isTest static void testContractAmendmentBatch() {
        // Set up test data
        List<String> contractIds = new List<String>();
        List<Contract> contracts = createTestContracts(1);
        for(Contract ct : contracts){
            contractIds.add(ct.Id);
        }
        //insert contracts; // Inserting mock contracts

        // Set mock callout class
       // Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Initialize and execute batch job
        Test.startTest();
       // ContractAmenderAsyncFA.performAsyncProcessing(contractIds);
      ContractAmendmentBatch batch = new ContractAmendmentBatch(contractIds);
      Database.executeBatch(batch, 1);
        Test.stopTest();

        // Assertions
        // Verify that Opportunities are correctly updated or created based on the logic in your batch class
/*        List<Opportunity> updatedOpps = [SELECT Id, Name FROM Opportunity];
        System.assertEquals(2, updatedOpps.size(), 'There should be three opportunities updated');

        for (Opportunity opp : updatedOpps) {
            System.assert(opp.Name.contains('Suspension Amendment'), 'Opportunity name should contain the amendment label');
        }
*/
    }
}