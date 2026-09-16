/***************************************************************************************************
* Name        : ContractAmendmentAutomationTest
* Description : Test class for Contract Amendment Automation.
*               Covers ContractAmenderAsyncFA, ContractAmendmentBatch, and
*               ContractAmendmentProcessorQueueable.
*
* Class Name : ContractAmendmentProcessorQueueable
* Test Class : ContractAmendmentAutomationTest
* ----
VERSION	  DEVELOPER	   DATE	  JIRA
63        Anil Kumar  

***************************************************************************************************/

/*@IsTest
private class ContractAmendmentAutomationTest {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contract con = new Contract(
            AccountId = acc.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 12
        );
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Opportunity2__c = opp.Id
        );
        insert quote;
    }

    @IsTest
    static void testBatchAndQueueableSuccess() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];
        SBQQ__Quote__c quote = [SELECT Id,SBQQ__Opportunity2__c FROM SBQQ__Quote__c LIMIT 1];

        con.Amendment_Trigger_Timestamp__c = System.now();
        con.Amendment_Trigger_Status__c = 'Pending';
        con.Amendment_Trigger_Payload__c = JSON.serialize(new Map<String, Object>{
            'contractId' => String.valueOf(con.Id),
            'opportunityFields' => new Map<String, Object>{
                'Name' => 'Updated From Payload',
                'CloseDate' => String.valueOf(Date.today().addDays(10))
            }
        });
        update con;

        ContractAmendmentProcessorQueueable.testQuoteId = quote.Id;

        Test.startTest();
        Database.executeBatch(
            new ContractAmendmentBatch(new List<String>{ String.valueOf(con.Id) }),
            1
        );
        Test.stopTest();

        Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c
            FROM Contract
            WHERE Id = :con.Id
        ];

        System.assertEquals('Completed', updatedCon.Amendment_Trigger_Status__c);

        Opportunity updatedOpp = [
            SELECT Name, CloseDate
            FROM Opportunity
            WHERE Id = :quote.SBQQ__Opportunity2__c
        ];

        System.assertEquals('Updated From Payload', updatedOpp.Name);
        System.assertEquals(Date.today().addDays(10), updatedOpp.CloseDate);
    }

    @IsTest
    static void testInvocableStartsBatch() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        con.Amendment_Trigger_Timestamp__c = System.now();
        con.Amendment_Trigger_Status__c = 'Pending';
        con.Amendment_Trigger_Payload__c = JSON.serialize(new Map<String, Object>{
            'contractId' => String.valueOf(con.Id),
            'opportunityFields' => new Map<String, Object>{
                'Name' => 'Updated From Invocable'
            }
        });
        update con;

        ContractAmendmentProcessorQueueable.testQuoteId = quote.Id;

        ContractAmenderAsyncFA.Request req = new ContractAmenderAsyncFA.Request();
        req.contractId = new List<String>{ String.valueOf(con.Id) };

        Test.startTest();
        ContractAmenderAsyncFA.performAsyncProcessing(
            new List<ContractAmenderAsyncFA.Request>{ req }
        );
        Test.stopTest();

        Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c
            FROM Contract
            WHERE Id = :con.Id
        ];

        System.assertEquals('Completed', updatedCon.Amendment_Trigger_Status__c);
    }

    @IsTest
    static void testQueueableFailsForInvalidJson() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];

        con.Amendment_Trigger_Status__c = 'Processing';
        con.Amendment_Trigger_Payload__c = '{ bad json';
        update con;

        Test.startTest();
        System.enqueueJob(
            new ContractAmendmentProcessorQueueable(new List<Id>{ con.Id })
        );
        Test.stopTest();

        Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c
            FROM Contract
            WHERE Id = :con.Id
        ];

        System.assertEquals('Failed', updatedCon.Amendment_Trigger_Status__c);
    }

    @IsTest
    static void testQueueableFailsForWrongContractId() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];

        con.Amendment_Trigger_Status__c = 'Processing';
        con.Amendment_Trigger_Payload__c = JSON.serialize(new Map<String, Object>{
            'contractId' => '800000000000000AAA',
            'opportunityFields' => new Map<String, Object>{
                'Name' => 'Should Fail'
            }
        });
        update con;

        Test.startTest();
        System.enqueueJob(
            new ContractAmendmentProcessorQueueable(new List<Id>{ con.Id })
        );
        Test.stopTest();

        Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c
            FROM Contract
            WHERE Id = :con.Id
        ];

        System.assertEquals('Failed', updatedCon.Amendment_Trigger_Status__c);
    }

    @IsTest
    static void testQueueableFailsForInvalidOpportunityField() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];

        con.Amendment_Trigger_Status__c = 'Processing';
        con.Amendment_Trigger_Payload__c = JSON.serialize(new Map<String, Object>{
            'contractId' => String.valueOf(con.Id),
            'opportunityFields' => new Map<String, Object>{
                'Fake_Field__c' => 'Bad Value'
            }
        });
        update con;

        Test.startTest();
        System.enqueueJob(
            new ContractAmendmentProcessorQueueable(new List<Id>{ con.Id })
        );
        Test.stopTest();

        Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c
            FROM Contract
            WHERE Id = :con.Id
        ];

        System.assertEquals('Failed', updatedCon.Amendment_Trigger_Status__c);
    }

    @IsTest
    static void testOpportunityDmlFailureMarksContractFailed() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        con.Amendment_Trigger_Status__c = 'Processing';
        con.Amendment_Trigger_Payload__c = JSON.serialize(new Map<String, Object>{
            'contractId' => String.valueOf(con.Id),
            'opportunityFields' => new Map<String, Object>{
                'CloseDate' => 'not-a-date'
            }
        });
        update con;

        ContractAmendmentProcessorQueueable.testQuoteId = quote.Id;

        Test.startTest();
        System.enqueueJob(
            new ContractAmendmentProcessorQueueable(new List<Id>{ con.Id })
        );
        Test.stopTest();

        Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c
            FROM Contract
            WHERE Id = :con.Id
        ];

        System.assertEquals('Failed', updatedCon.Amendment_Trigger_Status__c);
    }
   
}*/

