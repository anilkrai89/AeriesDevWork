@IsTest
private class FFBillingEmailServiceTest {

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
    }

    @IsTest
    static void testCreatesNewCaseFromInboundEmail() {
        EmailMessageHandler.bypassTrigger = true;

        Account acc = getHoldingAccount();

        Contact con = new Contact(
            FirstName = 'Billing',
            LastName = 'Tester',
            Email = 'billing.tester@example.com',
            AccountId = acc.Id
        );
        insert con;

        Messaging.InboundEmail email = buildEmail(
            'Billing Help Needed',
            'billing.tester@example.com',
            'billing@quickbase.com',
            'I need help with my invoice.'
        );

        Messaging.InboundEnvelope envelope = buildEnvelope(
            'billing.tester@example.com',
            'billing@quickbase.com'
        );

        Test.startTest();
        Messaging.InboundEmailResult result =
            new FFBillingEmailService().handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);

        Case c = [
            SELECT Id, Subject, Origin, SuppliedEmail, SuppliedName,
                   SuppliedCompany, ContactId, FastField_Submission_Id__c
            FROM Case
            WHERE SuppliedEmail = 'billing.tester@example.com'
            AND Origin = 'FastFieldBillingEmail'
            LIMIT 1
        ];

        System.assertEquals('Billing Help Needed', c.Subject);
        System.assertEquals('FastFieldBillingEmail', c.Origin);
        System.assertEquals('billing.tester@example.com', c.SuppliedEmail);
        System.assertEquals('Billing Tester', c.SuppliedName);
        System.assertEquals('Quickbase', c.SuppliedCompany);
        System.assertEquals(con.Id, c.ContactId);
        System.assertNotEquals(null, c.FastField_Submission_Id__c);

        List<EmailMessage> emails = [
            SELECT Id, ParentId, Subject, FromAddress, ToAddress, CcAddress, TextBody
            FROM EmailMessage
            WHERE ParentId = :c.Id
        ];

        System.assertEquals(1, emails.size());
        System.assertEquals('Billing Help Needed', emails[0].Subject);
        System.assertEquals('billing.tester@example.com', emails[0].FromAddress);
    }

    @IsTest
    static void testDuplicateEmailUpdatesExistingCase() {
        EmailMessageHandler.bypassTrigger = true;

        Messaging.InboundEmail email = buildEmail(
            'Re: Duplicate Billing Issue',
            'duplicate.sender@example.com',
            'billing@quickbase.com',
            'Duplicate email body.'
        );

        Messaging.InboundEnvelope envelope = buildEnvelope(
            'duplicate.sender@example.com',
            'billing@quickbase.com'
        );

        Test.startTest();

        Messaging.InboundEmailResult firstResult =
            new FFBillingEmailService().handleInboundEmail(email, envelope);

        Messaging.InboundEmailResult secondResult =
            new FFBillingEmailService().handleInboundEmail(email, envelope);

        Test.stopTest();

        System.assertEquals(true, firstResult.success, firstResult.message);
        System.assertEquals(true, secondResult.success, secondResult.message);

        System.assertEquals(
            'Existing billing Case updated. Duplicate Case was not created.',
            secondResult.message
        );

        List<Case> cases = [
            SELECT Id
            FROM Case
            WHERE SuppliedEmail = 'duplicate.sender@example.com'
            AND Origin = 'FastFieldBillingEmail'
        ];

        System.assertEquals(1, cases.size());

        List<EmailMessage> emails = [
            SELECT Id
            FROM EmailMessage
            WHERE ParentId = :cases[0].Id
        ];

        System.assertEquals(2, emails.size());
    }

    @IsTest
    static void testBlankSubjectAndHtmlBodyFallback() {
        EmailMessageHandler.bypassTrigger = true;

        Messaging.InboundEmail email = buildEmail(
            null,
            'html.sender@example.com',
            'billing@quickbase.com',
            null
        );

        email.htmlBody = '<p>Hello <b>Billing</b> Team</p>';

        Messaging.InboundEnvelope envelope = buildEnvelope(
            'html.sender@example.com',
            'billing@quickbase.com'
        );

        Test.startTest();
        Messaging.InboundEmailResult result =
            new FFBillingEmailService().handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);

        Case c = [
            SELECT Subject, Description
            FROM Case
            WHERE SuppliedEmail = 'html.sender@example.com'
            AND Origin = 'FastFieldBillingEmail'
            LIMIT 1
        ];

        System.assertEquals('FastField Billing Request', c.Subject);
        System.assert(c.Description.contains('Hello'));
    }

    @IsTest
    static void testNoBodyFallback() {
        EmailMessageHandler.bypassTrigger = true;

        Messaging.InboundEmail email = buildEmail(
            'No Body Test',
            'nobody.sender@example.com',
            'billing@quickbase.com',
            null
        );

        email.htmlBody = null;

        Messaging.InboundEnvelope envelope = buildEnvelope(
            'nobody.sender@example.com',
            'billing@quickbase.com'
        );

        Test.startTest();
        Messaging.InboundEmailResult result =
            new FFBillingEmailService().handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);

        Case c = [
            SELECT Description
            FROM Case
            WHERE SuppliedEmail = 'nobody.sender@example.com'
            AND Origin = 'FastFieldBillingEmail'
            LIMIT 1
        ];

        System.assertEquals('No email body was provided.', c.Description);
    }

    @IsTest
    static void testCreatesTextAndBinaryAttachmentsAndHeaderComment() {
        EmailMessageHandler.bypassTrigger = true;

        Messaging.InboundEmail email = buildEmail(
            'Billing Attachment Test',
            'attachment.sender@example.com',
            'billing@quickbase.com',
            'Please see attached file.'
        );

        Messaging.InboundEmail.TextAttachment textAttachment =
            new Messaging.InboundEmail.TextAttachment();
        textAttachment.fileName = 'notes.txt';
        textAttachment.body = 'Text attachment content';

        Messaging.InboundEmail.BinaryAttachment binaryAttachment =
            new Messaging.InboundEmail.BinaryAttachment();
        binaryAttachment.fileName = 'invoice.pdf';
        binaryAttachment.body = Blob.valueOf('Fake PDF content');

        email.textAttachments =
            new Messaging.InboundEmail.TextAttachment[] { textAttachment };

        email.binaryAttachments =
            new Messaging.InboundEmail.BinaryAttachment[] { binaryAttachment };

        Messaging.InboundEnvelope envelope = buildEnvelope(
            'attachment.sender@example.com',
            'billing@quickbase.com'
        );

        Test.startTest();
        Messaging.InboundEmailResult result =
            new FFBillingEmailService().handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);

        Case c = [
            SELECT Id
            FROM Case
            WHERE SuppliedEmail = 'attachment.sender@example.com'
            AND Origin = 'FastFieldBillingEmail'
            LIMIT 1
        ];

        List<CaseComment> comments = [
            SELECT Id, CommentBody, IsPublished
            FROM CaseComment
            WHERE ParentId = :c.Id
        ];

        System.assertEquals(1, comments.size());
        System.assertEquals(false, comments[0].IsPublished);
        System.assert(comments[0].CommentBody.contains('Email Headers'));

        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :c.Id
        ];

        System.assertEquals(2, links.size());
    }

    @IsTest
    static void testRequesterEmailUsesXOriginalFromHeader() {
        EmailMessageHandler.bypassTrigger = true;

        Messaging.InboundEmail email = buildEmail(
            'Original Sender Header Test',
            'forwarder@example.com',
            'billing@quickbase.com',
            'Forwarded billing request.'
        );

        Messaging.InboundEmail.Header xOriginalFrom =
            new Messaging.InboundEmail.Header();
        xOriginalFrom.name = 'X-Original-From';
        xOriginalFrom.value = 'Real Customer <real.customer@example.com>';

        email.headers.add(xOriginalFrom);

        Messaging.InboundEnvelope envelope = buildEnvelope(
            'forwarder@example.com',
            'billing@quickbase.com'
        );

        Test.startTest();
        Messaging.InboundEmailResult result =
            new FFBillingEmailService().handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);

        Case c = [
            SELECT SuppliedEmail, SuppliedName
            FROM Case
            WHERE SuppliedEmail = 'real.customer@example.com'
            AND Origin = 'FastFieldBillingEmail'
            LIMIT 1
        ];

        System.assertEquals('real.customer@example.com', c.SuppliedEmail);
        System.assertEquals('Real Customer', c.SuppliedName);
    }

    @IsTest
    static void testRequesterEmailUsesReplyToWhenNoOriginalFrom() {
        EmailMessageHandler.bypassTrigger = true;

        Messaging.InboundEmail email = buildEmail(
            'Reply To Header Test',
            null,
            'billing@quickbase.com',
            'Reply-To billing request.'
        );

        Messaging.InboundEmail.Header replyTo =
            new Messaging.InboundEmail.Header();
        replyTo.name = 'Reply-To';
        replyTo.value = 'Reply Customer <reply.customer@example.com>';

        email.headers.add(replyTo);

        Messaging.InboundEnvelope envelope = buildEnvelope(
            'envelope.sender@example.com',
            'billing@quickbase.com'
        );

        Test.startTest();
        Messaging.InboundEmailResult result =
            new FFBillingEmailService().handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);

        Case c = [
            SELECT SuppliedEmail, SuppliedName
            FROM Case
            WHERE SuppliedEmail = 'reply.customer@example.com'
            AND Origin = 'FastFieldBillingEmail'
            LIMIT 1
        ];

        System.assertEquals('reply.customer@example.com', c.SuppliedEmail);
        System.assertEquals('Reply Customer', c.SuppliedName);
    }

    @IsTest
    static void testEnvelopeFallbackWhenNoHeadersOrFromAddress() {
        EmailMessageHandler.bypassTrigger = true;

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Envelope Fallback Test';
        email.plainTextBody = 'Testing envelope fallback.';
        email.toAddresses = new String[] { 'billing@quickbase.com' };

        Messaging.InboundEnvelope envelope = buildEnvelope(
            'envelope.only@example.com',
            'billing@quickbase.com'
        );

        Test.startTest();
        Messaging.InboundEmailResult result =
            new FFBillingEmailService().handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);

        Case c = [
            SELECT SuppliedEmail, SuppliedName
            FROM Case
            WHERE SuppliedEmail = 'envelope.only@example.com'
            AND Origin = 'FastFieldBillingEmail'
            LIMIT 1
        ];

        System.assertEquals('envelope.only@example.com', c.SuppliedEmail);
    }

    private static Account getHoldingAccount() {
        return [
            SELECT Id
            FROM Account
            WHERE Name = 'Holding Account [DO NOT EDIT]'
            LIMIT 1
        ];
    }

    private static Messaging.InboundEmail buildEmail(
        String subject,
        String fromAddress,
        String toAddress,
        String plainTextBody
    ) {
        Messaging.InboundEmail email = new Messaging.InboundEmail();

        email.subject = subject;
        email.fromAddress = fromAddress;
        email.fromName = 'Billing Tester';
        email.toAddresses = new String[] { toAddress };
        email.ccAddresses = new String[] { 'cc@example.com' };
        email.plainTextBody = plainTextBody;

        Messaging.InboundEmail.Header fromHeader =
            new Messaging.InboundEmail.Header();
        fromHeader.name = 'From';
        fromHeader.value = String.isBlank(fromAddress)
            ? ''
            : 'Billing Tester <' + fromAddress + '>';

        Messaging.InboundEmail.Header toHeader =
            new Messaging.InboundEmail.Header();
        toHeader.name = 'To';
        toHeader.value = toAddress;

        Messaging.InboundEmail.Header originalToHeader =
            new Messaging.InboundEmail.Header();
        originalToHeader.name = 'X-Gm-Original-To';
        originalToHeader.value = toAddress;

        email.headers = new Messaging.InboundEmail.Header[] {
            fromHeader,
            toHeader,
            originalToHeader
        };

        return email;
    }

    private static Messaging.InboundEnvelope buildEnvelope(
        String fromAddress,
        String toAddress
    ) {
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        envelope.fromAddress = fromAddress;
        envelope.toAddress = toAddress;
        return envelope;
    }
}