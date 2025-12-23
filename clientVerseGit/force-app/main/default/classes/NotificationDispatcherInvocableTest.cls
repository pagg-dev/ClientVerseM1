@IsTest
@SuppressWarnings('PMD')
private class NotificationDispatcherInvocableTest {
	@testSetup
	static void setupData() {
		// Active template
		insert new Notification_Template__c(
			DeveloperName__c = 'TEST_EMAIL',
			Subject__c = 'Hello {{name}}',
			Body__c = '<p>Your code is {{code}}</p>',
			Short_Message__c = 'Hi {{name}}',
			Is_Active__c = true
		);

		// Inactive template
		insert new Notification_Template__c(
			DeveloperName__c = 'INACTIVE_TEMPLATE',
			Subject__c = 'Inactive',
			Body__c = 'Inactive',
			Short_Message__c = 'Inactive',
			Is_Active__c = false
		);

		// User for User / In-App tests
		insert new User(
			Alias = 'ntusr',
			Email = 'notify@test.com',
			EmailEncodingKey = 'UTF-8',
			LastName = 'Notify',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			TimeZoneSidKey = 'Asia/Kolkata',
			ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1]
			.Id,
			Username = 'notify.' + System.currentTimeMillis() + '@test.com'
		);
	}

	private static Notification_Request__c buildEmailRequest(
		String templateKey,
		String channel,
		String recipientType
	) {
		return new Notification_Request__c(
			Template_Key__c = templateKey,
			Channel__c = channel,
			Recipient_Type__c = recipientType,
			Email__c = 'user@test.com',
			Context_Record_Id__c = UserInfo.getUserId(),
			Template_Mappings__c = '{"name":"Pulkit","code":"1234"}'
		);
	}

	private static NotificationDispatcherInvocable.RequestInput wrap(Id requestId) {
		NotificationDispatcherInvocable.RequestInput input = new NotificationDispatcherInvocable.RequestInput();
		input.notificationRequestId = requestId;
		return input;
	}

	private static User fetchUser() {
		return [SELECT Id FROM User LIMIT 1];
	}

	@IsTest
	static void testEmailNotificationSuccess() {
		// Arrange
		Notification_Request__c req = buildEmailRequest('TEST_EMAIL', 'Email', 'Email');
		insert req;

		// Act
		Test.startTest();
		List<NotificationDispatcherInvocable.Result> results = NotificationDispatcherInvocable.send(
			new List<NotificationDispatcherInvocable.RequestInput>{ wrap(req.Id) }
		);
		Test.stopTest();

		// Assert
		System.assertEquals(1, results.size());
		System.assertEquals(true, results[0].success);
		System.assertEquals(req.Id, results[0].notificationRequestId);
	}

	@IsTest
	static void testUnsupportedChannelFails() {
		// Arrange
		Notification_Request__c req = buildEmailRequest('TEST_EMAIL', null, 'Email');
		insert req;

		// Act
		List<NotificationDispatcherInvocable.Result> results = NotificationDispatcherInvocable.send(
			new List<NotificationDispatcherInvocable.RequestInput>{ wrap(req.Id) }
		);

		// Assert
		System.assertEquals(false, results[0].success);
		System.assert(
			results[0].errorMessage.contains('Unsupported channel'),
			'Expected unsupported channel error'
		);
	}

	@IsTest
	static void testInactiveTemplateFails() {
		// Arrange
		Notification_Request__c req = buildEmailRequest(
			'INACTIVE_TEMPLATE',
			'Email',
			'Email'
		);
		insert req;

		// Act
		List<NotificationDispatcherInvocable.Result> results = NotificationDispatcherInvocable.send(
			new List<NotificationDispatcherInvocable.RequestInput>{ wrap(req.Id) }
		);

		// Assert
		System.assertEquals(false, results[0].success);
		System.assert(
			results[0].errorMessage.contains('Template not found or inactive'),
			'Expected inactive template error'
		);
	}

	@IsTest
	static void testInAppNotificationSuccess() {
		// Arrange
		User u = fetchUser();

		Notification_Request__c req = new Notification_Request__c(
			Template_Key__c = 'TEST_EMAIL',
			Channel__c = 'In App',
			Recipient_Type__c = 'User',
			Recipient_Id__c = u.Id,
			Context_Record_Id__c = u.Id,
			Template_Mappings__c = '{"name":"Pulkit"}'
		);
		insert req;

		// Act
		Test.startTest();
		List<NotificationDispatcherInvocable.Result> results = NotificationDispatcherInvocable.send(
			new List<NotificationDispatcherInvocable.RequestInput>{ wrap(req.Id) }
		);
		Test.stopTest();

		// Assert
		System.assertEquals(true, results[0].success);
	}

	@IsTest
	static void testMissingEmailFails() {
		// Arrange
		Notification_Request__c req = new Notification_Request__c(
			Template_Key__c = 'TEST_EMAIL',
			Channel__c = 'Email',
			Recipient_Type__c = 'Email',
			Context_Record_Id__c = UserInfo.getUserId(),
			Template_Mappings__c = '{}'
		);
		insert req;

		// Act
		List<NotificationDispatcherInvocable.Result> results = NotificationDispatcherInvocable.send(
			new List<NotificationDispatcherInvocable.RequestInput>{ wrap(req.Id) }
		);

		// Assert
		System.assertEquals(false, results[0].success);
		System.assert(
			results[0].errorMessage.contains('Email__c is required'),
			'Expected missing email error'
		);
	}

	@IsTest
	static void testMissingRecipientIdFails() {
		// Arrange
		Notification_Request__c req = new Notification_Request__c(
			Template_Key__c = 'TEST_EMAIL',
			Channel__c = 'Email',
			Recipient_Type__c = 'User',
			Context_Record_Id__c = UserInfo.getUserId(),
			Template_Mappings__c = '{}'
		);
		insert req;

		// Act
		List<NotificationDispatcherInvocable.Result> results = NotificationDispatcherInvocable.send(
			new List<NotificationDispatcherInvocable.RequestInput>{ wrap(req.Id) }
		);

		// Assert
		System.assertEquals(false, results[0].success);
		System.assert(
			results[0].errorMessage.contains('Recipient_Id__c is required'),
			'Expected missing recipient error'
		);
	}
}
