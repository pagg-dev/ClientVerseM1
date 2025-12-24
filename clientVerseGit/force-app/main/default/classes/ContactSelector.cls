/**
 * @description
 * Selector class for Contact records.
 */
public with sharing class ContactSelector extends fflib_SObjectSelector {
	/**
	 * @description
	 * Default constructor.
	 */
	public ContactSelector() {
		super();
		setDataAccess(DataAccess.USER_MODE);
	}

	/**
	 * @description
	 * Returns the default field set for Contact queries.
	 *
	 * @return
	 * List of Contact fields.
	 */
	public List<Schema.SObjectField> getSObjectFieldList() {
		return new List<Schema.SObjectField>{ Contact.Id, Contact.Name };
	}

	/**
	 * @description
	 * Returns the SObject type handled by this selector.
	 *
	 * @return
	 * Contact SObjectType.
	 */
	public Schema.SObjectType getSObjectType() {
		return Contact.SObjectType;
	}

	/**
	 * @description
	 * Selects Contact records by Id.
	 *
	 * @param ids
	 * Set of Contact record Ids.
	 *
	 * @return
	 * List of matching Contact records.
	 */
	public List<Contact> selectByIds(Set<Id> ids) {
		if (ids == null || ids.isEmpty()) {
			return new List<Contact>();
		}

		return (List<Contact>) selectSObjectsById(ids);
	}

	/**
	 * @description
	 * Selects Contact records by Id.
	 *
	 * @param ids
	 * List of Contact record Ids.
	 *
	 * @return
	 * List of matching Contact records.
	 */
	public List<Contact> selectByIds(List<Id> ids) {
		if (ids == null || ids.isEmpty()) {
			return new List<Contact>();
		}

		return selectByIds(new Set<Id>(ids));
	}
}
