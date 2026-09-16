trigger SurveySparrow1000083729Trigger on Case ( after update) {
    
    Automation_Settings__c triggerSetting = Automation_Settings__c.getInstance(UserInfo.getUserId());
    System.debug('Case Trigger is Enabled: ' + triggerSetting);
      
    if (!triggerSetting.Case_Trigger_Enabled__c) {
        System.debug('Bypassed SurveySparrow1000083729Trigger');
        return;
    }
    
    System.debug('SurveySparrow1000083729Trigger running');
    
    for (Case newObj : Trigger.new) {
        
        Case oldObj;
        
        if (Trigger.OldMap != null) {
            oldObj = Trigger.OldMap.get(newObj.Id);
        }
        
        if ((((newObj.Status != null && String.valueOf(newObj.Status) == String.valueOf('Closed')))  )) {
            System.debug('Condition Succesful');
            String endpoint = 'https://api.surveysparrow.com/v3/channels/1000026295';
            
            JSONGenerator gen = JSON.createGenerator(true);
            
            List<Map<String, Object>> contacts = new List<Map<String, Object>>();
            Map <String, Object> contact = new Map<String, Object>();
            
            
            
            Map <String, String> variables = new Map<String, String>();
            
            if (newObj.Id != null) {
                variables.put('Case.Id', String.valueOf(newObj.Id));
            }
            
            
            if (newObj.ContactId != null) {
                variables.put('Case.ContactId', String.valueOf(newObj.ContactId));
            }
            
            
            if (newObj.AccountId != null) {
                variables.put('Case.AccountId', String.valueOf(newObj.AccountId));
            }
            
            contact.put('variables', variables);
            
            contact.put('email', newObj.ContactEmail);
            contacts.add(contact);
            
            gen.writeStartObject();
            gen.writeNumberField('survey_id', 1000083729);
            
            gen.writeObjectField('contacts', contacts);
            
            gen.writeEndObject();
            
            
            String jsonS = gen.getAsString();
            System.debug(jsonS);
            
            SurveySparrow1000114885Class.makeCallout(endpoint, 'PUT', jsonS);
        } else {
            System.debug('Survey Triggering Failed for Survey 1000083729');
        }
    }
}