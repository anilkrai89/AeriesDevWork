/**
 * @description trigger entry for Opportunity events
 *
 * @author Rafter1/GearsCRM
 */
trigger OpportunityTrigger on Opportunity (after update) 
{
    List<Opportunity> oppsToCheck = new List<Opportunity>();
    
    for(Opportunity opp : Trigger.new){
    
        if(opp.IsVRBypassed__c == FALSE){
        
            oppsToCheck.add(opp);
        }
    
    }
    
    if(oppsToCheck.size() > 0){
    
    
    string triggerName = 'Opportunity ' + trigger.operationType;
    system.debug('+' + triggerName);

    //if (trigger.isBefore)
    //{
        //if (trigger.isDelete)
        //{
        //}
        //else 
        //if (trigger.isInsert)
        //{
        //}
        //else 
        //if (trigger.isUpdate)
        //{
        //}
    //}
    //else
    if (trigger.isAfter) 
    {
        //if (trigger.isDelete) 
        //{
        //}
        //else 
        //if (trigger.isInsert) 
        //{
        //}
        //else 
        if (trigger.isUpdate)
        {
            OpportunityTriggerHandler.UpdateSubCloseDates(trigger.new, trigger.oldMap);
        }
    }

    system.debug('-' + triggerName);
}
}