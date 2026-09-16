@isTest
private class ContactCustomHandlerTest {
    @isTest
    static void testInsertAndUpdate() {
        // Test Insert: Adding EU domain
        Contact contact = new Contact(
            LastName = 'Test1',
            QB_Instance__c = 'suvi.eu.qb.org'
        );
        insert contact;

        Contact insertedContact = [SELECT QB_Domain__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals('EU', insertedContact.QB_Domain__c);

        // Test Update: Change QB_Instance__c to add US domain
        contact.QB_Instance__c = 'suvi.qb.org';
        update contact;

        Contact updatedContact = [SELECT QB_Domain__c FROM Contact WHERE Id = :contact.Id];
        //System.assertEquals('EU;US', updatedContact.QB_Domain__c);

        // Test Update: Switch domains from US to EU
        contact.QB_Instance__c = 'suvi.eu.qb.org';
        update contact;

        Contact switchedContact = [SELECT QB_Domain__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals('US;EU', switchedContact.QB_Domain__c);

        // Test Update: Setting to a new instance with EU domain and check no duplicate
        contact.QB_Instance__c = 'new.europe.qb.org';
        update contact;

        Contact newContact = [SELECT QB_Domain__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals('US;EU', newContact.QB_Domain__c); // Still EU;US due to preservation

        // Test Update: Setting to a new instance with US domain and check no duplicate
        contact.QB_Instance__c = 'new.america.qb.org';
        update contact;

        Contact finalContact = [SELECT QB_Domain__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals('US;EU', finalContact.QB_Domain__c); // Still EU;US due to preservation

        // Test Update with a null value for QB_Instance__c
        contact.QB_Instance__c = null;
        update contact;

        Contact nullInstanceContact = [SELECT QB_Domain__c FROM Contact WHERE Id = :contact.Id];
        //System.assertEquals('US;EU', nullInstanceContact.QB_Domain__c); // Should remain as US;EU

        // Test Insert with a US domain
        Contact contactUS = new Contact(
            LastName = 'Test2',
            QB_Instance__c = 'suvi.qb.org'
        );
        insert contactUS;

        Contact insertedUSContact = [SELECT QB_Domain__c FROM Contact WHERE Id = :contactUS.Id];
        System.assertEquals('US', insertedUSContact.QB_Domain__c);

        // Test Update: Changing from US to EU
        contactUS.QB_Instance__c = 'suvi.eu.qb.org';
        update contactUS;

        Contact updatedUSContact = [SELECT QB_Domain__c FROM Contact WHERE Id = :contactUS.Id];
        System.assertEquals('US;EU', updatedUSContact.QB_Domain__c);

        // Test Update: Changing back to US
        contactUS.QB_Instance__c = 'suvi.qb.org';
        update contactUS;

        Contact finalUSContact = [SELECT QB_Domain__c FROM Contact WHERE Id = :contactUS.Id];
        System.assertEquals('US;EU', finalUSContact.QB_Domain__c); // Should still be US;EU
    }
}