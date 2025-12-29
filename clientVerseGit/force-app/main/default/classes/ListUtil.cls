/**
 * @description
 * Utility class providing list slicing helpers and
 * CSV-based Id manipulation helpers.
 */
public class ListUtil {
	/**
	 * @description
	 * Returns a sublist of Ids from the source list using
	 * start (inclusive) and end (exclusive) indexes.
	 *
	 * @param source Source list of Ids.
	 * @param start Zero-based start index (inclusive).
	 * @param endIdx Zero-based end index (exclusive).
	 * @return Sliced list of Ids.
	 */
	public static List<Id> sliceIds(List<Id> source, Integer start, Integer endIdx) {
		List<Id> result = new List<Id>();

		if (source == null || source.isEmpty()) {
			return result;
		}
		if (start == null || endIdx == null) {
			return result;
		}

		Integer safeStart = Math.max(0, start);
		Integer safeEnd = Math.min(endIdx, source.size());

		if (safeStart >= safeEnd) {
			return result;
		}

		for (Integer i = safeStart; i < safeEnd; i++) {
			result.add(source[i]);
		}

		return result;
	}

	/**
	 * @description
	 * Returns a sublist of SObjects from the source list using
	 * start (inclusive) and end (exclusive) indexes.
	 *
	 * @param sourceObjs Source list of SObjects.
	 * @param start Zero-based start index (inclusive).
	 * @param endIdx Zero-based end index (exclusive).
	 * @return Sliced list of SObjects.
	 */
	public static List<SObject> sliceSObjects(
		List<SObject> sourceObjs,
		Integer start,
		Integer endIdx
	) {
		List<SObject> result = new List<SObject>();

		if (sourceObjs == null || sourceObjs.isEmpty()) {
			return result;
		}
		if (start == null || endIdx == null) {
			return result;
		}

		Integer safeStart = Math.max(0, start);
		Integer safeEnd = Math.min(endIdx, sourceObjs.size());

		if (safeStart >= safeEnd) {
			return result;
		}

		for (Integer i = safeStart; i < safeEnd; i++) {
			result.add(sourceObjs[i]);
		}

		return result;
	}

	/**
	 * @description
	 * Checks whether the given Id exists in a CSV string.
	 *
	 * @param csv Comma-separated string.
	 * @param id Id to check.
	 * @return TRUE if Id exists in CSV.
	 */
	public static Boolean csvContains(String csv, Id id) {
		if (id == null) {
			return false;
		}

		return csvToSet(csv).contains(String.valueOf(id));
	}

	/**
	 * @description
	 * Adds an Id to a CSV string if not already present.
	 *
	 * @param csv Existing CSV string.
	 * @param id Id to add.
	 * @return Updated CSV string.
	 */
	public static String csvAdd(String csv, Id id) {
		if (id == null) {
			return csv;
		}

		Set<String> values = csvToSet(csv);
		values.add(String.valueOf(id));
		return setToCsv(values);
	}

	/**
	 * @description
	 * Removes an Id from a CSV string if present.
	 *
	 * @param csv Existing CSV string.
	 * @param id Id to remove.
	 * @return Updated CSV string.
	 */
	public static String csvRemove(String csv, Id id) {
		if (id == null) {
			return csv;
		}

		Set<String> values = csvToSet(csv);
		values.remove(String.valueOf(id));
		return setToCsv(values);
	}

	private static Set<String> csvToSet(String csv) {
		Set<String> result = new Set<String>();

		if (String.isBlank(csv)) {
			return result;
		}

		for (String token : csv.split(',')) {
			if (String.isNotBlank(token)) {
				result.add(token.trim());
			}
		}

		return result;
	}

	private static String setToCsv(Set<String> values) {
		if (values == null || values.isEmpty()) {
			return null;
		}

		return String.join(new List<String>(values), ',');
	}
}
