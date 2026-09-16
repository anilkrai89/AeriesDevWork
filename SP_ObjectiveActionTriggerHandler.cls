/*Description: Prevents deletion of Sales Plan Action records if they are tied to an open task. 
 * Recommended action is to de-activate the Sales Plan action
 */

public class SP_ObjectiveActionTriggerHandler  {
    
    public static void preventObjectiveActionDeletion(List<QS_Objective_Action__c> listofActions)
    {
        
        Set<Id> actionIds = new Set<Id>();
        Map<Id,QS_Objective_Action__c> mapOfActions = new Map<Id,QS_Objective_Action__c>(listofActions); 
        actionIds = mapOfActions.keySet();
        
        List<Task> listOfOpenTasks = [SELECT Id, Subject, ActivityDate, IsClosed, QS_ObjectiveActionID__c,
                                      QS_Key_Action__c, QS_StageObjectiveID__c, Description, QS_Related_Stage__c,
                                      WhatId, Status
                                      FROM Task where QS_ObjectiveActionID__c in: actionIds and Status <> 'Completed'];
       
        if(listOfOpenTasks != null && listOfOpenTasks.size() > 0)
        {
            for (QS_Objective_Action__c act : listofActions){ 
                act.adderror('You cannot delete this Action as there are open activities associated with it. Consider de-activating the action.');        		                                                  	                      
            }
        }
        
        
    }
    
}