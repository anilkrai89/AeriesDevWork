/********************************************************************************* 
ClassName : CreateCaseByAPITest
==================================================================================
Req: Validate CreateCaseByAPI REST service for single, bulk, invalid, and attachment requests.
Sol : Test class is designed to validate request parsing, case creation, attachment creation,
      invalid input handling, and response payload/status code verification.
      Supporting Case trigger dependencies are created in test setup.
==================================================================================
VERSION     DEV            DATE            Jira Ticket No
64        Anil Kumar    11-Apr-2026       TEAMS-6002
*********************************************************************************/ 
@IsTest
private class CreateCaseByAPITest {

    @testSetup
    static void setupData() {
        Account acc = new Account(
            Name = 'Holding Account [DO NOT EDIT]',
            Account_Hierarchy_Level__c = 'Global Parent'
        );
        insert acc;

        insert new List<Entitlement>{
            new Entitlement(
                Name = 'default Entitlement',
                AccountId = acc.Id,
                StartDate = System.today(),
                EndDate = System.today().addYears(1)
            ),
            new Entitlement(
                Name = 'P0 Entitlement',
                AccountId = acc.Id,
                StartDate = System.today(),
                EndDate = System.today().addYears(1)
            )
        };

        User u = [
            SELECT Id, Email, FirstName, LastName
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        Contact existingContact = new Contact(
            FirstName = u.FirstName,
            LastName = String.isBlank(u.LastName) ? 'User' : u.LastName,
            Email = u.Email,
            AccountId = acc.Id,
            Active_services__c = 'Essential'
        );
        insert existingContact;
    }

    private static void prepareRestContext(String requestBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/CreateCaseAPI/';
        req.httpMethod = 'POST';
        req.requestBody = requestBody == null ? null : Blob.valueOf(requestBody);

        RestContext.request = req;
        RestContext.response = res;
    }

    private static CreateCaseByAPI.ApiResponse parseResponse(String responseBody) {
        return (CreateCaseByAPI.ApiResponse)
            JSON.deserialize(responseBody, CreateCaseByAPI.ApiResponse.class);
    }

    private static Id getExpectedCaseRecordTypeId() {
        List<RecordType> rtList = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case'
            AND DeveloperName = :System.Label.FFRecordTypeDeveloperName
            LIMIT 1
        ];
        return rtList.isEmpty() ? null : rtList[0].Id;
    }

    @IsTest
    static void testCreateCase_emptyBody() {
        prepareRestContext('');

        Test.startTest();
        String responseBody = CreateCaseByAPI.createCase();
        Test.stopTest();

        CreateCaseByAPI.ApiResponse responseObj = parseResponse(responseBody);

        System.assertEquals(400, RestContext.response.statusCode, responseBody);
        System.assertEquals(false, responseObj.success);
        System.assertEquals('Request body is empty', responseObj.message);
        System.assertEquals(0, responseObj.results.size());
    }

    @IsTest
    static void testCreateCase_singleValidRequest() {
        CreateCaseByAPI.Wrapper payload = new CreateCaseByAPI.Wrapper();
        payload.subject = 'API Test Case';
        payload.descriptionOfIssueOrFeedback = 'Case created from single request';

        prepareRestContext(JSON.serialize(payload));

        Test.startTest();
        String responseBody = CreateCaseByAPI.createCase();
        Test.stopTest();

        CreateCaseByAPI.ApiResponse responseObj = parseResponse(responseBody);

        System.assertEquals(201, RestContext.response.statusCode, responseBody);
        System.assertEquals(true, responseObj.success, responseBody);
        System.assertEquals('Processed request successfully', responseObj.message);
        System.assertEquals(1, responseObj.results.size());
        System.assertEquals('API Test Case', responseObj.results[0].subject);
        System.assertEquals(false, responseObj.results[0].hasAttachment);
        System.assertEquals(false, responseObj.results[0].isDuplicate);
        System.assertEquals('Case created successfully', responseObj.results[0].message);
        System.assertNotEquals(null, responseObj.results[0].caseId);

        Case insertedCase = [
            SELECT Id, Subject, Description, Origin, RecordTypeId
            FROM Case
            WHERE Id = :responseObj.results[0].caseId
            LIMIT 1
        ];

        System.assertEquals('API Test Case', insertedCase.Subject);
        System.assertEquals('Case created from single request', insertedCase.Description);
        System.assertEquals('FFPortalAPI', insertedCase.Origin);

        Id expectedRtId = getExpectedCaseRecordTypeId();
        if (expectedRtId != null) {
            System.assertEquals(expectedRtId, insertedCase.RecordTypeId);
        }
    }

