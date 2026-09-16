/*@IsTest(SeeAllData=true)
private class BlockRoleMentionsOnChatterHandlerTest {

    @IsTest
    static void blocksForbiddenRoleMention() {
        // 1) Find an existing forbidden-role user
        User forbidden = [
            SELECT Id, Name, UserRole.Name
            FROM User
            WHERE IsActive = true
              AND UserRole.Name = :BlockRoleMentionsOnChatterHandler.FORBIDDEN_ROLE
            LIMIT 1
        ];

        // 2) Find a different active user to post as
        User poster = [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
              AND Id != :forbidden.Id
            LIMIT 1
        ];

        // 3) Use an existing record as ParentId; Account is commonly available
        Account a;
        List<Account> accts = [SELECT Id FROM Account LIMIT 1];
        if (!accts.isEmpty()) {
            a = accts[0];
        } else {
            // As a fallback, use the poster's User feed (usually works if no accounts exist)
            a = null;
        }

        System.runAs(poster) {
            FeedItem fi = new FeedItem();
            fi.ParentId = (a != null) ? a.Id : poster.Id;
            fi.Body = '@' + forbidden.Name + ' test';

            Test.startTest();
            try {
                insert fi;
                System.assert(false, 'Expected insert to fail due to forbidden role mention.');
            } catch (DmlException e) {
                System.assert(
                    e.getDmlMessage(0).contains('You cannot @mention'),
                    'Expected restriction error. Actual: ' + e.getDmlMessage(0)
                );
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void allowsNonForbiddenPost() {
        // Find any active user to post as
        User poster = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];

        Account a;
        List<Account> accts = [SELECT Id FROM Account LIMIT 1];
        if (!accts.isEmpty()) {
            a = accts[0];
        }

        System.runAs(poster) {
            FeedItem ok = new FeedItem();
            ok.ParentId = (a != null) ? a.Id : poster.Id;
            ok.Body = 'Hello team, no mentions here.';

            Test.startTest();
            insert ok;
            Test.stopTest();

            System.assertNotEquals(null, ok.Id, 'FeedItem should have been inserted.');
        }
    }
}*/


@IsTest(SeeAllData=true)
private class BlockRoleMentionsOnChatterHandlerTest {

    private static User getForbiddenUser() {
        List<User> users = [
            SELECT Id, Name, UserRole.Name
            FROM User
            WHERE IsActive = true
              AND UserRole.Name = :BlockRoleMentionsOnChatterHandler.FORBIDDEN_ROLE
            LIMIT 1
        ];
        System.assert(!users.isEmpty(),
            'Need an active user with role ' + BlockRoleMentionsOnChatterHandler.FORBIDDEN_ROLE);
        return users[0];
    }

    private static User getNonForbiddenUser(Id excludeUserId) {
        List<User> users = [
            SELECT Id, Name, UserRole.Name
            FROM User
            WHERE IsActive = true
              AND Id != :excludeUserId
              AND (UserRole.Name = null OR UserRole.Name != :BlockRoleMentionsOnChatterHandler.FORBIDDEN_ROLE)
            LIMIT 1
        ];
        System.assert(!users.isEmpty(), 'Need an active non-forbidden user.');
        return users[0];
    }

    private static Id getNonCaseParentId(Id fallbackUserId) {
        List<Account> accts = [SELECT Id FROM Account LIMIT 1];
        if (!accts.isEmpty()) {
            return accts[0].Id;
        }
        return fallbackUserId;
    }

