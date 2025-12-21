/**
 * @description
 * Selector class for CampaignMember records.
 * Encapsulates query logic using native fflib USER_MODE
 * enforcement for CRUD and FLS.
 */
public with sharing class CampaignMemberSelector extends fflib_SObjectSelector {
	/**
	 * @description
	 * Default constructor.
	 * Enforces native USER_MODE data access.
	 */
	public CampaignMemberSelector() {
		super();
		setDataAccess(DataAccess.USER_MODE);
	}

	/**
	 * @description
	 * Returns the SObject type handled by this selector.
	 *
	 * @return
	 * CampaignMember SObjectType.
	 */
	public Schema.SObjectType getSObjectType() {
		return CampaignMember.SObjectType;
	}

	/**
	 * @description
	 * Returns the default field set for CampaignMember queries.
	 *
	 * @return
	 * List of CampaignMember fields.
	 */
	public List<Schema.SObjectField> getSObjectFieldList() {
		return new List<Schema.SObjectField>{
			CampaignMember.Id,
			CampaignMember.CampaignId,
			CampaignMember.ContactId,
			CampaignMember.Source_Lists__c,
			CampaignMember.Status
		};
	}

	/**
	 * @description
	 * Selects campaign members by Campaign Ids.
	 *
	 * @param campaignIds
	 * Campaign Ids.
	 *
	 * @return
	 * List of CampaignMember records.
	 */
	public List<CampaignMember> selectByCampaignIds(Set<Id> campaignIds) {
		if (campaignIds == null || campaignIds.isEmpty()) {
			return new List<CampaignMember>();
		}

		fflib_QueryFactory queryFactory = newQueryFactory();
		queryFactory.setCondition('CampaignId IN :campaignIds AND ContactId != null');

		return (List<CampaignMember>) Database.query(queryFactory.toSOQL());
	}

	/**
	 * @description
	 * Returns a QueryLocator for campaign members by Campaign Ids.
	 *
	 * @param campaignIds
	 * Campaign Ids.
	 *
	 * @return
	 * QueryLocator for batch processing.
	 */
	public Database.QueryLocator queryLocatorByCampaignIds(Set<Id> campaignIds) {
		if (campaignIds == null || campaignIds.isEmpty()) {
			return null;
		}

		fflib_QueryFactory queryFactory = newQueryFactory();
		queryFactory.setCondition('CampaignId IN :campaignIds AND ContactId != null');
		queryFactory.addOrdering(
			CampaignMember.Id,
			fflib_QueryFactory.SortOrder.ASCENDING,
			false
		);

		return Database.getQueryLocator(queryFactory.toSOQL());
	}

	/**
	 * @description
	 * Selects a deterministic page of campaign members.
	 *
	 * @param campaignId
	 * Campaign Id.
	 *
	 * @param lastSeenId
	 * Last processed CampaignMember Id.
	 *
	 * @param size
	 * Page size.
	 *
	 * @param contactsOnly
	 * Whether to include only members with ContactId.
	 *
	 * @return
	 * Page of CampaignMember records.
	 */
	public List<CampaignMember> selectPage(
		Id campaignId,
		Id lastSeenId,
		Integer size,
		Boolean contactsOnly
	) {
		if (campaignId == null) {
			return new List<CampaignMember>();
		}

		Integer limitSize = size == null ? 2000 : size;

		fflib_QueryFactory queryFactory = newQueryFactory(false);

		queryFactory.selectFields(getSObjectFieldList());

		queryFactory.setCondition(
			buildPagingCondition(campaignId, lastSeenId, contactsOnly)
		);

		queryFactory.addOrdering(
			CampaignMember.Id,
			fflib_QueryFactory.SortOrder.ASCENDING,
			false
		);

		queryFactory.setLimit(limitSize);

		return (List<CampaignMember>) Database.query(queryFactory.toSOQL());
	}

	/**
	 * @description
	 * Selects campaign members by campaign and contact Ids.
	 *
	 * @param campaignId
	 * Campaign Id.
	 *
	 * @param contactIds
	 * Contact Ids.
	 *
	 * @return
	 * List of CampaignMember records.
	 */
	public List<CampaignMember> selectByCampaignAndContacts(
		Id campaignId,
		Set<Id> contactIds
	) {
		if (campaignId == null || contactIds == null || contactIds.isEmpty()) {
			return new List<CampaignMember>();
		}

		fflib_QueryFactory queryFactory = newQueryFactory();

		queryFactory.setCondition(
			'CampaignId = :campaignId AND ContactId IN :contactIds'
		);

		return (List<CampaignMember>) Database.query(queryFactory.toSOQL());
	}

	/**
	 * @description
	 * Selects campaign members by multiple campaigns and contacts.
	 *
	 * @param campaignIds
	 * Campaign Ids.
	 *
	 * @param contactIds
	 * Contact Ids.
	 *
	 * @return
	 * List of CampaignMember records.
	 */
	public List<CampaignMember> selectByCampaignsAndContacts(
		Set<Id> campaignIds,
		List<Id> contactIds
	) {
		if (
			campaignIds == null ||
			campaignIds.isEmpty() ||
			contactIds == null ||
			contactIds.isEmpty()
		) {
			return new List<CampaignMember>();
		}

		fflib_QueryFactory queryFactory = newQueryFactory();

		queryFactory.setCondition(
			'CampaignId IN :campaignIds AND ContactId IN :contactIds'
		);

		return (List<CampaignMember>) Database.query(queryFactory.toSOQL());
	}

	/**
	 * @description
	 * Selects existing campaign members grouped by campaign and contact.
	 *
	 * @param campaignIds
	 * Campaign Ids.
	 *
	 * @param contactIds
	 * Contact Ids.
	 *
	 * @return
	 * Map of CampaignId → ContactId → CampaignMember.
	 */
	public Map<Id, Map<Id, CampaignMember>> selectExistingByCampaignsAndContacts(
		Set<Id> campaignIds,
		Set<Id> contactIds
	) {
		Map<Id, Map<Id, CampaignMember>> result = new Map<Id, Map<Id, CampaignMember>>();

		if (
			campaignIds == null ||
			campaignIds.isEmpty() ||
			contactIds == null ||
			contactIds.isEmpty()
		) {
			return result;
		}

		fflib_QueryFactory queryFactory = newQueryFactory();

		queryFactory.setCondition(
			'CampaignId IN :campaignIds AND ContactId IN :contactIds'
		);

		List<CampaignMember> members = Database.query(queryFactory.toSOQL());

		for (CampaignMember member : members) {
			if (member.CampaignId == null || member.ContactId == null) {
				continue;
			}

			if (!result.containsKey(member.CampaignId)) {
				result.put(member.CampaignId, new Map<Id, CampaignMember>());
			}

			result.get(member.CampaignId).put(member.ContactId, member);
		}

		return result;
	}

	private static String buildPagingCondition(
		Id campaignId,
		Id lastSeenId,
		Boolean contactsOnly
	) {
		String condition = 'CampaignId = :campaignId';

		if (lastSeenId != null) {
			condition += ' AND Id > :lastSeenId';
		}

		if (contactsOnly == true) {
			condition += ' AND ContactId != null';
		}

		return condition;
	}
}
