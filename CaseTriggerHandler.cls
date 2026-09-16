/*********************************************************************************  
Name:	CaseTriggerHandler()
TestClass :CaseTriggerHandlerTest,CaseTriggerHelperTest,ContactUtilsTest
==================================================================================
Req:
SSC-142 - Automation for entitlement process and routing assignment
==================================================================================
History
-------
VERSION	  AUTHOR	DATE	       DETAIL
1.0       abajao    06-MAY-2024    Initial version to cater logic for entitlement 
                                   process and routing assignment
2.0       abajao    03-JUL-2024    Added logic for SSC-351: Create automation 
                                   to populate the Affected Cases field
*********************************************************************************
JIRA         DeveloperName   Date          Details
TEAMS-3444   Anil Kumar      10-OCT-2024   Need to fix CaseHandler APEX Class to route US Support Only 
                                           via the Product Account on a case(If US Required Only Is True 
                                           on Account then CaseOwner =T1USQueue)
TEAMS -3554  Anil Kumar      12-DEC-2024   It is designed in such a way,it will check for User Contact based on CreatedByID,If Contact exist,same contact will get associated and If no contact found,
                                           It will Create a Internal Contact and will associate it with case.

TEAMS -6035  Anil Kumar      12-DEC-2025  Update Time to First Touch Logic on Cases in Service Cloud to Include Support+ Tier from Product Account
TEAMs -6524  Anil Kumar      2-FEB-2026   Email notification when a case is submitted for an Account                                     
******************************************************************************************************/

public class CaseTriggerHandler {

    // Timezone used for handling date and time calculations
    public static final String EST_TIMEZONE = 'America/New_York';
    // Type identifier for standard cases
    public static final String STANDARD_TYPE = 'Standard';
    // Set containing the names of weekdays
    public static final Set<String> SET_OF_WEEKDAYS = new Set<String> {'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'};
    // Set containing issue types considered for routing and entitlement
    public static final Set<String> SET_OF_ISSUE_TYPES = new Set<String> {'Non-Technical', 'Technical'};
    
