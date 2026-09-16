public with sharing class CaseWatcherController {

    @AuraEnabled(cacheable=true)
    public static List<Contact> searchContacts(String searchKey) {

        if (String.isBlank(searchKey)) {
            return new List<Contact>();
        }

        // Get logged-in user's ContactId
        User u = [
            SELECT ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (u.ContactId == null) {
            return new List<Contact>();
        }

        // Get AccountId from Contact
        Contact loggedInContact = [
            SELECT AccountId
            FROM Contact
            WHERE Id = :u.ContactId
            LIMIT 1
        ];

        if (loggedInContact.AccountId == null) {
            return new List<Contact>();
        }

        String key = '%' + searchKey + '%';

        return [
            SELECT Id, Name, Email
            FROM Contact
            WHERE AccountId = :loggedInContact.AccountId
              AND Email != null
              AND (
                    Name LIKE :key
                 OR Email LIKE :key
              )
            ORDER BY Name
        ];
    }
}