@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class ListMemberServiceTest {
	@TestSetup
	static void setupBaseData() {
		// Contact
		Contact c = new Contact(LastName = 'Base Contact');
		insert c;

		// Lists
		List__c sourceList = new List__c(Name = 'Source List');
		List__c destList = new List__c(Name = 'Destination List');
		insert new List<List__c>{ sourceList, destList };

		// Campaign
		Campaign destCampaign = new Campaign(
			Name = 'Destination Campaign',
			IsActive = true
		);
		insert destCampaign;

		// Mapping
		insert new Source_List__c(
			Source_List__c = sourceList.Id,
			Destination_List__c = destList.Id,
			Destination_Campaign__c = destCampaign.Id,
			Sync__c = true
		);
	}

	private static Contact fetchContact() {
		return [SELECT Id FROM Contact LIMIT 1];
	}

	private static List__c fetchSourceList() {
		return [SELECT Id FROM List__c WHERE Name = 'Source List' LIMIT 1];
	}

	private static List__c fetchDestList() {
		return [SELECT Id FROM List__c WHERE Name = 'Destination List' LIMIT 1];
	}

	private static Campaign fetchDestCampaign() {
		return [SELECT Id FROM Campaign LIMIT 1];
	}

	private static Source_List__c fetchMapping() {
		return [SELECT Id FROM Source_List__c LIMIT 1];
	}

	@IsTest
	static void testEnqueueSyncCopyMembers() {
		// Arrange
		Contact contact = fetchContact();
		List__c sourceList = fetchSourceList();
		List__c destList = fetchDestList();
		Source_List__c mapping = fetchMapping();

		insert new List_Member__c(
			List__c = sourceList.Id,
			Contact__c = contact.Id,
			Status__c = 'Included'
		);

		ListMemberService service = new ListMemberService();

		// Act
		Test.startTest();
		service.enqueueSyncCopyMembers(new Set<Id>{ mapping.Id });
		Test.stopTest();

		// Assert
		Integer countAfter = [
			SELECT COUNT()
			FROM List_Member__c
			WHERE List__c = :destList.Id AND Contact__c = :contact.Id
		];

		System.assertEquals(
			1,
			countAfter,
			'List member should be copied to destination list'
		);
	}

	@IsTest
	static void testEnqueueSyncRemoveMembers() {
		// Arrange
		Contact contact = fetchContact();
		List__c destList = fetchDestList();
		Campaign destCampaign = fetchDestCampaign();
		Source_List__c mapping = fetchMapping();

		insert new List<List_Member__c>{
			new List_Member__c(
				List__c = destList.Id,
				Contact__c = contact.Id,
				Status__c = 'Included'
			)
		};

		insert new CampaignMember(
			CampaignId = destCampaign.Id,
			ContactId = contact.Id,
			Status = 'Sent'
		);

		Map<Id, Set<Id>> mappingToContacts = new Map<Id, Set<Id>>{
			mapping.Id => new Set<Id>{ contact.Id }
		};

		ListMemberService service = new ListMemberService();

		// Act
		Test.startTest();
		service.enqueueSyncRemoveMembers(mappingToContacts);
		Test.stopTest();

		// Assert — List_Member__c removed
		Integer listCount = [
			SELECT COUNT()
			FROM List_Member__c
			WHERE List__c = :destList.Id AND Contact__c = :contact.Id
		];

		System.assertEquals(0, listCount, 'List member should be removed');

		// Assert — CampaignMember removed
		Integer campaignCount = [
			SELECT COUNT()
			FROM CampaignMember
			WHERE CampaignId = :destCampaign.Id AND ContactId = :contact.Id
		];

		System.assertEquals(0, campaignCount, 'Campaign member should be removed');
	}
}
