/**
 * @description
 * Batch job responsible for cleaning up Clientverse_Log__c records
 * based on severity-specific retention policies.
 *
 * DEBUG logs are retained for a shorter period,
 * all other logs use the default retention window.
 *
 */
global with sharing class ClientverseLogCleanupBatch implements Database.Batchable<SObject>, Schedulable {
	/** @description Retention period for DEBUG logs (days). */
	private static final Integer DEBUG_RETENTION_DAYS = 30;

	/** @description Retention period for non-DEBUG logs (days). */
	private static final Integer DEFAULT_RETENTION_DAYS = 90;

	/**
	 * @description
	 * Builds the query locator for expired log records.
	 *
	 * @param bc
	 * Batch context.
	 * @return
	 * QueryLocator for expired Clientverse_Log__c records.
	 */
	global Database.QueryLocator start(Database.BatchableContext bc) {
		Datetime debugCutoff = System.now().addDays(-DEBUG_RETENTION_DAYS);

		Datetime defaultCutoff = System.now().addDays(-DEFAULT_RETENTION_DAYS);

		return Database.getQueryLocator(
			[
				SELECT Id
				FROM Clientverse_Log__c
				WHERE
					(Severity__c = 'DEBUG'
					AND CreatedDate < :debugCutoff)
					OR (Severity__c != 'DEBUG'
					AND CreatedDate < :defaultCutoff)
				WITH SYSTEM_MODE
			]
		);
	}

	/**
	 * @description
	 * Deletes expired log records in the current batch scope.
	 *
	 * @param bc
	 * Batch context.
	 * @param scope
	 * List of Clientverse_Log__c records to delete.
	 */
	global void execute(Database.BatchableContext bc, List<Clientverse_Log__c> scope) {
		if (scope == null || scope.isEmpty()) {
			return;
		}

		// Defensive CRUD check (PMD compliant)
		if (!Schema.sObjectType.Clientverse_Log__c.isDeletable()) {
			return;
		}

		delete scope;
	}

	/**
	 * @description
	 * No post-processing required after batch completion.
	 *
	 * @param bc
	 * Batch context.
	 */
	global void finish(Database.BatchableContext bc) {
		// Intentionally left blank
	}

	/**
	 * @description
	 * Schedulable entry point.
	 * Executes the cleanup batch with a safe batch size.
	 *
	 * @param sc
	 * Schedulable context.
	 */
	global void execute(SchedulableContext sc) {
		Database.executeBatch(new ClientverseLogCleanupBatch(), 2000);
	}
}
