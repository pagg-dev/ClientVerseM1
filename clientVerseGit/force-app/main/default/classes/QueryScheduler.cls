public class QueryScheduler implements Schedulable {

    private Id recordId;
    private String soql;

    public QueryScheduler(Id recordId, String soql) {
        this.recordId = recordId;
        this.soql = soql;
    }

   public void execute(SchedulableContext sc) {

        List<SObject> results = Database.query(soql);

        List<Id> contactIds = new List<Id>();
        for (SObject sob : results) {
            if (sob.get('Id') != null) {
                contactIds.add((Id)sob.get('Id'));
            }
        }

        FieldPickerController.createListMembers(recordId, contactIds);
    }
}