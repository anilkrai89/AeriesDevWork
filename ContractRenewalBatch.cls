/*******************************************************************************
 * Name             :   ContractRenewalBatch
 * Description      :   Batch class to create renewal opportunities from contracts
 * Tested By        :   ContractRenewalBatchTest
 * 
 * 
 * Created/Modified by                  Created/Modified Date       Description of Change
 * ----------------------------------------------------------------------------------------
 * 1. Lindsay Holmes (Gears CRM)        2022-01-18                  Created (Gears case #46827)
 * 2. Rafter1 / GearsCRM                2022-07-31                  updated to use managed our own scheduling
*******************************************************************************/


public with sharing class ContractRenewalBatch implements Schedulable, Database.Batchable<SObject>, Database.Stateful {

    public String optionalWhereClause;
    public Boolean useApexEmailNotification;
    @TestVisible private List<Contract> failures;

	private boolean mDidAny;
    
    public void execute(SchedulableContext SC) {
        Database.executeBatch(new ContractRenewalBatch(), 10);
    }

    public ContractRenewalBatch() {
		mDidAny = false;
        failures = new List<Contract>();
        if(useApexEmailNotification == null) {
            useApexEmailNotification = false;
        }
    }

	private boolean isEnabled()
	{
		return Test.isRunningTest() || Label.Batch_Enable == 'yes';
	}

    public Database.QueryLocator start(Database.BatchableContext BC) {

		system.debug('+start');

        String query = 'SELECT Id FROM Contract ' +
			' WHERE SBQQ__RenewalOpportunity__c = null AND SBQQ__RenewalForecast__c = false AND EndDate != null AND StartDate != null ';

        if(String.isNotBlank(optionalWhereClause)) {
            query += optionalWhereClause;
        }

		string querySize = isEnabled() ? Label.Batch_query_size : '0';

		query += ' ORDER BY EndDate ASC LIMIT ' + querySize;

		system.debug('using query: ' + query);

		system.debug('-start');
        return Database.getQueryLocator(query);
    }


    public void execute(Database.BatchableContext BC, List<sObject> scope) {

		system.debug('+execute');
		mDidAny = true;
        List<Contract> contracts = [SELECT Id, Name, EndDate, SBQQ__RenewalForecast__c, SBQQ__RenewalOpportunity__c FROM Contract WHERE Id IN :scope];
        for(Contract c : contracts) {
			system.debug('processing ' + c);
            c.SBQQ__RenewalForecast__c = true;
        }

        List<Database.SaveResult> srList1 = Database.update(contracts, false);
        for(Integer i=0; i<srList1.size(); i++) {
            Database.SaveResult sr = srList1[i];
            if(!sr.isSuccess()) {
                failures.add(contracts[i]);
                System.debug(sr.getErrors());
            }
        }

		system.debug('-execute');
    }
    
    
    public void finish(Database.BatchableContext BC) {

		system.debug('+finish');

		string minutes = Label.Batch_requeue_minutes;
		if (mDidAny) {
			if (!Test.isRunningTest()) {
				system.scheduleBatch(new ContractRenewalBatch(), 'Contract Renewal Batch', integer.valueOf(minutes));
				system.debug('reschedule to run in ' + minutes + ' minutes');
			}
		}
		else
		{
			system.debug('no longer enabled or no more records to process');
		}

        sendErrorEmail();

		system.debug('-finish');
    }


    @TestVisible
    private Messaging.SingleEmailMessage sendErrorEmail() {
        List<String> bodyList = new List<String>();
        if(!failures.isEmpty()) {
            String body = 'There was a problem updating SBQQ__RenewalForecast__c to generate renewal opportunities for the following contracts:';
            for(Contract c : failures) {
                body += '\nID: ' + c.Id + ';  Name: ' + c.Name;
            }
            bodyList.add(body);
        }

        if(!bodyList.isEmpty()) {
            List<String> emailAddresses = new List<String>();
            if(Test.isRunningTest()) {
                emailAddresses.add('test@test.com');
            }
            
            if(useApexEmailNotification) {
                for(ApexEmailNotification aen : [SELECT Email, UserId, User.IsActive, User.Email FROM ApexEmailNotification]) {
                    if(aen.Email != null) {
                        emailaddresses.add(aen.Email);
                    } else if(aen.UserId != null && aen.User.IsActive && aen.User.Email != null) {
                        emailAddresses.add(aen.User.Email);
                    }
                }
            } else {
                for(ErrorEmail__mdt errEmailAddr : [SELECT MasterLabel FROM ErrorEmail__mdt]) {
                    emailAddresses.add(errEmailAddr.MasterLabel);
                }
            }
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(emailAddresses);
            msg.setSubject('Renewal Opportunity Creation Error');
            msg.setPlainTextBody(String.join(bodyList, '\n\n\n'));
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{msg});
            return msg;
        }

        return null;
    }
}