    // Entry point method called by the Apex trigger
    public static void onTrigger(List<Case> newList, List<Case> oldList, 
                                 Map<Id, Case> newMap, Map<Id, Case> oldMap, 
                                 Boolean isBefore, Boolean isAfter, Boolean isInsert, 
                                 Boolean isUpdate, Boolean isDelete, Boolean isUndelete) {
        
        Automation_Settings__c triggerSetting = Automation_Settings__c.getInstance(UserInfo.getUserId());
        System.debug('Case Trigger is Enabled: ' + triggerSetting);
                                     
         if (!Test.isRunningTest() && !triggerSetting.Case_Trigger_Enabled__c) {
            System.debug('Bypassed CaseTrigger');
            return;
        }
        System.debug('CaseTrigger running');
                          
        if (isBefore) {
            System.debug('trigger subscription email');
            //CaseSubscriberEmailer.notifyOnCaseInsert(newList);
             
            
        } else if (isAfter) {
            updateAffectedCasesField(newList, oldList, isInsert, isUpdate, isDelete, isUndelete);
           
            if (isInsert) { 
                //assignEntitlementProcessAndQueue(newList); 
                System.debug('trigger is in InsertContext');
                CaseTriggerHelper.assignEntitlementProcessAndQueue1(newlist);
              
            } 
            // Call assignP0Entitlement after update
           else if (isUpdate) {
                CaseTriggerHelper.assignP0Entitlement(newMap, oldMap);
               // case to jira
               
              // CaseToJiraTrgHandler.afterUpdate(newList, oldMap);
               System.debug('CasetoJiraHandler is Invoked');
            }
        }
        
    }
    
  
    // Assigns the appropriate entitlement process and queue to new Case records based on several criteria
   /* private static void assignEntitlementProcessAndQueue(List<Case> listOfCase) {
        System.debug('@trigger assignEntitlementProcessAndQueue');
         system.debug('line 62 list of cases' +listOfCase);
        // Holds the IDs of cases that meet the criteria for processing
        Set<Id> setOfCaseIds = new Set<Id>();
        // Maps case IDs to their corresponding Case objects
        Map<Id, Case> mapOfCases = new Map<Id, Case>();
        // Maps case IDs to their corresponding contact IDs
        Map<Id, Id> mapOfCaseIdToContactId = new Map<Id, Id>();
        
        // Iterate over listOfCase to identify cases that have AccountId, ContactId, and a routing issue type that is included in SET_OF_ISSUE_TYPE
        // Add these cases to the collections initialized above
        for (Case c : listOfCase) { 
            if(c.AccountId != null && c.ContactId != null && SET_OF_ISSUE_TYPES.contains(c.Routing_Issue_Type__c)){
                setOfCaseIds.add(c.Id);  
                mapOfCases.put(c.Id, c);
                mapOfCaseIdToContactId.put(c.Id, c.ContactId);  
            }
            else if(c.id !=null && c.AccountId == null && c.ContactId == null){ 
                CaseTriggerHelper.assignContactAndAccount(listOfCase);          
            }
            
        }
        System.debug('setOfCaseIds: ' + setOfCaseIds.size() + ' : ' + setOfCaseIds);

        if (!setOfCaseIds.isEmpty()) {
            
            Set<String> setOfSLAProcesses = new Set<String>();
            Set<String> setOfQueues = new Set<String>();
            Set<String> setOfHolidays = new Set<String>();
            Map<Id, String> mapOfCaseIdToSLA = new Map<Id, String>();
            Map<Id, String> mapOfCaseIdToQueue = new Map<Id, String>();
            Map<Id, String> mapOfCaseIdToMDTCode = new Map<Id, String>();
            Map<String, Support_Entitlement__mdt> mapOfMDTCodeToMDT = new Map<String, Support_Entitlement__mdt>();
            
            // Retrieve holiday dates from the Holiday object and store them in setOfHolidays
            for(Holiday h : [SELECT Id, Name, Description, ActivityDate FROM Holiday]){
                setOfHolidays.add(String.valueOf(h.ActivityDate));
            }
            
            System.debug('setOfHolidays: ' + setOfHolidays);
            
            // Retrieve metadata from Support_Entitlement__mdt and construct a code (mdtCode) based on various fields
            // Map these codes to the corresponding metadata records.
            for (Support_Entitlement__mdt ent : [SELECT Id, DeveloperName, Entitlement_Process__c, Active_services__c, 
                                                 X24x7_Handoff__c, Premium_Support__c, US_Support_Required__c, 
                                                 Issue_Type__c, Route_To__c, Weekday__c, Holiday__c, Start_Time__c, End_Time__c 
                                                 FROM Support_Entitlement__mdt]) {
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
            
            System.debug('mapOfMDTCodeToMDT: ' + mapOfMDTCodeToMDT.size() + ' : ' + mapOfMDTCodeToMDT);
            
            // For each case, determine the creation date and time in EST, check if it is a holiday or weekday, and determine the time range (startTime and endTime)
            // Construct the mdtCode for each case and map it to the appropriate SLA process and queue using the metadata retrieved earlier
            for (Case c : [SELECT Id, Subject, Routing_Issue_Type__c, AccountId, CreatedDate,
                           Contact.Active_services__c, Contact.Premium_Support_Contact__c,
                           Contact.X24_7_Hand_off_Contact__c, Contact.Support_Level_Available__c, 
                           Account.US_support_only__c
                           FROM Case 
                           WHERE Id IN :setOfCaseIds]) {
                               System.debug('Case ************************ ' + c.Subject);
                               
                               DateTime caseCreatedDT = c.CreatedDate;
                               
                               String estDateTime = caseCreatedDT.format('yyyy-MM-dd HH:mm:ss', EST_TIMEZONE);
                               String estDate = estDateTime.split(' ')[0];
                               String estTimeHour = estDateTime.split(' ')[1].split(':')[0];
                               String estTimeMins = estDateTime.split(' ')[1].split(':')[1];
                               String estDay = caseCreatedDT.format('EEEE', EST_TIMEZONE);
                               
                               Integer intEstTimeHour = Integer.valueOf(estTimeHour);
                               Integer intEstTimeMins = Integer.valueOf(estTimeMins);
                               
                               Boolean isHoliday = setOfHolidays.contains(estDate);
                               Boolean isWeekday = SET_OF_WEEKDAYS.contains(estDay);
                               
                               System.debug('estDateTime > ' + estDateTime);
                               System.debug('estDate > ' + estDate 
                                            + ' : ' + 'estTimeHour > ' + estTimeHour 
                                            + ' : ' + 'estTimeMins > ' + estTimeMins 
                                            + ' : ' + 'estDay > '+ estDay);
                               
                               System.debug('intEstTimeHour > ' + intEstTimeHour 
                                            + ' : ' + 'intEstTimeMins > ' + intEstTimeMins);
                               
                               System.debug('isHoliday > ' + isHoliday 
                                            + ' : ' + 'isWeekday > ' + isWeekday);
                               
                               String startTime = '';
                               String endTime = '';
                               
                               if(isWeekday){
                                   // 00:00 AM to 00:59 AM // 01:00 AM to 05:59 AM // 06:00 AM to 06:59 AM
                                   if((intEstTimeHour == 0 && intEstTimeMins >= 0) || (intEstTimeHour >= 1 && intEstTimeHour <= 5) || (intEstTimeHour == 6 && intEstTimeMins <= 59)){ 
                                       
                                       startTime = '12:00 AM';
                                       endTime = '07:00 AM';
                                       
                                       // 07:00 AM to 07:59 AM // 08:00 AM to 01:59 AM // 02:00 PM to 02:59 PM
                                   } else if((intEstTimeHour == 7 && intEstTimeMins >= 0) || (intEstTimeHour >= 8 && intEstTimeHour <= 13) || (intEstTimeHour == 14 && intEstTimeMins <= 59)){ 
                                       
                                       startTime = '07:00 AM';
                                       endTime = '03:00 PM';
                                       
                                       // 03:00 PM to 03:59 PM // 04:00 PM to 06:59 PM // 07:00 PM to 07:59 PM
                                   } else if((intEstTimeHour == 15 && intEstTimeMins >= 0) || (intEstTimeHour >= 16 && intEstTimeHour <= 18) || (intEstTimeHour == 19 && intEstTimeMins <= 59)){ 
                                       
                                       startTime = '03:00 PM';
                                       endTime = '08:00 PM';
                                       
                                       // 08:00 PM to 08:59 PM // 09:00 PM to 10:59 PM // 11:00 PM to 11:59 PM
                                   } else if((intEstTimeHour == 20 && intEstTimeMins >= 0) || (intEstTimeHour >= 21 && intEstTimeHour <= 22) || (intEstTimeHour == 23 && intEstTimeMins <= 59)){ 
                                       
                                       startTime = '08:00 PM';
                                       endTime = '12:00 AM';
                               }
                                   
                               } else {
                                   
                                   startTime = '12:00 AM';
                                   endTime = '12:00 AM';
                                   
                               }
                               
                               System.debug(startTime + ' to ' + endTime);
                               
                               String mdtCode = c.Contact.Active_services__c 
                                   + ';' + c.Contact.Premium_Support_Contact__c
                                   + ';' + c.Contact.X24_7_Hand_off_Contact__c
                                   + ';' + c.Account.US_support_only__c
                                   + ';' + c.Routing_Issue_Type__c
                                   + ';' + isHoliday 
                                   + ';' + isWeekday 
                                   + ';' + startTime
                                   + ';' + endTime;
                               
                               if (mapOfMDTCodeToMDT.containsKey(mdtCode)) {
                                   System.debug('MDT code found: ' + mdtCode);
                                   setOfSLAProcesses.add(mapOfMDTCodeToMDT.get(mdtCode).Entitlement_Process__c);
                                   setOfQueues.add(mapOfMDTCodeToMDT.get(mdtCode).Route_To__c);
                                   mapOfCaseIdToSLA.put(c.Id, mapOfMDTCodeToMDT.get(mdtCode).Entitlement_Process__c);
                                   mapOfCaseIdToQueue.put(c.Id, mapOfMDTCodeToMDT.get(mdtCode).Route_To__c);
                                   mapOfCaseIdToMDTCode.put(c.Id, mapOfMDTCodeToMDT.get(mdtCode).DeveloperName);
                               } else {
                                  
                                   System.debug('MDT code not found: ' + mdtCode);
                               } 
                              
                               
                           }   
            
          System.debug('mapOfCaseIdToSLA: ' + mapOfCaseIdToSLA.size() + ' : ' + mapOfCaseIdToSLA);
            System.debug('mapOfCaseIdToQueue: ' + mapOfCaseIdToQueue.size() + ' : ' + mapOfCaseIdToQueue);
            
            if (!mapOfCaseIdToSLA.isEmpty() && !mapOfCaseIdToQueue.isEmpty()) {
                Map<String, Id> mapOfSLAProcessNameToId = new Map<String, Id>();
                
                // Retrieve SLA processes and queues based on the names collected from the cases and map them to their respective IDs
                for (SlaProcess sla : [SELECT Id, Name FROM SlaProcess WHERE Name IN :setOfSLAProcesses AND IsActive = TRUE]) { 
                    mapOfSLAProcessNameToId.put(sla.Name, sla.Id);
                }
                
                System.debug('mapOfSLAProcessNameToId: ' + mapOfSLAProcessNameToId.size() + ' : ' + mapOfSLAProcessNameToId);
                
                Map<String, Id> mapOfQueueNameToId = new Map<String, Id>();
                
                for (Group grp : [SELECT Id, Name FROM Group WHERE Name IN :setOfQueues]) { 
                    mapOfQueueNameToId.put(grp.Name, grp.Id);
                }
                
                System.debug('mapOfQueueNameToId: ' + mapOfQueueNameToId.size() + ' : ' + mapOfQueueNameToId);
                
                List<Entitlement> listOfEntitlementsToInsert = new List<Entitlement>();
                
                // Create entitlement records for the cases
                for(Id caseId : setOfCaseIds){
                    listOfEntitlementsToInsert.add(new Entitlement(Name = mapOfCaseIdToSLA.get(caseId), 
                                                                   SlaProcessId = mapOfSLAProcessNameToId.get(mapOfCaseIdToSLA.get(caseId)),
                                                                   AccountId = mapOfCases.get(caseId).AccountId,
                                                                   Contact__c = mapOfCases.get(caseId).ContactId));
                }
                
                System.debug('listOfEntitlementsToInsert: ' + listOfEntitlementsToInsert.size() + ' : ' + listOfEntitlementsToInsert);
                
                Map<Id, Entitlement> mapOfEntitlements = new Map<Id, Entitlement>();

                if (!listOfEntitlementsToInsert.isEmpty()) {
                    INSERT listOfEntitlementsToInsert;
                    
					// Map the contact IDs to the newly created entitlements                    
                    for (Entitlement ent : listOfEntitlementsToInsert) { 
                        mapOfEntitlements.put(ent.Contact__c, ent);
                    }
                    
                }
                
                // Update the cases with the new entitlement IDs, queue owner IDs, initial queue owner names, and support entitlement codes.
                List<Case> listOfCasesToUpdate = new List<Case>();
                for (Id caseId : setOfCaseIds) {
                    System.debug('mapOfCaseIdToContactId.get(caseId): ' + mapOfCaseIdToContactId.get(caseId));
                    System.debug('mapOfEntitlements.get(mapOfCaseIdToContactId.get(caseId)).Id: ' + mapOfEntitlements.get(mapOfCaseIdToContactId.get(caseId)).Id);
                                 
                    listOfCasesToUpdate.add(new Case(Id = caseId,
                                                     EntitlementId = mapOfEntitlements.get(mapOfCaseIdToContactId.get(caseId)).Id, 
                                                     OwnerId = mapOfQueueNameToId.get(mapOfCaseIdToQueue.get(caseId)),
                                                     Initial_Queue_Owner__c = mapOfCaseIdToQueue.get(caseId), 
                                                     Support_Entitlement_Code__c = mapOfCaseIdToMDTCode.get(caseId)));
                    
                    
                }
                
                System.debug('listOfCasesToUpdate: ' + listOfCasesToUpdate.size() + ' : ' + listOfCasesToUpdate);
                
                if (!listOfCasesToUpdate.isEmpty()) {
                    UPDATE listOfCasesToUpdate;
                }
            }
        }
    }*/ 
    
