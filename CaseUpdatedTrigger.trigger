trigger CaseUpdatedTrigger on Case (after update) {
    Automation_Settings__c triggerSetting = new Automation_Settings__c();
     Id getUserId = UserInfo.getUserId();
         
    triggerSetting =  Automation_Settings__c.getInstance(getUserId);
    System.debug('Case Trigger is Enabled: ' + triggerSetting);

    if (!Test.isRunningTest() && !triggerSetting.Case_Trigger_Enabled__c) {
        System.debug('Bypassed AttachmentTrigger');
        return;
    }
    Map<String,JiraTrigger_Activate_Deactivate__c> JS = JiraTrigger_Activate_Deactivate__c.getAll();
    if(!Test.isRunningTest()&& !( JS.Size() >0 && JS.get('JiraTriggerActive/Deactive').IsActive__c)){
        return;
    } 
    System.debug('CaseUpdatedTrigger running1');
    
    
    JCFS.API.pushUpdatesToJira();
   

    System.debug('CaseUpdatedTrigger running 2');
}