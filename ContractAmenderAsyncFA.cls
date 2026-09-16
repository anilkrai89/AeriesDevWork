/*public class ContractAmenderAsyncFA {

      public class Request {
        @InvocableVariable
        public List<String> contractId;
    }
    @InvocableMethod(label='Perform Contract Amend Async Processing' description='Performs asynchronous processing')
    public static void performAsyncProcessing(List<Request> requests) {
        List<String> idsToProcess = new List<String>();
        
        for (Request req : requests) {
            // Ensure there are contract IDs to process
            if(req.contractId != null) {
                for(String cid : req.contractId){
                    idsToProcess.add(cid);
                }
            }
        }
        // Enqueue a Queueable Apex job for asynchronous processing
         //System.enqueueJob(new QBContractAmender(idsToProcess));
        Database.executeBatch(new ContractAmendmentBatch(idsToProcess), 1);
}

}*/
/**************************************************************************************************/
/***************************************************************************************************
* Name        : ContractAmenderAsyncFA
* Description : Invocable Apex entry point for CPQ Amendment Automation.
*               This class is called from Flow and receives one or more Contract Ids.
*               It validates the incoming Contract Id list and starts ContractAmendmentBatch.
*               The batch then processes only eligible Contracts where amendment trigger
*               status, timestamp, and payload requirements are met.
*
* Class Name : ContractAmenderAsyncFA
* Test Class : ContractAmendmentAutomationTest
* ----
VERSION	  DEVELOPER	   DATE	  JIRA
63        Anil Kumar  

***************************************************************************************************/
public class ContractAmenderAsyncFA {

    public class Request {
        @InvocableVariable
        public List<String> contractId;
    }

    @InvocableMethod(
        label='Perform Contract Amend Async Processing'
        description='Performs asynchronous CPQ amendment processing for eligible Contracts'
    )
    public static void performAsyncProcessing(List<Request> requests) {
        List<Id> idsToProcess = new List<Id>();

        if (requests != null) {
            for (Request req : requests) {
                if (req != null && req.contractId != null) {
                    for (String cid : req.contractId) {
                        if (String.isNotBlank(cid)) {
                            idsToProcess.add((Id) cid);
                        }
                    }
                }
            }
        }

        if (idsToProcess.isEmpty()) {
            Database.executeBatch(new ContractAmendmentBatch(), 1);
        } else {
            Database.executeBatch(new ContractAmendmentBatch(idsToProcess), 1);
        }
    }
}