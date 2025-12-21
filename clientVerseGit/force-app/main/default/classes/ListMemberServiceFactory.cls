/**
 * @description
 * Factory class responsible for providing instances of
 * IListMemberService with support for test-time mocking.
 */
public with sharing class ListMemberServiceFactory {
	/**
	 * @description
	 * Mock service instance injected during test execution.
	 */
	@TestVisible
	private static IListMemberService mockService;

	/**
	 * @description
	 * Returns the active IListMemberService implementation.
	 * Uses a mock service when provided by tests.
	 *
	 * @return
	 * Instance of IListMemberService.
	 */
	public static IListMemberService getService() {
		if (mockService != null) {
			return mockService;
		}

		return new ListMemberService();
	}

	/**
	 * @description
	 * Injects a mock implementation of IListMemberService
	 * for use during test execution.
	 *
	 * @param mock
	 * Mock service implementation.
	 */
	public static void setMock(IListMemberService mock) {
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
