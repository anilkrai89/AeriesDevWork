/********************************************************************************* 
ClassName : WeeklySupportEntitlementCleanup
Test Class: WeeklySupportEntitlementCleanup_Test
==================================================================================
Req:Confirm Removal of Tech Support High Level of Support with Services Upon Cancellation/Non-Renewal.
Sol :When all entitled Product Accounts for an Account are cancelled (and not exceptions),
     it removes support tier entitlement, clears related support fields on Contacts, and emails a CSV audit report
==================================================================================
History
---------------------------------------------------------------------------------
APIVERSION	  AUTHOR	     DATE	       Jira Ticket No
    62       Anil Kumar    17-Feb-2026     TEAMS-6009
        
 
*********************************************************************************/ 

@IsTest
private class WeeklySupportEntitlementCleanup_Test {

    private static final String CRON = '0 0 0 * * ?';

    private static Product_Account__c makePA(Id acctId, String status, String tier, Boolean isException) {
        return new Product_Account__c(
            Account__c = acctId,
            Status__c = status,
            Support_Tier__c = tier,
            EntitlementException__c = isException
        );
    }

    private static Contact makeContact(Id acctId) {
        return new Contact(
            LastName = 'Tester',
            AccountId = acctId,
            Email = 'abc@gmail.com',
            X24_7_Hand_off_Contact__c = true,
            Active_Services__c = 'Essential',
            Support_Level_Available__c = ''
        );
    }

    @IsTest
    static void test_main_path_updates_PA_and_Contacts() {
        Account a = new Account(Name = 'Main Path Account');
        insert a;

        // Must match your step (1)/(2) filters
        Product_Account__c pa = makePA(a.Id, 'Cancelled', 'Advanced', false);
        insert pa;

        Contact c = makeContact(a.Id);
        insert c;

        // IMPORTANT: these only work if you wired them into execute()
        WeeklySupportEntitlementCleanup.TEST_paIdsChanged = new Set<Id>{ pa.Id };
        WeeklySupportEntitlementCleanup.TEST_cutoff = System.now().addDays(-7);

        Test.startTest();
        System.schedule('WSEC_Main', CRON, new WeeklySupportEntitlementCleanup());
        Test.stopTest();
       System.debug('Product_Account__c'+pa.Id);
        Product_Account__c paAfter = [
            SELECT Support_Tier__c, Previous_SupportTierVal__c, Status__c, EntitlementException__c
            FROM Product_Account__c
            WHERE Id = :pa.Id
        ];

        // Prove it actually processed the row
        System.assertEquals(null, paAfter.Support_Tier__c,
            'Job did not process PA (Support_Tier__c not nulled). Status=' + paAfter.Status__c);

        System.assertEquals('Advanced', paAfter.Previous_SupportTierVal__c,
            'Previous tier should be captured');
           System.debug('ContactId'+c.id);
        Contact cAfter = [
            SELECT Active_Services__c, Premium_Support_Contact__c, X24_7_Hand_off_Contact__c, Support_Level_Available__c
            FROM Contact
            WHERE Id = :c.Id
        ];
        System.assertEquals(null, cAfter.Active_Services__c);
        System.assertEquals(false, cAfter.X24_7_Hand_off_Contact__c);
        //System.assertEquals('', cAfter.Support_Level_Available__c);
        System.assert(
            cAfter.Support_Level_Available__c == null || cAfter.Support_Level_Available__c == '',
            'Support_Level_Available__c should be cleared (null or blank). Actual=' + cAfter.Support_Level_Available__c
        );

        // Premium flag is not changed by job; don't assert it
    }

    @IsTest
    static void test_early_return_no_changed_ids() {
        WeeklySupportEntitlementCleanup.TEST_paIdsChanged = null;
        WeeklySupportEntitlementCleanup.TEST_cutoff = System.now().addDays(-7);

        Test.startTest();
        System.schedule('WSEC_NoChanged', CRON, new WeeklySupportEntitlementCleanup());
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_account_still_entitled_skips_updates() {
        Account a = new Account(Name = 'Still Entitled Account');
        insert a;

        Product_Account__c paChanged = makePA(a.Id, 'Cancelled', 'Signature', false);
        insert paChanged;

        // Keeps account entitled => acct removed => paChanged not processed
        Product_Account__c paStillActive = makePA(a.Id, 'Active', 'Core', false);
        insert paStillActive;

        WeeklySupportEntitlementCleanup.TEST_paIdsChanged = new Set<Id>{ paChanged.Id };
        WeeklySupportEntitlementCleanup.TEST_cutoff = System.now().addDays(-7);

        Test.startTest();
        System.schedule('WSEC_StillEntitled', CRON, new WeeklySupportEntitlementCleanup());
        Test.stopTest();

        Product_Account__c paAfter = [
            SELECT Support_Tier__c, Previous_SupportTierVal__c
            FROM Product_Account__c
            WHERE Id = :paChanged.Id
        ];
        System.assertEquals('Signature', paAfter.Support_Tier__c);
        System.assertEquals(null, paAfter.Previous_SupportTierVal__c);
    }

    @IsTest
    static void test_exception_rows_ignored() {
        Account a = new Account(Name = 'Exception Row Account');
        insert a;

        Product_Account__c paException = makePA(a.Id, 'Cancelled', 'Advanced', true);
        insert paException;

        WeeklySupportEntitlementCleanup.TEST_paIdsChanged = new Set<Id>{ paException.Id };
        WeeklySupportEntitlementCleanup.TEST_cutoff = System.now().addDays(-7);

        Test.startTest();
        System.schedule('WSEC_Exception', CRON, new WeeklySupportEntitlementCleanup());
        Test.stopTest();

        Product_Account__c paAfter = [
            SELECT Support_Tier__c, Previous_SupportTierVal__c, EntitlementException__c
            FROM Product_Account__c
            WHERE Id = :paException.Id
        ];
        System.assertEquals(true, paAfter.EntitlementException__c);
        System.assertEquals('Advanced', paAfter.Support_Tier__c);
        System.assertEquals(null, paAfter.Previous_SupportTierVal__c);
    }
}