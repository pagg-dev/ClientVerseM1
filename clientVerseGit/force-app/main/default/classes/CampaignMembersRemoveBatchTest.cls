@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class CampaignMembersRemoveBatchTest {
	@TestSetup
	static void setupBaseData() {
		insert new Contact(LastName = 'Base Contact');

		Campaign sourceA = new Campaign(Name = 'Base Source A', IsActive = true);
		Campaign sourceB = new Campaign(Name = 'Base Source B', IsActive = true);
		Campaign destination = new Campaign(Name = 'Base Destination', IsActive = true);

		insert new List<Campaign>{ sourceA, sourceB, destination };

		ensureStatuses(sourceA.Id);
		ensureStatuses(sourceB.Id);
		ensureStatuses(destination.Id);
	}

	private static void ensureStatuses(Id campaignId) {
		Map<String, CampaignMemberStatus> existing = new Map<String, CampaignMemberStatus>();
		for (CampaignMemberStatus cms : [
			SELECT Label
			FROM CampaignMemberStatus
			WHERE CampaignId = :campaignId
		]) {
			existing.put(cms.Label, cms);
		}

		List<CampaignMemberStatus> toInsert = new List<CampaignMemberStatus>();

		if (!existing.containsKey('Included')) {
			toInsert.add(
				new CampaignMemberStatus(
					CampaignId = campaignId,
					Label = 'Included',
					SortOrder = 5
				)
			);
		}
		if (!existing.containsKey('Excluded')) {
			toInsert.add(
				new CampaignMemberStatus(
					CampaignId = campaignId,
					Label = 'Excluded',
					SortOrder = 6
				)
			);
		}

		if (!toInsert.isEmpty()) {
			insert toInsert;
		}
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

	private static SourceListService.IdPair buildPair(Id src, Id dest) {
		SourceListService.IdPair pair = new SourceListService.IdPair();
		pair.src = src;
		pair.dest = dest;
		return pair;
	}

	@IsTest
	static void testRemovesSingleSourceFromCsv() {
		// Arrange
		Contact contact = fetchContact();
		Map<String, Campaign> c = fetchCampaigns();

		Campaign sourceA = c.get('Base Source A');
		Campaign sourceB = c.get('Base Source B');
		Campaign destination = c.get('Base Destination');

		insert new List<CampaignMember>{
			new CampaignMember(
				CampaignId = sourceA.Id,
				ContactId = contact.Id,
				Status = 'Included'
			),
			new CampaignMember(
				CampaignId = destination.Id,
				ContactId = contact.Id,
				Status = 'Included',
				Source_Lists__c = sourceA.Id + ',' + sourceB.Id
			)
		};

		CampaignMembersRemoveBatch batch = new CampaignMembersRemoveBatch(
			new List<SourceListService.IdPair>{ buildPair(sourceA.Id, destination.Id) }
		);

		// Act
		Test.startTest();
		Database.executeBatch(batch, 50);
		Test.stopTest();

		// Assert
		CampaignMember updated = [
			SELECT Source_Lists__c
			FROM CampaignMember
			WHERE CampaignId = :destination.Id
			LIMIT 1
		];

		System.assertEquals(
			String.valueOf(sourceB.Id),
			updated.get('Source_Lists__c'),
			'Only the removed source should be dropped from CSV'
		);
	}

	@IsTest
	static void testDeletesMemberWhenCsvIsEmpty() {
		// Arrange
		Contact contact = fetchContact();
		Map<String, Campaign> c = fetchCampaigns();

		Campaign sourceA = c.get('Base Source A');
		Campaign destination = c.get('Base Destination');

		insert new CampaignMember(
			CampaignId = destination.Id,
			ContactId = contact.Id,
			Status = 'Included',
			Source_Lists__c = String.valueOf(sourceA.Id)
		);

		CampaignMembersRemoveBatch batch = new CampaignMembersRemoveBatch(
			new List<SourceListService.IdPair>{ buildPair(sourceA.Id, destination.Id) }
		);

		// Act
		Test.startTest();
		Database.executeBatch(batch, 50);
		Test.stopTest();

		// Assert
		Integer countAfter = [
			SELECT COUNT()
			FROM CampaignMember
			WHERE CampaignId = :destination.Id
		];

		System.assertEquals(0, countAfter, 'CampaignMember should be deleted');
	}

	@IsTest
	static void testDeletesWhenExistsInSourceAndNoCsv() {
		// Arrange
		Contact contact = fetchContact();
		Map<String, Campaign> c = fetchCampaigns();

		Campaign sourceA = c.get('Base Source A');
		Campaign destination = c.get('Base Destination');

		insert new List<CampaignMember>{
			new CampaignMember(
				CampaignId = sourceA.Id,
				ContactId = contact.Id,
				Status = 'Included'
			),
			new CampaignMember(
				CampaignId = destination.Id,
				ContactId = contact.Id,
				Status = 'Included'
			)
		};

		CampaignMembersRemoveBatch batch = new CampaignMembersRemoveBatch(
			new List<SourceListService.IdPair>{ buildPair(sourceA.Id, destination.Id) }
		);

		// Act
		Test.startTest();
		Database.executeBatch(batch, 50);
		Test.stopTest();

		// Assert
		Integer countAfter = [
			SELECT COUNT()
			FROM CampaignMember
			WHERE CampaignId = :destination.Id
		];

		System.assertEquals(0, countAfter, 'Member should be removed from destination');
	}
}
