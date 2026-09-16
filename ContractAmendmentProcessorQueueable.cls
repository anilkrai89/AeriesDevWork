/**
 * ContractAmendmentProcessorQueueable
 *
 * Processes CPQ contract amendments via the SBQQ Contract Manipulation API.
 *
 * KEY FIX: Filters subscriptions to only the CURRENT amendment term before
 * calling the CPQ amender, preventing all year-segments from loading as
 * quote lines. Handles three subscription categories:
 *
 *   1. MDQ (multi-year segmented) subs  — filtered by SegmentStartDate/SegmentEndDate covering today
 *   2. Non-MDQ (no segment dates) subs  — filtered by StartDate/EndDate covering today, active only
 *   3. Terminated subs                  — always excluded via TerminatedDate__c = null
 * 
 * 
 * APIVERSION	  Developer	     DATE	       Jira Ticket No
    63            Anil Kumar    05-June-2026    ETE-7197
    63            Anil Kumar    05-June-2026    ETE-9104
    
 **************************************************************************************************/
public class ContractAmendmentProcessorQueueable implements Queueable, Database.AllowsCallouts {

    private List<Id> contractIds;

    @TestVisible
    private static Id testQuoteId;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    public ContractAmendmentProcessorQueueable(List<Id> contractIds) {
        this.contractIds = contractIds == null ? new List<Id>() : contractIds;
        System.debug('ContractAmendmentProcessorQueueable initialized. contractIds=' + this.contractIds);
    }

    // -------------------------------------------------------------------------
    // Queueable execute
    // -------------------------------------------------------------------------

