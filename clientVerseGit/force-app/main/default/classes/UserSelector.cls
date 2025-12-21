/**
 * @description
 * Selector class for User records.
 * Provides reusable query methods for common User lookups.
 */
public with sharing class UserSelector extends fflib_SObjectSelector {
	/**
	 * @description
	 * Default constructor.
	 */
	public UserSelector() {
		super();
		setDataAccess(DataAccess.USER_MODE);
	}

	/**
	 * @description
	 * Returns the fields selected by default for User queries.
	 *
	 * @return
	 * List of User fields.
	 */
	public List<Schema.SObjectField> getSObjectFieldList() {
		return new List<Schema.SObjectField>{ User.Id, User.Name, User.Email };
	}

	/**
	 * @description
	 * Returns the SObject type for this selector.
	 *
	 * @return
	 * User SObjectType.
	 */
	public Schema.SObjectType getSObjectType() {
		return User.SObjectType;
	}

	/**
	 * @description
	 * Selects Users by their Ids.
	 *
	 * @param ids
	 * Set of User record Ids.
	 *
	 * @return
	 * List of matching User records.
	 */
	public List<User> selectByIds(Set<Id> ids) {
		if (ids == null || ids.isEmpty()) {
			return new List<User>();
		}

		return (List<User>) selectSObjectsById(ids);
	}

	/**
	 * @description
	 * Searches active Users by partial name, username, or email match.
	 *
	 * @param name
	 * Search term provided by the caller.
	 *
	 * @return
	 * List of active Users matching the search term.
	 */
	public List<User> selectActiveUsersByNameSearch(String name) {
		if (String.isBlank(name)) {
			return new List<User>();
		}

		String likeTerm = buildLikeTerm(name);

		fflib_QueryFactory queryFactory = newQueryFactory();
		configureBaseQuery(queryFactory);
		applySearchCondition(queryFactory, likeTerm);

		return (List<User>) Database.query(queryFactory.toSOQL());
	}

	/* =========================
       Helper Methods
       ========================= */

	/**
	 * @description
	 * Builds a safe SOQL LIKE pattern for partial matching.
	 *
	 * @param input
	 * Raw search input.
	 *
	 * @return
	 * Escaped LIKE pattern.
	 */
	private static String buildLikeTerm(String input) {
		String trimmed = input.trim();

		trimmed = trimmed.replace('%', '\\%');
		trimmed = trimmed.replace('_', '\\_');

		return '%' + trimmed + '%';
	}

	/**
	 * @description
	 * Configures common query options such as fields,
	 * ordering, and limits.
	 *
	 * @param queryFactory
	 * QueryFactory instance to configure.
	 */
	private void configureBaseQuery(fflib_QueryFactory queryFactory) {
		queryFactory.selectFields(getSObjectFieldList());
		queryFactory.setLimit(25);
		queryFactory.setOrdering(
			new fflib_QueryFactory.Ordering(
				User.Name,
				fflib_QueryFactory.SortOrder.ASCENDING,
				false
			)
		);
	}

	/**
	 * @description
	 * Applies the active-user search condition to the query.
	 *
	 * @param queryFactory
	 * QueryFactory instance to update.
	 *
	 * @param likeTerm
	 * Escaped LIKE search term.
	 */
	private static void applySearchCondition(
		fflib_QueryFactory queryFactory,
		String likeTerm
	) {
		String condition =
			'IsActive = true AND ' +
			'(Name LIKE :likeTerm ' +
			'OR Username LIKE :likeTerm ' +
			'OR Email LIKE :likeTerm)';

		queryFactory.setCondition(condition);
	}
}
