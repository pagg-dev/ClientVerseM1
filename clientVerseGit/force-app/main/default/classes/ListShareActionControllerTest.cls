@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class ListShareActionControllerTest {
	@TestSetup
	static void setupData() {
		// User to share with
		insert new User(
			Alias = 'shrusr',
			Email = 'share@test.com',
			EmailEncodingKey = 'UTF-8',
			LastName = 'Share',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			TimeZoneSidKey = 'Asia/Kolkata',
			ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1]
			.Id,
			Username = 'share.' + System.currentTimeMillis() + '@test.com'
		);

		// Parent List
		insert new List__c(Name = 'Test List');
	}

	private static User fetchUser() {
		return [SELECT Id, Name FROM User WHERE Alias = 'shrusr' LIMIT 1];
	}

	private static List__c fetchList() {
		return [SELECT Id FROM List__c LIMIT 1];
	}

	@IsTest
	static void testSearchUsers() {
		Test.startTest();
		List<User> users = ListShareActionController.searchUsers('Share');
		Test.stopTest();

		System.assert(users.size() > 0, 'Expected at least one matching active user');
	}

	@IsTest
	static void testGenerateTokenCreatesTokenAndNotifications() {
		User u = fetchUser();
		List__c listRec = fetchList();

		View_Share_Config__c share = new View_Share_Config__c(
			List__c = listRec.Id,
			Shared_With__c = u.Id,
			Sharing_Type__c = 'Authenticated',
			Expires_At__c = System.now().addDays(7)
		);

		Test.startTest();
		View_Share_Config__c result = ListShareActionController.generateToken(share);
		Test.stopTest();

		System.assertNotEquals(null, result.Id, 'Share record should be inserted');
		System.assertEquals('List Share', result.Type__c);
		System.assertEquals(false, result.Revoked__c);
		System.assertNotEquals(null, result.Token__c);
		System.assertNotEquals(null, result.Tokenized_URL__c);

		// Notifications created
		Integer notifCount = [
			SELECT COUNT()
			FROM Notification_Request__c
			WHERE Context_Record_Id__c = :result.Id
		];

		System.assertEquals(
			2,
			notifCount,
			'Expected Email + In-App notification requests'
		);
	}

	@IsTest
	static void testRevokeToken() {
		User u = fetchUser();
		List__c listRec = fetchList();

		View_Share_Config__c share = new View_Share_Config__c(
			List__c = listRec.Id,
			Shared_With__c = u.Id,
			Sharing_Type__c = 'Authenticated'
		);
		insert share;

		Test.startTest();
		Boolean success = ListShareActionController.revokeToken(share.Id);
		Test.stopTest();

		System.assertEquals(true, success);

		View_Share_Config__c updated = [
			SELECT Revoked__c
			FROM View_Share_Config__c
			WHERE Id = :share.Id
		];

		System.assertEquals(true, updated.Revoked__c);
	}

	@IsTest
	static void testRevokeTokenWithNullId() {
		Boolean result = ListShareActionController.revokeToken(null);
		System.assertEquals(false, result);
	}
}