    public void execute(QueueableContext context) {
        System.debug('Queueable execution started. Job Id=' + context.getJobId());
        System.debug('Input contractIds=' + contractIds);

        List<Contract> contracts = [
            SELECT Id,
                   Amendment_Trigger_Status__c,
                   Amendment_Trigger_Payload__c,
                   Amendment_Trigger_Error__c,
                   Amendment_Quote_Id__c,
                   Amendment_Opportunity_Id__c
            FROM Contract
            WHERE Id IN :contractIds
            AND Amendment_Trigger_Status__c = 'Processing'
        ];

        System.debug('Contracts found for processing=' + contracts.size());

        List<Opportunity>  oppsToUpdate      = new List<Opportunity>();
        Map<Id, Id>        oppIdToContractId = new Map<Id, Id>();
        Map<Id, CalloutResult> resultByOppId = new Map<Id, CalloutResult>();
        List<Contract>     contractsToUpdate = new List<Contract>();

        for (Contract con : contracts) {
            System.debug('Processing Contract Id=' + con.Id);
            System.debug('Contract status='         + con.Amendment_Trigger_Status__c);
            System.debug('Contract payload='         + con.Amendment_Trigger_Payload__c);

            try {
                if (String.isBlank(con.Amendment_Trigger_Payload__c)) {
                    System.debug('Payload is blank for Contract Id=' + con.Id);
                    throw new AmendmentException('Payload is blank.');
                }

                Map<String, Object> payload =
                    (Map<String, Object>) JSON.deserializeUntyped(con.Amendment_Trigger_Payload__c);

                System.debug('Deserialized payload=' + payload);

                String payloadContractId = (String) payload.get('contractId');
                System.debug('Payload contractId=' + payloadContractId);

                if (String.isBlank(payloadContractId)) {
                    throw new AmendmentException('Payload missing contractId.');
                }

                if (payloadContractId != String.valueOf(con.Id)) {
                    System.debug(
                        'Contract Id mismatch. Payload contractId=' + payloadContractId +
                        ', Actual Contract Id=' + con.Id
                    );
                    throw new AmendmentException('Payload Contract Id does not match Contract Id.');
                }

                Map<String, Object> opportunityFields =
                    (Map<String, Object>) payload.get('opportunityFields');

                System.debug('Opportunity fields from payload=' + opportunityFields);

                if (opportunityFields == null || opportunityFields.isEmpty()) {
                    throw new AmendmentException('Payload missing opportunityFields.');
                }

                System.debug('Calling CPQ Contract Amender for Contract Id=' + con.Id);

              //  CalloutResult result = amendContract(String.valueOf(con.Id), opportunityFields);
                
                // 
                CalloutResult result;

                if (String.isNotBlank(con.Amendment_Opportunity_Id__c)) {
                    System.debug('Retry detected. Reusing existing Amendment Opportunity=' + con.Amendment_Opportunity_Id__c);
                    
                    result = new CalloutResult();
                    result.quoteId = con.Amendment_Quote_Id__c;
                    result.contractId = String.valueOf(con.Id);
                    result.existingOpportunityId = con.Amendment_Opportunity_Id__c;
                    result.opportunityFields = opportunityFields;
                } else {
                    
                    System.debug(
                        'First attempt. Calling CPQ Contract Amender for Contract=' +
                        con.Id
                    );
                    result = amendContract(String.valueOf(con.Id), opportunityFields);
                }
                 
                //call updateQuoteSalesRep helper
                updateQuoteSalesRep(result.quoteId);
                
                Opportunity opp = prepareOpportunityUpdate(result);
                
               
                System.debug(
                    'CPQ amendment result. Quote Id=' + result.quoteId +
                    ', Contract Id=' + result.contractId
                );

                //Opportunity opp = prepareOpportunityUpdate(result);

                System.debug('Prepared Opportunity update. Opportunity Id=' + opp.Id);
                System.debug('Opportunity update values=' + opp);

                oppsToUpdate.add(opp);
                oppIdToContractId.put(opp.Id, con.Id);
                resultByOppId.put(opp.Id, result);

                System.debug('Mapped Opportunity Id=' + opp.Id + ' to Contract Id=' + con.Id);

            } catch (Exception e) {
                System.debug('ERROR processing Contract Id=' + con.Id);
                System.debug('Error message='   + e.getMessage());
                System.debug('Stack trace='     + e.getStackTraceString());

                contractsToUpdate.add(new Contract(
                    Id = con.Id,
                    Amendment_Trigger_Status__c = 'Failed',
                    Amendment_Trigger_Error__c = e.getMessage()
                ));

                System.debug('Contract marked Failed. Contract Id=' + con.Id);
            }
        }

        // ----- Update Opportunities ------------------------------------------

        System.debug('Total Opportunities to update=' + oppsToUpdate.size());
        System.debug('Total Contracts to update before Opportunity DML=' + contractsToUpdate.size());

        if (!oppsToUpdate.isEmpty()) {
            System.debug('Updating Opportunities...');

            Database.SaveResult[] oppResults = Database.update(oppsToUpdate, false);

            for (Integer i = 0; i < oppResults.size(); i++) {
                Opportunity opp               = oppsToUpdate[i];
                Id          relatedContractId = oppIdToContractId.get(opp.Id);
                CalloutResult calloutResult = resultByOppId.get(opp.Id);
                String quoteIdToStore = calloutResult == null ? null : calloutResult.quoteId;//to avoid null pointer exception

                System.debug('Processing Opportunity DML result. Opportunity Id=' + opp.Id);
                System.debug('Related Contract Id=' + relatedContractId);

                if (oppResults[i].isSuccess()) {
                    System.debug('Opportunity update successful. Id=' + oppResults[i].getId());
                    
                    contractsToUpdate.add(new Contract(
                        Id = relatedContractId,
                        Amendment_Trigger_Status__c = 'Completed',
                        Amendment_Trigger_Error__c = null,
                        Amendment_Quote_Id__c = quoteIdToStore,
                        Amendment_Opportunity_Id__c = opp.Id
                    ));

                    System.debug('Contract marked Completed. Contract Id=' + relatedContractId);
                } else {
                    String errMsg ='';
                    for (Database.Error err : oppResults[i].getErrors()) {
                        System.debug('Opportunity update failed. Error='       + err.getMessage());
                        System.debug('Opportunity update failed. Status Code=' + err.getStatusCode());
                        System.debug('Opportunity update failed. Fields='      + err.getFields());
                        errMsg += err.getMessage() + ' ';
                    }

                    contractsToUpdate.add(new Contract(
                        Id = relatedContractId,
                        Amendment_Trigger_Status__c = 'Failed',
                        Amendment_Trigger_Error__c =errMsg+'',
                        // NEW
                        Amendment_Quote_Id__c = quoteIdToStore,
                        Amendment_Opportunity_Id__c = opp.Id
                    ));

                    System.debug('Contract marked Failed due to Opportunity update failure. Contract Id=' + relatedContractId);
                }
            }
        } else {
            System.debug('No Opportunities to update.');
        }

        // ----- Update Contracts ----------------------------------------------

        System.debug('Total Contracts to update after Opportunity DML=' + contractsToUpdate.size());

        if (!contractsToUpdate.isEmpty()) {
            System.debug('Updating Contracts...');

            Database.SaveResult[] contractResults = Database.update(contractsToUpdate, false);

            for (Integer i = 0; i < contractResults.size(); i++) {
                if (contractResults[i].isSuccess()) {
                    System.debug('Contract update successful. Id=' + contractResults[i].getId());
                } else {
                    for (Database.Error err : contractResults[i].getErrors()) {
                        System.debug('Contract update failed. Error='       + err.getMessage());
                        System.debug('Contract update failed. Status Code=' + err.getStatusCode());
                        System.debug('Contract update failed. Fields='      + err.getFields());
                    }
                }
            }
        } else {
            System.debug('No Contracts to update.');
        }

        System.debug('Queueable execution finished. Job Id=' + context.getJobId());
    }

