@IsTest
@SuppressWarnings('PMD')
private class ListMemberDomainTest {
	private class MockListMemberService implements IListMemberService {
		public Set<Id> copyMappingIds = new Set<Id>();
		public Map<Id, Set<Id>> removeMappingToContacts = new Map<Id, Set<Id>>();

		public void enqueueSyncCopyMembers(Set<Id> mappingIds) {
			copyMappingIds.addAll(mappingIds);
		}

		public void enqueueSyncRemoveMembers(Map<Id, Set<Id>> mappingToContacts) {
			removeMappingToContacts.putAll(mappingToContacts);
		}
	}

	@TestSetup
	static void setupBaseData() {
		insert new Contact(LastName = 'Base Contact');

		List__c sourceList = new List__c(
			Name = 'Source List',
			List_Member_Mapping__c = '{"Status__c":"Included","Custom_Text__c":"Mapped"}'
		);

		List__c destinationList = new List__c(Name = 'Destination List');

		insert new List<List__c>{ sourceList, destinationList };

		insert new Source_List__c(
			Source_List__c = sourceList.Id,
			Destination_List__c = destinationList.Id,
			Sync__c = true
		);
	}

	private static Contact fetchContact() {
		return [SELECT Id FROM Contact LIMIT 1];
	}

	private static Map<String, List__c> fetchLists() {
		Map<String, List__c> result = new Map<String, List__c>();
		for (List__c l : [
			SELECT Id, Name, List_Member_Mapping__c
			FROM List__c
		]) {
			result.put(l.Name, l);
		}
		return result;
	}

	private static Source_List__c fetchMapping() {
		return [
			SELECT Id, Source_List__c
			FROM Source_List__c
			LIMIT 1
		];
	}

	@IsTest
	static void testAppliesListMemberMappingOnInsert() {
		// Arrange
		MockListMemberService mock = new MockListMemberService();
		ListMemberServiceFactory.setMock(mock);

		Contact contact = fetchContact();
		List__c sourceList = fetchLists().get('Source List');

		// Act
		Test.startTest();
		insert new List_Member__c(List__c = sourceList.Id, Contact__c = contact.Id);
		Test.stopTest();

		// Assert
		List_Member__c inserted = [
			SELECT Status__c
			FROM List_Member__c
			LIMIT 1
		];

		System.assertEquals('Included', inserted.Status__c);

		ListMemberServiceFactory.clearMock();
	}

	@IsTest
	static void testEnqueuesCopySyncOnInsert() {
		// Arrange
		MockListMemberService mock = new MockListMemberService();
		ListMemberServiceFactory.setMock(mock);

		Contact contact = fetchContact();
		List__c sourceList = fetchLists().get('Source List');
		Source_List__c mapping = fetchMapping();

		// Act
		Test.startTest();
		insert new List_Member__c(
			List__c = sourceList.Id,
			Contact__c = contact.Id,
			Status__c = 'Included'
		);
		Test.stopTest();

		// Assert
		System.assertEquals(
			1,
			mock.copyMappingIds.size(),
			'One mapping should be enqueued for copy'
		);
		System.assert(
			mock.copyMappingIds.contains(mapping.Id),
			'Correct mapping Id must be enqueued'
		);

		ListMemberServiceFactory.clearMock();
	}

	@IsTest
	static void testEnqueuesRemoveSyncOnDelete() {
		// Arrange
		MockListMemberService mock = new MockListMemberService();
		ListMemberServiceFactory.setMock(mock);

		Contact contact = fetchContact();
		Map<String, List__c> lists = fetchLists();
		List__c sourceList = lists.get('Source List');
		Source_List__c mapping = fetchMapping();

		List_Member__c member = new List_Member__c(
			List__c = sourceList.Id,
			Contact__c = contact.Id,
			Status__c = 'Included'
		);
		insert member;

		// Act
		Test.startTest();
		delete member;
		Test.stopTest();

		// Assert
		System.assertEquals(
			1,
			mock.removeMappingToContacts.size(),
			'One mapping should be enqueued for removal'
		);

		System.assert(
			mock.removeMappingToContacts.containsKey(mapping.Id),
			'Correct mapping Id must be used'
		);

		System.assert(
			mock.removeMappingToContacts.get(mapping.Id).contains(contact.Id),
			'Correct contact Id must be passed'
		);

		ListMemberServiceFactory.clearMock();
	}

	@IsTest
	static void testUndeleteTriggersCopySync() {
		// Arrange
		MockListMemberService mock = new MockListMemberService();
		ListMemberServiceFactory.setMock(mock);

		Contact contact = fetchContact();
		List__c sourceList = fetchLists().get('Source List');

		List_Member__c member = new List_Member__c(
			List__c = sourceList.Id,
			Contact__c = contact.Id,
			Status__c = 'Included'
		);

		insert member;
		delete member;

		// Act
		Test.startTest();
		undelete member;
		Test.stopTest();

		// Assert
		System.assert(
			!mock.copyMappingIds.isEmpty(),
			'Undelete should enqueue copy sync'
		);

		ListMemberServiceFactory.clearMock();
	}
}
