/********************************************************************************* 
ClassName : EmailMessageHandler
Test Class :EmailMessageHandler_Test
==================================================================================
Req:Solution to prevent reopening Support cases after 30 days.
Sol :Any Closed Post 30 days will not be Opened and Create a new case by copying all the details from Closed Case.
==================================================================================
History
---------------------------------------------------------------------------------
APIVERSION	  Developer	     DATE	       Jira Ticket No
    62       Anil Kumar    04-Mar-2026     Teams -6629
    62       Anil kumar    06-May-2026     TEAMS-7100
*********************************************************************************/ 
/*******************************************************************************************************/
/**
     * BEFORE INSERT:
     * - For incoming emails whose ParentId is a CLOSED Case:
     *   - reuse newest open child Case if exists, else create a follow-up Case
     *   - mark FollowUpCaseCreated__c on the closed parent
     *   - set EmailMessage.ParentId to the follow-up Case (in memory; saved by before insert)
     *
     * NOTE: No File copying here (EmailMessage.Id is not available yet).
     */


public class EmailMessageHandler {

    private static Boolean isRunning = false;
     public static Boolean bypassTrigger = false;
   
    @TestVisible private static Integer testDaysSinceClosedOverride;

    @TestVisible
    private static Boolean isEligibleClosedCase(Case c) {
        if (c == null) return false;
        if (!c.IsClosed) return false;
        if (c.Type == 'Escalation') return false;
        if (c.TS_Escalation_Case__c != null) return false;

        Integer daysClosed;
        if (Test.isRunningTest() && testDaysSinceClosedOverride != null) {
            daysClosed = testDaysSinceClosedOverride;
        } else {
            if (c.ClosedDate == null) return false;
            daysClosed = c.ClosedDate.date().daysBetween(System.today());
        }

        return daysClosed > 30;
    }
    
    //solvice
    private static final Pattern SOLVICE_JOB_ID_PATTERN = Pattern.compile(
        '(?i)\\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\\b'
    );
 
