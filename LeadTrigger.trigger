trigger LeadTrigger on Lead (before insert, before update) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
        LeadTriggerHandler.beforeInsert(Trigger.new);
    }
    
    if (Trigger.isBefore && Trigger.isUpdate) {
        LeadTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
}