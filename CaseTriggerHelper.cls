/********************************************************************************* 
ClassName : CaseTriggerHelperTest
==================================================================================
Req:All the cases which are created by Internal User,does not get associated with Account and Contact and also Entitlment is not being attached.
Sol :It is designed in such a way,it will check for User Contact based on CreatedByID,If Contact exist,same contact will get associated and If no contact found,
     It will Create a Internal Contact and will associate it with case.
==================================================================================
History
---------------------------------------------------------------------------------
APIVERSION	  AUTHOR	     DATE	       Jira Ticket No
    62       Anil Kumar    04-Dec-2024     Teams -3554
    62       Anil Kumar    07-July-2025    TEAMS-4729   
    62       Anil Kumar    21-April-2026   Teams -6002
    62       Anil Kumar    05-May-2026      TEAMS-7236
 
*********************************************************************************/ 

public class CaseTriggerHelper {
    // Timezone used for handling date and time calculations
    public static final String EST_TIMEZONE = 'America/New_York';
    // Type identifier for standard cases
    public static final String STANDARD_TYPE = 'Standard';
    // Set containing the names of weekdays
    public static final Set<String> SET_OF_WEEKDAYS = new Set<String> {'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'};
    // Set containing issue types considered for routing and entitlement
    public static final Set<String> SET_OF_ISSUE_TYPES = new Set<String> {'Non-Technical', 'Technical'};
        