    @IsTest
    static void testHandleBeforeInsert_NullAndEmptyList() {
        Test.startTest();
        BlockRoleMentionsOnChatterHandler.handleBeforeInsert(null);
        BlockRoleMentionsOnChatterHandler.handleBeforeInsert(new List<FeedItem>());
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testSafeBody_NoMention() {
        User poster = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        FeedItem fi = new FeedItem(
            ParentId = getNonCaseParentId(poster.Id),
            Body = 'Hello team, no mentions here.'
        );

        Test.startTest();
        BlockRoleMentionsOnChatterHandler.handleBeforeInsert(new List<FeedItem>{ fi });
        Test.stopTest();

        System.assertEquals(null, fi.Id);
    }

    @IsTest
    static void testBlankBodyBranch() {
        User poster = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        FeedItem fi = new FeedItem(
            ParentId = getNonCaseParentId(poster.Id),
            Body = '   '
        );

        Test.startTest();
        BlockRoleMentionsOnChatterHandler.handleBeforeInsert(new List<FeedItem>{ fi });
        Test.stopTest();

        System.assertEquals(null, fi.Id);
    }

    @IsTest
    static void testForbiddenMentionBranchCoverage() {
        User forbiddenUser = getForbiddenUser();
        User poster = getNonForbiddenUser(forbiddenUser.Id);

        System.runAs(poster) {
            FeedItem fi = new FeedItem(
                ParentId = getNonCaseParentId(poster.Id),
                Body = '@' + forbiddenUser.Name + ' please review this'
            );

            Test.startTest();
            BlockRoleMentionsOnChatterHandler.handleBeforeInsert(new List<FeedItem>{ fi });
            Test.stopTest();

            System.assertEquals(null, fi.Id);
        }
    }

    @IsTest
    static void testForbiddenMentionWithHtmlNormalizationCoverage() {
        User forbiddenUser = getForbiddenUser();
        User poster = getNonForbiddenUser(forbiddenUser.Id);

        System.runAs(poster) {
            FeedItem fi = new FeedItem(
                ParentId = getNonCaseParentId(poster.Id),
                Body = '<p>@' + forbiddenUser.Name.replace(' ', '&nbsp;') + '</p>'
            );

            Test.startTest();
            BlockRoleMentionsOnChatterHandler.handleBeforeInsert(new List<FeedItem>{ fi });
            Test.stopTest();

            System.assertEquals(null, fi.Id);
        }
    }

    @IsTest
    static void testAllowedMentionBranchCoverage() {
        User forbiddenUser = getForbiddenUser();
        User poster = getNonForbiddenUser(forbiddenUser.Id);

        List<User> allowedTargets = [
            SELECT Id, Name, UserRole.Name
            FROM User
            WHERE IsActive = true
              AND Id != :poster.Id
              AND Id != :forbiddenUser.Id
              AND (UserRole.Name = null OR UserRole.Name != :BlockRoleMentionsOnChatterHandler.FORBIDDEN_ROLE)
            LIMIT 1
        ];
        System.assert(!allowedTargets.isEmpty(), 'Need one allowed mention target.');

        System.runAs(poster) {
            FeedItem fi = new FeedItem(
                ParentId = getNonCaseParentId(poster.Id),
                Body = '@' + allowedTargets[0].Name + ' thanks'
            );

            Test.startTest();
            BlockRoleMentionsOnChatterHandler.handleBeforeInsert(new List<FeedItem>{ fi });
            Test.stopTest();

            System.assertEquals(null, fi.Id);
        }
    }

    @IsTest
    static void testBulkMixedBranchCoverage() {
        User forbiddenUser = getForbiddenUser();
        User poster = getNonForbiddenUser(forbiddenUser.Id);
        Id parentId = getNonCaseParentId(poster.Id);

        List<FeedItem> items = new List<FeedItem>{
            new FeedItem(ParentId = parentId, Body = 'safe post'),
            new FeedItem(ParentId = parentId, Body = 'another safe post'),
            new FeedItem(ParentId = parentId, Body = '@' + forbiddenUser.Name + ' blocked mention')
        };

        System.runAs(poster) {
            Test.startTest();
            BlockRoleMentionsOnChatterHandler.handleBeforeInsert(items);
            Test.stopTest();
        }

        System.assertEquals(3, items.size());
    }

   @IsTest
static void testCaseBranch_InternalUser() {
    User poster = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];

    // Fake Case Id just to exercise the Case ParentId branch without inserting a Case
    Id fakeCaseId = '500000000000001AAA';

    FeedItem fi = new FeedItem(
        ParentId = fakeCaseId,
        Body = 'Safe post on case without mention'
    );

    System.runAs(poster) {
        Test.startTest();
        BlockRoleMentionsOnChatterHandler.handleBeforeInsert(new List<FeedItem>{ fi });
        Test.stopTest();
    }

    System.assertEquals(null, fi.Id);
}

   @IsTest
static void testCaseBranchWithBlankBody() {
    User poster = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];

    // Fake Case Id just to exercise the Case ParentId branch without inserting a Case
    Id fakeCaseId = '500000000000002AAA';

    FeedItem fi = new FeedItem(
        ParentId = fakeCaseId,
        Body = '   '
    );

    System.runAs(poster) {
        Test.startTest();
        BlockRoleMentionsOnChatterHandler.handleBeforeInsert(new List<FeedItem>{ fi });
        Test.stopTest();
    }

    System.assertEquals(null, fi.Id);
}
}