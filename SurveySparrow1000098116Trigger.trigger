trigger SurveySparrow1000098116Trigger on Case ( after update) {
    
    Automation_Settings__c triggerSetting = Automation_Settings__c.getInstance(UserInfo.getUserId());
    System.debug('Case Trigger is Enabled: ' + triggerSetting);
    
    if (!triggerSetting.Case_Trigger_Enabled__c) {
        System.debug('Bypassed SurveySparrow1000098116Trigger');
        return;
    }
    
    System.debug('SurveySparrow1000098116Trigger running');
    
    for (Case newObj : Trigger.new) {
        Case oldObj;
        
        if (Trigger.OldMap != null) {
            oldObj = Trigger.OldMap.get(newObj.Id);
        }
        
        if ((((newObj.Status != null && String.valueOf(newObj.Status) == String.valueOf('Closed'))) && ((newObj.Do_Not_Send_Survey__c != null && String.valueOf(newObj.Do_Not_Send_Survey__c) == String.valueOf('false'))) && ((oldObj != null && String.valueOf(oldObj.Status) != String.valueOf(newObj.Status)))  )) {
            System.debug('Condition Succesful');
            String endpoint = 'https://api.surveysparrow.com/v3/channels/1000033489';
            
            JSONGenerator gen = JSON.createGenerator(true);
            
            List<Map<String, Object>> contacts = new List<Map<String, Object>>();
            Map <String, Object> contact = new Map<String, Object>();
            
            
            
            Map <String, String> variables = new Map<String, String>();
            
            if (newObj.Id != null) {
                variables.put('Case.Id', String.valueOf(newObj.Id));
            }
            
            
            if (newObj.CaseNumber != null) {
                variables.put('Case.CaseNumber', String.valueOf(newObj.CaseNumber));
            }
            
            
            if (newObj.OwnerId != null) {
                variables.put('Case.OwnerId', String.valueOf(newObj.OwnerId));
            }
            
            
            if (newObj.SuppliedEmail != null) {
                variables.put('Case.SuppliedEmail', String.valueOf(newObj.SuppliedEmail));
            }
            
            
            if (newObj.ContactEmail != null) {
                variables.put('Case.ContactEmail', String.valueOf(newObj.ContactEmail));
            }
            
            
            if (newObj.ContactId != null) {
                variables.put('Case.ContactId', String.valueOf(newObj.ContactId));
            }
            
            
            if (newObj.SuppliedName != null) {
                variables.put('Case.SuppliedName', String.valueOf(newObj.SuppliedName));
            }
            
            
            if (newObj.Contact_First_Name__c != null) {
                variables.put('Case.Contact_First_Name__c', String.valueOf(newObj.Contact_First_Name__c));
            }
            
            contact.put('variables', variables);
            
            contact.put('email', newObj.ContactEmail);
            contacts.add(contact);
            
            gen.writeStartObject();
            gen.writeNumberField('survey_id', 1000098116);
            
            gen.writeObjectField('contacts', contacts);
            
            gen.writeEndObject();
            
            
            String jsonS = gen.getAsString();
            System.debug(jsonS);
            
            SurveySparrow1000114885Class.makeCallout(endpoint, 'PUT', jsonS);
        } else {
            System.debug('Survey Triggering Failed for Survey 1000098116');
        }
    }
}