            // This method will process cases and return the updated list of cases
            // public static List<Case> assignContactAndAccount(List<Case> newList) {
        public static void assignContactAndAccount(List<Case> newList) {
            System.debug('Inside assignContactAndAccount. Number of Cases: ' + newList.size());
            
            Set<String> userEmails = new Set<String>();
            Set<Id> createdByIds = new Set<Id>();
            List<Case> casesToUpdate = new List<Case>();
            Set<Id> setOfCaseIds = new Set<Id>();
            Map<Id, Case> mapOfCases = new Map<Id, Case>();
            Map<Id, Id> mapOfCaseIdToContactId = new Map<Id, Id>();
            Map<Id, Id> mapOfCaseIdToAccountId = new Map<Id, Id>();
            Set<String> suppliedEmails = new Set<String>();
            
            for (Case c : newList) {
                if (c.AccountId == null && c.ContactId == null) {
                    createdByIds.add(c.CreatedById);
                    setOfCaseIds.add(c.Id);
                    
                    if (c.Origin == 'FastFieldEmail' && !String.isBlank(c.SuppliedEmail)) {
                        suppliedEmails.add(c.SuppliedEmail.trim().toLowerCase());
                    }
                }
            }
            
            Map<Id, String> userIdToEmailMap = new Map<Id, String>();
            Map<Id, String> usrName = new Map<Id, String>();
            
            for (User user : [
                SELECT Id, Email, Name
                FROM User
                WHERE Id IN :createdByIds
            ]) {
                userIdToEmailMap.put(user.Id, user.Email);
            }
            
            userEmails.addAll(userIdToEmailMap.values());
            
            Map<String, Id> emailToContactIdMap = new Map<String, Id>();
            Map<Id, Id> emailToAccountIdMap = new Map<Id, Id>();
            Map<Id, Id> mapOfConToAccId = new Map<Id, Id>();
            List<Id> accid = new List<Id>();
            
            for (Contact con : [
                SELECT Id, Email, AccountId
                FROM Contact
                WHERE Email IN :userEmails
            ]) {
                emailToContactIdMap.put(con.Email, con.Id);
                accid.add(con.AccountId);
                emailToAccountIdMap.put(con.Id, con.AccountId);
            }
            
            // FastField contact lookup by normalized SuppliedEmail
            Map<String, Contact> suppliedEmailToContactMap = new Map<String, Contact>();
            
            if (!suppliedEmails.isEmpty()) {
                for (Contact con : [
                    SELECT Id, Email, AccountId, FirstName, LastName
                    FROM Contact
                    WHERE Email IN :suppliedEmails
                ]) {
                    if (!String.isBlank(con.Email)) {
                        suppliedEmailToContactMap.put(con.Email.trim().toLowerCase(), con);
                    }
                }
            }
            
            Group caseOwner = [
                SELECT Id
                FROM Group
                WHERE Type = 'Queue'
                AND DeveloperName = 'T1_Global_Queue'
                LIMIT 1
            ];
            
            Group fastFieldQ = [
                SELECT Id
                FROM Group
                WHERE Type = 'Queue'
                AND DeveloperName = 'FastField_Support'
                LIMIT 1
            ];
            
            Entitlement ent = [
                SELECT Id, Name
                FROM Entitlement
                WHERE Name = 'default Entitlement'
                LIMIT 1
            ];
            
            List<Contact> fastFieldContactsToInsert = new List<Contact>();
            Map<Id, Integer> fastFieldCaseToContactIndex = new Map<Id, Integer>();
            
            for (Case cs : newList) {
                System.debug('inside assignContactAcc');
                System.debug('case origin is ' + cs.Origin);
                
                if (cs.Origin != 'FastFieldEmail') {
                    System.debug('Processing Case: ' + cs.Id);
                    
                    if (cs.AccountId == null && cs.ContactId == null && cs.CreatedById != null) {
                        String userEmail = userIdToEmailMap.get(cs.CreatedById);
                        System.debug('created by email is' + userEmail);
                        
                        if (userEmail == 'mb-sf-cpq@quickbase.com') {
                            continue;
                        }
                        //if (userEmail != null && emailToContactIdMap.containsKey(userEmail)){
                        // added cs.Type !='Escalation' so that it should not add the contact of the user who created only escalation case
                        if (userEmail != null && emailToContactIdMap.containsKey(userEmail) && cs.Type !='Escalation') {
                            Case updatedCase = new Case(Id = cs.Id);
                            updatedCase.ContactId = emailToContactIdMap.get(userEmail);
                            updatedCase.AccountId = emailToAccountIdMap.get(updatedCase.ContactId);
                            updatedCase.EntitlementId = ent.Id;
                            
                            if (cs.Type != 'Escalation' && cs.Origin != 'FastFieldEmail') {
                                updatedCase.OwnerId = caseOwner.Id;
                            }
                            
                            casesToUpdate.add(updatedCase);
                        } else {
                            List<Contact> newContact = ContactUtils.getOrCreateContact(createdByIds);
                            
                            System.debug('line 84 ' + newContact);
                            //if (newContact != null && !newContact.isEmpty() && newContact[0] != null) {
                            // added cs.Type !='Escalation' so that it should not add the contact of the user who created only escalation case
                            if (newContact != null && !newContact.isEmpty() && newContact[0] != null && cs.Type !='Escalation') {
                                Case updatedCase = new Case(Id = cs.Id);
                                updatedCase.ContactId = newContact[0].Id;
                                updatedCase.AccountId = newContact[0].AccountId;
                                updatedCase.EntitlementId = ent.Id;
                                
                                if (cs.Type != 'Escalation' && cs.Origin != 'FastFieldEmail') {
                                    updatedCase.OwnerId = caseOwner.Id;
                                }
                                
                                casesToUpdate.add(updatedCase);
                            }
                        }
                    }
                } else if (cs.Origin == 'FastFieldEmail') {
                    if (cs.AccountId == null && cs.ContactId == null && !String.isBlank(cs.SuppliedEmail)) {
                        String normalizedSuppliedEmail = cs.SuppliedEmail.trim().toLowerCase();
                        
                        Contact existingFastFieldContact =
                            suppliedEmailToContactMap.get(normalizedSuppliedEmail);
                        
                        if (existingFastFieldContact != null) {
                            Case updatedCase = new Case(Id = cs.Id);
                            updatedCase.ContactId = existingFastFieldContact.Id;
                            updatedCase.AccountId = existingFastFieldContact.AccountId;
                            updatedCase.OwnerId = fastFieldQ.Id;
                            // updatedCase.EntitlementId = ent.Id;
                            
                            // Do not assign T1 queue for FastFieldEmail cases.
                            casesToUpdate.add(updatedCase);
                        } else {
                            Contact newFFContact = new Contact();
                            newFFContact.Email = normalizedSuppliedEmail;
                            newFFContact.IsFFContact__c = true;
                            
                            if (!String.isBlank(cs.SuppliedName)) {
                                List<String> nameParts = cs.SuppliedName.trim().split('\\s+');
                                
                                if (nameParts.size() > 1) {
                                    newFFContact.FirstName = nameParts[0];
                                    
                                    String lastName = '';
                                    for (Integer i = 1; i < nameParts.size(); i++) {
                                        lastName += (i > 1 ? ' ' : '') + nameParts[i];
                                    }
                                    
                                    newFFContact.LastName = lastName;
                                    newFFContact.IsFFContact__c = true;
                                } else {
                                    newFFContact.LastName = cs.SuppliedName.trim();
                                    newFFContact.IsFFContact__c = true;
                                }
                            } else {
                                newFFContact.LastName = 'FastField';
                                newFFContact.IsFFContact__c = true;
                            }
                            
                            fastFieldContactsToInsert.add(newFFContact);
                            fastFieldCaseToContactIndex.put(cs.Id, fastFieldContactsToInsert.size() - 1);
                        }
                    } else if (cs.AccountId == null && cs.ContactId == null) {
                        Case updatedCase = new Case(Id = cs.Id);
                        updatedCase.OwnerId = fastFieldQ.Id;
                        casesToUpdate.add(updatedCase);
                    }
                }
            }
            
            if (!fastFieldContactsToInsert.isEmpty()) {
                Database.SaveResult[] contactInsertResults =
                    Database.insert(fastFieldContactsToInsert, false);
                
                for (Case cs : newList) {
                    if (fastFieldCaseToContactIndex.containsKey(cs.Id)) {
                        Integer idx = fastFieldCaseToContactIndex.get(cs.Id);
                        Database.SaveResult sr = contactInsertResults[idx];
                        
                        Case updatedCase = new Case(Id = cs.Id);
                        updatedCase.OwnerId = fastFieldQ.Id;
                        
                        if (sr.isSuccess()) {
                            updatedCase.ContactId = sr.getId();
                            // updatedCase.AccountId = fastFieldContactsToInsert[idx].AccountId;
                        } else {
                            System.debug(
                                'FastField Contact insert failed for Case ' + cs.Id +
                                '. SuppliedEmail=' + cs.SuppliedEmail +
                                '. Error=' + sr.getErrors()[0].getStatusCode() +
                                ' - ' + sr.getErrors()[0].getMessage()
                            );
                            
                            // Do not throw exception.
                            // Leave ContactId blank so duplicate Contact rule does not block Case creation.
                        }
                        
                        casesToUpdate.add(updatedCase);
                    }
                }
            }
            
            if (!casesToUpdate.isEmpty()) {
                update casesToUpdate;
            }
        }
    
    
// TEAMS-4729- logic for P0 milestone when case priority is P0 - Critical Customer Issue - No workaround
   /*public static void assignP0Entitlement(Map<Id, Case> newValue, Map<Id, Case> oldValue) {
    Set<Id> assignEntitlementIds = new Set<Id>();
    Set<Id> removeEntitlementIds = new Set<Id>();
    
       // Create a new List<Case> from the map values
    List<Case> newCaseList = new List<Case>(newValue.values());
   
       Entitlement ent = [SELECT Id FROM Entitlement WHERE Name = 'P0 Entitlement' LIMIT 1];

    for (Id caseId : newValue.keySet()) {
        Case newCase = newValue.get(caseId);
        Case oldCase = oldValue.get(caseId);

        if (oldCase != null) {
            Boolean isP0 = newCase.Priority == 'P0 - Critical Customer Issue - No workaround';
            Boolean OldP0 =OldCase.Priority == 'P0 - Critical Customer Issue - No workaround';

            // Check for assignment conditions
            if (isP0 && newCase.Status == 'In Progress' &&
                (oldCase.Status != 'In Progress'|| oldCase.Status == 'Waiting for Customer'/* || OldCase.Status =='Waiting'||
                oldCase.Status == 'On Hold' || oldCase.Status == 'Escalated'*///)) {
               // assignEntitlementIds.add(caseId);
          //  }

