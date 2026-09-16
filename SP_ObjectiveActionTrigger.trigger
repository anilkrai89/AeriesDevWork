trigger SP_ObjectiveActionTrigger on QS_Objective_Action__c (before delete) {
    
    SP_ObjectiveActionTriggerHandler.preventObjectiveActionDeletion(trigger.old);

}