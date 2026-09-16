trigger SurveySparrow1000082264Trigger on Case ( after update) {

    for (Case newObj : Trigger.new) {

      
      Case oldObj;

      if (Trigger.OldMap != null) {
        oldObj = Trigger.OldMap.get(newObj.Id);
      }

      if ((((newObj.Status != null && String.valueOf(newObj.Status) == String.valueOf('Closed')))  )) {
        System.debug('Condition Succesful');
        String endpoint = 'https://api.surveysparrow.com/v3/channels/1000206641';

        JSONGenerator gen = JSON.createGenerator(true);
        
        List<Map<String, Object>> contacts = new List<Map<String, Object>>();
        Map <String, Object> contact = new Map<String, Object>();

        
    
    Map <String, String> variables = new Map<String, String>();
    
      if (newObj.ContactId != null) {
        variables.put('Case.ContactId', String.valueOf(newObj.ContactId));
      }
    

      if (newObj.Id != null) {
        variables.put('Case.Id', String.valueOf(newObj.Id));
      }
    

      if (newObj.CaseNumber != null) {
        variables.put('Case.CaseNumber', String.valueOf(newObj.CaseNumber));
      }
    
    contact.put('variables', variables);
  
    contact.put('email', newObj.SuppliedEmail);
    contacts.add(contact);

    gen.writeStartObject();
    gen.writeNumberField('survey_id', 1000082264);
    
    gen.writeObjectField('contacts', contacts);

    gen.writeEndObject();
  

        String jsonS = gen.getAsString();
        System.debug(jsonS);

       SurveySparrow1000114885Class.makeCallout(endpoint, 'PUT', jsonS);
      } else {
        System.debug('Survey Triggering Failed for Survey 1000082264');
      }
    }
  }