            // Check for removal conditions
            //if (isP0 && oldCase.Status == 'In Progress' && (newCase.Status == 'Waiting for Customer'|| newCase.Status =='Escalated' || newCase.Status =='Closed' || newCase.Status =='Awaiting Agent')) {
              //  removeEntitlementIds.add(caseId);
           // }
          /* if (isP0 != OldP0) {
              //On changing the Priority from P0,it should again attach the Normal Entitlement
              assignEntitlementProcessAndQueue1(newCaseList);
             }
        }
    }

    Set<Id> allAffectedIds = new Set<Id>();
    allAffectedIds.addAll(assignEntitlementIds);
    allAffectedIds.addAll(removeEntitlementIds);

    if (!allAffectedIds.isEmpty()) {
        List<Case> casesToUpdate = [SELECT Id, EntitlementId FROM Case WHERE Id IN :allAffectedIds];

        for (Case c : casesToUpdate) {
            if (assignEntitlementIds.contains(c.Id)) {
                c.EntitlementId = ent.Id;
            } else if (removeEntitlementIds.contains(c.Id)) {
                c.EntitlementId = null;
            }
        }

        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }
}*/
    
/*******************************P0 new logic************************************************************************/
     
     public static void assignP0Entitlement(Map<Id, Case> newValue, Map<Id, Case> oldValue) {
    Set<Id> assignEntitlementIds      = new Set<Id>(); // attach P0 entitlement
    Set<Id> removeEntitlementIds      = new Set<Id>(); // detach P0 entitlement
    Set<Id> completeMilestoneCaseIds  = new Set<Id>(); // cases whose P0 milestone must be completed

    // Cases where priority changed FROM P0 → non-P0 → send to normal entitlement logic
    List<Case> priorityChangedFromP0  = new List<Case>();

    // Create a new List<Case> from the map values (if you still need all of them)
    // List<Case> newCaseList = new List<Case>(newValue.values());

    Entitlement ent = [
        SELECT Id
        FROM Entitlement
        WHERE Name = 'P0 Entitlement'
        LIMIT 1
    ];

    for (Id caseId : newValue.keySet()) {
        Case newCase = newValue.get(caseId);
        Case oldCase = oldValue.get(caseId);

        if (oldCase == null) continue;

        Boolean isP0  = newCase.Priority == 'P0 - Critical Customer Issue - No workaround';
        Boolean wasP0 = oldCase.Priority == 'P0 - Critical Customer Issue - No workaround';

        // --- P0 assignment: when case is P0 + moves into In Progress ---
        if (isP0 &&
            newCase.Status == 'In Progress' &&
            (oldCase.Status != 'In Progress' || oldCase.Status == 'Waiting for Customer')) {

            assignEntitlementIds.add(caseId);
        }

        // --- P0 removal / completion conditions ---
        // Example: leaving In Progress to Waiting/Escalated/Closed/Awaiting Agent
        Boolean leavingInProgress = oldCase.Status == 'In Progress' &&
            (newCase.Status == 'Waiting for Customer' ||
             newCase.Status == 'Escalated' ||
             newCase.Status == 'Closed' ||
             newCase.Status == 'Awaiting Agent');

        // 1) Still P0 but left In Progress → complete P0 milestone (and optionally remove entitlement)
        if (isP0 && leavingInProgress) {
            completeMilestoneCaseIds.add(caseId);
            removeEntitlementIds.add(caseId); // if you do NOT want to detach P0 here, comment this out
        }

        // 2) Priority changed FROM P0 → non-P0
        if (wasP0 && !isP0) {
            // Complete any open P0 milestone + remove P0 entitlement
            completeMilestoneCaseIds.add(caseId);
            removeEntitlementIds.add(caseId);

            // Send this case to your "normal" entitlement logic
           // priorityChangedFromP0.add(newCase);
            //System.debug('changing the owner from here');
        }
    }

    // --- COMPLETE open P0 milestones before removing entitlement ---
    if (!completeMilestoneCaseIds.isEmpty()) {
        List<CaseMilestone> msToComplete = [
            SELECT Id, CaseId, CompletionDate
            FROM CaseMilestone
            WHERE CaseId IN :completeMilestoneCaseIds
              AND CompletionDate = null
        ];

        for (CaseMilestone cm : msToComplete) {
            cm.CompletionDate = System.now();
        }

        if (!msToComplete.isEmpty()) {
            update msToComplete;
        }
    }

    // --- Reassign normal entitlement when leaving P0 (priority changed) ---
    if (!priorityChangedFromP0.isEmpty()) {
        assignEntitlementProcessAndQueue1(priorityChangedFromP0);
    }

    // --- Attach / remove P0 entitlement on Case ---
    Set<Id> allAffectedIds = new Set<Id>();
    allAffectedIds.addAll(assignEntitlementIds);
    allAffectedIds.addAll(removeEntitlementIds);

    if (!allAffectedIds.isEmpty()) {
        List<Case> casesToUpdate = [
            SELECT Id, EntitlementId
            FROM Case
            WHERE Id IN :allAffectedIds
        ];

        for (Case c : casesToUpdate) {
            if (assignEntitlementIds.contains(c.Id)) {
                c.EntitlementId = ent.Id;
            } else if (removeEntitlementIds.contains(c.Id)) {
                c.EntitlementId = null;
            }
        }

        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }
}

 

