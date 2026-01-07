@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class ClientverseLogCleanupBatchTest {
	@IsTest
	static void testSeverityBasedRetention() {
		Clientverse_Log__c debugLog = new Clientverse_Log__c(Severity__c = 'DEBUG');
		Clientverse_Log__c infoLog = new Clientverse_Log__c(Severity__c = 'INFO');

		insert new List<Clientverse_Log__c>{ debugLog, infoLog };

		Test.setCreatedDate(debugLog.Id, System.now().addDays(-31));
		Test.setCreatedDate(infoLog.Id, System.now().addDays(-91));

		Test.startTest();
		Database.executeBatch(new ClientverseLogCleanupBatch(), 200);
		Test.stopTest();

		System.assertEquals(
			0,
			[SELECT COUNT() FROM Clientverse_Log__c WHERE Id = :debugLog.Id]
		);
		System.assertEquals(
			0,
			[SELECT COUNT() FROM Clientverse_Log__c WHERE Id = :infoLog.Id]
		);
	}
}
