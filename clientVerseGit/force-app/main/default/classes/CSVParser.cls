public class CSVParser {

    public class Row {
        public String firstName, lastName, title, company, email;
    }

    public static List<Row> parse(String csv) {
        List<Row> results = new List<Row>();
        List<String> lines = csv.split('\n');

        for (Integer i = 1; i < lines.size(); i++) {
            List<String> cols = lines[i].split(',');

            if (cols.size() < 5) continue;

            Row r = new Row();
            r.firstName = cols[0].trim();
            r.lastName  = cols[1].trim();
            r.title     = cols[2].trim();
            r.company   = cols[3].trim();
            r.email     = cols[4].trim();

            results.add(r);
        }
        return results;
    }
}