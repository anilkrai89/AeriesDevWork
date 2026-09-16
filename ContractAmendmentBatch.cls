/*global class ContractAmendmentBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {

        public class Request {
        @InvocableVariable
        public List<String> contractId;
    }
    
    public class CalloutResult {
        public String recordId;
        public String contractId;
    }

    private List<String> contractIds;

    public ContractAmendmentBatch(List<String> inputs) {
        this.contractIds = inputs;
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM Contract WHERE Id IN :contractIds';
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext bc, List<Contract> contracts) {
        List<CalloutResult> calloutResults = new List<CalloutResult>();

        for(Contract contract : contracts) {
            CalloutResult result = AmendContract(contract.Id);
            if(result != null) {
                calloutResults.add(result);
            }
        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for(CalloutResult result : calloutResults) {
            Opportunity opp = PrepareOpportunityUpdate(result);
            oppsToUpdate.add(opp);
        }

        update oppsToUpdate; // DML operation in bulk after all callouts
    }

    global void finish(Database.BatchableContext bc) {
        // Any post-processing if needed
    }
    
    public static CalloutResult AmendContract(String cId) {
        String quote = SBQQ.ServiceRouter.load('SBQQ.ContractManipulationAPI.ContractAmender', cId, null);
        Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(quote);
        Map<String, Object> recordMap = (Map<String, Object>) jsonMap.get('record');
        String recordId = (String) recordMap.get('Id');
        
        if(recordId != null) {
            CalloutResult result = new CalloutResult();
            result.recordId = recordId;
            result.contractId = cId;
            return result;
        }
        return null;
    }   
    
    public static Opportunity PrepareOpportunityUpdate(CalloutResult result) {
        SBQQ__Quote__c sbq    = [Select SBQQ__Opportunity2__c, SBQQ__Account__r.Name   from SBQQ__Quote__c where Id = :result.recordId];
        Opportunity opp = new Opportunity();
        opp.Id = sbq.SBQQ__Opportunity2__c;
        opp.QS_Order_Sub_Type__c  = 'Cancel ';
        opp.QS_Order_Type__c = 'Existing Business';
        opp.Opportunity_Origin__c  = 'Other';
        opp.QS_Win_Loss_Comments__c = 'Suspend Cancel';
        opp.What_s_the_downside_risk__c  = 'Suspend';
        opp.Name = sbq.SBQQ__Account__r.Name + ' - Suspension Amendment ';
        opp.CloseDate = Date.today().addDays(30);
        return opp;
    }   

}*/
/***************************************************************************************************
* Name        : ContractAmendmentBatch
* Description : Batch Apex class for CPQ Amendment Automation.
*               This class identifies eligible Contract amendment requests where:
*               - Amendment Trigger Timestamp is populated
*               - Amendment Trigger Status is Pending
*
*               The batch updates eligible Contracts from Pending to Processing to prevent
*               duplicate processing, then enqueues ContractAmendmentProcessorQueueable
*               to perform payload validation, CPQ Contract Amender API callout, dynamic
*               Opportunity updates, and final Contract status updates.

* Class Name : ContractAmendmentBatch
* Test Class : ContractAmendmentAutomationTest
*
VERSION	  DEVELOPER	   DATE	  JIRA
63        Anil Kumar  

*
/*************************************************************************************************/
global class ContractAmendmentBatch implements Database.Batchable<SObject> {

    private List<String> contractIds;

    public ContractAmendmentBatch() {

        this.contractIds = new List<String>();

        System.debug('ContractAmendmentBatch default constructor called.');
        System.debug('Initialized empty contractIds list.');
    }

    public ContractAmendmentBatch(List<String> inputs) {

        this.contractIds = inputs == null
            ? new List<String>()
            : inputs;

        System.debug('ContractAmendmentBatch parameterized constructor called.');
        System.debug('Input contractIds=' + inputs);
        System.debug('Stored contractIds=' + this.contractIds);
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {

        System.debug('Batch start method started.');

        String query =
            'SELECT Id ' +
            'FROM Contract ' +
            'WHERE Amendment_Trigger_Timestamp__c != null ' +
            'AND Amendment_Trigger_Status__c = \'Pending\'';

        System.debug('Base query=' + query);

        if (!contractIds.isEmpty()) {

            System.debug('Filtering contracts using provided contractIds.');

            query += ' AND Id IN :contractIds';
        }

        System.debug('Final query=' + query);

        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext bc,List<Contract> contracts) {

        System.debug('Batch execute method started.');
        System.debug('Contracts received for execution=' + contracts.size());

        List<Contract> processingUpdates = new List<Contract>();
        List<Id> idsToProcess = new List<Id>();

        for (Contract con : contracts) {

            System.debug('Processing Contract Id=' + con.Id);
         
/********* setting the contract amendment_trigger_status from pending to Processing 
            so that next batch job will not pick the same record.***********************************/
            
            processingUpdates.add(new Contract(
                Id = con.Id,
                Amendment_Trigger_Status__c = 'Processing'
            ));

            idsToProcess.add(con.Id);// the same contract Id will be pass to queable jobs

            System.debug(
                'Contract prepared for Processing status update. Contract Id=' +
                con.Id
            );
        }

        System.debug(
            'Total contracts to update as Processing=' +
            processingUpdates.size()
        );

        if (!processingUpdates.isEmpty()) {

            System.debug('Updating contracts to Processing status.');

            Database.SaveResult[] updateResults =
                Database.update(processingUpdates, false);

            for (Integer i = 0; i < updateResults.size(); i++) {

                if (updateResults[i].isSuccess()) {

                    System.debug(
                        'Contract update successful. Contract Id=' +
                        updateResults[i].getId()
                    );

                } else {

                    for (Database.Error err :
                        updateResults[i].getErrors()) {

                        System.debug(
                            'Contract update failed. Error=' +
                            err.getMessage()
                        );
                    }
                }
            }
        }

        System.debug('Total Contract Ids to enqueue=' + idsToProcess.size());

        if (!idsToProcess.isEmpty()) {

            System.debug(
                'Enqueuing ContractAmendmentProcessorQueueable.'
            );

            Id queueableJobId =
                System.enqueueJob(
                    new ContractAmendmentProcessorQueueable(
                        idsToProcess
                    )
                );

            System.debug(
                'Queueable job enqueued successfully. Job Id=' +
                queueableJobId
            );
        }

        System.debug('Batch execute method completed.');
    }

    global void finish(Database.BatchableContext bc) {

        System.debug('Batch finish method started.');
        System.debug('ContractAmendmentBatch completed successfully.');
    }
}