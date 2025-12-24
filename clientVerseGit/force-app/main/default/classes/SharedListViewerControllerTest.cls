@IsTest
@SuppressWarnings('PMD')
private class SharedListViewerControllerTest {
	/* =========================================================
	   Test Setup
	   ========================================================= */

	@testSetup
	static void setupData() {
		// User
		User u = new User(
			Alias = 'shusr',
			Email = 'shared@test.com',
			EmailEncodingKey = 'UTF-8',
			LastName = 'Shared',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			TimeZoneSidKey = 'Asia/Kolkata',
			ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1]
			.Id,
			Username = 'shared.' + System.currentTimeMillis() + '@test.com'
		);
		insert u;

		// Contact
		insert new Contact(LastName = 'Viewer');

		// List
		insert new List__c(Name = 'Shared List');
	}

	/* =========================================================
	   Utilities
	   ========================================================= */

	private static User fetchUser() {
		return [SELECT Id FROM User WHERE Alias = 'shusr' LIMIT 1];
	}

	private static Contact fetchContact() {
		return [SELECT Id, Name FROM Contact LIMIT 1];
	}

	private static List__c fetchList() {
		return [SELECT Id FROM List__c LIMIT 1];
	}

	private static View_Share_Config__c createShare(String accessType, Boolean expired) {
		View_Share_Config__c share = new View_Share_Config__c(
			List__c = fetchList().Id,
			Access_Type__c = accessType,
			Shared_With__c = fetchUser().Id,
			Token__c = 'TEST_TOKEN',
			Type__c = 'List Share',
			Revoked__c = false,
			Expires_At__c = expired ? System.now().addMinutes(-10) : null
		);
		insert share;
		return share;
	}

	/* =========================================================
	   Test: resolveShareAccess
	   ========================================================= */

	@IsTest
	static void testResolveShareAccess() {
		View_Share_Config__c share = createShare('View', false);
		Contact c = fetchContact();

		insert new List_Member__c(
			List__c = share.List__c,
			Contact__c = c.Id,
			Status__c = 'Included'
		);

		Test.startTest();
		SharedListViewerController.LandingData data = SharedListViewerController.resolveShareAccess(
			'TEST_TOKEN'
		);
		Test.stopTest();

		System.assertEquals('Shared List', data.listName);
		System.assertEquals('View', data.access);
		System.assertEquals(1, data.members.size());
		System.assertEquals(c.Id, data.members[0].contactId);
	}

	/* =========================================================
	   Test: getContactNames
	   ========================================================= */

	@IsTest
	static void testGetContactNames() {
		Contact c = fetchContact();

		Map<Id, String> result = SharedListViewerController.getContactNames(
			new List<Id>{ c.Id }
		);

		System.assertEquals(1, result.size());
		System.assertEquals(c.Name, result.get(c.Id));
	}

	/* =========================================================
	   Test: submitListChanges – Approved Reviewer
	   ========================================================= */

	@IsTest
	static void testSubmitChangesApprovedReviewer() {
		View_Share_Config__c share = createShare('Approved Reviewer', false);

		Contact c = fetchContact();

		String payload = JSON.serialize(
			new List<Object>{
				new Map<String, Object>{
					'isNew' => true,
					'contactId' => c.Id,
					'status' => 'Included'
				}
			}
		);

		Test.startTest();
		Boolean success = SharedListViewerController.submitListChanges(
			share.List__c,
			share.Id,
			payload
		);
		Test.stopTest();

		System.assertEquals(true, success);

		Integer memberCount = [
			SELECT COUNT()
			FROM List_Member__c
			WHERE List__c = :share.List__c AND Contact__c = :c.Id
		];

		System.assertEquals(1, memberCount);
	}

	/* =========================================================
	   Test: submitListChanges – Proposal path
	   ========================================================= */

	@IsTest
	static void testSubmitChangesCreatesProposal() {
		View_Share_Config__c share = createShare('View', false);

		Contact c = fetchContact();

		String payload = JSON.serialize(
			new List<Object>{
				new Map<String, Object>{
					'isNew' => true,
					'contactId' => c.Id,
					'status' => 'Included'
				}
			}
		);

		Test.startTest();
		Boolean success = SharedListViewerController.submitListChanges(
			share.List__c,
			share.Id,
			payload
		);
		Test.stopTest();

		System.assertEquals(true, success);

		// Assert proposal created
		List_Change__c change = [
			SELECT Id
			FROM List_Change__c
			WHERE List__c = :share.List__c
			LIMIT 1
		];

		System.assertNotEquals(null, change.Id);

		// Assert notification created (NO semi-join on polymorphic field)
		Integer notifCount = [
			SELECT COUNT()
			FROM Notification_Request__c
			WHERE Context_Record_Id__c = :change.Id
		];

		System.assertEquals(
			1,
			notifCount,
			'Expected one in-app notification for change proposal'
		);
	}
}
