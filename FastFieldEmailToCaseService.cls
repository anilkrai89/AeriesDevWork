global class FastFieldEmailToCaseService implements Messaging.InboundEmailHandler {

    global Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

        try {
            Id caseOwnerId = getFastFieldSupportQueueId();
            Id fastFieldRecordTypeId = getCaseRecordTypeId('FastField');

            Case c = new Case();
            c.Subject = buildSubject(email);
            c.Description = buildDescription(email);
            c.Origin = 'FastFieldEmail';
            c.Priority = 'P2 - Minor issue identified but need further support';
            c.RecordTypeId = fastFieldRecordTypeId;
            c.OwnerId = caseOwnerId;

            // Useful standard Case fields
            c.SuppliedEmail = envelope.fromAddress;
            c.SuppliedName = getSenderName(email);
            c.SuppliedCompany = 'Quickbase';

            insert c;

            // Save the inbound email on the Case
            EmailMessage em = new EmailMessage();
            em.ParentId = c.Id;
            em.Incoming = true;
            em.Subject = email.subject;
            em.FromAddress = envelope.fromAddress;
            em.ToAddress = String.join(email.toAddresses == null ? new List<String>() : email.toAddresses, ';');
            em.CcAddress = String.join(email.ccAddresses == null ? new List<String>() : email.ccAddresses, ';');
            em.TextBody = email.plainTextBody;
            em.HtmlBody = email.htmlBody;
            em.MessageDate = System.now();
            em.Status = '3'; // Sent/received email message status value commonly used for stored EmailMessage

            insert em;

            // Save headers if available
            if (email.headers != null && !email.headers.isEmpty()) {
                String headerText = '';

                for (Messaging.InboundEmail.Header h : email.headers) {
                    headerText += h.name + ': ' + h.value + '\n';
                }

                // Store headers in a Case comment.
                // Better option: create a custom long text field like Email_Headers__c on Case.
                CaseComment cc = new CaseComment();
                cc.ParentId = c.Id;
                cc.IsPublished = false;
                cc.CommentBody = 'Email Headers:\n\n' + headerText.left(3900);
                insert cc;
            }
            
            System.debug('case inserted by email services');

            // Attach inbound email attachments to the Case
            List<ContentVersion> filesToInsert = new List<ContentVersion>();

            if (email.binaryAttachments != null) {
                for (Messaging.InboundEmail.BinaryAttachment a : email.binaryAttachments) {
                    filesToInsert.add(new ContentVersion(
                        Title = a.fileName,
                        PathOnClient = a.fileName,
                        VersionData = a.body,
                        FirstPublishLocationId = c.Id
                    ));
                }
            }

            if (email.textAttachments != null) {
                for (Messaging.InboundEmail.TextAttachment a : email.textAttachments) {
                    filesToInsert.add(new ContentVersion(
                        Title = a.fileName,
                        PathOnClient = a.fileName,
                        VersionData = Blob.valueOf(a.body),
                        FirstPublishLocationId = c.Id
                    ));
                }
            }

            if (!filesToInsert.isEmpty()) {
                insert filesToInsert;
            }

            result.success = true;

        } catch (Exception ex) {
            result.success = false;
            result.message = 'Failed to create FastField Case: ' + ex.getMessage();
        }

        return result;
    }

    private static String buildSubject(Messaging.InboundEmail email) {
        if (String.isBlank(email.subject)) {
            return 'FastField Support Request';
        }

        return email.subject.left(255);
    }

    private static String buildDescription(Messaging.InboundEmail email) {
        String body = '';

        if (!String.isBlank(email.plainTextBody)) {
            body = email.plainTextBody;
        } else if (!String.isBlank(email.htmlBody)) {
            body = email.htmlBody.stripHtmlTags();
        } else {
            body = 'No email body was provided.';
        }

        return body;
    }

    private static String getSenderName(Messaging.InboundEmail email) {
        if (!String.isBlank(email.fromName)) {
            return email.fromName;
        }

        return 'Email Sender';
    }

    private static Id getCaseRecordTypeId(String recordTypeDeveloperName) {
        RecordType rt = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case'
            AND DeveloperName = :recordTypeDeveloperName
            LIMIT 1
        ];

        return rt.Id;
    }

    private static Id getFastFieldSupportQueueId() {
        Group q = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND Name = 'FastField Support'
            LIMIT 1
        ];

        return q.Id;
    }
}