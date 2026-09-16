public class UnbounceContactsBatch implements Database.Batchable<SObject>, Database.Stateful {
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Query Contacts with non-null EmailBouncedReason for users with the 'QB Community Login User' profile
        return Database.getQueryLocator([
            SELECT Id, EmailBouncedReason 
            FROM Contact 
            WHERE EmailBouncedReason != NULL
            AND Id IN (
                SELECT ContactId 
                FROM User 
                WHERE Profile.Name = 'QB Community Login User'
            )
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Contact> scope) {
        List<Contact> contactsToUpdate = new List<Contact>();
        
        for (Contact con : scope) {
            con.EmailBouncedReason = null;  // Clear the EmailBouncedReason field
            contactsToUpdate.add(con);
        }
        
        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        // You can add any post-batch logic here if required
    }
}