    // -------------------------------------------------------------------------
    // Inner classes
    // -------------------------------------------------------------------------

    public class CalloutResult {
        public String              quoteId;
        public String              contractId;
        public Map<String, Object> opportunityFields;
        public String existingOpportunityId;//to update the failed amendment opportunity
        
    }

    public class AmendmentException extends Exception {}

    // -------------------------------------------------------------------------
    // getCurrentTermSubscriptionIds
    //
    // Returns ONLY the subscription IDs that belong to the CURRENT amendment
    // term (i.e. whose active segment covers today). Handles two categories:
    //
    //   Category A — MDQ segmented subs:
    //     SegmentStartDate and SegmentEndDate are populated.
    //     A multi-year MDQ contract creates one row per product per year.
    //     We keep only rows where SegmentStartDate <= today <= SegmentEndDate.
    //     Example: a 5-year contract with 10 products = 50 subscription rows.
    //     This query returns only the 10 rows covering the current year.
    //
    //   Category B — Non-MDQ / flat subs (no segment dates):
    //     No SegmentStartDate/SegmentEndDate — spans full contract life.
    //     Included when NOT terminated and StartDate <= today <= EndDate.
    //     Example: "Enterprise Usage - Annual" one-time product.
    //
    //   Terminated — excluded in BOTH queries via TerminatedDate__c = null.
    //     Terminated rows have TerminatedDate__c populated regardless of
    //     whether they are MDQ or non-MDQ.
    //
    // The union of A + B is passed as AmendmentContext.subscriptionIds to
    // the CPQ ContractManipulationAPI.ContractAmender so only current-term
    // lines appear on the amendment quote.
    // -------------------------------------------------------------------------

    @TestVisible
    private static List<Id> getCurrentTermSubscriptionIds(String contractId) {
        Date today = Date.today();
        System.debug('getCurrentTermSubscriptionIds called. contractId=' + contractId + ', today=' + today);

        Set<Id> subIdSet = new Set<Id>();

        // ── Category A: MDQ segmented subscriptions ────────────────────────────
        // Only rows where segment dates exist AND bracket today.
        // Terminated rows are excluded by the TerminatedDate__c = null filter.

        List<SBQQ__Subscription__c> mdqSubs = [
            SELECT Id,
                   SBQQ__Product__r.Name,
                   SBQQ__SegmentStartDate__c,
                   SBQQ__SegmentEndDate__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__Contract__c         = :contractId
            AND   SBQQ__SegmentStartDate__c != null
            AND   SBQQ__SegmentEndDate__c   != null
            AND   SBQQ__SegmentStartDate__c <= :today
            AND   SBQQ__SegmentEndDate__c   >= :today
            AND   SBQQ__TerminatedDate__c   = null
        ];

        System.debug('Category A (MDQ segment) subs found=' + mdqSubs.size());

        for (SBQQ__Subscription__c s : mdqSubs) {
            System.debug(
                'Including MDQ sub. Id=' + s.Id +
                ', Product=' + s.SBQQ__Product__r.Name +
                ', SegStart=' + s.SBQQ__SegmentStartDate__c +
                ', SegEnd='   + s.SBQQ__SegmentEndDate__c
            );
            subIdSet.add(s.Id);
        }

        // ── Category B: Non-MDQ / flat subscriptions ───────────────────────────
        // Segment dates are null — product spans the whole contract life.
        // Include only if still active (not terminated) and covering today.

        List<SBQQ__Subscription__c> nonMdqSubs = [
            SELECT Id,
                   SBQQ__Product__r.Name,
                   SBQQ__StartDate__c,
                   SBQQ__EndDate__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__Contract__c         = :contractId
            AND   SBQQ__SegmentStartDate__c = null
            AND   SBQQ__SegmentEndDate__c   = null
            AND   SBQQ__TerminatedDate__c   = null
            AND   SBQQ__StartDate__c        <= :today
            AND   SBQQ__EndDate__c          >= :today
        ];

        System.debug('Category B (Non-MDQ) subs found=' + nonMdqSubs.size());

        for (SBQQ__Subscription__c s : nonMdqSubs) {
            System.debug(
                'Including Non-MDQ sub. Id=' + s.Id +
                ', Product=' + s.SBQQ__Product__r.Name +
                ', Start=' + s.SBQQ__StartDate__c +
                ', End='   + s.SBQQ__EndDate__c
            );
            subIdSet.add(s.Id);
        }

        System.debug('Total current-term subscription IDs to pass to CPQ=' + subIdSet.size());

        if (subIdSet.isEmpty()) {
            System.debug(
                'WARNING: Zero current-term subscriptions found for Contract=' + contractId +
                '. Today=' + today +
                '. Check SBQQ__SegmentStartDate__c, SBQQ__SegmentEndDate__c, ' +
                'SBQQ__StartDate__c, SBQQ__EndDate__c, and SBQQ__TerminatedDate__c on subscriptions.'
            );
        }

        return new List<Id>(subIdSet);
    }

