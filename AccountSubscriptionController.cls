/******************************************************************************************************
  JIRA         DeveloperName   Date          Details

 TEAMs -6524  Anil Kumar      2-FEB-2026   Email notification when a case is submitted for an Account 
******************************************************************************************************/

public with sharing class AccountSubscriptionController {

    public class SubscriptionState {
        @AuraEnabled public Boolean exists;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Id subscriptionId;
    }

    @AuraEnabled(cacheable=true)
    public static SubscriptionState getState(Id accountId) {
        SubscriptionState s = new SubscriptionState();
        s.exists = false;
        s.active = false;

        if (accountId == null) return s;

        List<Account_Subscription__c> rows = [
            SELECT Id, Active__c
            FROM Account_Subscription__c
            WHERE Account__c = :accountId
              AND Subscriber__c = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (!rows.isEmpty()) {
            s.exists = true;
            s.active = rows[0].Active__c;
            s.subscriptionId = rows[0].Id;
        }
        return s;
    }

    @AuraEnabled
    public static SubscriptionState subscribe(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('AccountId is required.');
        }

        Id uid = UserInfo.getUserId();

        List<Account_Subscription__c> rows = [
            SELECT Id, Active__c
            FROM Account_Subscription__c
            WHERE Account__c = :accountId
              AND Subscriber__c = :uid
            LIMIT 1
            FOR UPDATE
        ];

        if (rows.isEmpty()) {
            insert new Account_Subscription__c(
                Account__c = accountId,
                Subscriber__c = uid,
                Active__c = true
            );
        } else if (rows[0].Active__c == false) {
            rows[0].Active__c = true;
            update rows[0];
        }

        return getState(accountId);
    }

    @AuraEnabled
    public static SubscriptionState unsubscribe(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('AccountId is required.');
        }

        Id uid = UserInfo.getUserId();

        List<Account_Subscription__c> rows = [
            SELECT Id, Active__c
            FROM Account_Subscription__c
            WHERE Account__c = :accountId
              AND Subscriber__c = :uid
            LIMIT 1
            FOR UPDATE
        ];

        if (!rows.isEmpty() && rows[0].Active__c == true) {
            rows[0].Active__c = false;
            update rows[0];
        }

        return getState(accountId);
    }
}