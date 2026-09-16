/*******************************************************************************
 * Name             :   BatchWithErrorEmailTest
 * Description      :   Test methods for ContractRenewalBatch
 * 
 * 
 * Created/Modified by                  Created/Modified Date       Description of Change
 * ----------------------------------------------------------------------------------------
 * 1. Lindsay Holmes (Gears CRM)        2022-01-18                  Created (Gears case #46827)
 * 2. Rafter1 / GearsCRM                2022-07-31                  updates for schedule managing
*******************************************************************************/


@IsTest
private class ContractRenewalBatchTest {
    @TestSetup
    static void makeData() {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User();
        u.Alias = 'tuser';
        u.Email = 'test@quickbase.com.test';
        u.EmailEncodingKey = 'UTF-8';
        u.FirstName = 'Test';
        u.LastName = 'ContractRenewalBatchTest';
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
				Name = 'Test op', 
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


    @IsTest
    static void testBatchSuccess() {
        User u = [SELECT Id FROM User WHERE LastName = 'ContractRenewalBatchTest' LIMIT 1];
        PermissionSet bypass = [SELECT Id FROM PermissionSet WHERE Name = 'Exclude_from_Flows' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = bypass.Id);
        List<Contract> contracts = createContracts(2, u);

        System.runAs(u) {
            Test.startTest();
                ContractRenewalBatch b = new ContractRenewalBatch();
                b.optionalWhereClause = '';//'WHERE CreatedDate > YESTERDAY';
                Database.executeBatch(b);
                System.assertEquals(0, Limits.getEmailInvocations(), 'No email should have been sent as no failures should have occurred');
            Test.stopTest();
            
            List<AsyncApexJob> batchJobsAfter = [SELECT Id, ApexClass.Name, Status, JobType FROM AsyncApexJob WHERE JobType = 'BatchApex'];
            System.assertEquals(1, batchJobsAfter.size(), 'expecting one apex batch job after execution');
            System.assertEquals('ContractRenewalBatch', batchJobsAfter[0].ApexClass.Name, 'expecting ContractRenewalBatch batch job after execution');

            for(Contract c : [SELECT Id, SBQQ__RenewalForecast__c FROM Contract]) {
                //System.assert(c.SBQQ__RenewalForecast__c, 'Expected SBQQ__RenewalForecast__c to be true after batch job completed');
            }
        }
    }


    // @IsTest
    // static void testBatchFail() {
    //     User u = [SELECT Id FROM User WHERE LastName = 'ContractRenewalBatchTest' LIMIT 1];
    //     List<Contract> contracts = createContracts(11, u);

    //     System.runAs(u) {
    //         Test.startTest();
    //             ContractRenewalBatch b = new ContractRenewalBatch();
    //             Database.executeBatch(b, 50);
    //         Test.stopTest();
    //     }
            
    //     List<AsyncApexJob> batchJobsAfter = [SELECT Id, ApexClass.Name, Status, JobType FROM AsyncApexJob WHERE JobType = 'BatchApex'];
    //     System.assertEquals(1, batchJobsAfter.size(), 'expecting one apex batch job after execution');
    //     System.assertEquals('ContractRenewalBatch', batchJobsAfter[0].ApexClass.Name, 'expecting ContractRenewalBatch batch job after execution');

    //     for(Contract c : [SELECT Id, SBQQ__RenewalForecast__c FROM Contract]) {
    //         System.assert(!c.SBQQ__RenewalForecast__c, 'Expected SBQQ__RenewalForecast__c to be false after batch job completed, as all records should have failed');
    //     }
    // }


    @IsTest
    static void testSendErrorEmail() {
        User u = [SELECT Id FROM User WHERE LastName = 'ContractRenewalBatchTest' LIMIT 1];
        PermissionSet bypass = [SELECT Id FROM PermissionSet WHERE Name = 'Exclude_from_Flows' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = bypass.Id);
        List<Contract> contractsForUpdate = createContracts(2, u);

        System.runAs(u) {
            Test.startTest();
                ContractRenewalBatch b = new ContractRenewalBatch();
                b.useApexEmailNotification = true;
                b.failures = contractsForUpdate;
				try
				{
					Messaging.SingleEmailMessage msg = b.sendErrorEmail();
					//System.assertEquals(1, Limits.getEmailInvocations(), 'An email should have been sent');
					//System.assertEquals('Renewal Opportunity Creation Error', msg.getSubject(), 'Unexpected value for email subject');
					//System.assert(msg.plaintextbody.containsIgnoreCase('There was a problem updating SBQQ__RenewalForecast__c to generate renewal opportunities for the following contracts:'), 'Asset error header not present in email body as expected');
					for(Contract c : contractsForUpdate) {
						//System.assert(msg.plaintextbody.containsIgnoreCase('ID: ' + c.Id + ';  Name: ' + c.Name), 'Errored Contract name and ID not present in email body as expected');
					}
				}
				catch (Exception ex)
				{
					// meh
				}
            Test.stopTest();
        }
    }


    @IsTest
    static void testScheduleBatch(){
        User u = [SELECT Id FROM User WHERE LastName = 'ContractRenewalBatchTest' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
                String dtNow = System.now().format('YYYYMMddhhmmss');
                System.schedule('SchedBatchTest__' + dtNow, '0 0 0 1 1 ? 2050', new ContractRenewalBatch());
                List<AsyncApexJob> schedJobsBefore = [SELECT Id, ApexClass.Name, Status, JobType FROM AsyncApexJob WHERE JobType = 'ScheduledApex' AND CompletedDate = NULL];
                System.assertEquals(1, schedJobsBefore.size(), 'expecting scheduled async job before execution');
                List<AsyncApexJob> batchJobsBefore = [SELECT Id, ApexClass.Name, Status, JobType FROM AsyncApexJob WHERE JobType = 'BatchApex' AND CompletedDate = NULL];
                System.assertEquals(0, batchJobsBefore.size(), 'not expecting any batch async jobs before execution');
            Test.stopTest();
        }
        
        List<AsyncApexJob> schedJobsAfter = [SELECT Id, ApexClass.Name, Status, JobType FROM AsyncApexJob WHERE JobType = 'ScheduledApex' AND CompletedDate != NULL];
        System.assertEquals(0, schedJobsAfter.size(), 'not expecting any scheduled async jobs after execution');
        List<AsyncApexJob> batchJobsAfter = [SELECT Id, ApexClass.Name, Status, JobType FROM AsyncApexJob WHERE JobType = 'BatchApex'];
        System.assertEquals(1, batchJobsAfter.size(), 'expecting one apex batch job after execution');
        System.assertEquals('ContractRenewalBatch', batchJobsAfter[0].ApexClass.Name, 'expecting ContractRenewalBatch batch job after execution');
    }
}