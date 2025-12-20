public with sharing class UserSelector extends fflib_SObjectSelector {
	public UserSelector() {
		super();
	}

	public List<Schema.SObjectField> getSObjectFieldList() {
		return new List<Schema.SObjectField>{ User.Id, User.Name, User.Email };
	}

	public Schema.SObjectType getSObjectType() {
		return User.SObjectType;
	}

	public List<User> selectByIds(Set<Id> ids) {
		return (List<User>) selectSObjectsById(ids);
	}

	public List<User> selectActiveUsersByNameSearch(String name) {
		if (String.isBlank(name)) {
			return new List<User>();
		}
		// Build a safe LIKE pattern with wildcards for partial matches
		String term = '%' + name.trim().replace('%', '\\%').replace('_', '\\_') + '%';

		fflib_QueryFactory qf = newQueryFactory();
		// Only include commonly useful fields (from getSObjectFieldList)
        qf.selectFields(getSObjectFieldList());
		qf.setLimit(25);
		qf.setOrdering(
			new fflib_QueryFactory.Ordering(
				User.Name,
				fflib_QueryFactory.SortOrder.ASCENDING,
				false
			)
		);

		// Search across Name, Username, and Email; prefer Active users
		// Note: escape sequences may vary by DB; using literal escaping in term above
		String condition = 'IsActive = true AND (Name LIKE :term OR Username LIKE :term OR Email LIKE :term)';
		qf.setCondition(condition);

		return (List<User>) Database.query(qf.toSOQL());
	}
}