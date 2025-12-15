public class FuzzyMatcher {

    public static Decimal score(String a, String b) {
        if (String.isBlank(a) || String.isBlank(b)) return 0;

        Integer dist = StringDistance.levenshtein(a.toLowerCase(), b.toLowerCase());
        Integer maxLen = Math.max(a.length(), b.length());

        if (maxLen == 0) return 0;
        return 1 - (Decimal.valueOf(dist) / maxLen);
    }

    public static Decimal combinedScore(String firstName, String lastName, String company, Contact c) {
        Decimal nameScore = score(firstName + ' ' + lastName, c.FirstName + ' ' + c.LastName);
        Decimal companyScore = score(company, c.Account != null ? c.Account.Name : '');

        return (nameScore * 0.6) + (companyScore * 0.4);
    }
}