    @IsTest
    static void testCreateCase_bulkRequestWithMixedValidAndInvalidRows() {
        List<CreateCaseByAPI.Wrapper> payload = new List<CreateCaseByAPI.Wrapper>();

        CreateCaseByAPI.Wrapper valid1 = new CreateCaseByAPI.Wrapper();
        valid1.subject = 'Bulk Case 1';
        valid1.descriptionOfIssueOrFeedback = 'Desc 1';
        payload.add(valid1);

        CreateCaseByAPI.Wrapper invalid1 = new CreateCaseByAPI.Wrapper();
        invalid1.subject = '';
        invalid1.descriptionOfIssueOrFeedback = '';
        payload.add(invalid1);

        CreateCaseByAPI.Wrapper valid2 = new CreateCaseByAPI.Wrapper();
        valid2.subject = 'Bulk Case 2';
        valid2.descriptionOfIssueOrFeedback = 'Desc 2';
        payload.add(valid2);

        prepareRestContext(JSON.serialize(payload));

        Test.startTest();
        String responseBody = CreateCaseByAPI.createCase();
        Test.stopTest();

        CreateCaseByAPI.ApiResponse responseObj = parseResponse(responseBody);

        System.assertEquals(201, RestContext.response.statusCode, responseBody);
        System.assertEquals(true, responseObj.success, responseBody);
        System.assertEquals('Processed request successfully', responseObj.message);
        System.assertEquals(2, responseObj.results.size());
        System.assertEquals('Bulk Case 1', responseObj.results[0].subject);
        System.assertEquals('Bulk Case 2', responseObj.results[1].subject);
        System.assertEquals(false, responseObj.results[0].hasAttachment);
        System.assertEquals(false, responseObj.results[1].hasAttachment);
        System.assertEquals(false, responseObj.results[0].isDuplicate);
        System.assertEquals(false, responseObj.results[1].isDuplicate);
        System.assertEquals('Case created successfully', responseObj.results[0].message);
        System.assertEquals('Case created successfully', responseObj.results[1].message);

        List<Case> insertedCases = [
            SELECT Id, Subject, Description, Origin, RecordTypeId
            FROM Case
            WHERE Subject IN ('Bulk Case 1', 'Bulk Case 2')
        ];

        System.assertEquals(2, insertedCases.size());

        Id expectedRtId = getExpectedCaseRecordTypeId();
        Set<String> subjectSet = new Set<String>();

        for (Case c : insertedCases) {
            subjectSet.add(c.Subject);
            System.assertEquals('FFPortalAPI', c.Origin);
            if (expectedRtId != null) {
                System.assertEquals(expectedRtId, c.RecordTypeId);
            }
        }

        System.assert(subjectSet.contains('Bulk Case 1'));
        System.assert(subjectSet.contains('Bulk Case 2'));
    }

