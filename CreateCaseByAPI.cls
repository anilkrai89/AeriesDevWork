/********************************************************************************* 
ClassName : CreateCaseByAPI 
==================================================================================
Req:  FastField Portal Customer will submit the Forms and It should Create a case in Salesforce.
==================================================================================
VERSION   DEV        DATE            Jira Ticket No
64        Anil Kumar    11-Apr-2026  TEAMS-6002
*********************************************************************************/ 

@RestResource(urlMapping='/CreateCaseAPI/*')
global with sharing class CreateCaseByAPI {

    @HttpPost
    global static String createCase() {
        RestContext.response.addHeader('Content-Type', 'application/json');

        RestRequest req = RestContext.request;
        String body = req.requestBody == null ? null : req.requestBody.toString();

        if (String.isBlank(body)) {
            RestContext.response.statusCode = 400;
            return JSON.serialize(new ApiResponse(false, 'Request body is empty'));
        }

        try {
            List<Wrapper> requestList = new List<Wrapper>();

            if (body.trim().startsWith('[')) {
                requestList = (List<Wrapper>) JSON.deserialize(body, List<Wrapper>.class);
            } else {
                Wrapper singleRequest = (Wrapper) JSON.deserialize(body, Wrapper.class);
                if (singleRequest != null) {
                    requestList.add(singleRequest);
                }
            }

            if (requestList.isEmpty()) {
                RestContext.response.statusCode = 400;
                return JSON.serialize(new ApiResponse(false, 'No records found in request body'));
            }

            Id caseRecordTypeId = getCaseRecordTypeId();
            Id defaultAccountId = getDefaultAccountId();

            Set<String> emailSet = new Set<String>();
            Set<String> submissionIdSet = new Set<String>();

            for (Wrapper item : requestList) {
                if (item == null) {
                    continue;
                }

                if (!String.isBlank(item.contactEmail)) {
                    emailSet.add(normalizeEmail(item.contactEmail));
                }

                if (!String.isBlank(item.externalSubmissionId)) {
                    submissionIdSet.add(item.externalSubmissionId.trim());
                }
            }

            Map<String, Contact> contactByEmail = getContactsByEmail(emailSet);
            Map<String, Case> existingCaseBySubmissionId = getCasesBySubmissionId(submissionIdSet);

            List<Contact> contactsToInsert = new List<Contact>();
            Map<String, Contact> pendingNewContactByEmail = new Map<String, Contact>();

            for (Wrapper item : requestList) {
                if (item == null || String.isBlank(item.contactEmail)) {
                    continue;
                }

                String normalizedEmail = normalizeEmail(item.contactEmail);

                if (!contactByEmail.containsKey(normalizedEmail) &&
                    !pendingNewContactByEmail.containsKey(normalizedEmail)) {

                    Contact newContact = new Contact();
                    newContact.Email = item.contactEmail.trim();
                    newContact.FirstName = item.contactFirstName;
                    newContact.LastName = String.isBlank(item.contactLastName) ? 'FFPortalUser' : item.contactLastName;
                    newContact.IsFFContact__c =true;
                    if (defaultAccountId != null) {
                        newContact.AccountId = defaultAccountId;
                    }

                    contactsToInsert.add(newContact);
                    pendingNewContactByEmail.put(normalizedEmail, newContact);
                }
            }

            if (!contactsToInsert.isEmpty()) {
                insert contactsToInsert;

                for (Contact con : contactsToInsert) {
                    if (!String.isBlank(con.Email)) {
                        contactByEmail.put(normalizeEmail(con.Email), con);
                    }
                }
            }

            List<RequestCasePair> pairs = new List<RequestCasePair>();
            List<CaseResult> results = new List<CaseResult>();

            for (Wrapper item : requestList) {
                if (item == null) {
                    continue;
                }

                if (String.isBlank(item.subject) && String.isBlank(item.descriptionOfIssueOrFeedback)) {
                    continue;
                }

                String submissionId = String.isBlank(item.externalSubmissionId)
                    ? null
                    : item.externalSubmissionId.trim();

                if (!String.isBlank(submissionId) && existingCaseBySubmissionId.containsKey(submissionId)) {
                    Case existingCase = existingCaseBySubmissionId.get(submissionId);

                    CaseResult duplicateResult = new CaseResult();
                    duplicateResult.caseId = existingCase.Id;
                    duplicateResult.subject = existingCase.Subject;
                    duplicateResult.contactId = existingCase.ContactId;
                    duplicateResult.accountId = existingCase.AccountId;
                    duplicateResult.hasAttachment = false;
                    duplicateResult.contentVersionId = null;
                    duplicateResult.isDuplicate = true;
                    duplicateResult.message = 'Duplicate skipped. Existing case found for externalSubmissionId.';
                    results.add(duplicateResult);
                    continue;
                }

                Contact matchedContact;
                if (!String.isBlank(item.contactEmail)) {
                    matchedContact = contactByEmail.get(normalizeEmail(item.contactEmail));
                }

                Case c = new Case();
                c.Subject = item.subject;
                c.Description = item.descriptionOfIssueOrFeedback;
                c.Origin = 'FFPortalAPI';

                if (caseRecordTypeId != null) {
                    c.RecordTypeId = caseRecordTypeId;
                }

                c.FF_WhatPartOfPlatforms__c = item.whatPartOfThePlatform;
                c.Form_Name__c = item.formName;
                c.Field_Name__c = item.fieldName;
                c.App_Version_or_Browser__c = item.appVersionOrBrowser;
                c.FastField_Submission_Id__c = submissionId;

                if (matchedContact != null) {
                    c.ContactId = matchedContact.Id;
                    if (matchedContact.AccountId != null) {
                        c.AccountId = matchedContact.AccountId;
                    }
                }

                pairs.add(new RequestCasePair(item, c));
            }

            if (pairs.isEmpty()) {
                RestContext.response.statusCode = 200;
                return JSON.serialize(new ApiResponse(true, 'No new cases inserted', results));
            }

            List<Case> casesToInsert = new List<Case>();
            for (RequestCasePair pair : pairs) {
                casesToInsert.add(pair.caseRecord);
            }

            Database.SaveResult[] caseSaveResults = Database.insert(casesToInsert, false);

            List<RequestCasePair> insertedPairs = new List<RequestCasePair>();

            for (Integer i = 0; i < caseSaveResults.size(); i++) {
                Database.SaveResult sr = caseSaveResults[i];
                RequestCasePair pair = pairs[i];

                CaseResult r = new CaseResult();
                r.subject = pair.caseRecord.Subject;
                r.contactId = pair.caseRecord.ContactId;
                r.accountId = pair.caseRecord.AccountId;
                r.isDuplicate = false;

                if (sr.isSuccess()) {
                    pair.caseRecord.Id = sr.getId();
                    insertedPairs.add(pair);

                    r.caseId = sr.getId();
                    r.hasAttachment = !String.isBlank(pair.requestData.fileName) &&
                                      !String.isBlank(pair.requestData.fileBodyBase64);
                    r.message = 'Case created successfully';
                } else {
                    String errMsg = sr.getErrors()[0].getMessage();
                    r.caseId = null;
                    r.hasAttachment = false;
                    r.message = errMsg;

                    if (errMsg != null && errMsg.toLowerCase().contains('duplicate')) {
                        r.isDuplicate = true;
                    }
                }

                results.add(r);
            }

            List<ContentVersion> filesToInsert = new List<ContentVersion>();
            List<Id> fileCaseIdsInOrder = new List<Id>();

            for (RequestCasePair pair : insertedPairs) {
                Wrapper item = pair.requestData;
                Case insertedCase = pair.caseRecord;

                if (!String.isBlank(item.fileName) && !String.isBlank(item.fileBodyBase64)) {
                    String base64Data = sanitizeBase64(item.fileBodyBase64);

                    ContentVersion cv = new ContentVersion();
                    cv.Title = getSafeTitle(item.fileName);
                    cv.PathOnClient = '/' + item.fileName;
                    cv.VersionData = EncodingUtil.base64Decode(base64Data);
                    cv.FirstPublishLocationId = insertedCase.Id;

                    filesToInsert.add(cv);
                    fileCaseIdsInOrder.add(insertedCase.Id);
                }
            }

            if (!filesToInsert.isEmpty()) {
                insert filesToInsert;
            }

            Map<Id, String> contentVersionIdByCaseId = new Map<Id, String>();
            for (Integer i = 0; i < filesToInsert.size(); i++) {
                contentVersionIdByCaseId.put(fileCaseIdsInOrder[i], filesToInsert[i].Id);
            }

            for (CaseResult r : results) {
                if (r.caseId != null && r.hasAttachment && contentVersionIdByCaseId.containsKey((Id)r.caseId)) {
                    r.contentVersionId = contentVersionIdByCaseId.get((Id)r.caseId);
                }
            }

            RestContext.response.statusCode = 201;
            return JSON.serialize(
                new ApiResponse(
                    true,
                    'Processed request successfully',
                    results
                )
            );

        } catch (System.JSONException e) {
            RestContext.response.statusCode = 400;
            return JSON.serialize(
                new ApiResponse(
                    false,
                    'Invalid JSON format: ' + e.getMessage() + ' | Line: ' + e.getLineNumber()
                )
            );
        } catch (Exception e) {
            RestContext.response.statusCode = 500;
            return JSON.serialize(
                new ApiResponse(
                    false,
                    'Error: ' + e.getMessage() + ' | Line: ' + e.getLineNumber()
                )
            );
        }
    }

    private static String normalizeEmail(String email) {
        return String.isBlank(email) ? null : email.trim().toLowerCase();
    }

    private static Id getCaseRecordTypeId() {
        List<RecordType> rtList = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case'
            AND DeveloperName = :System.Label.FFRecordTypeDeveloperName
            LIMIT 1
        ];
        return rtList.isEmpty() ? null : rtList[0].Id;
    }

    private static Id getDefaultAccountId() {
        String accountName = System.Label.FFDefaultAccountName;
        if (String.isBlank(accountName)) {
            return null;
        }

        List<Account> accList = [
            SELECT Id
            FROM Account
            WHERE Name = :accountName
            LIMIT 1
        ];
        return accList.isEmpty() ? null : accList[0].Id;
    }

    private static Map<String, Contact> getContactsByEmail(Set<String> emailSet) {
        Map<String, Contact> result = new Map<String, Contact>();

        if (emailSet == null || emailSet.isEmpty()) {
            return result;
        }

        for (Contact con : [
            SELECT Id, Email, AccountId, FirstName, LastName
            FROM Contact
            WHERE Email IN :emailSet
        ]) {
            if (!String.isBlank(con.Email)) {
                result.put(normalizeEmail(con.Email), con);
            }
        }

        return result;
    }

    private static Map<String, Case> getCasesBySubmissionId(Set<String> submissionIdSet) {
        Map<String, Case> result = new Map<String, Case>();

        if (submissionIdSet == null || submissionIdSet.isEmpty()) {
            return result;
        }

        for (Case c : [
            SELECT Id, Subject, ContactId, AccountId, FastField_Submission_Id__c
            FROM Case
            WHERE FastField_Submission_Id__c IN :submissionIdSet
        ]) {
            if (!String.isBlank(c.FastField_Submission_Id__c)) {
                result.put(c.FastField_Submission_Id__c, c);
            }
        }

        return result;
    }

    private static String sanitizeBase64(String inputValue) {
        if (String.isBlank(inputValue)) {
            return inputValue;
        }

        String cleaned = inputValue.trim();

        if (cleaned.contains('base64,')) {
            cleaned = cleaned.substringAfter('base64,');
        }

        cleaned = cleaned.replace('\r', '');
        cleaned = cleaned.replace('\n', '');
        cleaned = cleaned.replace(' ', '');

        return cleaned;
    }

    private static String getSafeTitle(String fileName) {
        if (String.isBlank(fileName)) {
            return 'attachment';
        }

        Integer dotIndex = fileName.lastIndexOf('.');
        if (dotIndex > 0) {
            return fileName.substring(0, dotIndex);
        }
        return fileName;
    }

    global class Wrapper {
        public String subject;
        public String whatPartOfThePlatform;
        public String descriptionOfIssueOrFeedback;
        public String formName;
        public String fieldName;
        public String appVersionOrBrowser;

        public String contactEmail;
        public String contactFirstName;
        public String contactLastName;

        public String externalSubmissionId;

        public String fileName;
        public String fileBodyBase64;
        public String contentType;
    }

    global class RequestCasePair {
        public Wrapper requestData;
        public Case caseRecord;

        public RequestCasePair(Wrapper requestData, Case caseRecord) {
            this.requestData = requestData;
            this.caseRecord = caseRecord;
        }
    }

    global class CaseResult {
        public String caseId;
        public String subject;
        public String contactId;
        public String accountId;
        public Boolean hasAttachment;
        public String contentVersionId;
        public Boolean isDuplicate;
        public String message;
    }

    global class ApiResponse {
        public Boolean success;
        public String message;
        public List<CaseResult> results;

        public ApiResponse(Boolean success, String message) {
            this.success = success;
            this.message = message;
            this.results = new List<CaseResult>();
        }

        public ApiResponse(Boolean success, String message, List<CaseResult> results) {
            this.success = success;
            this.message = message;
            this.results = results;
        }
    }
}