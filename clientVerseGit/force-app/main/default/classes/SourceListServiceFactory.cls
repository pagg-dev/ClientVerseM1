/**
 * @description
 * Factory class responsible for providing instances of
 * ISourceListService with support for test-time mocking.
 */
public with sharing class SourceListServiceFactory {
	/**
	 * @description
	 * Mock service instance injected during test execution.
	 */
	@TestVisible
	private static ISourceListService mockService;

	/**
	 * @description
	 * Returns the active ISourceListService implementation.
	 * Uses a mock service when provided by tests.
	 *
	 * @return
	 * Instance of ISourceListService.
	 */
	public static ISourceListService getService() {
		if (mockService != null) {
			return mockService;
		}

		return new SourceListService();
	}

	/**
	 * @description
	 * Injects a mock implementation of ISourceListService
	 * for use during test execution.
	 *
	 * @param mock
	 * Mock service implementation.
	 */
	public static void setMock(ISourceListService mock) {
		mockService = mock;
	}

	/**
	 * @description
	 * Clears the currently injected mock service.
	 */
	public static void clearMock() {
		mockService = null;
	}
}
