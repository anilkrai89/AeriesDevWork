/********************************************************************************************************
 * Class Name    : FFBillingEmailService
 * Author        : Anil Kumar
 * Created Date  : 2026-06-02
 *
 * Description:
 * Inbound Email Service used to process FastField Billing emails and
 * automatically create or update Salesforce Cases.
 *
 * Features:
 * - Extracts requester information from email headers.
 * - Applies email blocking rules using Email_Case_Block_Rule__mdt.
 * - Prevents duplicate open Cases using a SHA-256 dedupe key.
 * - Creates new FastField billing Cases when no matching Case exists.
 * - Associates Cases with matching Contacts when available.
 * - Stores inbound emails as EmailMessage records.
 * - Uploads email attachments as Salesforce Files.
 * - Saves email headers as private Case Comments for troubleshooting.
 * - Routes Cases to the FastField Support queue.
 *
 * Notes:
 * - Uses FastField_Submission_Id__c to store the email dedupe key.
 * - Duplicate detection is based on requester email, recipient address,
 *   and normalized email subject.
 * - Blocked emails are skipped and no Case is created.
 *************************************************************************************************************/
global class FFBillingEmailService implements Messaging.InboundEmailHandler {

    private static final String CASE_ORIGIN = 'FastFieldBillingEmail';
    private static final String CASE_RECORD_TYPE_DEVELOPER_NAME = 'FastField';
    private static final String CASE_QUEUE_NAME = 'FastField Support';

    global Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

        try {
            System.debug('FF_BILLING_EMAIL_SERVICE_STARTED');
            System.debug('Inbound Subject: ' + email.subject);
            System.debug('Envelope From: ' + (envelope == null ? null : envelope.fromAddress));
            System.debug('Envelope To: ' + (envelope == null ? null : envelope.toAddress));

            String requesterEmail = getRequesterEmail(email, envelope);
            String requesterName = getRequesterName(email, requesterEmail);
            Contact matchedContact = findContactByEmail(requesterEmail);
            String emailDescription = buildDescription(email);

            String blockReason = getCaseBlockReason(
                email,
                envelope,
                requesterEmail,
                matchedContact,
                emailDescription
            );

            if (!String.isBlank(blockReason)) {
                result.success = true;
                result.message = 'Case creation skipped. Reason: ' + blockReason;
                System.debug(result.message);
                return result;
            }

            String dedupeKey = buildDedupeKey(email, envelope, requesterEmail);
            System.debug('Generated Dedupe Key: ' + dedupeKey);

            Case existingCase = findExistingOpenCase(dedupeKey);

            if (existingCase != null) {
                System.debug('Existing Case found. Attaching email to Case Id: ' + existingCase.Id);

                insertEmailMessage(existingCase.Id, email, envelope, requesterEmail);
                insertAttachments(existingCase.Id, email);
                insertEmailHeadersAsComment(existingCase.Id, email);

                result.success = true;
                result.message = 'Existing billing Case updated. Duplicate Case was not created.';
                return result;
            }

            Case c = new Case();
            c.Subject = buildSubject(email);
            c.Description = emailDescription;

            c.Origin = CASE_ORIGIN;
            c.Priority = 'P2 - Minor issue identified but need further support';

            c.SuppliedEmail = requesterEmail;
            c.SuppliedName = requesterName;
            c.SuppliedCompany = 'Quickbase';

            /*
             * Reusing FastField_Submission_Id__c for email dedupe.
             * For API-created Cases, keep using this field for real FastField submission IDs.
             * For email-created Cases, Origin = FastFieldBillingEmail separates this usage.
             */
            c.FastField_Submission_Id__c = dedupeKey;

            if (matchedContact != null) {
                c.ContactId = matchedContact.Id;
            }

            c.RecordTypeId = getCaseRecordTypeId(CASE_RECORD_TYPE_DEVELOPER_NAME);
            c.OwnerId = getQueueId(CASE_QUEUE_NAME);

            insert c;

            System.debug('New billing Case created. Case Id: ' + c.Id);

            insertEmailMessage(c.Id, email, envelope, requesterEmail);
            insertAttachments(c.Id, email);
            insertEmailHeadersAsComment(c.Id, email);

            result.success = true;
            result.message = 'New billing Case created.';

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'FF_BILLING_EMAIL_SERVICE_FAILED');
            System.debug(LoggingLevel.ERROR, ex.getMessage());
            System.debug(LoggingLevel.ERROR, ex.getStackTraceString());

            result.success = false;
            result.message = 'Failed to process billing email: ' + ex.getMessage();
        }

        return result;
    }

    private static String getCaseBlockReason(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope,
        String requesterEmail,
        Contact matchedContact,
        String description
    ) {
        String normalizedSubject = String.isBlank(email.subject)
            ? ''
            : email.subject.trim().toLowerCase();

        String normalizedDescription = String.isBlank(description)
            ? ''
            : description.trim().toLowerCase();

        String fromEmail = getRequesterEmail(email, envelope);

        String normalizedFromEmail = String.isBlank(fromEmail)
            ? ''
            : fromEmail.trim().toLowerCase();

        String normalizedSuppliedEmail = String.isBlank(requesterEmail)
            ? ''
            : requesterEmail.trim().toLowerCase();

        String normalizedContactEmail = '';

        if (
            matchedContact != null &&
            !String.isBlank(matchedContact.Email)
        ) {
            normalizedContactEmail = matchedContact.Email.trim().toLowerCase();
        }

        List<Email_Case_Block_Rule__mdt> rules = [
            SELECT DeveloperName,
                   Active__c,
                   Subject_Contains__c,
                   Description_Contains__c,
                   From_Email__c,
                   Contact_Email__c,
                   Supplied_Email__c
            FROM Email_Case_Block_Rule__mdt
            WHERE Active__c = true
        ];

        for (Email_Case_Block_Rule__mdt rule : rules) {
            if (matchesContainsList(normalizedSubject, rule.Subject_Contains__c)) {
                return 'Subject matched block rule: ' + rule.DeveloperName;
            }

            if (matchesContainsList(normalizedDescription, rule.Description_Contains__c)) {
                return 'Description matched block rule: ' + rule.DeveloperName;
            }

            if (matchesEmailList(normalizedFromEmail, rule.From_Email__c)) {
                return 'From address matched block rule: ' + rule.DeveloperName;
            }

            if (matchesEmailList(normalizedContactEmail, rule.Contact_Email__c)) {
                return 'Contact email matched block rule: ' + rule.DeveloperName;
            }

            if (matchesEmailList(normalizedSuppliedEmail, rule.Supplied_Email__c)) {
                return 'Supplied email matched block rule: ' + rule.DeveloperName;
            }
        }

        return null;
    }

    private static Boolean matchesContainsList(String sourceValue, String blockedValues) {
        if (String.isBlank(sourceValue) || String.isBlank(blockedValues)) {
            return false;
        }

        List<String> values = blockedValues.split(',');

        for (String value : values) {
            if (String.isBlank(value)) {
                continue;
            }

            String normalizedValue = value.trim().toLowerCase();

            if (
                !String.isBlank(normalizedValue) &&
                sourceValue.contains(normalizedValue)
            ) {
                return true;
            }
        }

        return false;
    }

    private static Boolean matchesEmailList(String sourceEmail, String blockedEmails) {
        if (String.isBlank(sourceEmail) || String.isBlank(blockedEmails)) {
            return false;
        }

        List<String> values = blockedEmails.split(',');

        for (String value : values) {
            if (String.isBlank(value)) {
                continue;
            }

            String normalizedBlockedEmail = value.trim().toLowerCase();

            if (sourceEmail == normalizedBlockedEmail) {
                return true;
            }
        }

        return false;
    }

    private static Contact findContactByEmail(String emailAddress) {
        if (String.isBlank(emailAddress)) {
            return null;
        }

        List<Contact> contacts = [
            SELECT Id, Email, Name, AccountId
            FROM Contact
            WHERE Email = :emailAddress
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        return contacts.isEmpty() ? null : contacts[0];
    }

    private static Case findExistingOpenCase(String dedupeKey) {
        if (String.isBlank(dedupeKey)) {
            return null;
        }

        List<Case> cases = [
            SELECT Id
            FROM Case
            WHERE FastField_Submission_Id__c = :dedupeKey
            AND Origin = :CASE_ORIGIN
            AND IsClosed = false
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        return cases.isEmpty() ? null : cases[0];
    }

    private static String buildDedupeKey(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope,
        String requesterEmail
    ) {
        String originalRecipient = getOriginalRecipient(email, envelope);
        String normalizedSubject = normalizeSubject(email.subject);

        String keySource =
            safeLower(requesterEmail) + '|' +
            safeLower(originalRecipient) + '|' +
            safeLower(normalizedSubject);

        return EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(keySource))
        );
    }

    private static String getRequesterEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {
        String xOriginalFrom = getHeaderValue(email, 'X-Original-From');
        String originalSender = getHeaderValue(email, 'X-Original-Sender');
        String replyTo = getHeaderValue(email, 'Reply-To');
        String fromHeader = getHeaderValue(email, 'From');

        String requesterEmail = extractEmailAddress(xOriginalFrom);

        if (String.isBlank(requesterEmail)) {
            requesterEmail = extractEmailAddress(originalSender);
        }

        if (String.isBlank(requesterEmail)) {
            requesterEmail = extractEmailAddress(replyTo);
        }

        if (String.isBlank(requesterEmail)) {
            requesterEmail = extractEmailAddress(fromHeader);
        }

        if (String.isBlank(requesterEmail) && !String.isBlank(email.fromAddress)) {
            requesterEmail = extractEmailAddress(email.fromAddress);
        }

        if (String.isBlank(requesterEmail) && envelope != null) {
            requesterEmail = extractEmailAddress(envelope.fromAddress);
        }

        return requesterEmail == null ? null : requesterEmail.toLowerCase();
    }

    private static String getRequesterName(
        Messaging.InboundEmail email,
        String requesterEmail
    ) {
        String xOriginalFrom = getHeaderValue(email, 'X-Original-From');
        String replyTo = getHeaderValue(email, 'Reply-To');
        String fromHeader = getHeaderValue(email, 'From');

        String rawNameSource;

        if (!String.isBlank(xOriginalFrom)) {
            rawNameSource = xOriginalFrom;
        } else if (!String.isBlank(replyTo)) {
            rawNameSource = replyTo;
        } else {
            rawNameSource = fromHeader;
        }

        if (!String.isBlank(rawNameSource) && rawNameSource.contains('<')) {
            String namePart = rawNameSource.substringBefore('<').replace('"', '').trim();

            if (!String.isBlank(namePart)) {
                return namePart.left(80);
            }
        }

        if (!String.isBlank(email.fromName)) {
            return email.fromName.left(80);
        }

        if (!String.isBlank(requesterEmail)) {
            return requesterEmail.left(80);
        }

        return 'Email Sender';
    }

    private static String getOriginalRecipient(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {
        String gmOriginalTo = getHeaderValue(email, 'X-Gm-Original-To');

        if (!String.isBlank(gmOriginalTo)) {
            return extractEmailAddress(gmOriginalTo);
        }

        String originalRcpt = getHeaderValue(email, 'X-SFDC-Original-RCPT');

        if (!String.isBlank(originalRcpt)) {
            return extractEmailAddress(originalRcpt);
        }

        String toHeader = getHeaderValue(email, 'To');

        if (!String.isBlank(toHeader)) {
            return extractEmailAddress(toHeader);
        }

        if (envelope != null && !String.isBlank(envelope.toAddress)) {
            return extractEmailAddress(envelope.toAddress);
        }

        return null;
    }

    private static void insertEmailMessage(
        Id caseId,
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope,
        String requesterEmail
    ) {
        EmailMessage em = new EmailMessage();
        em.ParentId = caseId;
        em.Incoming = true;
        em.Subject = String.isBlank(email.subject) ? 'No Subject' : email.subject.left(255);
        em.FromAddress = requesterEmail;
        em.ToAddress = joinAddresses(email.toAddresses);
        em.CcAddress = joinAddresses(email.ccAddresses);
        em.TextBody = email.plainTextBody;
        em.HtmlBody = email.htmlBody;
        em.MessageDate = System.now();
        em.Status = '3';

        insert em;
    }

    private static void insertAttachments(
        Id caseId,
        Messaging.InboundEmail email
    ) {
        List<ContentVersion> filesToInsert = new List<ContentVersion>();

        if (email.binaryAttachments != null) {
            for (Messaging.InboundEmail.BinaryAttachment a : email.binaryAttachments) {
                if (a == null || a.body == null || String.isBlank(a.fileName)) {
                    continue;
                }

                String fileName = a.fileName.left(255);

                filesToInsert.add(new ContentVersion(
                    Title = fileName,
                    PathOnClient = fileName,
                    VersionData = a.body,
                    FirstPublishLocationId = caseId
                ));
            }
        }

        if (email.textAttachments != null) {
            for (Messaging.InboundEmail.TextAttachment a : email.textAttachments) {
                if (a == null || String.isBlank(a.body) || String.isBlank(a.fileName)) {
                    continue;
                }

                String fileName = a.fileName.left(255);

                filesToInsert.add(new ContentVersion(
                    Title = fileName,
                    PathOnClient = fileName,
                    VersionData = Blob.valueOf(a.body),
                    FirstPublishLocationId = caseId
                ));
            }
        }

        if (!filesToInsert.isEmpty()) {
            insert filesToInsert;
        }
    }

    private static void insertEmailHeadersAsComment(
        Id caseId,
        Messaging.InboundEmail email
    ) {
        if (email.headers == null || email.headers.isEmpty()) {
            return;
        }

        String headerText = '';

        for (Messaging.InboundEmail.Header h : email.headers) {
            if (h == null || String.isBlank(h.name)) {
                continue;
            }

            headerText += h.name + ': ' + h.value + '\n';
        }

        if (String.isBlank(headerText)) {
            return;
        }

        CaseComment cc = new CaseComment();
        cc.ParentId = caseId;
        cc.IsPublished = false;
        cc.CommentBody = 'Email Headers:\n\n' + headerText.left(3900);

        insert cc;
    }

    private static String buildSubject(Messaging.InboundEmail email) {
        if (String.isBlank(email.subject)) {
            return 'FastField Billing Request';
        }

        return email.subject.left(255);
    }

    private static String buildDescription(Messaging.InboundEmail email) {
        String body;

        if (!String.isBlank(email.plainTextBody)) {
            body = email.plainTextBody;
        } else if (!String.isBlank(email.htmlBody)) {
            body = email.htmlBody.stripHtmlTags();
        } else {
            body = 'No email body was provided.';
        }

        return body.left(32000);
    }

    private static Id getCaseRecordTypeId(String developerName) {
        List<RecordType> recordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case'
            AND DeveloperName = :developerName
            LIMIT 1
        ];

        if (recordTypes.isEmpty()) {
            throw new FFBillingEmailServiceException(
                'Case Record Type not found: ' + developerName
            );
        }

        return recordTypes[0].Id;
    }

    private static Id getQueueId(String queueName) {
        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND Name = :queueName
            LIMIT 1
        ];

        if (queues.isEmpty()) {
            throw new FFBillingEmailServiceException(
                'Queue not found: ' + queueName
            );
        }

        return queues[0].Id;
    }

    private static String getHeaderValue(
        Messaging.InboundEmail email,
        String headerName
    ) {
        if (email == null || email.headers == null || String.isBlank(headerName)) {
            return null;
        }

        for (Messaging.InboundEmail.Header h : email.headers) {
            if (
                h != null &&
                h.name != null &&
                h.name.equalsIgnoreCase(headerName)
            ) {
                return h.value;
            }
        }

        return null;
    }

    private static String extractEmailAddress(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }

        Pattern p = Pattern.compile(
            '(?i)[A-Z0-9._%+\\-]+@[A-Z0-9.\\-]+\\.[A-Z]{2,}'
        );

        Matcher m = p.matcher(rawValue);

        if (m.find()) {
            return m.group(0).toLowerCase();
        }

        return null;
    }

    private static String normalizeSubject(String subject) {
        if (String.isBlank(subject)) {
            return 'no subject';
        }

        String s = subject.trim().toLowerCase();

        while (
            s.startsWith('re:') ||
            s.startsWith('fw:') ||
            s.startsWith('fwd:')
        ) {
            s = s.substringAfter(':').trim();
        }

        s = s.replaceAll('\\s+', ' ');

        return s.left(200);
    }

    private static String safeLower(String value) {
        return String.isBlank(value) ? '' : value.trim().toLowerCase();
    }

    private static String joinAddresses(List<String> addresses) {
        if (addresses == null || addresses.isEmpty()) {
            return null;
        }

        return String.join(addresses, ';').left(4000);
    }

    public class FFBillingEmailServiceException extends Exception {}
}