    public static void handleClosedCaseEmailsBefore(List<EmailMessage> newEmails) {
        
         //Boolean bypassTrigger = false;
        if (bypassTrigger) {
            return;
        }

        Map<String, EmailMessageTrigger__c> emt = EmailMessageTrigger__c.getAll();
        if (!Test.isRunningTest() && !(emt.size() > 0 && emt.get('Activate').IsActive__c)) {
            return;
        }
       System.debug('custom setting EMT value is '+emt.get('Activate').IsActive__c);
        if (isRunning) return;
        isRunning = true;

        try {
            if (newEmails == null || newEmails.isEmpty()) return;

            Map<Id, List<EmailMessage>> caseIdToEmails = new Map<Id, List<EmailMessage>>();
            Set<Id> parentCaseIds = new Set<Id>();
            set<id> contactIds =new set<Id>();

            for (EmailMessage em : newEmails) {
                if (em == null) continue;
                if (em.Incoming != true) continue;

                if (em.ParentId != null && em.ParentId.getSObjectType() == Case.SObjectType) {
                    parentCaseIds.add(em.ParentId);

                    if (!caseIdToEmails.containsKey(em.ParentId)) {
                        caseIdToEmails.put(em.ParentId, new List<EmailMessage>());
                    }
                    caseIdToEmails.get(em.ParentId).add(em);
                }
            }
            if (parentCaseIds.isEmpty()) return;

            Map<Id, Case> allParents = new Map<Id, Case>([
                SELECT Id, CaseNumber, ContactId, AccountId, Subject,
                       Priority, RecordTypeId, OwnerId, FollowUpCaseCreated__c,
                       Issue_Type__c, Type, TS_Escalation_Case__c, ClosedDate, IsClosed,Contact.Name,origin
                FROM Case
                WHERE Id IN :parentCaseIds
            ]);

            Map<Id, Case> closedParents = new Map<Id, Case>();
            for (Id caseId : allParents.keySet()) {
                Case c = allParents.get(caseId);
                if (isEligibleClosedCase(c)) {
                    closedParents.put(caseId, c);
                }
            }
            if (closedParents.isEmpty()) return;

            Set<Id> closedParentIds = closedParents.keySet();

            Map<Id, Id> parentToOpenChild = new Map<Id, Id>();
            for (Case child : [
                SELECT Id, ParentId, CreatedDate
                FROM Case
                WHERE ParentId IN :closedParentIds
                  AND IsClosed = false
                ORDER BY CreatedDate DESC
            ]) {
                if (!parentToOpenChild.containsKey(child.ParentId)) {
                    parentToOpenChild.put(child.ParentId, child.Id);
                }
            }
            //T1 global
            Id t1GlobalQueueId = [
                SELECT Id
                FROM Group
                WHERE Type = 'Queue'
                AND DeveloperName ='T1_Global_Queue'
                LIMIT 1
            ].Id;
            // get the fastfieldQueueID
            Id ffQId = [
                SELECT Id
                FROM Group
                WHERE Type = 'Queue'
                AND DeveloperName ='FastField_Support'
                LIMIT 1
            ].Id;
            // get the solvice QueueID 'solvice'
            Id sQId = [
                SELECT Id
                FROM Group
                WHERE Type = 'Queue'
                AND DeveloperName ='solvice'
                LIMIT 1
            ].Id;
            
            List<Case> toInsert = new List<Case>();
            for (Id parentId : closedParentIds) {
                if (parentToOpenChild.containsKey(parentId)) continue;

                Case p = closedParents.get(parentId);
               /* toInsert.add(new Case(
                    ContactId     = p.ContactId,
                    AccountId     = p.AccountId,
                    Subject       = 'Reopen of Case ' + ' ' + p.CaseNumber + ' - ' + p.Subject,
                    Description   = 'Customer replied to closed case #' + ' ' + p.CaseNumber,
                    Origin        = 'Email',
                    Issue_Type__c = p.Issue_Type__c,
                    Priority      = p.Priority,
                    RecordTypeId  = p.RecordTypeId,
                    ParentId      = p.Id,
                    Status        = 'New'
                ));*/
                //
                Case newCase = new Case(
                    ContactId     = p.ContactId,
                    AccountId     = p.AccountId,
                    Subject       = 'Reopen of Case ' + ' ' + p.CaseNumber + ' - ' + p.Subject,
                    Description   = 'Customer replied to closed case #' + ' ' + p.CaseNumber,
                    Origin        = 'Email',
                    Issue_Type__c = p.Issue_Type__c,
                    Priority      = p.Priority,
                    RecordTypeId  = p.RecordTypeId,
                    ParentId      = p.Id,
                    Status        = 'New'
                    );
                
                // If the old closed case contact is Automation Integration User then make T1 Global queue as owner
                if (p.ContactId != null && p.ContactId == system.label.AutomationIntegrationContactID){
                    //Case newCase =new Case();
                    newCase.OwnerId = t1GlobalQueueId;
                    System.debug('owner is T1 Global queue');
                    
                }
                //for fastfield set the origin ='fastfieldEmail
                if ('FastFieldEmail'.equalsIgnoreCase(p.Origin)) {
                    newcase.Origin = 'FastFieldEmail';
                    newCase.OwnerId =ffQId;
                }
                //for Solvice Case
                if ('solvice'.equalsIgnoreCase(p.Origin)) {
                    newcase.Origin = 'solvice';
                    newCase.OwnerId =sQId;
                }
                
                toInsert.add(newCase);
                
                
            }
           


            if (!toInsert.isEmpty()) {
                insert toInsert;
                for (Case c : toInsert) {
                    parentToOpenChild.put(c.ParentId, c.Id);
                }
            }

            List<Case> toUpdateClosed = new List<Case>();
            for (Id parentId : closedParentIds) {
                Case p = closedParents.get(parentId);
                if (p.FollowUpCaseCreated__c != true) {
                    toUpdateClosed.add(new Case(
                        Id = parentId,
                        FollowUpCaseCreated__c = true
                        
                    ));
                    system.debug('have marked FollowUpCaseCreated__c to true');
                }
            }
            if (!toUpdateClosed.isEmpty()) {
                update toUpdateClosed;
            }

            for (Id closedParentId : caseIdToEmails.keySet()) {
                if (!closedParents.containsKey(closedParentId)) continue;

                Id targetCaseId = parentToOpenChild.get(closedParentId);
                if (targetCaseId == null) continue;

                for (EmailMessage em : caseIdToEmails.get(closedParentId)) {
                    em.ParentId = targetCaseId;
                }
            }

        } finally {
            isRunning = false;
        }
    }

