@IsTest
private class UpdateAccountOwnerBatchTest {
    @TestSetup
    static void setup() {
    //Create users
    Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator']; 
    User usr1 = new User(Alias = 'standt3', Email='standarduser3@testorg.com', 
                        EmailEncodingKey='UTF-8', LastName='Testing3', LanguageLocaleKey='en_US', 
                        LocaleSidKey='en_US', ProfileId = p.Id, 
                        TimeZoneSidKey='America/Los_Angeles', UserName='standarduser3@testorg.com');
    insert usr1 ;
    User usr2 = new User(Alias = 'standt4', Email='standarduser4@testorg.com', 
                        EmailEncodingKey='UTF-8', LastName='Testing4', LanguageLocaleKey='en_US', 
                        LocaleSidKey='en_US', ProfileId = p.Id, 
                        TimeZoneSidKey='America/Los_Angeles', UserName='standarduser4@testorg.com');
    insert usr2 ;
        // Create test data - Accounts with the specified oldOwnerId
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 20; i++) {
            Account acc = new Account(Name = 'Test Account ' + i, OwnerId = usr1.Id, Account_Hierarchy_Level__c = 'Global Parent');
            accounts.add(acc);
        }
        insert accounts;
    }
    
    @IsTest
    static void testUpdateAccountOwnerBatch() {
        // Set up test data
        User u1 = [select Id from User where Username = 'standarduser3@testorg.com'];
        User u2 = [select Id from User where Username = 'standarduser4@testorg.com'];
        String oldOwnerId = u1.Id; // Provide the existing OwnerId
        String newOwnerId = u2.Id; // Provide the new OwnerId
        
        // Start the batch process
        Test.startTest();
        UpdateAccountOwnerBatch batch = new UpdateAccountOwnerBatch(oldOwnerId, newOwnerId, True);
        Database.executeBatch(batch);
        Test.stopTest();
        
        // Verify the updated records
        List<Account> updatedAccounts = [SELECT Id, OwnerId FROM Account WHERE OwnerId = :newOwnerId];
        System.assertEquals(20, updatedAccounts.size());
        
        // Verify the error records in the custom object
       // List<CustomObject__c> errorRecords = [SELECT Id FROM CustomObject__c];
       // System.assertEquals(0, errorRecords.size());
    }
}