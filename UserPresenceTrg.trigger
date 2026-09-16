trigger UserPresenceTrg on UserServicePresence(after insert, after update)
{
    UserPresenceTrgHandler.handleAfter(Trigger.new, Trigger.oldMap);
}