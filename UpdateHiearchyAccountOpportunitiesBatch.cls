public class UpdateHiearchyAccountOpportunitiesBatch implements Database.Batchable<SObject>,Database.Stateful {

    private Id newOwnerId;
    private String segment;
    private String territoryName;
    private Id ultimateParentId; 
   

    public UpdateHiearchyAccountOpportunitiesBatch(Id newOwnerId, String territoryName, Id ultimateParentId, String segment) {
      
        this.newOwnerId = newOwnerId;       
        this.territoryName = territoryName;
        this.ultimateParentId = ultimateParentId;
        this.segment = segment;
        
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Id, OwnerId, Opportunity_Territory__c, StageName                 
            FROM Opportunity
            WHERE Account.Ultimate_Parent_ID__c = :ultimateParentId AND
                  StageName != 'Closed Won' AND
                  StageName != 'Closed Lost' AND
                  Opp_Territory_Override__c = FALSE
           
        ]);
    }

    public void execute(Database.BatchableContext BC, List<Opportunity> scope) {
        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for (Opportunity o : scope) {
            
                o.OwnerId = newOwnerId;
                o.Opportunity_Segment__c = segment;
                o.Opportunity_Territory__c = territoryName;
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