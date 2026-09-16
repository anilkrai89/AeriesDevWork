public class UpdateAccountContactsBatch implements Database.Batchable<SObject>,Database.Stateful {

    private Set<Id> updatedAccountIds;
    private Id newOwnerId;
    private String territoryName;
   

    public UpdateAccountContactsBatch(Set<Id> updatedAccountIds, Id newOwnerId, String territoryName) {
        this.updatedAccountIds = updatedAccountIds;
        this.newOwnerId = newOwnerId;       
        this.territoryName = territoryName;
        System.debug('line 12 inside contact batch'+updatedAccountIds);
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Id, OwnerId, AccountId                 
            FROM Contact
            WHERE AccountId =:updatedAccountIds
           
        ]);
    }

    public void execute(Database.BatchableContext BC, List<Contact> scope) {
        List<Contact> contactsToUpdate = new List<Contact>();

        for (Contact c : scope) {
            
                c.OwnerId = newOwnerId;
                c.ValidationBypassDateTime__c = Datetime.now();
                contactsToUpdate.add(c);
            
        }

        if (!contactsToUpdate.isEmpty()) {
            
                update contactsToUpdate;
           
        }
    }

    public void finish(Database.BatchableContext BC) {
        
        UpdateOpportunitiesBatch oppBatch = new UpdateOpportunitiesBatch(newOwnerId, territoryName);
         Database.executeBatch(oppBatch, 100);
    }
}