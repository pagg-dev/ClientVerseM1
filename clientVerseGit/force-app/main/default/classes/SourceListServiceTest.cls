@IsTest
private class SourceListServiceTest {

    // Helpers to create minimal records for lists and members
    private static List__c createList(String namePrefix, Integer count) {
        // List__c is assumed to be the "list" SObject referenced by List_Member__c.List__c
        List__c L = new List__c(Name = namePrefix);
        insert L;
        return L;
    }

    private static Contact createContact(String suffix) {
        Contact c = new Contact(FirstName = 'Tst', LastName = 'User' + suffix);
        insert c;
        return c;
    }

    private static List<List_Member__c> createMembers(List__c listRec, Integer howMany) {
        List<List_Member__c> members = new List<List_Member__c>();
        for (Integer i = 0; i < howMany; i++) {
            Contact c = createContact(String.valueOf(Math.abs(Crypto.getRandomInteger())));
            members.add(new List_Member__c(List__c = listRec.Id, Contact__c = c.Id));
        }
        if (!members.isEmpty()) insert members;
        return members;
    }

    @IsTest
    static void testAllowedSimpleInsert() {
        // Basic allowed mapping: source->destination when combined size is small
        Test.startTest();
            List__c a = createList('List-A', 0);
            List__c b = createList('List-B', 0);

            // Create the Source_List__c (junction) record
            Source_List__c rec = new Source_List__c(
                Source_List__c = a.Id,
                Destination_List__c = b.Id
            );

            // Insert should succeed (no validation errors)
            insert rec; // if this throws, the test will fail
        Test.stopTest();

        // Sanity check it exists
        Source_List__c inserted = [SELECT Id, Source_List__c, Destination_List__c FROM Source_List__c WHERE Id = :rec.Id];
        System.assertEquals(a.Id, inserted.Source_List__c);
        System.assertEquals(b.Id, inserted.Destination_List__c);
    }

    @IsTest
    static void testCycleDetectionBlocksInsert() {
        Test.startTest();
            // Build two lists A and B and create A->B first (allowed)
            List__c A = createList('Cycle-A', 0);
            List__c B = createList('Cycle-B', 0);

            Source_List__c aToB = new Source_List__c(
                Source_List__c = A.Id,
                Destination_List__c = B.Id
            );
            insert aToB;

            // Now attempt to insert B -> A which should be blocked by cycle detection
            Source_List__c bToA = new Source_List__c(
                Source_List__c = B.Id,
                Destination_List__c = A.Id
            );

            // Use partial DML to capture SaveResult rather than throwing
            Database.SaveResult sr = Database.insert(bToA, false);

            System.assertEquals(false, sr.isSuccess(), 'Insert should fail due to cycle');
            String err = sr.getErrors()[0].getMessage();
            System.assert(err.contains('cycle') || err.contains('cycle') || err.toLowerCase().contains('cycle') 
                          || err.toLowerCase().contains('mapping would create'), 'Expected cycle-related error, got: ' + err);
        Test.stopTest();
    }

    @IsTest
    static void testDepthExceededBlocksInsert() {
        Test.startTest();
            // Create chain L1->L2, L2->L3, L3->L4 (this is depth 3 from L1 to L4)
            List__c L1 = createList('D-L1', 0);
            List__c L2 = createList('D-L2', 0);
            List__c L3 = createList('D-L3', 0);
            List__c L4 = createList('D-L4', 0);
            List__c L5 = createList('D-L5', 0);

            insert new Source_List__c[] {
                new Source_List__c(Source_List__c = L1.Id, Destination_List__c = L2.Id),
                new Source_List__c(Source_List__c = L2.Id, Destination_List__c = L3.Id),
                new Source_List__c(Source_List__c = L3.Id, Destination_List__c = L4.Id)
            };

            // Now inserting L4 -> L5 would make a path L1->...->L5 of length 4 (exceeds MAX_DEPTH = 3)
            Source_List__c l4ToL5 = new Source_List__c(Source_List__c = L4.Id, Destination_List__c = L5.Id);

            Database.SaveResult sr = Database.insert(l4ToL5, false);
            System.assertEquals(false, sr.isSuccess(), 'Insert should be blocked due to depth > MAX_DEPTH');
            String err = sr.getErrors()[0].getMessage();
            System.assert(err.contains('depth') || err.toLowerCase().contains('depth') || err.toLowerCase().contains('exceed'),
                          'Expected depth-related error, got: ' + err);
        Test.stopTest();
    }

    /* ----------------------------------------------------------------
     * NOTE: Member-limit testing (Rule 3)
     *
     * The live MEMBER_LIMIT in production code is 50,000; inserting that many
     * List_Member__c rows inside a unit test is not practical.
     *
     * Two recommended ways to add a unit test for Rule 3:
     *
     * 1) Temporary test switch (quick & dirty):
     *    - Add code in SourceListService like:
     *      private static Integer getMemberLimit() { return Test.isRunningTest() ? 100 : MEMBER_LIMIT; }
     *    - Then write a test that creates >100 members across two lists and asserts the insert is blocked.
     *
     * 2) Dependency-injection (clean & recommended):
     *    - Refactor SourceListService to accept a selector interface (e.g. IListMemberSelector)
     *      and use that selector to get counts.
     *    - In tests, inject a fake selector that returns large counts (like 30k + 25k).
     *    - Then assert the insert is blocked without creating large numbers of member rows.
     *
     * I didn't change production code in this test file. If you want, I can:
     *  - provide a quick patch to SourceListService to support Test.isRunningTest() for member-limit,
     *  - or refactor for DI and provide tests using a mock selector.
     * ----------------------------------------------------------------
     */
}