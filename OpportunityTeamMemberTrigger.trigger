trigger OpportunityTeamMemberTrigger on OpportunityTeamMember (after delete) {
    if (Trigger.isAfter && Trigger.isDelete) {
        OpportunityTeamMemberTriggerHandler.handleAfterDelete(Trigger.old);
    }
}