    // -------------------------------------------------------------------------
    // amendContract
    //
    // 1. Resolves current-term subscription IDs via getCurrentTermSubscriptionIds.
    // 2. Wraps them in AmendmentContext and calls CPQ ContractManipulationAPI.
    // 3. Parses the response and returns a CalloutResult with the new Quote Id.
    // -------------------------------------------------------------------------

    public static CalloutResult amendContract(
        String              contractId,
        Map<String, Object> opportunityFields
    ) {
        System.debug('amendContract started. contractId=' + contractId);
        System.debug('Opportunity fields passed to amendContract=' + opportunityFields);

        // ── Test context bypass ────────────────────────────────────────────────
        if (Test.isRunningTest() && testQuoteId != null) {
            System.debug('Test context detected. Returning test quote Id=' + testQuoteId);

            CalloutResult testResult     = new CalloutResult();
            testResult.quoteId           = String.valueOf(testQuoteId);
            testResult.contractId        = contractId;
            testResult.opportunityFields = opportunityFields;

            System.debug('amendContract completed with test result=' + testResult);
            return testResult;
        }

        // ── Step 1: Resolve current-term subscription IDs ──────────────────────
        List<Id> currentTermSubIds = getCurrentTermSubscriptionIds(contractId);

        System.debug('Current-term subscription count=' + currentTermSubIds.size());
        System.debug('Current-term subscription IDs='   + currentTermSubIds);

        if (currentTermSubIds.isEmpty()) {
            throw new AmendmentException(
                'No active subscriptions found for the current amendment term on Contract: ' +
                contractId + '. Today=' + Date.today() +
                '. Verify SBQQ__SegmentStartDate__c/EndDate__c or SBQQ__StartDate__c/EndDate__c ' +
                'covers today and SBQQ__TerminatedDate__c is null.'
            );
        }

        // ── Step 2: Build AmendmentContext ─────────────────────────────────────
        // Passing subscriptionIds tells CPQ to load ONLY these subscriptions
        // into the amendment quote, suppressing all other year-segments.
        // Requires CPQ Winter '21 (API v51+) or later.

        Map<String, Object> amendmentContext = new Map<String, Object>{
            'subscriptionIds' => currentTermSubIds
        };

        String amendmentContextJson = JSON.serialize(amendmentContext);
        System.debug('AmendmentContext JSON=' + amendmentContextJson);

        // ── Step 3: Call CPQ Contract Amender ─────────────────────────────────
        String quoteResponse = SBQQ.ServiceRouter.load(
            'SBQQ.ContractManipulationAPI.ContractAmender',
            contractId,
            amendmentContextJson        // was null — now filters to current term only
        );

        System.debug('CPQ quoteResponse (truncated)=' +
                     (quoteResponse != null && quoteResponse.length() > 500
                         ? quoteResponse.substring(0, 500) + '...'
                         : quoteResponse));

        // ── Step 4: Parse response ─────────────────────────────────────────────
        Map<String, Object> jsonMap =
            (Map<String, Object>) JSON.deserializeUntyped(quoteResponse);

        Map<String, Object> recordMap =
            (Map<String, Object>) jsonMap.get('record');

        System.debug('CPQ record map=' + recordMap);

        if (recordMap == null) {
            throw new AmendmentException('CPQ response missing record node.');
        }

        String quoteId = (String) recordMap.get('Id');
        System.debug('Quote Id returned by CPQ=' + quoteId);

        if (String.isBlank(quoteId)) {
            throw new AmendmentException('CPQ response missing Quote Id.');
        }

        // ── Step 5: Log actual quote line count returned by CPQ ───────────────
        List<Object> lineItems = (List<Object>) jsonMap.get('lineItems');
        Integer lineCount      = lineItems != null ? lineItems.size() : 0;
        System.debug('Quote lines on amendment quote=' + lineCount +
                     ' (expected ~' + currentTermSubIds.size() + ')');

        if (lineCount > currentTermSubIds.size() * 2) {
            System.debug(
                'WARNING: Quote line count (' + lineCount + ') is significantly higher than ' +
                'current-term subscription count (' + currentTermSubIds.size() + '). ' +
                'CPQ may have added child/bundle lines or option lines. Review if expected.'
            );
        }

        CalloutResult result     = new CalloutResult();
        result.quoteId           = quoteId;
        result.contractId        = contractId;
        result.opportunityFields = opportunityFields;

        System.debug('amendContract completed. result=' + result);
        return result;
    }

