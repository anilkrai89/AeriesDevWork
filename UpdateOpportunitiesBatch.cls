public class UpdateOpportunitiesBatch implements Database.Batchable<SObject>,Database.Stateful {

    private Id newOwnerId;
    private String territoryName;
   

    public UpdateOpportunitiesBatch(Id newOwnerId, String territoryName) {
      
        this.newOwnerId = newOwnerId;       
        this.territoryName = territoryName;
        
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Id, OwnerId, Opportunity_Territory__c, StageName                 
            FROM Opportunity
            WHERE Opportunity_Territory__c =:territoryName AND
                  StageName != 'Closed Won' AND
                  StageName != 'Closed Lost' AND
                  Opp_Territory_Override__c = FALSE
           
        ]);
    }

    public void execute(Database.BatchableContext BC, List<Opportunity> scope) {
        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for (Opportunity o : scope) {
            
                o.OwnerId = newOwnerId;
                o.ValidationBypassDateTime__c = Datetime.now();
                oppsToUpdate.add(o);
            
        }

        if (!oppsToUpdate.isEmpty()) {
            
                update oppsToUpdate;
           
        }
    }

    public void finish(Database.BatchableContext BC) {
        
    }
}