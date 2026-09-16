/********************************************************************************* 
ClassName : ContactUtils
==================================================================================
Description :This Utils Class will look for Internal Contact based on CreatedByID and If not found will create and return the values to HelperClass.
==================================================================================
History
-------
VERSION	  AUTHOR	     DATE	       Jira Ticket No
62       Anil Kumar    04-Dec-2024     Teams -3554
 
*********************************************************************************/ 



public class ContactUtils {

    // Utility method to get or create a contact based on the email
    public static List<Contact> getOrCreateContact(set<id> usrids) {
        
       /* Set<Id> usrid = new Set<Id>();
        for (Case cs : caselist) {
            System.debug('Processing Case: ' + cs.Id);
            usrid.add(cs.CreatedById);
        }*/
        
        // Query the User records based on the given set of ids
        List<User> usr = [SELECT Id, Email, FirstName, LastName FROM User WHERE Id IN :usrids];
        //get the Account id
         Account acc =[SELECT Id,Name From Account WHERE NAME ='Holding Account [DO NOT EDIT]'];
        // Declare a contact list
        List<Contact> con = new List<Contact>();

        // Check if users are found
        if (usr.isEmpty()) {
            System.debug('No users found with the provided CreatedById.');
            return con; // Return an empty list if no users are found
        } else {
            // Create a new contact for each user
            for (User u : usr) {
                Contact newContact = new Contact(
                    FirstName = u.FirstName,
                    LastName = u.LastName,
                    Email = u.Email,
                    AccountId =acc.id,
                    Active_services__c='Essential'
                    
                );
                con.add(newContact);
            }

            // Attempt to insert contacts
            try {
                insert con; // Insert all the new contacts
                System.debug('contact created.');
            } catch (DmlException e) {
                System.debug('Error inserting contacts: ' + e.getMessage());
               
            }
        }

        return con; // Return the created contacts
    }
}