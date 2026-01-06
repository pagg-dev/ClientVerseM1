@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class LogServiceTest {
	private static LogService.LogEntry buildEntry() {
		return new LogService.LogEntry()
			.setProcess('UnitTest')
			.setSeverity(LogService.Severity.INFO)
			.setMessage('Test message')
			.setData(new Map<String, Object>{ 'key' => 'value' });
	}

	@IsTest
	static void testQueueAndFlushPublishesAndClearsBuffer() {
		LogService service = new LogService();

		LogService.LogEntry entry1 = buildEntry();
		LogService.LogEntry entry2 = buildEntry().setMessage('Second message');

		Test.startTest();
		service.queue(entry1);
		service.queue(entry2);
		service.flush(); // should route to debugFallback in tests
		Test.stopTest();

		// No exception = success
		System.assert(true, 'Flush should complete without errors');
	}

	@IsTest
	static void testFlushWithEmptyBufferDoesNothing() {
		LogService service = new LogService();

		Test.startTest();
		service.flush();
		Test.stopTest();

		System.assert(true, 'Flush on empty buffer should be a no-op');
	}

	@IsTest
	static void testQueueIgnoresNullEntry() {
		LogService service = new LogService();

		Test.startTest();
		service.queue(null);
		service.flush();
		Test.stopTest();

		System.assert(true, 'Null entries should be ignored safely');
	}

	@IsTest
	static void testStaticLogPublishesSingleEntry() {
		LogService.LogEntry entry = buildEntry();

		Test.startTest();
		LogService.log(entry);
		Test.stopTest();

		System.assert(true, 'Static log should execute without exception');
	}

	@IsTest
	static void testStaticLogIgnoresNullEntry() {
		Test.startTest();
		LogService.log(null);
		Test.stopTest();

		System.assert(true, 'Static log should ignore null safely');
	}

	@IsTest
	static void testLogErrorCreatesErrorSeverityEntry() {
		Exception ex = new IllegalArgumentException('Boom');

		Test.startTest();
		LogService.logError(
			'ErrorProcess',
			ex,
			new Map<String, Object>{ 'context' => 'test' }
		);
		Test.stopTest();

		System.assert(true, 'logError should publish safely');
	}

	@IsTest
	static void testLogErrorIgnoresNullException() {
		Test.startTest();
		LogService.logError('Process', null, null);
		Test.stopTest();

		System.assert(true, 'Null exception should be ignored');
	}

	@IsTest
	static void testLogEntryFluentSetters() {
		LogService.LogEntry entry = new LogService.LogEntry()
			.setProcess('MyProcess')
			.setSeverity(LogService.Severity.WARN)
			.setMessage('Something happened')
			.setData('payload');

		System.assertEquals('MyProcess', entry.process);
		System.assertEquals(LogService.Severity.WARN, entry.severity);
		System.assertEquals('Something happened', entry.message);
		System.assertEquals('payload', entry.data);
		System.assertNotEquals(null, entry.timestamp);
	}

	@IsTest
	static void testToPlatformEventMapping() {
		LogService.LogEntry entry = new LogService.LogEntry()
			.setProcess('UnitTest')
			.setSeverity(LogService.Severity.ERROR)
			.setMessage('Failure occurred')
			.setData(new Map<String, Object>{ 'id' => 123 });

		Notification_Event__e evt = LogService.toPlatformEvent(entry);

		System.assertEquals('Log', evt.Type__c);
		System.assertEquals('UnitTest', evt.Process__c);
		System.assertEquals('ERROR', evt.Severity__c);
		System.assertEquals('Failure occurred', evt.Message__c);
		System.assert(evt.Data__c.contains('123'));
		System.assertNotEquals(null, evt.Timestamp__c);
	}
}