    // Collects the IDs of the affected escalation records and calls the method to update the count on the escalation records
    private static void updateAffectedCasesField(List<Case> listOfCase, List<Case> listOfOldCase, 
                                                 Boolean isInsert, Boolean isUpdate, Boolean isDelete, Boolean isUndelete) {
                                                     
                                                     System.debug(' affectedCasesField method is called');
        // Set to hold the Ids of parent records to update
        Set<Id> parentIds = new Set<Id>();
        
        // Collect parentIds from the trigger context
        if (isInsert || isUndelete || isUpdate) {
            for (Case standardCase : listOfCase) {
                if (standardCase.Type == STANDARD_TYPE && standardCase.TS_Escalation_Case__c != null) {
                    parentIds.add(standardCase.TS_Escalation_Case__c);
                }
            }
        }
          System.debug('line 298'+parentIds);                                           
        
        if (isUpdate || isDelete) {
            for (Case standardCase : listOfOldCase) {
                if (standardCase.Type == STANDARD_TYPE && standardCase.TS_Escalation_Case__c != null) {
                    parentIds.add(standardCase.TS_Escalation_Case__c);
                }
            }
        }
        
        System.debug('line 330 parentIds: ' + parentIds);
        
        // Update the parent records with the child cases
        if (!parentIds.isEmpty()) {
            updateAffectedCasesField(parentIds);
        }
        System.debug('line 314'+parentIds);                                                      
        
    }

