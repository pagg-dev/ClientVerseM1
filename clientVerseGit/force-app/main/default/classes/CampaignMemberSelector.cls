public with sharing class CampaignMemberSelector extends fflib_SObjectSelector {
	public CampaignMemberSelector() {
		super();
	}

	// Required fields the selector returns
	public List<Schema.SObjectField> getSObjectFieldList() {
		return new List<Schema.SObjectField>{
			CampaignMember.Id,
			CampaignMember.CampaignId,
			CampaignMember.ContactId,
			CampaignMember.Source_Lists__c,
			CampaignMember.Status
		};
	}

	public Schema.SObjectType getSObjectType() {
		return CampaignMember.SObjectType;
	}

	public List<CampaignMember> selectByCampaignIds(Set<Id> campaignIds) {
		if (campaignIds == null || campaignIds.isEmpty())
			return new List<CampaignMember>();

		fflib_QueryFactory qf = newQueryFactory();
		qf.setCondition('CampaignId IN :campaignIds AND ContactId != null');

		return (List<CampaignMember>) Database.query(qf.toSOQL());
	}

	public Database.QueryLocator queryLocatorByCampaignIds(Set<Id> campaignIds) {
		if (campaignIds == null || campaignIds.isEmpty())
			return null;

		fflib_QueryFactory qf = newQueryFactory();
		qf.setCondition('CampaignId IN :campaignIds AND ContactId != null');
		qf.setOrdering(
			new fflib_QueryFactory.Ordering(
				CampaignMember.Id,
				fflib_QueryFactory.SortOrder.ASCENDING,
				false
			)
		);

		return Database.getQueryLocator(qf.toSOQL());
	}

	public List<CampaignMember> selectPage(
		Id campId,
		Id lastSeenId,
		Integer size,
		Boolean contactsOnly
	) {
		if (campId == null)
			return new List<CampaignMember>();
		Integer limitSize = (size == null) ? 2000 : size;

		fflib_QueryFactory qf = new fflib_QueryFactory(CampaignMember.SObjectType);
		qf.selectFields(getSObjectFieldList());

		String cond = 'CampaignId = :campId';
		if (lastSeenId != null)
			cond += ' AND Id > :lastSeenId';
		if (contactsOnly != null && contactsOnly)
			cond += ' AND ContactId != null';
		qf.setCondition(cond);

		qf.setOrdering(
			new fflib_QueryFactory.Ordering(
				CampaignMember.Id,
				fflib_QueryFactory.SortOrder.ASCENDING,
				false
			)
		);
		qf.setLimit(limitSize);

		return (List<CampaignMember>) Database.query(qf.toSOQL());
	}

	public List<CampaignMember> selectByCampaignAndContacts(
		Id campId,
		Set<Id> contactIds
	) {
		if (campId == null || contactIds == null || contactIds.isEmpty())
			return new List<CampaignMember>();

		fflib_QueryFactory qf = new fflib_QueryFactory(CampaignMember.SObjectType);
		qf.selectFields(getSObjectFieldList());
		qf.setCondition('CampaignId = :campId AND ContactId IN :contactIds');

		return (List<CampaignMember>) Database.query(qf.toSOQL());
	}

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
		)
			return result;

		fflib_QueryFactory qf = new fflib_QueryFactory(CampaignMember.SObjectType);
		qf.selectFields(getSObjectFieldList());
		qf.setCondition('CampaignId IN :campaignIds AND ContactId IN :contactIds');

		List<CampaignMember> cms = Database.query(qf.toSOQL());

		for (CampaignMember cm : cms) {
			if (cm.CampaignId == null || cm.ContactId == null)
				continue;
			if (!result.containsKey(cm.CampaignId))
				result.put(cm.CampaignId, new Map<Id, CampaignMember>());
			result.get(cm.CampaignId).put(cm.ContactId, cm);
		}
		return result;
	}
}