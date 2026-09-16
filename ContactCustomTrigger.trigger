trigger ContactCustomTrigger on Contact (before insert, before update) {

    List<Contact> contactsToCheck = new List<Contact>();
    
    for(Contact con : Trigger.new){
    
        if(con.IsVRBypassed__c == FALSE){
        
            contactsToCheck.add(con);
        }
    
    }
    
    if(contactsToCheck.size() > 0){
                 
     ContactCustomHandler.updateQBDomain(Trigger.new, Trigger.oldMap);

}                       
}