    // Static method that takes a set of escalations IDs and updates the Affected Cases field on Escalation records
    private static void updateAffectedCasesField(Set<Id> parentIds) {
        // Map to hold the count the number of cases for each Escalation
        Map<Id, Integer> escalationToCasesCountMap = new Map<Id, Integer>();
        
        // Aggregate query to count the number of cases for each Escalation
        List<AggregateResult> listOfAffectedCases = [
            SELECT COUNT(Id), TS_Escalation_Case__c 
            FROM Case 
            WHERE TS_Escalation_Case__c IN :parentIds
            GROUP BY TS_Escalation_Case__c 
        ];
		
        System.debug('listOfAffectedCases: ' + listOfAffectedCases);
        
        // Populate the map with counts
        for (AggregateResult ar : listOfAffectedCases) {
            escalationToCasesCountMap.put((Id)ar.get('TS_Escalation_Case__c'), (Integer)ar.get('expr0'));
        }
        
        System.debug('escalationToCasesCountMap: ' + escalationToCasesCountMap);

        // Update the escalation records
        List<Case> listOfCasesToUpdate = new List<Case>();
        for (Id parentId : parentIds) {
            Integer affectedCases = escalationToCasesCountMap.get(parentId);
            listOfCasesToUpdate.add(new Case(Id = parentId, Affected_Cases__c = affectedCases != null ? affectedCases : 0));
        }
        
        System.debug('listOfCasesToUpdate: ' + listOfCasesToUpdate);
        
        // Perform the update
        if (!listOfCasesToUpdate.isEmpty()) {
            UPDATE listOfCasesToUpdate;
        }
    }
 
}