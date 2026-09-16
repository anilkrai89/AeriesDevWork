trigger OpportunityContactRoleTrigger on OpportunityContactRole (
    before insert, before update,
    after insert, after update, after delete
) {
    // ── BYPASS CHECK ──────────────────────────────────────────────────────────
    // If the custom metadata record for this trigger has Is_Disabled__c = true,
    // exit immediately without running any logic.
    if (OpportunityContactRoleHandler.isTriggerDisabled()) {
        return;
    }

    // ── BEFORE ────────────────────────────────────────────────────────────────
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        OpportunityContactRoleHandler.handleBefore(Trigger.new, Trigger.oldMap);
    }

    // ── AFTER ─────────────────────────────────────────────────────────────────
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate || Trigger.isDelete)) {
        OpportunityContactRoleHandler.handleAfter(Trigger.new, Trigger.old, Trigger.isDelete);
    }
}