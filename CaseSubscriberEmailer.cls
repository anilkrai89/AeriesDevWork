public with sharing class CaseSubscriberEmailer {

    public static void notifyOnCaseInsert(List<Case> newCases) {
        if (newCases == null || newCases.isEmpty()) return;

        // Collect AccountIds from inserted cases
        Set<Id> acctIds = new Set<Id>();
        for (Case c : newCases) {
            if (c.AccountId != null) acctIds.add(c.AccountId);
        }
        if (acctIds.isEmpty()) return;

        // Query active subscriptions for those accounts
        List<Account_Subscription__c> subs = [
            SELECT Account__c, Subscriber__c
            FROM Account_Subscription__c
            WHERE Account__c IN :acctIds
              AND Active__c = true
              AND Subscriber__c != null
        ];
        if (subs.isEmpty()) return;

        // Collect subscriber user ids
        Set<Id> userIds = new Set<Id>();
        for (Account_Subscription__c s : subs) userIds.add(s.Subscriber__c);

        // Query user emails (only active users with an email)
        Map<Id, User> usersById = new Map<Id, User>([
            SELECT Id, Email, IsActive
            FROM User
            WHERE Id IN :userIds
        ]);

        // Build Account -> Email recipients map
        Map<Id, Set<String>> acctToEmails = new Map<Id, Set<String>>();
        for (Account_Subscription__c s : subs) {
            User u = usersById.get(s.Subscriber__c);
            if (u == null || !u.IsActive || String.isBlank(u.Email)) continue;

            if (!acctToEmails.containsKey(s.Account__c)) {
                acctToEmails.put(s.Account__c, new Set<String>());
            }
            acctToEmails.get(s.Account__c).add(u.Email);
        }

        if (acctToEmails.isEmpty()) return;

        // ✅ Replacement for getSalesforceBaseUrl()
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();

        // Prepare emails (one email per Case, with all subscribers in To:)
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Case c : newCases) {
            Set<String> toSet = acctToEmails.get(c.AccountId);
            if (toSet == null || toSet.isEmpty()) continue;

            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new List<String>(toSet));

            String subject = 'New Case ' + c.CaseNumber;
            if (!String.isBlank(c.Subject)) subject += ': ' + c.Subject;
            msg.setSubject(subject);

            String body =
                'A new Case was created.\n\n' +
                'Case Number: ' + c.CaseNumber + '\n' +
                'Subject: ' + (c.Subject == null ? '' : c.Subject) + '\n' +
                'Priority: ' + (c.Priority == null ? '' : c.Priority) + '\n' +
                'Status: ' + (c.Status == null ? '' : c.Status) + '\n' +
                'Link: ' + baseUrl + '/' + c.Id + '\n';

            msg.setPlainTextBody(body);
            msg.setSaveAsActivity(false);

            emails.add(msg);
        }

        if (!emails.isEmpty()) {
            System.debug('email sentline 80'+emails);
            Messaging.sendEmail(emails);
        }
    }
}