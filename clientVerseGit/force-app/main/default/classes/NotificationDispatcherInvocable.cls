/**
 * @description
 * Invocable dispatcher responsible for sending notifications
 * based on Notification_Request__c records.
 */
public with sharing class NotificationDispatcherInvocable {
	/**
	 * @description
	 * Input wrapper for Flow invocation.
	 */
	public class RequestInput {
		/**
		 * @description
		 * Id of the Notification_Request__c record.
		 */
		@InvocableVariable(required=true)
		public Id notificationRequestId;
	}

	/**
	 * @description
	 * Result wrapper returned to Flow.
	 */
	public class Result {
		/**
		 * @description
		 * Id of the processed Notification_Request__c record.
		 */
		@InvocableVariable
		public Id notificationRequestId;

		/**
		 * @description
		 * Indicates whether notification was sent successfully.
		 */
		@InvocableVariable
		public Boolean success;

		/**
		 * @description
		 * Error message if processing failed.
		 */
		@InvocableVariable
		public String errorMessage;
	}

	/**
	 * @description
	 * Sends notifications for the provided request records.
	 *
	 * @param inputs
	 * Flow input containing Notification_Request__c Ids.
	 *
	 * @return
	 * Processing results per request.
	 */
	@InvocableMethod(
		label='Send Notification'
		description='Merges template with payload and sends notification'
	)
	public static List<Result> send(List<RequestInput> inputs) {
		List<Result> results = new List<Result>();
		Set<Id> requestIds = collectRequestIds(inputs);

		if (requestIds.isEmpty()) {
			return results;
		}

		Map<Id, Notification_Request__c> requestMap = queryRequests(requestIds);

		Map<String, Notification_Template__c> templateMap = queryTemplates(
			requestMap.values()
		);

		for (Id requestId : requestIds) {
			Result result = new Result();
			result.notificationRequestId = requestId;
			result.success = false;

			try {
				processSingleRequest(requestId, requestMap, templateMap);
				result.success = true;
			} catch (Exception ex) {
				result.errorMessage = ex.getMessage();

				LogService.logError(
					'Notification Dispatch',
					ex,
					new Map<String, Object>{
						'requestId' => requestId,
						'channel' => requestMap.get(requestId).Channel__c,
						'contextRecordId' => requestMap.get(requestId)
							.Context_Record_Id__c,
						'recipientId' => requestMap.get(requestId).Recipient_Id__c
					}
				);
			}

			results.add(result);
		}

		return results;
	}

	private static void processSingleRequest(
		Id requestId,
		Map<Id, Notification_Request__c> requestMap,
		Map<String, Notification_Template__c> templateMap
	) {
		Notification_Request__c request = requestMap.get(requestId);

		if (request == null) {
			throw new NotificationException('Notification request not found.');
		}

		Notification_Template__c template = templateMap.get(request.Template_Key__c);

		if (template == null || !template.Is_Active__c) {
			throw new NotificationException('Template not found or inactive.');
		}

		Map<String, Object> payload = parsePayload(request.Template_Mappings__c);

		dispatchByChannel(request, template, payload);
	}

	private static void dispatchByChannel(
		Notification_Request__c request,
		Notification_Template__c template,
		Map<String, Object> payload
	) {
		if (request.Channel__c == 'Email') {
			sendEmailNotification(request, template, payload);
			return;
		}

		if (request.Channel__c == 'In App') {
			sendInAppNotification(request, template, payload);
			return;
		}

		throw new NotificationException('Unsupported channel: ' + request.Channel__c);
	}

	private static void sendEmailNotification(
		Notification_Request__c request,
		Notification_Template__c template,
		Map<String, Object> payload
	) {
		String subject = mergeTokens(template.Subject__c, payload);
		String body = mergeTokens(template.Body__c, payload);

		Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();

		email.setSaveAsActivity(false);
		email.setSubject(subject);
		email.setHtmlBody(body);

		if (request.Recipient_Type__c == 'Email') {
			if (String.isBlank(request.Email__c)) {
				throw new NotificationException(
					'Email__c is required for Email recipient.'
				);
			}

			email.setToAddresses(new List<String>{ request.Email__c });
		} else if (
			request.Recipient_Type__c == 'User' ||
			request.Recipient_Type__c == 'Contact'
		) {
			if (request.Recipient_Id__c == null) {
				throw new NotificationException('Recipient_Id__c is required.');
			}

			email.setTargetObjectId(request.Recipient_Id__c);
		} else {
			throw new NotificationException(
				'Unsupported Email recipient type: ' + request.Recipient_Type__c
			);
		}

		Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
	}

	private static void sendInAppNotification(
		Notification_Request__c request,
		Notification_Template__c template,
		Map<String, Object> payload
	) {
		if (request.Recipient_Type__c != 'User' || request.Recipient_Id__c == null) {
			throw new NotificationException(
				'In-App notifications require a User recipient.'
			);
		}

		String title = mergeTokens(template.Subject__c, payload);
		String body = mergeTokens(template.Short_Message__c, payload);

		Messaging.CustomNotification notification = new Messaging.CustomNotification();

		notification.setTitle(title);
		notification.setBody(body);
		notification.setNotificationTypeId(getInAppTypeId());
		notification.setTargetId(request.Context_Record_Id__c);

		notification.send(new Set<String>{ request.Recipient_Id__c });
	}

	private static Set<Id> collectRequestIds(List<RequestInput> inputs) {
		Set<Id> ids = new Set<Id>();

		if (inputs == null) {
			return ids;
		}

		for (RequestInput input : inputs) {
			if (input != null && input.notificationRequestId != null) {
				ids.add(input.notificationRequestId);
			}
		}

		return ids;
	}

	private static Map<Id, Notification_Request__c> queryRequests(Set<Id> requestIds) {
		return new Map<Id, Notification_Request__c>(
			[
				SELECT
					Id,
					Template_Key__c,
					Template_Mappings__c,
					Recipient_Id__c,
					Recipient_Type__c,
					Email__c,
					Channel__c,
					Context_Record_Id__c
				FROM Notification_Request__c
				WHERE Id IN :requestIds
				WITH USER_MODE
			]
		);
	}

	private static Map<String, Notification_Template__c> queryTemplates(
		List<Notification_Request__c> requests
	) {
		Set<String> keys = new Set<String>();

		for (Notification_Request__c req : requests) {
			if (req.Template_Key__c != null) {
				keys.add(req.Template_Key__c);
			}
		}

		Map<String, Notification_Template__c> templates = new Map<String, Notification_Template__c>();

		if (keys.isEmpty()) {
			return templates;
		}

		for (Notification_Template__c tpl : [
			SELECT DeveloperName__c, Subject__c, Body__c, Short_Message__c, Is_Active__c
			FROM Notification_Template__c
			WHERE DeveloperName__c IN :keys
			WITH USER_MODE
		]) {
			templates.put(tpl.DeveloperName__c, tpl);
		}

		return templates;
	}

	private static Map<String, Object> parsePayload(String jsonStr) {
		if (String.isBlank(jsonStr)) {
			return new Map<String, Object>();
		}

		Object parsed = JSON.deserializeUntyped(jsonStr);

		if (parsed instanceof Map<String, Object>) {
			return (Map<String, Object>) parsed;
		}

		return new Map<String, Object>();
	}

	private static String mergeTokens(String template, Map<String, Object> payload) {
		if (String.isBlank(template) || payload == null) {
			return template;
		}

		String result = template;

		for (String key : payload.keySet()) {
			String token = '{{' + key + '}}';
			String value = payload.get(key) == null
				? '—'
				: String.valueOf(payload.get(key));

			result = result.replace(token, value);
		}

		return result;
	}

	private static Id getInAppTypeId() {
		return [
			SELECT Id
			FROM CustomNotificationType
			WHERE DeveloperName = 'ClientVerse_Notification'
			WITH USER_MODE
			LIMIT 1
		]
		.Id;
	}

	/* =========================================================
       Custom Exception
       ========================================================= */

	/**
	 * @description
	 * Exception used for notification processing failures.
	 */
	private class NotificationException extends Exception {
	}
}
