/******************************************************************************************************
  JIRA         DeveloperName   Date          Details

 TEAMs -6524  Anil Kumar      2-FEB-2026   Email notification when a case is submitted for an Account 
******************************************************************************************************/
@IsTest
private class AccountSubscriptionControllerTest {

    // Test data
    private static Account makeAccount() {
        Account acc = new Account(Name = 'Sub Test Account');
        insert acc;
        return acc;
    }

    @IsTest
    static void testGetStateNullAccount() {
        AccountSubscriptionController.SubscriptionState state = AccountSubscriptionController.getState(null);
        System.assertEquals(false, state.exists);
        System.assertEquals(false, state.active);
        System.assertEquals(null, state.subscriptionId);
    }

    @IsTest
    static void testGetStateWithActiveSubscription() {
        Account acc = makeAccount();
        Account_Subscription__c sub = new Account_Subscription__c(
            Account__c = acc.Id,
            Subscriber__c = UserInfo.getUserId(),
            Active__c = true
        );
        insert sub;

        AccountSubscriptionController.SubscriptionState state = AccountSubscriptionController.getState(acc.Id);
        System.assertEquals(true, state.exists);
        System.assertEquals(true, state.active);
        System.assertEquals(sub.Id, state.subscriptionId);
    }

    @IsTest
    static void testSubscribeCreatesNew() {
        Account acc = makeAccount();

        Test.startTest();
        AccountSubscriptionController.SubscriptionState state = AccountSubscriptionController.subscribe(acc.Id);
        Test.stopTest();

        System.assertEquals(true, state.exists);
        System.assertEquals(true, state.active);

        Account_Subscription__c db = [
            SELECT Active__c FROM Account_Subscription__c
            WHERE Account__c = :acc.Id AND Subscriber__c = :UserInfo.getUserId()
            LIMIT 1
        ];
        System.assertEquals(true, db.Active__c);
    }

    @IsTest
    static void testSubscribeReactivatesExisting() {
        Account acc = makeAccount();
        Account_Subscription__c sub = new Account_Subscription__c(
            Account__c = acc.Id,
            Subscriber__c = UserInfo.getUserId(),
            Active__c = false
        );
        insert sub;

        Test.startTest();
        AccountSubscriptionController.SubscriptionState state = AccountSubscriptionController.subscribe(acc.Id);
        Test.stopTest();

        System.assertEquals(true, state.active);
        System.assertEquals(sub.Id, state.subscriptionId);

        sub = [SELECT Active__c FROM Account_Subscription__c WHERE Id = :sub.Id];
        System.assertEquals(true, sub.Active__c);
    }

    @IsTest
    static void testUnsubscribeDeactivates() {
        Account acc = makeAccount();
        Account_Subscription__c sub = new Account_Subscription__c(
            Account__c = acc.Id,
            Subscriber__c = UserInfo.getUserId(),
            Active__c = true
        );
        insert sub;

        Test.startTest();
        AccountSubscriptionController.SubscriptionState state = AccountSubscriptionController.unsubscribe(acc.Id);
        Test.stopTest();

        System.assertEquals(true, state.exists);
        System.assertEquals(false, state.active);

        sub = [SELECT Active__c FROM Account_Subscription__c WHERE Id = :sub.Id];
        System.assertEquals(false, sub.Active__c);
    }

    @IsTest
    static void testSubscribeNullGuard() {
        try {
            AccountSubscriptionController.subscribe(null);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage().contains('AccountId is required'));
        }
    }
}