    @IsTest
    static void testCreateCase_noValidRecords() {
        List<CreateCaseByAPI.Wrapper> payload = new List<CreateCaseByAPI.Wrapper>();

        CreateCaseByAPI.Wrapper invalid1 = new CreateCaseByAPI.Wrapper();
        invalid1.subject = '';
        invalid1.descriptionOfIssueOrFeedback = '';
        payload.add(invalid1);

        CreateCaseByAPI.Wrapper invalid2 = new CreateCaseByAPI.Wrapper();
        payload.add(invalid2);

        prepareRestContext(JSON.serialize(payload));

        Test.startTest();
        String responseBody = CreateCaseByAPI.createCase();
        Test.stopTest();

        CreateCaseByAPI.ApiResponse responseObj = parseResponse(responseBody);

        System.assertEquals(200, RestContext.response.statusCode, responseBody);
        System.assertEquals(true, responseObj.success);
        System.assertEquals('No new cases inserted', responseObj.message);
        System.assertEquals(0, responseObj.results.size());
    }

    @IsTest
    static void testCreateCase_singleRequestWithAttachment() {
        CreateCaseByAPI.Wrapper payload = new CreateCaseByAPI.Wrapper();
        payload.subject = 'Case With File';
        payload.descriptionOfIssueOrFeedback = 'Includes attachment';
        payload.fileName = 'sample.txt';
        payload.fileBodyBase64 = EncodingUtil.base64Encode(Blob.valueOf('Hello World'));
        payload.contentType = 'text/plain';

        prepareRestContext(JSON.serialize(payload));

        Test.startTest();
        String responseBody = CreateCaseByAPI.createCase();
        Test.stopTest();

        CreateCaseByAPI.ApiResponse responseObj = parseResponse(responseBody);

        System.assertEquals(201, RestContext.response.statusCode, responseBody);
        System.assertEquals(true, responseObj.success);
        System.assertEquals('Processed request successfully', responseObj.message);
        System.assertEquals(1, responseObj.results.size());
        System.assertEquals(true, responseObj.results[0].hasAttachment);
        System.assertEquals(false, responseObj.results[0].isDuplicate);
        System.assertEquals('Case created successfully', responseObj.results[0].message);
        System.assertNotEquals(null, responseObj.results[0].contentVersionId);
        System.assertNotEquals(null, responseObj.results[0].caseId);

        Case insertedCase = [
            SELECT Id, Subject, Origin, RecordTypeId
            FROM Case
            WHERE Id = :responseObj.results[0].caseId
            LIMIT 1
        ];

        System.assertEquals('Case With File', insertedCase.Subject);
        System.assertEquals('FFPortalAPI', insertedCase.Origin);

        Id expectedRtId = getExpectedCaseRecordTypeId();
        if (expectedRtId != null) {
            System.assertEquals(expectedRtId, insertedCase.RecordTypeId);
        }

        ContentVersion cv = [
            SELECT Id, Title, PathOnClient
            FROM ContentVersion
            WHERE Id = :responseObj.results[0].contentVersionId
            LIMIT 1
        ];

        System.assertEquals('sample', cv.Title);
        System.assertEquals('/sample.txt', cv.PathOnClient);
    }

    @IsTest
    static void testCreateCase_fileNameOnly_noAttachmentCreated() {
        CreateCaseByAPI.Wrapper payload = new CreateCaseByAPI.Wrapper();
        payload.subject = 'Case Without File Body';
        payload.descriptionOfIssueOrFeedback = 'No attachment should be created';
        payload.fileName = 'sample.txt';
        payload.fileBodyBase64 = null;

        prepareRestContext(JSON.serialize(payload));

        Test.startTest();
        String responseBody = CreateCaseByAPI.createCase();
        Test.stopTest();

        CreateCaseByAPI.ApiResponse responseObj = parseResponse(responseBody);

        System.assertEquals(201, RestContext.response.statusCode, responseBody);
        System.assertEquals(true, responseObj.success);
        System.assertEquals('Processed request successfully', responseObj.message);
        System.assertEquals(1, responseObj.results.size());
        System.assertEquals(false, responseObj.results[0].hasAttachment);
        System.assertEquals(null, responseObj.results[0].contentVersionId);
        System.assertEquals(false, responseObj.results[0].isDuplicate);
        System.assertEquals('Case created successfully', responseObj.results[0].message);
    }

