/*------------------
Description: Opportunity trigger handles the validation of the existence of Activities related to the Sales Plan actions for the current opportunity stage.
 
*/
trigger SP_OpportunityTrigger on Opportunity (before update) {

    //disabled for bulk updatess
    if (Trigger.size == 1) {
        SP_SalesPlanValidations.validateRequiredActions(Trigger.newMap, Trigger.oldMap);
    }
}