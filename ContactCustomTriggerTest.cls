@isTest
public class ContactCustomTriggerTest {

    @isTest
    static void testBeforeInsert_WithIsVRBypassedFalse() {
        
        Contact con = new Contact(
            FirstName = 'AE Change Contact1',
            LastName = 'Testing Batch Class1',
            Email = 'AEChang1@example.com'
                       
        );
        
        Test.startTest();
        insert con;
        Test.stopTest();
        
        // Add asserts here if updateQBDomain makes visible changes
        System.assertNotEquals(null, con.Id);
    }

    @isTest
    static void testBeforeInsert_WithIsVRBypassedTrue() {
        // This contact should be ignored by the trigger logic
        Contact con = new Contact(
            FirstName = 'AE Change Contact2',
            LastName = 'Testing Batch Class2',
            Email = 'AEChang2@example.com',
            ValidationBypassDateTime__c = Datetime.now()
        );
        
        Test.startTest();
        insert con;
        Test.stopTest();

        System.assertNotEquals(null, con.Id);
    }

    @isTest
    static void testBeforeUpdate_WithIsVRBypassedFalse() {
        // First insert a contact
        Contact con = new Contact(
            FirstName = 'AE Change Contact3',
            LastName = 'Testing Batch Class3',
            Email = 'AEChang3@example.com'
          
        );
        insert con;

        // Now update and change IsVRBypassed__c to false to trigger logic
        con.Email = 'AEChang4@example.com';
        

        Test.startTest();
        update con;
        Test.stopTest();
    }

    @isTest
    static void testBeforeUpdate_WithIsVRBypassedTrue() {
        // First insert a contact
        Contact con = new Contact(
            LastName = 'No Trigger Update',
            Email = 'no.trigger@example.com',
            ValidationBypassDateTime__c = Datetime.now()
        );
        insert con;

        // Still bypassed, should not enter handler logic
        con.Email = 'no.trigger.update@example.com';

        Test.startTest();
        update con;
        Test.stopTest();
    }
}