    public static void copyFilesToParentCaseAfter(List<EmailMessage> insertedEmails) {

        Map<String, EmailMessageTrigger__c> emt = EmailMessageTrigger__c.getAll();
        if (!Test.isRunningTest() && !(emt.size() > 0 && emt.get('Activate').IsActive__c)) {
            return;
        }

        if (isRunning) return;
        isRunning = true;

        try {
            if (insertedEmails == null || insertedEmails.isEmpty()) return;

            Map<Id, Id> emailToCase = new Map<Id, Id>();
            for (EmailMessage em : insertedEmails) {
                if (em == null) continue;
                if (em.Incoming != true) continue;
                if (em.Id == null) continue;

                if (em.ParentId != null && em.ParentId.getSObjectType() == Case.SObjectType) {
                    emailToCase.put(em.Id, em.ParentId);
                }
            }
            if (emailToCase.isEmpty()) return;

            List<ContentDocumentLink> emailLinks = [
                SELECT ContentDocumentId, LinkedEntityId, Visibility
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :emailToCase.keySet()
            ];
            if (emailLinks.isEmpty()) return;

            Set<String> desiredKeys = new Set<String>();
            Map<String, String> visibilityByKey = new Map<String, String>();

            for (ContentDocumentLink l : emailLinks) {
                Id targetCaseId = emailToCase.get(l.LinkedEntityId);
                if (targetCaseId == null) continue;

                String key = targetCaseId + ':' + l.ContentDocumentId;
                desiredKeys.add(key);
                visibilityByKey.put(key, l.Visibility);
            }
            if (desiredKeys.isEmpty()) return;

            Set<Id> caseIds = new Set<Id>();
            Set<Id> docIds = new Set<Id>();
            for (String k : desiredKeys) {
                List<String> parts = k.split(':');
                if (parts.size() == 2) {
                    caseIds.add((Id)parts[0]);
                    docIds.add((Id)parts[1]);
                }
            }

            if (!caseIds.isEmpty() && !docIds.isEmpty()) {
                for (ContentDocumentLink existing : [
                    SELECT LinkedEntityId, ContentDocumentId
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId IN :caseIds
                      AND ContentDocumentId IN :docIds
                ]) {
                    desiredKeys.remove(existing.LinkedEntityId + ':' + existing.ContentDocumentId);
                }
            }

            List<ContentDocumentLink> toInsert = new List<ContentDocumentLink>();
            for (String k : desiredKeys) {
                List<String> parts = k.split(':');
                if (parts.size() != 2) continue;

                Id caseId = (Id)parts[0];
                Id docId = (Id)parts[1];

                toInsert.add(new ContentDocumentLink(
                    LinkedEntityId    = caseId,
                    ContentDocumentId = docId,
                    ShareType         = 'V',
                    Visibility        = visibilityByKey.containsKey(k) ? visibilityByKey.get(k) : 'AllUsers'
                ));
            }

            if (!toInsert.isEmpty()) {
                insert toInsert;
            }

        } finally {
            isRunning = false;
        }
    }
    
   
    //Solvice start
    public static void populateSolviceJobIdAfter(
        List<EmailMessage> insertedEmails
    ) {
        /*Map<String, EmailMessageTrigger__c> emt =
            EmailMessageTrigger__c.getAll();
        
        if (
            !Test.isRunningTest() &&
            !(
                emt.size() > 0 &&
                emt.containsKey('Activate') &&
                emt.get('Activate').IsActive__c
            )
        ) {
            return;
        }*/
        
        if (insertedEmails == null || insertedEmails.isEmpty()) {
            return;
        }
        
        Map<Id, String> caseIdToJobId = new Map<Id, String>();
        
        for (EmailMessage emailMessage : insertedEmails) {
            if (emailMessage == null) {
                continue;
            }
            
            // Only process incoming Email-to-Case emails.
            if (emailMessage.Incoming != true) {
                continue;
            }
            
            if (
                emailMessage.ParentId == null ||
                emailMessage.ParentId.getSObjectType() != Case.SObjectType
            ) {
                continue;
            }
            
            String emailBody = '';
            
            if (String.isNotBlank(emailMessage.TextBody)) {
                emailBody += emailMessage.TextBody;
            }
            
            if (String.isNotBlank(emailMessage.HtmlBody)) {
                emailBody += '\n' + emailMessage.HtmlBody;
            }
            
            if (String.isBlank(emailBody)) {
                continue;
            }
            
            Matcher jobIdMatcher =
                SOLVICE_JOB_ID_PATTERN.matcher(emailBody);
            
            if (jobIdMatcher.find()) {
                caseIdToJobId.put(
                    emailMessage.ParentId,
                    jobIdMatcher.group(0).toLowerCase()
                );
            }
            
            System.debug('Incoming: ' + emailMessage.Incoming);
            System.debug('ParentId: ' + emailMessage.ParentId);
            System.debug('TextBody: ' + emailMessage.TextBody);
            System.debug('HtmlBody: ' + emailMessage.HtmlBody);
        }
        
        if (caseIdToJobId.isEmpty()) {
           return;
        }
         // get the solvice QueueID 'solvice'
            Id sQId = [
                SELECT Id
                FROM Group
                WHERE Type = 'Queue'
                AND DeveloperName ='solvice'
                LIMIT 1
            ].Id;
            
        List<Case> casesToUpdate = new List<Case>();
        
        for (Case caseRecord : [
            SELECT Id,
            Origin,
            RecordType.DeveloperName,
            Solvice_Job_ID__c
            FROM Case
            WHERE Id IN :caseIdToJobId.keySet()
        ]) {
            Boolean isSolviceCase =
                caseRecord.Origin == 'solvice' ||
                caseRecord.RecordType.DeveloperName == 'Solvice';
            
            if (!isSolviceCase) {
                continue;
            }
            
            // Prevent overwriting an existing value.
            if (String.isNotBlank(caseRecord.Solvice_Job_ID__c)) {
                continue;
            }
            
            casesToUpdate.add(new Case(
                Id = caseRecord.Id,
                Solvice_Job_ID__c = caseIdToJobId.get(caseRecord.Id),
                ownerId =sQId
            ));
        }
        
        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }//solvice end 
}