    // -------------------------------------------------------------------------
    // prepareOpportunityUpdate
    //
    // Fetches the Opportunity linked to the amendment Quote and applies the
    // field values from the payload with proper type conversion.
    // -------------------------------------------------------------------------

    public static Opportunity prepareOpportunityUpdate(CalloutResult result) {
        System.debug('prepareOpportunityUpdate started.');
        System.debug('Quote Id=' + result.quoteId);

        Opportunity opp = new Opportunity();
        
        if (String.isNotBlank(result.existingOpportunityId)) {
            opp.Id = result.existingOpportunityId;
        } else {
            SBQQ__Quote__c quote = [
                SELECT Id,
                SBQQ__Opportunity2__c,
                OwnerId,SBQQ__SalesRep__c
                FROM SBQQ__Quote__c
                WHERE Id = :result.quoteId
                LIMIT 1
            ];
            
            //fetch the ownerId from created quote
            //Update the Sales Rep of quote
           // update new SBQQ__Quote__c(
              //  Id = quote.Id,
              //  SBQQ__SalesRep__c = quote.OwnerId
            //);
            
            System.debug('Quote fetched='          + quote);
            System.debug('Related Opportunity Id=' + quote.SBQQ__Opportunity2__c);
            System.debug('salesRep on Quote'+quote.SBQQ__SalesRep__c);
            
            if (quote.SBQQ__Opportunity2__c == null) {
                throw new AmendmentException('Quote missing related Opportunity.');
            }
            
            opp.Id = quote.SBQQ__Opportunity2__c;
        }
        
        
        
        
        
        
       /* SBQQ__Quote__c quote = [
            SELECT Id,
                   SBQQ__Opportunity2__c
            FROM SBQQ__Quote__c
            WHERE Id = :result.quoteId
            LIMIT 1
        ];*/

        //System.debug('Quote fetched='          + quote);
        //System.debug('Related Opportunity Id=' + quote.SBQQ__Opportunity2__c);

      //  if (quote.SBQQ__Opportunity2__c == null) {
        //    throw new AmendmentException('Quote missing related Opportunity.');
        //}

        //Opportunity opp = new Opportunity();
        //opp.Id = quote.SBQQ__Opportunity2__c;

        Map<String, Schema.SObjectField> oppFieldMap =
            Opportunity.SObjectType.getDescribe().fields.getMap();

        System.debug('Opportunity field map loaded. Total fields=' + oppFieldMap.size());

        for (String fieldApiName : result.opportunityFields.keySet()) {
            System.debug('Processing Opportunity field=' + fieldApiName);

            if (!oppFieldMap.containsKey(fieldApiName)) {
                throw new AmendmentException('Invalid Opportunity field: ' + fieldApiName);
            }

            Schema.DescribeFieldResult fieldDescribe =
                oppFieldMap.get(fieldApiName).getDescribe();

            System.debug('Field type='       + fieldDescribe.getType());
            System.debug('Field updateable=' + fieldDescribe.isUpdateable());

            if (!fieldDescribe.isUpdateable()) {
                throw new AmendmentException('Opportunity field not updateable: ' + fieldApiName);
            }

            Object rawValue       = result.opportunityFields.get(fieldApiName);
            Object convertedValue = convertValue(rawValue, fieldDescribe);

            System.debug('Raw value for '       + fieldApiName + '=' + rawValue);
            System.debug('Converted value for ' + fieldApiName + '=' + convertedValue);

            opp.put(fieldApiName, convertedValue);

            System.debug('Opportunity field set. Field=' + fieldApiName + ', Value=' + convertedValue);
        }

        System.debug('prepareOpportunityUpdate completed. opp=' + opp);
        return opp;
    }
    /******************************************************************************************/
    // Quote salesRep should be owner of the quote
    private static void updateQuoteSalesRep(String quoteId) {
        if (String.isBlank(quoteId)) {
            System.debug('Quote Id is blank. Skipping Sales Rep update.');
            return;
        }
        
        SBQQ__Quote__c quote = [
            SELECT Id,
            OwnerId,
            SBQQ__SalesRep__c
            FROM SBQQ__Quote__c
            WHERE Id = :quoteId
            LIMIT 1
        ];
        
        System.debug(
            'Updating Quote Sales Rep. Quote Id=' + quote.Id +
            ', OwnerId=' + quote.OwnerId +
            ', Current Sales Rep=' + quote.SBQQ__SalesRep__c
        );
        
        //Just update the salesRep on Quote
         update new SBQQ__Quote__c(
                Id = quote.Id,
                SBQQ__SalesRep__c = quote.OwnerId
            );
        System.debug(
                'Quote Sales Rep updated successfully. Quote Id=' + quote.Id +
                ', New Sales Rep=' + quote.OwnerId
            );
        
      /* if (quote.SBQQ__SalesRep__c != quote.OwnerId) {
            update new SBQQ__Quote__c(
                Id = quote.Id,
                SBQQ__SalesRep__c = quote.OwnerId
            );
            
            System.debug(
                'Quote Sales Rep updated successfully. Quote Id=' + quote.Id +
                ', New Sales Rep=' + quote.OwnerId
            );
        } else {
            System.debug(
                'Quote Sales Rep already matches Quote Owner. No update required.'
            );
        }*/
    }
    