    @IsTest
    static void testCreateCase_invalidJsonReturns400() {
        prepareRestContext('{"subject":"Test",');

        Test.startTest();
        String responseBody = CreateCaseByAPI.createCase();
        Test.stopTest();

        CreateCaseByAPI.ApiResponse responseObj = parseResponse(responseBody);

        System.assertEquals(400, RestContext.response.statusCode, responseBody);
        System.assertEquals(false, responseObj.success);
        System.assert(
            responseObj.message.startsWith('Invalid JSON format:'),
            'Expected invalid JSON message but got: ' + responseObj.message
        );
    }

 @IsTest
static void testCreateCase_duplicateExternalSubmissionId() {
    CreateCaseByAPI.Wrapper firstPayload = new CreateCaseByAPI.Wrapper();
    firstPayload.subject = 'Original Case';
    firstPayload.descriptionOfIssueOrFeedback = 'First insert';
    firstPayload.externalSubmissionId = 'SUB-001';

    prepareRestContext(JSON.serialize(firstPayload));
    String firstResponse = CreateCaseByAPI.createCase();

    CreateCaseByAPI.ApiResponse firstObj = parseResponse(firstResponse);
    System.assertEquals(201, RestContext.response.statusCode, firstResponse);
    System.assertEquals(true, firstObj.success);
    System.assertEquals('Processed request successfully', firstObj.message);
    System.assertEquals(1, firstObj.results.size());
    System.assertNotEquals(null, firstObj.results[0].caseId);

    CreateCaseByAPI.Wrapper duplicatePayload = new CreateCaseByAPI.Wrapper();
    duplicatePayload.subject = 'Duplicate Case';
    duplicatePayload.descriptionOfIssueOrFeedback = 'Should be skipped';
    duplicatePayload.externalSubmissionId = 'SUB-001';

    prepareRestContext(JSON.serialize(duplicatePayload));
    String secondResponse = CreateCaseByAPI.createCase();

    CreateCaseByAPI.ApiResponse secondObj = parseResponse(secondResponse);

    System.assertEquals(200, RestContext.response.statusCode, secondResponse);
    System.assertEquals(true, secondObj.success);
    System.assertEquals('No new cases inserted', secondObj.message);
    System.assertEquals(1, secondObj.results.size());
    System.assertEquals(true, secondObj.results[0].isDuplicate);
    System.assertEquals(false, secondObj.results[0].hasAttachment);
    System.assertEquals(
        'Duplicate skipped. Existing case found for externalSubmissionId.',
        secondObj.results[0].message
    );
    System.assertEquals(firstObj.results[0].caseId, secondObj.results[0].caseId);
}
    @IsTest
    static void testCreateCase_createsContactWhenEmailProvided() {
        CreateCaseByAPI.Wrapper payload = new CreateCaseByAPI.Wrapper();
        payload.subject = 'Case With Contact';
        payload.descriptionOfIssueOrFeedback = 'Creates contact';
        payload.contactEmail = 'testuser@example.com';
        payload.contactFirstName = 'Test';
        payload.contactLastName = 'User';

        prepareRestContext(JSON.serialize(payload));

        Test.startTest();
        String responseBody = CreateCaseByAPI.createCase();
        Test.stopTest();

        CreateCaseByAPI.ApiResponse responseObj = parseResponse(responseBody);

        System.assertEquals(201, RestContext.response.statusCode, responseBody);
        System.assertEquals(true, responseObj.success);
        System.assertEquals(1, responseObj.results.size());
        System.assertNotEquals(null, responseObj.results[0].contactId);

        Contact con = [
            SELECT Id, Email, FirstName, LastName, AccountId, IsFFContact__c
            FROM Contact
            WHERE Id = :responseObj.results[0].contactId
            LIMIT 1
        ];

        System.assertEquals('testuser@example.com', con.Email);
        System.assertEquals('Test', con.FirstName);
        System.assertEquals('User', con.LastName);
        System.assertEquals(true, con.IsFFContact__c);
    }
}