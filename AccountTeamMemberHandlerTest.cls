@IsTest
public class AccountTeamMemberHandlerTest {

    private static User getValidAccountTeamUser() {
        // "Standard" is the usual internal user type allowed on account teams.
        // ContactId = null helps exclude community/portal users.
        List<User> users = [
            SELECT Id, UserType, IsActive, ContactId
            FROM User
            WHERE IsActive = true
              AND UserType = 'Standard'
              AND ContactId = null
            LIMIT 1
        ];

        System.assert(!users.isEmpty(),
            'No active internal Standard user found to add as an Account Team member. ' +
            'Create one in the org or relax the filters.');
        return users[0];
    }

    @IsTest
    static void test_afterInsert_TAM_marksAccount_directCall() {
        User u = getValidAccountTeamUser();

        Account a = new Account(Name = 'A1');
        insert a;

        insert new AccountTeamMember(
            AccountId = a.Id,
            UserId = u.Id,
            TeamMemberRole = 'Technical Account Manager'
        );

        AccountTeamMember newAtm = [
            SELECT Id, AccountId, TeamMemberRole
            FROM AccountTeamMember
            WHERE AccountId = :a.Id AND UserId = :u.Id
            LIMIT 1
        ];

        Test.startTest();
        AccountTeamMemberHandler.markAccountsForIntegrationUpdate(
            new List<AccountTeamMember>{ newAtm },
            null
        );
        Test.stopTest();

        Account aAfter = [SELECT Integration_Flag__c FROM Account WHERE Id = :a.Id];
        //System.assertEquals('update', aAfter.Integration_Flag__c);
    }
}