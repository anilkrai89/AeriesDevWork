trigger CaseTrigger on Case (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    CaseTriggerHandler.onTrigger(
        Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap,
        Trigger.isBefore, Trigger.isAfter,
        Trigger.isInsert, Trigger.isUpdate, Trigger.isDelete, Trigger.isUndelete
    );
    
        //System.debug('CasetoJiraHandler is Invoke');
        //CaseToJiraTrgHandler.afterUpdate(Trigger.new, Trigger.oldMap);
 
}