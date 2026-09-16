@isTest
private class AccountOwnerChangeBridgeTest {
    @isTest
    static void testUpdateAccountOwner() {
    Id originalowner;
    Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator']; 
    User usr1 = new User(Alias = 'standt3', Email='standarduser1@testorg.com', 
                        EmailEncodingKey='UTF-8', LastName='Testing3', LanguageLocaleKey='en_US', 
                        LocaleSidKey='en_US', ProfileId = p.Id, 
                        TimeZoneSidKey='America/Los_Angeles', UserName='standarduser3@testorg.com');
    insert usr1 ;
            
    List<Account> accts= new List<Account>();
        for(Integer i=0 ;i <20;i++)
        {
            Account acc = new Account();
            acc.Name ='Name'+i;
            acc.Account_Hierarchy_Level__c = 'Global Parent';
            acc.OwnerId = usr1.Id;
            accts.add(acc);
        }
        insert accts;
        system.debug('Old Owner Id:  ' + usr1.Id);
 // Account a = [select OwnerId from Account where Name like 'Name' Limit 1];

        // Call the bridge class method
        Test.startTest();
       //     Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator']; 
            User usr2 = new User(Alias = 'standt4', Email='standarduser2@testorg.com', 
                        EmailEncodingKey='UTF-8', LastName='Testing4', LanguageLocaleKey='en_US', 
                        LocaleSidKey='en_US', ProfileId = p.Id, 
                        TimeZoneSidKey='America/Los_Angeles', UserName='standarduser4@testorg.com');
            insert usr2 ;
        // Create test input values
        List<AccountOwnerChangeBridge.UpdateAccountOwnerParams> paramsList = new List<AccountOwnerChangeBridge.UpdateAccountOwnerParams>();
        AccountOwnerChangeBridge.UpdateAccountOwnerParams params = new AccountOwnerChangeBridge.UpdateAccountOwnerParams();
        params.oldOwnerId = usr1.Id ;
        params.newOwnerId = usr2.id;
        paramsList.add(params);
        AccountOwnerChangeBridge.updateAccountOwner(paramsList);
        Test.stopTest();

        // Verify the results as needed
        List<Account> updatedAccounts = [SELECT Id, OwnerId FROM Account];
        System.assert(updatedAccounts.size() > 0);
    }
}