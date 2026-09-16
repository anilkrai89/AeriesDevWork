public class UpdateAccountHiearchyContactsBatch implements Database.Batchable<SObject>,Database.Stateful {

    private Set<Id> updatedAccountIds;
    private Id newOwnerId;
    private Id sdrOwnerId;
    private String segment;
    private String territoryName;
    private Id ultimateParentId;
  
   

    public UpdateAccountHiearchyContactsBatch(Set<Id> updatedAccountIds, Id newOwnerId, Id sdrOwnerId, String territoryName, Id ultimateParentId, String segment) {
        this.updatedAccountIds = updatedAccountIds;
        this.newOwnerId = newOwnerId; 
        this.sdrOwnerId = sdrOwnerId;
        this.ultimateParentId = ultimateParentId; 
        this.territoryName = territoryName;
        this.segment = segment;      
     
        System.debug('line 12 inside contact batch'+updatedAccountIds);
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Id, OwnerId, AccountId, SDR_Owner__c                 
            FROM Contact
            WHERE AccountId =:updatedAccountIds
           
        ]);
    }

    public void execute(Database.BatchableContext BC, List<Contact> scope) {
        List<Contact> contactsToUpdate = new List<Contact>();

        for (Contact c : scope) {
            
                c.OwnerId = newOwnerId;
                c.SDR_Owner__c = sdrOwnerId;
                c.ValidationBypassDateTime__c = Datetime.now();
                contactsToUpdate.add(c);
            
        }

        if (!contactsToUpdate.isEmpty()) {
            
                update contactsToUpdate;
           
        }
    }

    public void finish(Database.BatchableContext BC) {
        
        System.debug('line 70 set has' +updatedAccountIds);
        
        UpdateHiearchyAccountOpportunitiesBatch oppBatch = new UpdateHiearchyAccountOpportunitiesBatch(newOwnerId, territoryName, ultimateParentId, segment);
         Database.executeBatch(oppBatch, 100);
    
    }
}