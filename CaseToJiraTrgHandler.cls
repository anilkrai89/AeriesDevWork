public class CaseToJiraTrgHandler {
    
    public static void afterUpdate(List<Case> newList, Map<Id, Case> oldMap) {
        
      
          /* Automation_Settings__c triggerSetting =
            Automation_Settings__c.getInstance(UserInfo.getUserId());
        
        System.debug('Case Trigger setting: ' + triggerSetting);
        
        // Null-safe bypass
        if (triggerSetting == null || triggerSetting.Case_Trigger_Enabled__c == false) {
            System.debug('Bypassed CaseJiraTriggerHandler');
            return;
        }*/
        Map<String,Jira_Trigger_Activate_Deactivate__c> JS = Jira_Trigger_Activate_Deactivate__c.getAll();
        if(!Test.isRunningTest()&& !( JS.Size() >0 && JS.get('JiraTriggerActive/Deactive').IsActive__c)){
            return;
        } 
        System.debug('CaseJiraTriggerHandler running');
        
        // -----------------------------
        // Part A: Create Jira issue
        // -----------------------------
        List<Case> toBeCreated = new List<Case>();
        String pid;
        String issuetype;
        
        for (Case newc : newList) {
            Case oldc = oldMap.get(newc.Id);
            if (oldc == null) continue;
            
            // Checkbox flipped to true => create Jira issue
            if (newc.JIRA_Create_Issue__c == true && oldc.JIRA_Create_Issue__c != true) {
                toBeCreated.add(newc);
                
                // Keeping your current behavior (last one wins)
                pid = newc.JIRA_Project_ID__c;
                issuetype = newc.JIRA_Issue_Type_ID__c;
            }
        }
           
        if (!toBeCreated.isEmpty() && !String.isBlank(pid) && !String.isBlank(issuetype)) {
            System.debug('pid: ' + pid);
            System.debug('issuetype: ' + issuetype);
            System.debug('toBeCreated: ' + toBeCreated);
            
            // Old list aligned to subset (safer than passing full Trigger.old)
            List<Case> oldSubset = new List<Case>();
            for (Case c : toBeCreated) {
                oldSubset.add(oldMap.get(c.Id));
            }
            
            JCFS.API.createJiraIssueWithDefaultPostAction(pid, issuetype, toBeCreated, oldSubset);
            System.debug('createJiraIssueWithDefaultPostAction called');
        }
        
        // -----------------------------
        // Part B: Push updates to Jira only when mapped fields changed
        // -----------------------------
        Boolean shouldPush = false;
        
        for (Case cNew : newList) {
            Case cOld = oldMap.get(cNew.Id);
            if (cOld == null) continue;
            
            // condition to send update to jira
            
            if (cNew.Affected_Cases__c            != cOld.Affected_Cases__c
                || cNew.Escalation_Status__c         != cOld.Escalation_Status__c
                || cNew.Escalation_Team__c           != cOld.Escalation_Team__c
                || cNew.Last_PD_Update__c            != cOld.Last_PD_Update__c
                
                || cNew.JIRA_Create_Issue__c         != cOld.JIRA_Create_Issue__c
                || cNew.JIRA_Description__c          != cOld.JIRA_Description__c
                || cNew.JIRA_Discovery_Phase__c      != cOld.JIRA_Discovery_Phase__c
                || cNew.JIRA_Discovery_Source__c     != cOld.JIRA_Discovery_Source__c
                || cNew.Jira_Escalation_Owner__c     != cOld.Jira_Escalation_Owner__c
                || cNew.JIRA_Functional_Area__c      != cOld.JIRA_Functional_Area__c
                || cNew.JIRA_Issue_Tracker_ID__c     != cOld.JIRA_Issue_Tracker_ID__c
                || cNew.JIRA_Issue_Type_ID__c        != cOld.JIRA_Issue_Type_ID__c
                || cNew.JIRA_Issue_User__c           != cOld.JIRA_Issue_User__c
                || cNew.JIRA_Key__c                  != cOld.JIRA_Key__c
                || cNew.JIRA_Owner_Email__c          != cOld.JIRA_Owner_Email__c
                || cNew.JIRA_PD_Team_Email__c        != cOld.JIRA_PD_Team_Email__c
                || cNew.JIRA_Priority__c             != cOld.JIRA_Priority__c
                || cNew.JIRA_Project_ID__c           != cOld.JIRA_Project_ID__c
                || cNew.JIRA_Project_Issue_Type__c   != cOld.JIRA_Project_Issue_Type__c
                || cNew.JIRA_Summary__c              != cOld.JIRA_Summary__c
                || cNew.JIRA_Team__c                 != cOld.JIRA_Team__c
                || cNew.JIRA_Ticket_status__c        != cOld.JIRA_Ticket_status__c
               ) {
                   shouldPush = true;
                   break;
               }
            
            
        }
        
        if (shouldPush) {
            JCFS.API.pushUpdatesToJira();
            System.debug('pushUpdatesToJira called');
        } else {
            System.debug('Skipping pushUpdatesToJira (no relevant field changes)');
        }
    }
}