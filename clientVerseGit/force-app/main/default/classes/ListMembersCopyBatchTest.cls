@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class ListMembersCopyBatchTest {
	@TestSetup
	static void setupBaseData() {
		// Contact
		insert new Contact(LastName = 'Base Contact');

		// Source & Destination Lists
		List__c sourceList = new List__c(Name = 'Base Source List');
		List__c destinationList = new List__c(Name = 'Base Destination List');

		insert new List<List__c>{ sourceList, destinationList };
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
	static void testCreatesNewListMember() {
		// Arrange
		Contact contact = fetchContact();
		Map<String, List__c> lists = fetchLists();

		List__c source = lists.get('Base Source List');
		List__c destination = lists.get('Base Destination List');

		insert new List_Member__c(
			List__c = source.Id,
			Contact__c = contact.Id,
			Status__c = 'Included'
		);

		ListMembersCopyBatch batch = new ListMembersCopyBatch(
			new List<SourceListService.IdPair>{
				buildPair(source.Id, destination.Id, 'Inclusion')
			}
		);

		// Act
		Test.startTest();
		Database.executeBatch(batch, 50);
		Test.stopTest();

		// Assert
		List_Member__c created = [
			SELECT Status__c, Source_Lists__c
			FROM List_Member__c
			WHERE List__c = :destination.Id
			LIMIT 1
		];

		System.assertEquals('Included', created.Status__c);
		System.assertEquals(String.valueOf(source.Id), created.Source_Lists__c);
	}

	@IsTest
	static void testUpdatesExistingListMember() {
		// Arrange
		Contact contact = fetchContact();
		Map<String, List__c> lists = fetchLists();

		List__c source = lists.get('Base Source List');
		List__c destination = lists.get('Base Destination List');

		insert new List<List_Member__c>{
			new List_Member__c(
				List__c = source.Id,
				Contact__c = contact.Id,
				Status__c = 'Included'
			),
			new List_Member__c(
				List__c = destination.Id,
				Contact__c = contact.Id,
				Status__c = 'Excluded'
			)
		};

		ListMembersCopyBatch batch = new ListMembersCopyBatch(
			new List<SourceListService.IdPair>{
				buildPair(source.Id, destination.Id, 'Inclusion')
			}
		);

		// Act
		Test.startTest();
		Database.executeBatch(batch, 50);
		Test.stopTest();

		// Assert
		List_Member__c updated = [
			SELECT Status__c, Source_Lists__c
			FROM List_Member__c
			WHERE List__c = :destination.Id AND Contact__c = :contact.Id
			LIMIT 1
		];

		System.assertEquals('Included', updated.Status__c);
		System.assertEquals(String.valueOf(source.Id), updated.Source_Lists__c);
	}

	@IsTest
	static void testDoesNotDuplicateExistingMember() {
		// Arrange
		Contact contact = fetchContact();
		Map<String, List__c> lists = fetchLists();

		List__c source = lists.get('Base Source List');
		List__c destination = lists.get('Base Destination List');

		insert new List<List_Member__c>{
			new List_Member__c(
				List__c = source.Id,
				Contact__c = contact.Id,
				Status__c = 'Included'
			),
			new List_Member__c(
				List__c = destination.Id,
				Contact__c = contact.Id,
				Status__c = 'Included',
				Source_Lists__c = String.valueOf(source.Id)
			)
		};

		ListMembersCopyBatch batch = new ListMembersCopyBatch(
			new List<SourceListService.IdPair>{
				buildPair(source.Id, destination.Id, 'Inclusion')
			}
		);

		// Act
		Test.startTest();
		Database.executeBatch(batch, 50);
		Test.stopTest();

		// Assert
		Integer countAfter = [
			SELECT COUNT()
			FROM List_Member__c
			WHERE List__c = :destination.Id AND Contact__c = :contact.Id
		];

		System.assertEquals(
			1,
			countAfter,
			'No duplicate List_Member__c should be created'
		);
	}
}
