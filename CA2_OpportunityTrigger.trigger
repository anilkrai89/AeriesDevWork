trigger CA2_OpportunityTrigger on Opportunity (after update) {
     
    
     if(Trigger.IsAfter)
    {
        if(Trigger.IsUpdate)
        {
            List<Opportunity> opportunitiesToConsiderForDecommisionRecords = new List<Opportunity>();
            CA2_OpportunityTriggerHandler thl = new CA2_OpportunityTriggerHandler();
            
            
            for(Opportunity currentOpp : Trigger.new)
            {
                Opportunity oldOpp = Trigger.oldMap.get(currentOpp.Id);
                if(!oldOpp.IsClosed && currentOpp.IsClosed && currentOpp.IsVRBypassed__c == FALSE)
                {
                    opportunitiesToConsiderForDecommisionRecords.add(currentOpp);
                }
            }
            
            if(opportunitiesToConsiderForDecommisionRecords.size() > 0){
                thl.addDecommissionRecordsForZeroedOutProducts(opportunitiesToConsiderForDecommisionRecords);    
            }
            
            
        }
        
    }

}