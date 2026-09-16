trigger SalesTerritoryAEChange on Sales_Territories__c (after update) {
    
    
    for (Sales_Territories__c st : Trigger.new) {
        
        Sales_Territories__c oldTerritory = Trigger.oldMap.get(st.id);
        System.debug('line 7 inside ST trigger');
        
        if(oldTerritory.AE_Id__c != null){
              System.debug('line 10 inside ST trigger');
            Boolean aeIdsMatch = oldTerritory.AE_Id__c.equals(st.AE_Id__c);
            
            
        
    if(!aeIdsMatch){
        
        String territoryName = st.Territory__c;
        String newOwnerId = st.AE_Id__c;
        String segment = st.Segment__c;
        String testAccountId = '001UN0000046zmXYAQ';
        
        System.debug('line 21 inside ST trigger');
        
        UpdateAccountOwnersBatch batch = new UpdateAccountOwnersBatch(territoryName, newOwnerId);
        Database.executeBatch(batch, 100);
       
        

              
    }
    }
    
}
}