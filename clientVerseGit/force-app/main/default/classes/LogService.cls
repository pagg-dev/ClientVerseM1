/**
 * @description
 * Centralized logging service for ClientVerse applications.
 * Supports buffered and immediate logging using platform events
 * with a safe System.debug fallback.
 */
public with sharing class LogService {
	private static final String EVENT_TYPE = 'Log';

	/** @description Buffered log entries */
	private List<LogEntry> buffer = new List<LogEntry>();

	/**
	 * @description
	 * Supported log severity levels.
	 */
	public enum Severity {
		DEBUG,
		INFO,
		WARN,
		ERROR,
		FATAL
	}

	/**
	 * @description
	 * Log entry data model.
	 * Uses explicit setters to avoid long parameter lists.
	 */
	public class LogEntry {
		/** @description Name of the process */
		public String process;

		/** @description Severity level */
		public Severity severity;

		/** @description Log message */
		public String message;

		/** @description Optional data payload */
		public Object data;

		/** @description Timestamp of log creation */
		public Datetime timestamp;

		/**
		 * @description
		 * Default constructor.
		 */
		public LogEntry() {
			this.timestamp = System.now();
		}

		/**
		 * @description
		 * Sets the process name.
		 *
		 * @param process
		 * Name of the process.
		 * @return
		 * Current LogEntry instance.
		 */
		public LogEntry setProcess(String process) {
			this.process = process;
			return this;
		}

		/**
		 * @description
		 * Sets severity level.
		 *
		 * @param severity
		 * Severity level.
		 * @return
		 * Current LogEntry instance.
		 */
		public LogEntry setSeverity(Severity severity) {
			this.severity = severity;
			return this;
		}

		/**
		 * @description
		 * Sets log message.
		 *
		 * @param message
		 * Log message.
		 * @return
		 * Current LogEntry instance.
		 */
		public LogEntry setMessage(String message) {
			this.message = message;
			return this;
		}

		/**
		 * @description
		 * Sets optional data payload.
		 *
		 * @param data
		 * Data payload.
		 * @return
		 * Current LogEntry instance.
		 */
		public LogEntry setData(Object data) {
			this.data = data;
			return this;
		}
	}

	/**
	 * @description
	 * Queues a log entry for later publishing.
	 *
	 * @param entry
	 * Log entry to queue.
	 */
	public void queue(LogEntry entry) {
		if (entry == null) {
			return;
		}
		buffer.add(entry);
	}

	/**
	 * @description
	 * Publishes all queued log entries and clears the buffer.
	 */
	public void flush() {
		if (buffer.isEmpty()) {
			return;
		}

		publish(buffer);
		buffer.clear();
	}

	/**
	 * @description
	 * Publishes a single log entry immediately.
	 *
	 * @param entry
	 * Log entry to publish.
	 */
	public static void log(LogEntry entry) {
		if (entry == null) {
			return;
		}

		publish(new List<LogEntry>{ entry });
	}

	/**
	 * @description
	 * Convenience helper for exception logging.
	 *
	 * @param process
	 * Name of the process.
	 * @param ex
	 * Exception instance.
	 * @param data
	 * Optional data payload.
	 */
	public static void logError(String process, Exception ex, Object data) {
		if (ex == null) {
			return;
		}

		LogEntry entry = new LogEntry()
			.setProcess(process)
			.setSeverity(Severity.ERROR)
			.setMessage(ex.getMessage())
			.setData(data);

		log(entry);
	}

	/**
	 * @description
	 * Publishes log entries as platform events.
	 * Falls back to System.debug on failure or during tests.
	 *
	 * @param entries
	 * List of log entries to publish.
	 */
	private static void publish(List<LogEntry> entries) {
		if (entries == null || entries.isEmpty()) {
			return;
		}

		if (Test.isRunningTest()) {
			debugFallback(entries);
			return;
		}

		List<Notification_Event__e> events = new List<Notification_Event__e>();

		for (LogEntry entry : entries) {
			events.add(toPlatformEvent(entry));
		}

		try {
			EventBus.publish(events);
		} catch (Exception ex) {
			// Logging must never break business logic
			debugFallback(entries);
		}
	}

	/**
	 * @description
	 * Converts a LogEntry into a platform event.
	 *
	 * @param entry
	 * Log entry to convert.
	 *
	 * @return
	 * Notification_Event__e platform event.
	 */
	private static Notification_Event__e toPlatformEvent(LogEntry entry) {
		Notification_Event__e evt = new Notification_Event__e();

		evt.Type__c = EVENT_TYPE;
		evt.Process__c = entry.process;
		evt.Severity__c = entry.severity != null ? entry.severity.name() : null;
		evt.Message__c = entry.message;
		evt.Data__c = entry.data != null ? JSON.serialize(entry.data) : null;
		evt.Timestamp__c = entry.timestamp;

		return evt;
	}

	/**
	 * @description
	 * Fallback logger using System.debug.
	 *
	 * @param entries
	 * List of log entries.
	 */
	private static void debugFallback(List<LogEntry> entries) {
		for (LogEntry entry : entries) {
			System.debug(
				'[LOG][' +
					entry.severity +
					'][' +
					entry.process +
					'] ' +
					entry.message +
					' | data=' +
					entry.data
			);
		}
	}
}
