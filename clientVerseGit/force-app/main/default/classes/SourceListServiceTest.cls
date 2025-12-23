@IsTest
@SuppressWarnings('PMD')
private class SourceListServiceTest {
	@TestSetup
	static void setupBaseData() {
		// Contact
		insert new Contact(LastName = 'Base Contact');

		// Lists
		insert new List<List__c>{
			new List__c(Name = 'List A'),
			new List__c(Name = 'List B'),
			new List__c(Name = 'List C')
		};

		// Campaigns
		insert new List<Campaign>{
			new Campaign(Name = 'Camp A', IsActive = true),
			new Campaign(Name = 'Camp B', IsActive = true)
		};

		// Seed one member (used for validation paths)
		insert new List_Member__c(
			List__c = [SELECT Id FROM List__c WHERE Name = 'List A' LIMIT 1]
			.Id,
			Contact__c = [SELECT Id FROM Contact LIMIT 1]
			.Id,
			Status__c = 'Included'
		);
	}

	private static Contact fetchContact() {
		return [SELECT Id FROM Contact LIMIT 1];
	}

	private static Map<String, List__c> fetchLists() {
		Map<String, List__c> result = new Map<String, List__c>();
		for (List__c l : [SELECT Id, Name FROM List__c]) {
			result.put(l.Name, l);
		}
		return result;
	}

	private static Map<String, Campaign> fetchCampaigns() {
		Map<String, Campaign> result = new Map<String, Campaign>();
		for (Campaign c : [SELECT Id, Name FROM Campaign]) {
			result.put(c.Name, c);
		}
		return result;
	}

	@IsTest
	static void testBuildSnapshotCreatesPairs() {
		Map<String, List__c> lists = fetchLists();
		Map<String, Campaign> camps = fetchCampaigns();

		Source_List__c mapping = new Source_List__c(
			Source_List__c = lists.get('List A').Id,
			Destination_List__c = lists.get('List B').Id,
			Source_Campaign__c = camps.get('Camp A').Id,
			Destination_Campaign__c = camps.get('Camp B').Id,
			Source_List_Type__c = 'Inclusion'
		);
		insert mapping;

		SourceListService.Snapshot snapshot = new SourceListService()
			.buildSnapshot(new Set<Id>{ mapping.Id });

		System.assertEquals(1, snapshot.listPairs.size());
		System.assertEquals(1, snapshot.campPairs.size());
	}

	@IsTest
	static void testEnqueueCopyRunsBatches() {
		Map<String, List__c> lists = fetchLists();
		Map<String, Campaign> camps = fetchCampaigns();
		Contact contact = fetchContact();

		Source_List__c mapping = new Source_List__c(
			Source_List__c = lists.get('List A').Id,
			Destination_List__c = lists.get('List B').Id,
			Source_Campaign__c = camps.get('Camp A').Id,
			Destination_Campaign__c = camps.get('Camp B').Id,
			Source_List_Type__c = 'Inclusion'
		);
		insert mapping;

		insert new List_Member__c(
			List__c = lists.get('List A').Id,
			Contact__c = contact.Id,
			Status__c = 'Included'
		);

		insert new CampaignMember(
			CampaignId = camps.get('Camp A').Id,
			ContactId = contact.Id,
			Status = 'Sent'
		);

		Test.startTest();
		new SourceListService().enqueueCopy(new Set<Id>{ mapping.Id });
		Test.stopTest();

		System.assertEquals(
			1,
			[SELECT COUNT() FROM List_Member__c WHERE List__c = :lists.get('List B').Id]
		);

		System.assertEquals(
			1,
			[
				SELECT COUNT()
				FROM CampaignMember
				WHERE CampaignId = :camps.get('Camp B').Id
			]
		);
	}

	@IsTest
	static void testEnqueueRemoveDeletesMembers() {
		Map<String, List__c> lists = fetchLists();
		Map<String, Campaign> camps = fetchCampaigns();
		Contact contact = fetchContact();

		Source_List__c mapping = new Source_List__c(
			Source_List__c = lists.get('List A').Id,
			Destination_List__c = lists.get('List B').Id,
			Source_Campaign__c = camps.get('Camp A').Id,
			Destination_Campaign__c = camps.get('Camp B').Id
		);
		insert mapping;

		insert new List_Member__c(
			List__c = lists.get('List B').Id,
			Contact__c = contact.Id,
			Status__c = 'Included'
		);

		insert new CampaignMember(
			CampaignId = camps.get('Camp B').Id,
			ContactId = contact.Id,
			Status = 'Sent'
		);

		Test.startTest();
		new SourceListService().enqueueRemove(new Set<Id>{ mapping.Id });
		Test.stopTest();
	}

	@IsTest
	static void testValidateDetectsCycle() {
		Map<String, List__c> lists = fetchLists();

		insert new Source_List__c(
			Source_List__c = lists.get('List A').Id,
			Destination_List__c = lists.get('List B').Id
		);

		Source_List__c invalid = new Source_List__c(
			Source_List__c = lists.get('List B').Id,
			Destination_List__c = lists.get('List A').Id
		);

		try {
			insert invalid;
			System.assert(false, 'Cycle should have been blocked');
		} catch (DmlException ex) {
			System.assert(ex.getMessage().contains('cycle'));
		}
	}

	@IsTest
	static void testValidateAllowsValidMapping() {
		Map<String, List__c> lists = fetchLists();

		Source_List__c valid = new Source_List__c(
			Source_List__c = lists.get('List A').Id,
			Destination_List__c = lists.get('List C').Id
		);

		insert valid;

		System.assertNotEquals(null, valid.Id);
	}
}
