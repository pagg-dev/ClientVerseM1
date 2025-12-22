@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class CampaignMembersCopyBatchTest {
	@TestSetup
	static void setupBaseData() {
		// Contact
		insert new Contact(LastName = 'Base Contact');

		// Campaigns
		Campaign source = new Campaign(Name = 'Base Source Campaign', IsActive = true);
		Campaign destination = new Campaign(
			Name = 'Base Destination Campaign',
			IsActive = true
		);
		insert new List<Campaign>{ source, destination };

		// Status values for BOTH campaigns
		createStatuses(source.Id);
		createStatuses(destination.Id);
	}

	private static void createStatuses(Id campaignId) {
		insert new List<CampaignMemberStatus>{
			new CampaignMemberStatus(
				CampaignId = campaignId,
				Label = 'Included',
				SortOrder = 5,
				IsDefault = true
			),
			new CampaignMemberStatus(
				CampaignId = campaignId,
				Label = 'Excluded',
				SortOrder = 6
			)
		};
	}

	private static Contact fetchContact() {
		return [SELECT Id FROM Contact LIMIT 1];
	}

	private static Map<String, Campaign> fetchCampaigns() {
		Map<String, Campaign> result = new Map<String, Campaign>();
		for (Campaign c : [
			SELECT Id, Name
			FROM Campaign
			WHERE Name LIKE 'Base%'
		]) {
			result.put(c.Name, c);
		}
		return result;
	}

	private static SourceListService.IdPair buildPair(
		Id src,
		Id dest,
		String sourceListType
	) {
		SourceListService.IdPair pair = new SourceListService.IdPair();
		pair.src = src;
		pair.dest = dest;
		pair.sourceListType = sourceListType;
		return pair;
	}

	@IsTest
	static void testCreatesCampaignMember() {
		// Arrange
		Contact contact = fetchContact();
		Map<String, Campaign> campaigns = fetchCampaigns();

		Campaign source = campaigns.get('Base Source Campaign');
		Campaign destination = campaigns.get('Base Destination Campaign');

		insert new CampaignMember(
			CampaignId = source.Id,
			ContactId = contact.Id,
			Status = 'Sent'
		);

		CampaignMembersCopyBatch batch = new CampaignMembersCopyBatch(
			new List<SourceListService.IdPair>{
				buildPair(source.Id, destination.Id, 'Inclusion')
			}
		);

		// Act
		Test.startTest();
		Database.executeBatch(batch, 50);
		Test.stopTest();

		// Assert
		CampaignMember created = [
			SELECT Status, Source_Lists__c
			FROM CampaignMember
			WHERE CampaignId = :destination.Id
			LIMIT 1
		];

		System.assertEquals('Included', created.Status);
		System.assertEquals(String.valueOf(source.Id), created.get('Source_Lists__c'));
	}

	@IsTest
	static void testUpdatesExistingMember() {
		// Arrange
		Contact contact = fetchContact();
		Map<String, Campaign> campaigns = fetchCampaigns();

		Campaign source = campaigns.get('Base Source Campaign');
		Campaign destination = campaigns.get('Base Destination Campaign');

		insert new List<CampaignMember>{
			new CampaignMember(
				CampaignId = source.Id,
				ContactId = contact.Id,
				Status = 'Sent'
			),
			new CampaignMember(
				CampaignId = destination.Id,
				ContactId = contact.Id,
				Status = 'Sent'
			)
		};

		CampaignMembersCopyBatch batch = new CampaignMembersCopyBatch(
			new List<SourceListService.IdPair>{
				buildPair(source.Id, destination.Id, 'Inclusion')
			}
		);

		// Act
		Test.startTest();
		Database.executeBatch(batch, 50);
		Test.stopTest();

		// Assert
		CampaignMember updated = [
			SELECT Status, Source_Lists__c
			FROM CampaignMember
			WHERE CampaignId = :destination.Id AND ContactId = :contact.Id
			LIMIT 1
		];

		System.assertEquals('Included', updated.Status);
		System.assertEquals(String.valueOf(source.Id), updated.get('Source_Lists__c'));
	}

	@IsTest
	static void testExclusionSetsExcludedStatus() {
		// Arrange
		Contact contact = fetchContact();
		Map<String, Campaign> campaigns = fetchCampaigns();

		Campaign source = campaigns.get('Base Source Campaign');
		Campaign destination = campaigns.get('Base Destination Campaign');

		insert new CampaignMember(
			CampaignId = source.Id,
			ContactId = contact.Id,
			Status = 'Sent'
		);

		CampaignMembersCopyBatch batch = new CampaignMembersCopyBatch(
			new List<SourceListService.IdPair>{
				buildPair(source.Id, destination.Id, 'Exclusion')
			}
		);

		// Act
		Test.startTest();
		Database.executeBatch(batch, 50);
		Test.stopTest();

		// Assert
		CampaignMember result = [
			SELECT Status
			FROM CampaignMember
			WHERE CampaignId = :destination.Id AND ContactId = :contact.Id
			LIMIT 1
		];

		System.assertEquals('Excluded', result.Status);
	}
}
