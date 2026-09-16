trigger EmailMessageTrigger on EmailMessage (before insert, after insert) {

    if (Trigger.isBefore && Trigger.isInsert) {
        EmailMessageHandler.handleClosedCaseEmailsBefore(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        EmailMessageHandler.copyFilesToParentCaseAfter(Trigger.new);
        //for solvice 
        EmailMessageHandler.populateSolviceJobIdAfter(Trigger.new);
    }
}