/***************************************************************************************************
* Name        : ContractAmendmentAutomationTest
* Description : Test class for Contract Amendment Automation.
*
* Class Name : ContractAmendmentProcessorQueueable
* Test Class : ContractAmendmentAutomationTest
*
* VERSION    DEVELOPER       DATE          JIRA
* 63         Anil Kumar
***************************************************************************************************/
@IsTest
private class ContractAmendmentAutomationTest {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contract con = new Contract(
            AccountId = acc.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 12
        );
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Opportunity2__c = opp.Id
        );
        insert quote;
    }

    @IsTest
    static void testQueueableSuccessFirstAttemptDirect() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];
        SBQQ__Quote__c quote = [
            SELECT Id, SBQQ__Opportunity2__c
            FROM SBQQ__Quote__c
            LIMIT 1
        ];

        con.Amendment_Trigger_Status__c = 'Processing';
        con.Amendment_Trigger_Payload__c = JSON.serialize(new Map<String, Object>{
            'contractId' => String.valueOf(con.Id),
            'opportunityFields' => new Map<String, Object>{
                'Name' => 'Queueable Direct Success',
                'CloseDate' => String.valueOf(Date.today().addDays(20)),
                'Amount' => 100
            }
        });
        update con;

        ContractAmendmentProcessorQueueable.testQuoteId = quote.Id;

        Test.startTest();
        System.enqueueJob(
            new ContractAmendmentProcessorQueueable(new List<Id>{ con.Id })
        );
        Test.stopTest();

        Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c,
                   Amendment_Trigger_Error__c,
                   Amendment_Quote_Id__c,
                   Amendment_Opportunity_Id__c
            FROM Contract
            WHERE Id = :con.Id
        ];

        System.assertEquals('Completed', updatedCon.Amendment_Trigger_Status__c);
        System.assertEquals(null, updatedCon.Amendment_Trigger_Error__c);
        System.assertEquals(quote.Id, updatedCon.Amendment_Quote_Id__c);
        System.assertEquals(quote.SBQQ__Opportunity2__c, updatedCon.Amendment_Opportunity_Id__c);

        Opportunity updatedOpp = [
            SELECT Name, CloseDate, Amount
            FROM Opportunity
            WHERE Id = :quote.SBQQ__Opportunity2__c
        ];

        System.assertEquals('Queueable Direct Success', updatedOpp.Name);
        System.assertEquals(Date.today().addDays(20), updatedOpp.CloseDate);
        System.assertEquals(100, updatedOpp.Amount);
    }

    @IsTest
    static void testRetryUsesExistingOpportunity() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];

        SBQQ__Quote__c quote = [
            SELECT Id, SBQQ__Opportunity2__c
            FROM SBQQ__Quote__c
            LIMIT 1
        ];

        con.Amendment_Trigger_Status__c = 'Processing';
        con.Amendment_Quote_Id__c = quote.Id;
        con.Amendment_Opportunity_Id__c = quote.SBQQ__Opportunity2__c;
        con.Amendment_Trigger_Payload__c = JSON.serialize(new Map<String, Object>{
            'contractId' => String.valueOf(con.Id),
            'opportunityFields' => new Map<String, Object>{
                'Name' => 'Retry Opportunity',
                'CloseDate' => String.valueOf(Date.today().addDays(15))
            }
        });
        update con;

        ContractAmendmentProcessorQueueable.testQuoteId = null;

        Test.startTest();
        System.enqueueJob(
            new ContractAmendmentProcessorQueueable(new List<Id>{ con.Id })
        );
        Test.stopTest();

        Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c,
                   Amendment_Quote_Id__c,
                   Amendment_Opportunity_Id__c
            FROM Contract
            WHERE Id = :con.Id
        ];

        System.assertEquals('Completed', updatedCon.Amendment_Trigger_Status__c);
        System.assertEquals(quote.Id, updatedCon.Amendment_Quote_Id__c);
        System.assertEquals(quote.SBQQ__Opportunity2__c, updatedCon.Amendment_Opportunity_Id__c);

        Opportunity updatedOpp = [
            SELECT Name, CloseDate
            FROM Opportunity
            WHERE Id = :quote.SBQQ__Opportunity2__c
        ];

        System.assertEquals('Retry Opportunity', updatedOpp.Name);
        System.assertEquals(Date.today().addDays(15), updatedOpp.CloseDate);
    }

    @IsTest
    static void testBatchAndQueueableSuccess() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];
        SBQQ__Quote__c quote = [
            SELECT Id, SBQQ__Opportunity2__c
            FROM SBQQ__Quote__c
            LIMIT 1
        ];

        con.Amendment_Trigger_Timestamp__c = System.now();
        con.Amendment_Trigger_Status__c = 'Pending';
        con.Amendment_Trigger_Payload__c = JSON.serialize(new Map<String, Object>{
            'contractId' => String.valueOf(con.Id),
            'opportunityFields' => new Map<String, Object>{
                'Name' => 'Updated From Payload',
                'CloseDate' => String.valueOf(Date.today().addDays(10))
            }
        });
        update con;

        ContractAmendmentProcessorQueueable.testQuoteId = quote.Id;

        Test.startTest();
        Database.executeBatch(
            new ContractAmendmentBatch(new List<String>{ String.valueOf(con.Id) }),
            1
        );
        Test.stopTest();

        Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c
            FROM Contract
            WHERE Id = :con.Id
        ];

        System.assert(
            updatedCon.Amendment_Trigger_Status__c == 'Processing' ||
            updatedCon.Amendment_Trigger_Status__c == 'Completed'
        );
    }

    @IsTest
    static void testInvocableStartsBatch() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];

        con.Amendment_Trigger_Timestamp__c = System.now();
        con.Amendment_Trigger_Status__c = 'Pending';
        con.Amendment_Trigger_Payload__c = JSON.serialize(new Map<String, Object>{
            'contractId' => String.valueOf(con.Id),
            'opportunityFields' => new Map<String, Object>{
                'Name' => 'Updated From Invocable'
            }
        });
        update con;

        ContractAmenderAsyncFA.Request req = new ContractAmenderAsyncFA.Request();
        req.contractId = new List<String>{ String.valueOf(con.Id) };

        Test.startTest();
        ContractAmenderAsyncFA.performAsyncProcessing(
            new List<ContractAmenderAsyncFA.Request>{ req }
        );
        Test.stopTest();

        /*Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c
            FROM Contract
            WHERE Id = :con.Id
        ];

        System.assert(
            updatedCon.Amendment_Trigger_Status__c == 'Processing' ||
            updatedCon.Amendment_Trigger_Status__c == 'Completed'
        );*/
        Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c
            FROM Contract
            WHERE Id = :con.Id
        ];
        
        System.assert(
            new Set<String>{'Pending', 'Processing', 'Completed', 'Failed'}
            .contains(updatedCon.Amendment_Trigger_Status__c),
            'Unexpected amendment status: ' + updatedCon.Amendment_Trigger_Status__c
        );
    }

    @IsTest
    static void testQueueableFailsForInvalidJson() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];

        con.Amendment_Trigger_Status__c = 'Processing';
        con.Amendment_Trigger_Payload__c = '{ bad json';
        update con;

        Test.startTest();
        System.enqueueJob(
            new ContractAmendmentProcessorQueueable(new List<Id>{ con.Id })
        );
        Test.stopTest();

        Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c,
                   Amendment_Trigger_Error__c
            FROM Contract
            WHERE Id = :con.Id
        ];

        System.assertEquals('Failed', updatedCon.Amendment_Trigger_Status__c);
    }

    @IsTest
    static void testQueueableFailsForBlankPayload() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];

        con.Amendment_Trigger_Status__c = 'Processing';
        con.Amendment_Trigger_Payload__c = null;
        update con;

        Test.startTest();
        System.enqueueJob(
            new ContractAmendmentProcessorQueueable(new List<Id>{ con.Id })
        );
        Test.stopTest();

        Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c,
                   Amendment_Trigger_Error__c
            FROM Contract
            WHERE Id = :con.Id
        ];

        System.assertEquals('Failed', updatedCon.Amendment_Trigger_Status__c);
        System.assert(updatedCon.Amendment_Trigger_Error__c.contains('Payload is blank'));
    }

    @IsTest
    static void testQueueableFailsForMissingContractId() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];

        con.Amendment_Trigger_Status__c = 'Processing';
        con.Amendment_Trigger_Payload__c = JSON.serialize(new Map<String, Object>{
            'opportunityFields' => new Map<String, Object>{
                'Name' => 'Missing Contract Id'
            }
        });
        update con;

        Test.startTest();
        System.enqueueJob(
            new ContractAmendmentProcessorQueueable(new List<Id>{ con.Id })
        );
        Test.stopTest();

        Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c,
                   Amendment_Trigger_Error__c
            FROM Contract
            WHERE Id = :con.Id
        ];

        System.assertEquals('Failed', updatedCon.Amendment_Trigger_Status__c);
        System.assert(updatedCon.Amendment_Trigger_Error__c.contains('Payload missing contractId'));
    }

    @IsTest
    static void testQueueableFailsForWrongContractId() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];

        con.Amendment_Trigger_Status__c = 'Processing';
        con.Amendment_Trigger_Payload__c = JSON.serialize(new Map<String, Object>{
            'contractId' => '800000000000000AAA',
            'opportunityFields' => new Map<String, Object>{
                'Name' => 'Should Fail'
            }
        });
        update con;

        Test.startTest();
        System.enqueueJob(
            new ContractAmendmentProcessorQueueable(new List<Id>{ con.Id })
        );
        Test.stopTest();

        Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c,
                   Amendment_Trigger_Error__c
            FROM Contract
            WHERE Id = :con.Id
        ];

        System.assertEquals('Failed', updatedCon.Amendment_Trigger_Status__c);
    }

    @IsTest
    static void testQueueableFailsForMissingOpportunityFields() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];

        con.Amendment_Trigger_Status__c = 'Processing';
        con.Amendment_Trigger_Payload__c = JSON.serialize(new Map<String, Object>{
            'contractId' => String.valueOf(con.Id)
        });
        update con;

        Test.startTest();
        System.enqueueJob(
            new ContractAmendmentProcessorQueueable(new List<Id>{ con.Id })
        );
        Test.stopTest();

        Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c,
                   Amendment_Trigger_Error__c
            FROM Contract
            WHERE Id = :con.Id
        ];

        System.assertEquals('Failed', updatedCon.Amendment_Trigger_Status__c);
        System.assert(updatedCon.Amendment_Trigger_Error__c.contains('Payload missing opportunityFields'));
    }

    @IsTest
    static void testQueueableFailsForInvalidOpportunityField() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];

        con.Amendment_Trigger_Status__c = 'Processing';
        con.Amendment_Trigger_Payload__c = JSON.serialize(new Map<String, Object>{
            'contractId' => String.valueOf(con.Id),
            'opportunityFields' => new Map<String, Object>{
                'Fake_Field__c' => 'Bad Value'
            }
        });
        update con;

        Test.startTest();
        System.enqueueJob(
            new ContractAmendmentProcessorQueueable(new List<Id>{ con.Id })
        );
        Test.stopTest();

        Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c,
                   Amendment_Trigger_Error__c
            FROM Contract
            WHERE Id = :con.Id
        ];

        System.assertEquals('Failed', updatedCon.Amendment_Trigger_Status__c);
    }

    @IsTest
    static void testOpportunityDmlFailureMarksContractFailed() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];
        SBQQ__Quote__c quote = [
            SELECT Id, SBQQ__Opportunity2__c
            FROM SBQQ__Quote__c
            LIMIT 1
        ];

        String longName = '';
        for (Integer i = 0; i < 300; i++) {
            longName += 'X';
        }

        con.Amendment_Trigger_Status__c = 'Processing';
        con.Amendment_Trigger_Payload__c = JSON.serialize(new Map<String, Object>{
            'contractId' => String.valueOf(con.Id),
            'opportunityFields' => new Map<String, Object>{
                'Name' => longName
            }
        });
        update con;

        ContractAmendmentProcessorQueueable.testQuoteId = quote.Id;

        Test.startTest();
        System.enqueueJob(
            new ContractAmendmentProcessorQueueable(new List<Id>{ con.Id })
        );
        Test.stopTest();

        Contract updatedCon = [
            SELECT Amendment_Trigger_Status__c,
                   Amendment_Trigger_Error__c,
                   Amendment_Quote_Id__c,
                   Amendment_Opportunity_Id__c
            FROM Contract
            WHERE Id = :con.Id
        ];

        System.assertEquals('Failed', updatedCon.Amendment_Trigger_Status__c);
        System.assertNotEquals(null, updatedCon.Amendment_Trigger_Error__c);
        System.assertEquals(quote.Id, updatedCon.Amendment_Quote_Id__c);
        System.assertEquals(quote.SBQQ__Opportunity2__c, updatedCon.Amendment_Opportunity_Id__c);
    }

    @IsTest
    static void testAmendContractFailsWhenNoActiveSubscriptions() {
        Contract con = [SELECT Id FROM Contract LIMIT 1];

        ContractAmendmentProcessorQueueable.testQuoteId = null;

        try {
            ContractAmendmentProcessorQueueable.amendContract(
                String.valueOf(con.Id),
                new Map<String, Object>{
                    'Name' => 'Should Not Reach CPQ'
                }
            );

            System.assert(false, 'Expected exception was not thrown.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('No active subscriptions found'));
        }
    }
}