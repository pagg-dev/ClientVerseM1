public class StringDistance {

    public static Integer levenshtein(String s, String t) {
        if (s == null) s = '';
        if (t == null) t = '';

        Integer n = s.length();
        Integer m = t.length();

        if (n == 0) return m;
        if (m == 0) return n;

        List<List<Integer>> dp = new List<List<Integer>>();

        for (Integer i = 0; i <= n; i++) {
            List<Integer> row = new List<Integer>();
            for (Integer j = 0; j <= m; j++) {
                row.add(0);
            }
            dp.add(row);
        }

        for (Integer i = 0; i <= n; i++) dp[i][0] = i;
        for (Integer j = 0; j <= m; j++) dp[0][j] = j;

        for (Integer i = 1; i <= n; i++) {
            for (Integer j = 1; j <= m; j++) {
                Integer cost = (s.substring(i - 1, i) == t.substring(j - 1, j)) ? 0 : 1;

                dp[i][j] = Math.min(
                    Math.min(
                        dp[i - 1][j] + 1,     
                        dp[i][j - 1] + 1
                    ),
                    dp[i - 1][j - 1] + cost
                );
            }
        }

        return dp[n][m];
    }
}