   /* **************************************TEAMS -6035*****************************************/
 /* Assigns an Entitlement Process, creates Entitlements, and routes Cases to the correct Queue
 * based on Support Entitlement CMDT, account tier, contact services, routing issue, and
 * time/holiday windows.
 *
 * High-level flow:
 * 1. Filters the incoming cases to those that:
 *    - Have Account and Contact populated, and
 *    - Have a Routing_Issue_Type__c value in SET_OF_ISSUE_TYPES.
 *    If a Case has no Account and no Contact, it delegates to CaseTriggerHelper.assignContactAndAccount(...)
 *    to populate them.
 *
 * 2. For all eligible Accounts, determines the “highest” Product_Account__c Support_Tier__c
 *    (Signature > Advanced > Core) and stores that per Account.
 *
 * 3. Loads:
 *    - All Holidays, to detect if the case creation date is a holiday.
 *    - All Support_Entitlement__mdt records, building a composite key based on:
 *      Active_services__c, Premium_Support__c, X24x7_Handoff__c, US_Support_Required__c,
 *      Issue_Type__c, Holiday__c, Weekday__c, Start_Time__c, and End_Time__c.
 *
 * 4. For each eligible Case (queried fresh with Contact and Account fields):
 *    - Normalizes SLA “service level” using:
 *        * Contact.Active_Services__c (Essential / Premium / Ultimate / blank) and
 *        * The Account’s highest tier (Core / Advanced / Signature → mapped to Essential / Premium / Ultimate),
 *      choosing the stricter (faster) of the two or falling back to “Standard” when both are blank.
 *    - Derives whether it is a weekday vs. holiday, and which time window (12–7, 7–3, 3–8, 8–12 EST)
 *      the Case.CreatedDate falls into.
 *    - Builds the CMDT key (SLA service, premium flag, 24x7 flag, US-only flag, issue type,
 *      weekday/holiday, time window) and looks up the matching Support_Entitlement__mdt row.
 *    - From the matched CMDT row, collects:
 *        * Entitlement_Process__c (SLA Process name) and
 *        * Route_To__c (Queue name),
 *      and stores them per Case including the CMDT DeveloperName as a “code”.
 *
 * 5. Once mapping is resolved:
 *    - Queries SlaProcess and Group (Queue) records by the collected names.
 *    - Creates Entitlement records for each Case (Name = SLA Process name, SlaProcessId from lookup,
 *      AccountId and Contact__c from the Case).
 *    - Maps each Contact to its inserted Entitlement, then updates each Case to:
 *        * Set EntitlementId to the Entitlement for that Case’s Contact,
 *        * Set OwnerId to the resolved Queue,
 *        * Set Initial_Queue_Owner__c to the Queue name,
 *        * Set Support_Entitlement_Code__c to the CMDT DeveloperName used.
 *
 * 6. Exits without changes if no eligible cases or no SLA/Queue mappings are found.
 *
 * This method is bulkified: it processes all input Cases in a single context and minimizes
 * SOQL/DML usage by using sets, maps, and batched queries.
 */