   /**********************************************************************************************/
    // -------------------------------------------------------------------------
    // convertValue — maps raw JSON-deserialized values to correct Apex types
    // -------------------------------------------------------------------------

    private static Object convertValue(
        Object                     rawValue,
        Schema.DescribeFieldResult fieldDescribe
    ) {
        System.debug('convertValue called. rawValue=' + rawValue);

        if (rawValue == null) {
            System.debug('Raw value is null. Returning null.');
            return null;
        }

        Schema.DisplayType fieldType = fieldDescribe.getType();
        System.debug('Converting value. Field type=' + fieldType);

        if (fieldType == Schema.DisplayType.Date) {
            Date convertedDate = Date.valueOf(String.valueOf(rawValue));
            System.debug('Converted Date value=' + convertedDate);
            return convertedDate;
        }

        if (fieldType == Schema.DisplayType.DateTime) {
            String dtValue = String.valueOf(rawValue);
            System.debug('Original DateTime value=' + dtValue);

            if (dtValue.contains('T')) {
                dtValue = dtValue.replace('T', ' ');
                System.debug('DateTime value after T replacement=' + dtValue);
            }
            if (dtValue.endsWith('Z')) {
                dtValue = dtValue.substringBeforeLast('Z');
                System.debug('DateTime value after Z removal=' + dtValue);
            }

            Datetime convertedDateTime = Datetime.valueOf(dtValue);
            System.debug('Converted DateTime value=' + convertedDateTime);
            return convertedDateTime;
        }

        if (
            fieldType == Schema.DisplayType.Currency ||
            fieldType == Schema.DisplayType.Double   ||
            fieldType == Schema.DisplayType.Percent
        ) {
            Decimal convertedDecimal = Decimal.valueOf(String.valueOf(rawValue));
            System.debug('Converted Decimal value=' + convertedDecimal);
            return convertedDecimal;
        }

        if (fieldType == Schema.DisplayType.Integer) {
            Integer convertedInteger = Integer.valueOf(String.valueOf(rawValue));
            System.debug('Converted Integer value=' + convertedInteger);
            return convertedInteger;
        }

        if (fieldType == Schema.DisplayType.Boolean) {
            Boolean convertedBoolean = Boolean.valueOf(String.valueOf(rawValue));
            System.debug('Converted Boolean value=' + convertedBoolean);
            return convertedBoolean;
        }

        System.debug('No conversion required. Returning raw value=' + rawValue);
        return rawValue;
    }
}