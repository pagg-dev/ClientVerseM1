@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class ListMembersRemoveBatchTest {
	@TestSetup
	static void setupBaseData() {
		insert new Contact(LastName = 'Base Contact');

		List__c sourceA = new List__c(Name = 'Base Source A');
		List__c sourceB = new List__c(Name = 'Base Source B');
		List__c destination = new List__c(Name = 'Base Destination');

		insert new List<List__c>{ sourceA, sourceB, destination };
	}

	private static Contact fetchContact() {
		return [SELECT Id FROM Contact LIMIT 1];
	}

	private static Map<String, List__c> fetchLists() {
		Map<String, List__c> result = new Map<String, List__c>();
		for (List__c lst : [
			SELECT Id, Name
			FROM List__c
			WHERE Name LIKE 'Base%'
		]) {
			result.put(lst.Name, lst);
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
		Map<String, List__c> lists = fetchLists();

		List__c sourceA = lists.get('Base Source A');
		List__c sourceB = lists.get('Base Source B');
		List__c destination = lists.get('Base Destination');

		insert new List<List_Member__c>{
			new List_Member__c(
				List__c = sourceA.Id,
				Contact__c = contact.Id,
				Status__c = 'Included'
			),
			new List_Member__c(
				List__c = destination.Id,
				Contact__c = contact.Id,
				Status__c = 'Included',
				Source_Lists__c = sourceA.Id + ',' + sourceB.Id
			)
		};

		ListMembersRemoveBatch batch = new ListMembersRemoveBatch(
			new List<SourceListService.IdPair>{ buildPair(sourceA.Id, destination.Id) }
		);

		// Act
		Test.startTest();
		Database.executeBatch(batch, 50);
		Test.stopTest();

		// Assert
		List_Member__c updated = [
			SELECT Source_Lists__c
			FROM List_Member__c
			WHERE List__c = :destination.Id
			LIMIT 1
		];

		System.assertEquals(
			String.valueOf(sourceB.Id),
			updated.Source_Lists__c,
			'Only removed source should be dropped from CSV'
		);
	}

	@IsTest
	static void testDeletesWhenCsvBecomesEmpty() {
		// Arrange
		Contact contact = fetchContact();
		Map<String, List__c> lists = fetchLists();

		List__c sourceA = lists.get('Base Source A');
		List__c destination = lists.get('Base Destination');

		insert new List_Member__c(
			List__c = destination.Id,
			Contact__c = contact.Id,
			Status__c = 'Included',
			Source_Lists__c = String.valueOf(sourceA.Id)
		);

		ListMembersRemoveBatch batch = new ListMembersRemoveBatch(
			new List<SourceListService.IdPair>{ buildPair(sourceA.Id, destination.Id) }
		);

		// Act
		Test.startTest();
		Database.executeBatch(batch, 50);
		Test.stopTest();

		// Assert
		Integer remaining = [
			SELECT COUNT()
			FROM List_Member__c
			WHERE List__c = :destination.Id
		];

		System.assertEquals(0, remaining, 'List member should be deleted');
	}

	@IsTest
	static void testDeletesWhenExistsInSourceAndNoCsv() {
		// Arrange
		Contact contact = fetchContact();
		Map<String, List__c> lists = fetchLists();

		List__c sourceA = lists.get('Base Source A');
		List__c destination = lists.get('Base Destination');

		insert new List<List_Member__c>{
			new List_Member__c(
				List__c = sourceA.Id,
				Contact__c = contact.Id,
				Status__c = 'Included'
			),
			new List_Member__c(
				List__c = destination.Id,
				Contact__c = contact.Id,
				Status__c = 'Included'
			)
		};

		ListMembersRemoveBatch batch = new ListMembersRemoveBatch(
			new List<SourceListService.IdPair>{ buildPair(sourceA.Id, destination.Id) }
		);

		// Act
		Test.startTest();
		Database.executeBatch(batch, 50);
		Test.stopTest();

		// Assert
		Integer remaining = [
			SELECT COUNT()
			FROM List_Member__c
			WHERE List__c = :destination.Id
		];

		System.assertEquals(
			0,
			remaining,
			'Member should be removed when still exists in source and no CSV'
		);
	}
}