 /*********************************************************************************************************/ 
  public static void assignEntitlementProcessAndQueue1(List<Case> listOfCase) {
    System.debug('===== ENTERED assignEntitlementProcessAndQueue =====');
    System.debug('Input listOfCase size: ' + (listOfCase != null ? listOfCase.size() : 0));

    Set<Id> setOfCaseIds = new Set<Id>();
    Map<Id, Case> mapOfCases = new Map<Id, Case>();
    Map<Id, Id> mapOfCaseIdToContactId = new Map<Id, Id>();
    Set<Id> conId = new Set<Id>();
    Set<Id> accountIds = new Set<Id>();

      for (Case c : listOfCase) {
          System.debug('Inspecting Case Id=' + c.Id + ', AccountId=' + c.AccountId + ', ContactId=' + c.ContactId + ', Routing Issue=' + c.Routing_Issue_Type__c);
          if (c.AccountId != null && c.ContactId != null && SET_OF_ISSUE_TYPES.contains(c.Routing_Issue_Type__c)) {
              setOfCaseIds.add(c.Id);
              mapOfCases.put(c.Id, c);
              mapOfCaseIdToContactId.put(c.Id, c.ContactId);
              conId.add(c.ContactId);
              accountIds.add(c.AccountId);
          } 
          //solvice
          if(c.Origin =='solvice') {
              System.debug('case is '+c.Origin);
              continue;
          }
          
          else if (c.Id != null && c.AccountId == null && c.ContactId == null) {
              System.debug('line is 510');
              CaseTriggerHelper.assignContactAndAccount(listOfCase);
          }
      }
      
    System.debug('Eligible setOfCaseIds size=' + setOfCaseIds.size());
    if (setOfCaseIds.isEmpty()) {
        System.debug('===== EXIT assignEntitlementProcessAndQueue (no eligible cases) =====');
        return;
    }

    // Highest Product Account tier per Account (Signature > Advanced > Core)
    Map<String, Integer> tierRank = new Map<String, Integer>{ 'Core' => 1, 'Advanced' => 2, 'Signature' => 3 };
    Map<Id, String> accountIdToHighestTier = new Map<Id, String>();
    if (!accountIds.isEmpty()) {
        for (Product_Account__c pa : [
            SELECT Id, Account__c, Support_Tier__c
            FROM Product_Account__c
            WHERE Account__c IN :accountIds
        ]) {
            String t = pa.Support_Tier__c;
            if (String.isBlank(t)) continue;
            String cur = accountIdToHighestTier.get(pa.Account__c);
            if (cur == null || tierRank.get(t) > tierRank.get(cur)) {
                accountIdToHighestTier.put(pa.Account__c, t);
            }
        }
        System.debug('Resolved highest Product Account tier per Account: ' + accountIdToHighestTier);
    }

    // Collections
    Set<String> setOfSLAProcesses = new Set<String>();
    Set<String> setOfQueues = new Set<String>();
    Set<String> setOfHolidays = new Set<String>();
    Map<Id, String> mapOfCaseIdToSLA = new Map<Id, String>();
    Map<Id, String> mapOfCaseIdToQueue = new Map<Id, String>();
    Map<Id, String> mapOfCaseIdToMDTCode = new Map<Id, String>();
    Map<String, Support_Entitlement__mdt> mapOfMDTCodeToMDT = new Map<String, Support_Entitlement__mdt>();

    // Holidays
    for (Holiday h : [SELECT Id, Name, Description, ActivityDate FROM Holiday]) {
        setOfHolidays.add(String.valueOf(h.ActivityDate));
    }

    // CMDT cached by composite key
    for (Support_Entitlement__mdt ent : [
        SELECT Id, DeveloperName, Entitlement_Process__c, Active_services__c,
               X24x7_Handoff__c, Premium_Support__c, US_Support_Required__c,
               Issue_Type__c, Route_To__c, Weekday__c, Holiday__c, Start_Time__c, End_Time__c
        FROM Support_Entitlement__mdt
    ]) {
        String mdtCode = ent.Active_services__c
            + ';' + ent.Premium_Support__c
            + ';' + ent.X24x7_Handoff__c
            + ';' + ent.US_Support_required__c
            + ';' + ent.Issue_Type__c
            + ';' + ent.Holiday__c
            + ';' + ent.Weekday__c
            + ';' + ent.Start_Time__c
            + ';' + ent.End_Time__c;
        mapOfMDTCodeToMDT.put(mdtCode, ent);
    }

    // -------- MAIN LOOP --------
    for (Case c : [
        SELECT Id, Subject, Routing_Issue_Type__c, AccountId, CreatedDate,
               Contact.Active_Services__c, Contact.Premium_Support_Contact__c,
               Contact.X24_7_Hand_off_Contact__c,
               Account.US_support_only__c
        FROM Case
        WHERE Id IN :setOfCaseIds
    ]) {
        // Time window
        DateTime dt = c.CreatedDate;
        String estDateTime = dt.format('yyyy-MM-dd HH:mm:ss', EST_TIMEZONE);
        String estDate = estDateTime.substring(0, 10);
        String hh = estDateTime.substring(11, 13);
        String mm = estDateTime.substring(14, 16);
        String dayName = dt.format('EEEE', EST_TIMEZONE);
        Integer ih = Integer.valueOf(hh), im = Integer.valueOf(mm);
        Boolean isHoliday = setOfHolidays.contains(estDate);
        Boolean isWeekday = SET_OF_WEEKDAYS.contains(dayName);

        String startTime = '', endTime = '';
        if (isWeekday) {
            if ((ih == 0 && im >= 0) || (ih >= 1 && ih <= 5) || (ih == 6 && im <= 59)) {
                startTime = '12:00 AM'; endTime = '07:00 AM';
            } else if ((ih == 7 && im >= 0) || (ih >= 8 && ih <= 13) || (ih == 14 && im <= 59)) {
                startTime = '07:00 AM'; endTime = '03:00 PM';
            } else if ((ih == 15 && im >= 0) || (ih >= 16 && ih <= 18) || (ih == 19 && im <= 59)) {
                startTime = '03:00 PM'; endTime = '08:00 PM';
            } else if ((ih == 20 && im >= 0) || (ih >= 21 && ih <= 22) || (ih == 23 && im <= 59)) {
                startTime = '08:00 PM'; endTime = '12:00 AM';
            }
        } else {
            startTime = '12:00 AM'; endTime = '12:00 AM';
        }

        // ===== SLA SELECTION (new) =====
        String active = c.Contact.Active_Services__c;          // Essential/Premium/Ultimate or blank
        String tier   = accountIdToHighestTier.get(c.AccountId); // Core/Advanced/Signature or null

        // Map Tier → service
        String tierService;
        if ('Signature'.equalsIgnoreCase(tier))      tierService = 'Ultimate';   // 1h
        else if ('Advanced'.equalsIgnoreCase(tier))  tierService = 'Premium';    // 2h
        else if ('Core'.equalsIgnoreCase(tier))      tierService = 'Essential';  // 4h
        else                                         tierService = null;         // no tier

        // Rank: lower is stricter
        Map<String, Integer> rank = new Map<String, Integer>{
            'Ultimate' => 1, 'Premium' => 2, 'Essential' => 3, 'Standard' => 4
        };

        String chosen; // Ultimate/Premium/Essential/Standard
        if (String.isBlank(active) && tierService == null) {
            // both blank → Standard
            chosen = 'Standard';
            System.debug('SLA: Active blank & Tier blank => Standard (24h)');
        } else if (String.isBlank(active)) {
            // only tier present
            chosen = tierService;
            System.debug('SLA: Active blank, Tier=' + tier + ' => ' + chosen);
        } else if (tierService == null) {
            // only active present
            chosen = active;
            System.debug('SLA: Tier blank, Active=' + active + ' => ' + chosen);
        } else {
            // both present → stricter one
            Integer ra = rank.get(active);
            Integer rt = rank.get(tierService);
            chosen = (ra <= rt) ? active : tierService;
            System.debug('SLA: Active=' + active + '(' + ra + '), Tier→' + tierService + '(' + rt + ') => ' + chosen);
        }

        // MDT expects Active_services__c = '' for Standard rows
        String mdtActiveValue = (chosen == 'Standard') ? null : chosen;

        // Premium flag: true only for 2h “Premium” rows; false otherwise (incl. Standard)
        //Boolean premiumFlag = (chosen == 'Premium');
         Boolean premiumFlag =c.Contact.Premium_Support_Contact__c;
        // 24x7 flag comes from Contact
        Boolean x247 = c.Contact.X24_7_Hand_off_Contact__c;

        //System.debug('Normalized SLA -> chosen=' + chosen + ' (mdtActiveValue="' + mdtActiveValue + '"), premium=' + premiumFlag + ', 24x7=' + x247 + ', tier=' + tier + ', active(raw)=' + active);

        // Build MDT key and resolve
        String mdtCode = mdtActiveValue
            + ';' + String.valueOf(premiumFlag)
            + ';' + String.valueOf(x247)
            + ';' + String.valueOf(c.Account.US_support_only__c)
            + ';' + c.Routing_Issue_Type__c
            + ';' + String.valueOf(isHoliday)
            + ';' + String.valueOf(isWeekday)
            + ';' + startTime
            + ';' + endTime;

        Support_Entitlement__mdt row = mapOfMDTCodeToMDT.get(mdtCode);
        if (row != null) {
            setOfSLAProcesses.add(row.Entitlement_Process__c);
            setOfQueues.add(row.Route_To__c);
            mapOfCaseIdToSLA.put(c.Id, row.Entitlement_Process__c);
            mapOfCaseIdToQueue.put(c.Id, row.Route_To__c);
            mapOfCaseIdToMDTCode.put(c.Id, row.DeveloperName);
            System.debug('MDT match OK: ' + row.Entitlement_Process__c + ' / ' + row.Route_To__c + ' (key=' + mdtCode + ')');
        } else {
            System.debug('WARNING: No CMDT row for key=' + mdtCode + ' (chosen=' + chosen + '). Verify a row exists for this window/flags.');
        }
    }

    System.debug('Total SLA mappings=' + mapOfCaseIdToSLA.size() + ', Queue mappings=' + mapOfCaseIdToQueue.size());

    if (!mapOfCaseIdToSLA.isEmpty() && !mapOfCaseIdToQueue.isEmpty()) {
        Map<String, Id> mapOfSLAProcessNameToId = new Map<String, Id>();
        for (SlaProcess sla : [SELECT Id, Name FROM SlaProcess WHERE Name IN :setOfSLAProcesses AND IsActive = TRUE]) {
            mapOfSLAProcessNameToId.put(sla.Name, sla.Id);
        }

        Map<String, Id> mapOfQueueNameToId = new Map<String, Id>();
        for (Group grp : [SELECT Id, Name FROM Group WHERE Name IN :setOfQueues]) {
            mapOfQueueNameToId.put(grp.Name, grp.Id);
        }

        List<Entitlement> entsToInsert = new List<Entitlement>();
        for (Id caseId : setOfCaseIds) {
            entsToInsert.add(new Entitlement(
                Name = mapOfCaseIdToSLA.get(caseId),
                SlaProcessId = mapOfSLAProcessNameToId.get(mapOfCaseIdToSLA.get(caseId)),
                AccountId = mapOfCases.get(caseId).AccountId,
                Contact__c = mapOfCases.get(caseId).ContactId
            ));
        }

        Map<Id, Entitlement> contactToEnt = new Map<Id, Entitlement>();
        if (!entsToInsert.isEmpty()) {
            insert entsToInsert;
            for (Entitlement e : entsToInsert) contactToEnt.put(e.Contact__c, e);
        }

        List<Case> updates = new List<Case>();
        for (Id caseId : setOfCaseIds) {
            Id entId = (contactToEnt.get(mapOfCaseIdToContactId.get(caseId)) == null) ? null
                : contactToEnt.get(mapOfCaseIdToContactId.get(caseId)).Id;
            updates.add(new Case(
                Id = caseId,
                EntitlementId = entId,
                OwnerId = mapOfQueueNameToId.get(mapOfCaseIdToQueue.get(caseId)),
                Initial_Queue_Owner__c = mapOfCaseIdToQueue.get(caseId),
                Support_Entitlement_Code__c = mapOfCaseIdToMDTCode.get(caseId),
                ProductSupportTier__c = accountIdToHighestTier.get(mapOfCases.get(caseId).AccountId)
            ));
        }
        if (!updates.isEmpty()) update updates;
    }
      /************************************************************************************************/
       // Query active subscriptions for those accounts
        List<Account_Subscription__c> subs = [
            SELECT Account__c, Subscriber__c
            FROM Account_Subscription__c
            WHERE Account__c IN :accountIds
              AND Active__c = true
              AND Subscriber__c != null
        ];
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
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        // Prepare emails (one email per Case, with all subscribers in To:)
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

      
      // Query OWEA once (outside loop)
      Id oweaId;
      OrgWideEmailAddress[] owea =
          [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'noreply@quickbase.com' LIMIT 1];
      if (!owea.isEmpty()) oweaId = owea[0].Id;
      
      // Re-query cases with the fields you need (outside loop)
      Map<Id, Case> caseById = new Map<Id, Case>([
          SELECT Id, CaseNumber, Subject, Priority, Status,
          AccountId, Account.Name,
          ContactId, Contact.Name
          FROM Case
          WHERE Id IN :listOfCase
      ]);

      /************************************************************************************************/
      for (Case cStub : listOfCase) {
          Case c = caseById.get(cStub.Id);
          if (c == null) continue;
          
          Set<String> toSet = acctToEmails.get(c.AccountId);
          if (toSet == null || toSet.isEmpty()) continue;
          
          Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
          if (oweaId != null) msg.setOrgWideEmailAddressId(oweaId);
          msg.setToAddresses(new List<String>(toSet));
          
          String acctName = (c.AccountId != null && c.Account != null) ? c.Account.Name : '';
          String contactName = (c.ContactId != null && c.Contact != null) ? c.Contact.Name : '';
          
          String subject = 'New Support Case from Account ' + acctName;
          if (!String.isBlank(c.Subject)) subject += ': ' + c.Subject;
          msg.setSubject(subject);
          
          String caseUrl = baseUrl + '/' + c.Id;
          
          
          String htmlBody =
              'A new case was submitted for an Account for which you are subscribed to receive new case notifications.<br/><br/>' +
              'Account: ' + acctName + '<br/>' +
              'Contact: ' + contactName + '<br/>' +
              'Case Number: <a href="' + caseUrl + '">' + c.CaseNumber + '</a><br/>' +
              'Subject: ' + (c.Subject == null ? '' : c.Subject) + '<br/>' +
              'Priority: ' + (c.Priority == null ? '' : c.Priority) + '<br/>' +
              'Status: ' + (c.Status == null ? '' : c.Status) + '<br/><br/>' +
              
              'If you wish to unsubscribe from these notifications, ' +
              'please navigate to the Account in Salesforce and press the “Stop new case notifications” button.';
          
          //msg.setPlainTextBody(textBody);  // fallback for non-HTML clients
          msg.setHtmlBody(htmlBody);      
          msg.setSaveAsActivity(false);
          
          emails.add(msg);
      }
      
        if (!emails.isEmpty()) {
            System.debug('email sentline 683'+emails);
            Messaging.sendEmail(emails);
        }
      /**************************************************************************************/

    System.debug('===== EXIT assignEntitlementProcessAndQueue =====');
}
    
      
}