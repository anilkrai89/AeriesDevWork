trigger casetojiraissue on Case (after update) {
  Automation_Settings__c triggerSetting = Automation_Settings__c.getInstance(UserInfo.getUserId());
    System.debug('Case Trigger is Enabled: ' + triggerSetting);
    
    if (!triggerSetting.Case_Trigger_Enabled__c) {
        System.debug('Bypassed casetojiraissue');
        return;
    } 
    
   Map<String,JiraTrigger_Activate_Deactivate__c> JS = JiraTrigger_Activate_Deactivate__c.getAll();
    if(!Test.isRunningTest() && !( JS.Size() >0 && JS.get('JiraTriggerActive/Deactive').IsActive__c)){
        System.debug('line 12');
        return;
    }
    
    System.debug('casetojiraissue running');
    
    List<Case> toBeCreated = new List<Case>();
    string pid;
    string issuetype;

    for(Case newc : Trigger.new) {
        Case oldc = Trigger.oldMap.get(newc.Id);
        if(newc.JIRA_Create_Issue__c != oldc.JIRA_Create_Issue__c && newc.JIRA_Create_Issue__c == true ){
            toBeCreated.add(newc);
            pid = newc.JIRA_Project_ID__c;
            issuetype = newc.JIRA_Issue_Type_ID__c; //JIRA_Issue_Type_ID__c;
        }
    }
   // if(pid != '' && issuetype != ''){
    if(!String.isblank(pid) && !String.IsBlank(issuetype)){
        system.debug('this is the pid from casetojiraissue ' + pid);
        system.debug('this is the issuetype from casetojiraissue' + issuetype);
        system.debug('TO be created from casetojiraissue ' + toBeCreated);   
        //pid = '13462';
        //issuetype = '10100';   
        JCFS.API.createJiraIssueWithDefaultPostAction(pid, issuetype, toBeCreated, Trigger.old);
        System.debug('CasetoJira line 31');
    }
}