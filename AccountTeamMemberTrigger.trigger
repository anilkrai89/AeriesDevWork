trigger AccountTeamMemberTrigger on AccountTeamMember (after insert, after update, after undelete) {
    AccountTeamMemberHandler.markAccountsForIntegrationUpdate(Trigger.new, Trigger.oldMap);
}