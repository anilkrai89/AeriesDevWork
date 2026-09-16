trigger BlockRoleMentionsOnChatter on FeedItem (before insert) {
    BlockRoleMentionsOnChatterHandler.handleBeforeInsert(Trigger.new);
}