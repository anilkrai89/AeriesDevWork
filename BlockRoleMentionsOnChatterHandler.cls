/********************************************************************************* 
ClassName : BlockRoleMentionsOnChatterHandler
Test Class :BlockRoleMentionsOnChatterHandlerTest
==================================================================================
Req:Prohibit Solutions Architects from being mentioned in Chatter
 
==================================================================================
History
---------------------------------------------------------------------------------
APIVERSION	  AUTHOR	     DATE	       Jira Ticket No
    62       Anil Kumar    04-Mar-2026      TEAMS-6731
    62       Anil Kumar    14-Mar-2026      TEAMS-6629
*******************************************************************************************************/

/*public with sharing class BlockRoleMentionsOnChatterHandler {
    public static final String FORBIDDEN_ROLE = 'Solution Architect';

    public static void handleBeforeInsert(List<FeedItem> newItems) {
        
        Map<String,BlockRoleMentionOnChatter__c> blockRole = BlockRoleMentionOnChatter__c.getAll();
        if(!Test.isRunningTest() && ( blockRole.Size() >0 && blockRole.get('BlockSARole').MakeActive__c)){
            return;
        } 
      
        if (newItems == null || newItems.isEmpty()) return;
        

        List<User> forbiddenUsers = [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
              AND UserRole.Name = :FORBIDDEN_ROLE
        ];
        if (forbiddenUsers.isEmpty()) return;

        // Precompute normalized tokens
        List<String> tokens = new List<String>();
        for (User u : forbiddenUsers) {
            if (String.isBlank(u.Name)) continue;
            String t = ('@' + u.Name).toLowerCase();
            t = t.replace('&nbsp;', ' ');
            t = t.replace('\u00A0', ' ');
            t = t.replaceAll('\\s+', ' ').trim();
            tokens.add(t);
        }
        if (tokens.isEmpty()) return;
       
        for (FeedItem fi : newItems) {
            if (String.isBlank(fi.Body)) continue;

            String body = fi.Body.toLowerCase();
            body = body.replace('&nbsp;', ' ');
            body = body.replace('\u00A0', ' ');
            body = body.replaceAll('<[^>]*>', '');     // strip HTML tags
            body = body.replaceAll('\\s+', ' ').trim(); // normalize spaces

            if (!body.contains('@')) continue;

            for (String token : tokens) {
                if (body.contains(token)) {
                    fi.addError('You cannot @mention ' + FORBIDDEN_ROLE + ' users in Chatter...');
                    break;
                }
            }
             
        }
    }
}*/
/*****************************************************************************************************/

public with sharing class BlockRoleMentionsOnChatterHandler {
    public static final String FORBIDDEN_ROLE = 'Solution Architect';
    public static final Integer CLOSED_POST_BLOCK_DAYS = 30;

    public static void handleBeforeInsert(List<FeedItem> newItems) {
       /* Map<String, BlockRoleMentionOnChatter__c> blockRole =
            BlockRoleMentionOnChatter__c.getAll();

       if (!Test.isRunningTest()
            && blockRole.size() > 0
            && blockRole.containsKey('BlockSARole')
            && blockRole.get('BlockSARole').MakeActive__c) {
            return;
        }*/
         Map<String,BlockRoleMentionOnChatter__c> blockRole = BlockRoleMentionOnChatter__c.getAll();
        if(!Test.isRunningTest() && !( blockRole.Size() >0 && blockRole.get('BlockSARole').MakeActive__c)){
            return;
        } 

        if (newItems == null || newItems.isEmpty()) {
            return;
        }

        Set<Id> caseIds = new Set<Id>();
        for (FeedItem fi : newItems) {
            if (fi.ParentId != null && fi.ParentId.getSObjectType() == Case.SObjectType) {
                caseIds.add(fi.ParentId);
            }
        }

        Map<Id, Case> caseMap = new Map<Id, Case>();
        if (!caseIds.isEmpty()) {
            caseMap = new Map<Id, Case>([
                SELECT Id, Status, IsClosed, DaysSinceClosed__c,Type
                FROM Case
                WHERE Id IN :caseIds
            ]);
        }

        List<User> forbiddenUsers = [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
            AND UserRole.Name = :FORBIDDEN_ROLE
        ];
        
        
      User currentUser = [
            SELECT Id, IsPortalEnabled
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        Boolean isPortalUser = currentUser.IsPortalEnabled;

        List<String> tokens = new List<String>();
        for (User u : forbiddenUsers) {
            if (String.isBlank(u.Name)) {
                continue;
            }

            String t = ('@' + u.Name).toLowerCase();
            t = t.replace('&nbsp;', ' ');
            t = t.replace('\u00A0', ' ');
            t = t.replaceAll('\\s+', ' ').trim();
            tokens.add(t);
        }

        for (FeedItem fi : newItems) {
            if (isPortalUser && fi.ParentId != null && caseMap.containsKey(fi.ParentId)) {
                Case parentCase = caseMap.get(fi.ParentId);

                if (parentCase != null
                    && parentCase.IsClosed
                    && parentCase.Status =='Closed'
                    && parentCase.Type =='Standard'
                    && parentCase.DaysSinceClosed__c != null
                    && parentCase.DaysSinceClosed__c > CLOSED_POST_BLOCK_DAYS) {
                    fi.addError('Posts are not allowed on cases that have been closed for more than 30 days. Please open a new case referencing this case number, and we will get back to you.');
                    continue;
                }
            }

            if (String.isBlank(fi.Body) || tokens.isEmpty()) {
                continue;
            }

            String body = fi.Body.toLowerCase();
            body = body.replace('&nbsp;', ' ');
            body = body.replace('\u00A0', ' ');
            body = body.replaceAll('<[^>]*>', '');
            body = body.replaceAll('\\s+', ' ').trim();

            if (!body.contains('@')) {
                continue;
            }

            for (String token : tokens) {
                if (body.contains(token)) {
                    fi.addError('You cannot @mention ' + FORBIDDEN_ROLE + ' users in Chatter...');
                    break;
                }
            }
        }
    }
}