//
//  NotificationServiceTests.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import XCTest
import UserNotifications
@testable import usajobs

@MainActor
final class NotificationServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    var notificationService: NotificationService!
    var mockPersistenceService: MockDataPersistenceService!
    var mockAPIService: MockUSAJobsAPIService!
    var mockNotificationCenter: MockUNUserNotificationCenter!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockPersistenceService = MockDataPersistenceService()
        mockAPIService = MockUSAJobsAPIService()
        mockNotificationCenter = MockUNUserNotificationCenter()
        
        notificationService = NotificationService(
            persistenceService: mockPersistenceService,
            apiService: mockAPIService,
            notificationCenter: mockNotificationCenter
        )
    }
    
    override func tearDown() async throws {
        notificationService = nil
        mockPersistenceService = nil
        mockAPIService = nil
        mockNotificationCenter = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Permission Tests
    
    func testRequestNotificationPermissions_Success() async throws {
        // Given
        mockNotificationCenter.authorizationResult = true
        
        // When
        let granted = try await notificationService.requestNotificationPermissions()
        
        // Then
        XCTAssertTrue(granted)
        XCTAssertTrue(mockNotificationCenter.requestAuthorizationCalled)
    }
    
    func testRequestNotificationPermissions_Denied() async throws {
        // Given
        mockNotificationCenter.authorizationResult = false
        
        // When
        let granted = try await notificationService.requestNotificationPermissions()
        
        // Then
        XCTAssertFalse(granted)
        XCTAssertTrue(mockNotificationCenter.requestAuthorizationCalled)
    }
    
    func testRequestNotificationPermissions_Error() async {
        // Given
        mockNotificationCenter.authorizationError = NSError(domain: "TestError", code: 1, userInfo: nil)
        
        // When/Then
        do {
            _ = try await notificationService.requestNotificationPermissions()
            XCTFail("Expected error to be thrown")
        } catch let error as NotificationError {
            if case .schedulingFailed = error {
                // Expected error type
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Deadline Reminder Tests
    
    func testScheduleDeadlineReminder_Success() async throws {
        // Given
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
        let application = ApplicationTracking(context: context, jobId: "test-job-123")
        application.reminderDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        
        let job = Job(context: context)
        job.jobId = "test-job-123"
        job.title = "Software Developer"
        
        mockNotificationCenter.notificationSettings = createAuthorizedSettings()
        mockPersistenceService.cachedJobs["test-job-123"] = job
        
        // When
        try await notificationService.scheduleDeadlineReminder(for: application)
        
        // Then
        XCTAssertTrue(mockNotificationCenter.addNotificationCalled)
        XCTAssertEqual(mockNotificationCenter.lastNotificationRequest?.identifier, "deadline_test-job-123")
        XCTAssertEqual(mockNotificationCenter.lastNotificationRequest?.content.title, "Application Deadline Reminder")
        XCTAssertTrue(mockNotificationCenter.lastNotificationRequest?.content.body.contains("Software Developer") ?? false)
    }
    
    func testScheduleDeadlineReminder_NoPermission() async {
        // Given
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
        let application = ApplicationTracking(context: context, jobId: "test-job-123")
        application.reminderDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        
        mockNotificationCenter.notificationSettings = createDeniedSettings()
        
        // When/Then
        do {
            try await notificationService.scheduleDeadlineReminder(for: application)
            XCTFail("Expected permission denied error")
        } catch let error as NotificationError {
            if case .permissionDenied = error {
                // Expected error type
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testScheduleDeadlineReminder_InvalidData() async {
        // Given
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
        let application = ApplicationTracking(context: context, jobId: "test-job-123")
        // No reminder date set
        
        // When/Then
        do {
            try await notificationService.scheduleDeadlineReminder(for: application)
            XCTFail("Expected invalid data error")
        } catch let error as NotificationError {
            if case .invalidApplicationData = error {
                // Expected error type
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCancelDeadlineReminder() async {
        // Given
        let jobId = "test-job-123"
        
        // When
        await notificationService.cancelDeadlineReminder(for: jobId)
        
        // Then
        XCTAssertTrue(mockNotificationCenter.removePendingNotificationsCalled)
        XCTAssertEqual(mockNotificationCenter.removedIdentifiers, ["deadline_test-job-123"])
    }
    
    // MARK: - New Jobs Notification Tests
    
    func testScheduleNewJobsNotification_Success() async throws {
        // Given
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
        let search = SavedSearch(context: context, name: "iOS Developer Jobs")
        search.isNotificationEnabled = true
        
        mockNotificationCenter.notificationSettings = createAuthorizedSettings()
        
        // When
        try await notificationService.scheduleNewJobsNotification(for: search, jobCount: 5)
        
        // Then
        XCTAssertTrue(mockNotificationCenter.addNotificationCalled)
        XCTAssertEqual(mockNotificationCenter.lastNotificationRequest?.content.title, "New Federal Jobs Available")
        XCTAssertTrue(mockNotificationCenter.lastNotificationRequest?.content.body.contains("5 new jobs") ?? false)
        XCTAssertTrue(mockNotificationCenter.lastNotificationRequest?.content.body.contains("iOS Developer Jobs") ?? false)
    }
    
    func testScheduleNewJobsNotification_SingleJob() async throws {
        // Given
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
        let search = SavedSearch(context: context, name: "Data Scientist")
        search.isNotificationEnabled = true
        
        mockNotificationCenter.notificationSettings = createAuthorizedSettings()
        
        // When
        try await notificationService.scheduleNewJobsNotification(for: search, jobCount: 1)
        
        // Then
        XCTAssertTrue(mockNotificationCenter.addNotificationCalled)
        XCTAssertTrue(mockNotificationCenter.lastNotificationRequest?.content.body.contains("1 new job matches") ?? false)
    }
    
    func testScheduleNewJobsNotification_NotificationsDisabled() async throws {
        // Given
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
        let search = SavedSearch(context: context, name: "Test Search")
        search.isNotificationEnabled = false
        
        mockNotificationCenter.notificationSettings = createAuthorizedSettings()
        
        // When
        try await notificationService.scheduleNewJobsNotification(for: search, jobCount: 3)
        
        // Then
        XCTAssertFalse(mockNotificationCenter.addNotificationCalled)
    }
    
    func testScheduleNewJobsNotification_NoNewJobs() async throws {
        // Given
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
        let search = SavedSearch(context: context, name: "Test Search")
        search.isNotificationEnabled = true
        
        mockNotificationCenter.notificationSettings = createAuthorizedSettings()
        
        // When
        try await notificationService.scheduleNewJobsNotification(for: search, jobCount: 0)
        
        // Then
        XCTAssertFalse(mockNotificationCenter.addNotificationCalled)
    }
    
    func testCancelNewJobsNotification() async {
        // Given
        let searchId = UUID()
        
        // When
        await notificationService.cancelNewJobsNotification(for: searchId)
        
        // Then
        XCTAssertTrue(mockNotificationCenter.removePendingNotificationsCalled)
        XCTAssertEqual(mockNotificationCenter.removedIdentifiers, ["new_jobs_\(searchId.uuidString)"])
    }
    
    // MARK: - Background Job Checking Tests
    
    func testCheckForNewJobsInBackground_Success() async {
        // Given
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
        let search1 = SavedSearch(context: context, name: "Search 1")
        search1.isNotificationEnabled = true
        search1.keywords = "developer"
        search1.lastChecked = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        
        let search2 = SavedSearch(context: context, name: "Search 2")
        search2.isNotificationEnabled = false
        search2.keywords = "analyst"
        
        mockPersistenceService.savedSearches = [search1, search2]
        
        // Mock API response with new jobs
        let jobDescriptor = JobDescriptor(
            jobTitle: "Software Developer",
            organizationName: "Department of Defense",
            departmentName: "Defense",
            jobGrade: [JobGrade(code: "GS")],
            positionLocation: [PositionLocation(locationName: "Washington, DC")],
            minimumRange: "50000",
            maximumRange: "80000",
            publicationDate: Date(), // Recent date
            applicationCloseDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            positionURI: "https://usajobs.gov/job/123",
            applyURI: ["https://usajobs.gov/apply/123"],
            jobSummary: "Test job summary",
            whoMayApply: JobWhoMayApply(name: "Public", code: "15317")
        )
        
        let jobItem = JobSearchItem(
            matchedObjectId: "123",
            matchedObjectDescriptor: jobDescriptor,
            relevanceRank: 1
        )
        
        let response = JobSearchResponse(
            searchResult: SearchResult(
                searchResultItems: [jobItem],
                searchResultCount: 1,
                searchResultCountAll: 1
            )
        )
        
        mockAPIService.searchResponse = response
        mockNotificationCenter.notificationSettings = createAuthorizedSettings()
        
        // When
        await notificationService.checkForNewJobsInBackground()
        
        // Then
        XCTAssertTrue(mockAPIService.searchJobsCalled)
        XCTAssertTrue(mockPersistenceService.updateSavedSearchCalled)
        // Only search1 should trigger notification (search2 has notifications disabled)
        XCTAssertTrue(mockNotificationCenter.addNotificationCalled)
    }
    
    func testCheckForNewJobsInBackground_NoNewJobs() async {
        // Given
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
        let search = SavedSearch(context: context, name: "Test Search")
        search.isNotificationEnabled = true
        search.keywords = "developer"
        search.lastChecked = Date() // Recent check
        
        mockPersistenceService.savedSearches = [search]
        
        // Mock API response with old jobs
        let jobDescriptor = JobDescriptor(
            jobTitle: "Software Developer",
            organizationName: "Department of Defense",
            departmentName: "Defense",
            jobGrade: [JobGrade(code: "GS")],
            positionLocation: [PositionLocation(locationName: "Washington, DC")],
            minimumRange: "50000",
            maximumRange: "80000",
            publicationDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()), // Old date
            applicationCloseDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            positionURI: "https://usajobs.gov/job/123",
            applyURI: ["https://usajobs.gov/apply/123"],
            jobSummary: "Test job summary",
            whoMayApply: JobWhoMayApply(name: "Public", code: "15317")
        )
        
        let jobItem = JobSearchItem(
            matchedObjectId: "123",
            matchedObjectDescriptor: jobDescriptor,
            relevanceRank: 1
        )
        
        let response = JobSearchResponse(
            searchResult: SearchResult(
                searchResultItems: [jobItem],
                searchResultCount: 1,
                searchResultCountAll: 1
            )
        )
        
        mockAPIService.searchResponse = response
        mockNotificationCenter.notificationSettings = createAuthorizedSettings()
        
        // When
        await notificationService.checkForNewJobsInBackground()
        
        // Then
        XCTAssertTrue(mockAPIService.searchJobsCalled)
        XCTAssertTrue(mockPersistenceService.updateSavedSearchCalled)
        XCTAssertFalse(mockNotificationCenter.addNotificationCalled) // No new jobs, so no notification
    }
    
    // MARK: - Notification Management Tests
    
    func testCancelAllNotifications() async {
        // When
        await notificationService.cancelAllNotifications()
        
        // Then
        XCTAssertTrue(mockNotificationCenter.removeAllPendingNotificationsCalled)
    }
    
    func testHandleNotificationResponse_DeadlineReminder() async {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "type": "deadline_reminder",
            "jobId": "test-job-123"
        ]
        
        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        
        let request = UNNotificationRequest(identifier: "test", content: content, trigger: nil)
        let notification = UNNotification(request: request, date: Date())
        let response = UNNotificationResponse(notification: notification, actionIdentifier: UNNotificationDefaultActionIdentifier)
        
        // Set up notification observer
        var receivedNotification: Notification?
        let expectation = XCTestExpectation(description: "Navigation notification")
        
        let observer = NotificationCenter.default.addObserver(
            forName: .navigateToJobDetail,
            object: nil,
            queue: .main
        ) { notification in
            receivedNotification = notification
            expectation.fulfill()
        }
        
        // When
        await notificationService.handleNotificationResponse(response)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedNotification)
        XCTAssertEqual(receivedNotification?.userInfo?["jobId"] as? String, "test-job-123")
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testHandleNotificationResponse_NewJobs() async {
        // Given
        let searchId = UUID()
        let userInfo: [AnyHashable: Any] = [
            "type": "new_jobs",
            "searchId": searchId.uuidString,
            "searchName": "Test Search",
            "jobCount": 3
        ]
        
        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        
        let request = UNNotificationRequest(identifier: "test", content: content, trigger: nil)
        let notification = UNNotification(request: request, date: Date())
        let response = UNNotificationResponse(notification: notification, actionIdentifier: UNNotificationDefaultActionIdentifier)
        
        // Set up notification observer
        var receivedNotification: Notification?
        let expectation = XCTestExpectation(description: "Navigation notification")
        
        let observer = NotificationCenter.default.addObserver(
            forName: .navigateToSavedSearch,
            object: nil,
            queue: .main
        ) { notification in
            receivedNotification = notification
            expectation.fulfill()
        }
        
        // When
        await notificationService.handleNotificationResponse(response)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedNotification)
        XCTAssertEqual(receivedNotification?.userInfo?["searchId"] as? UUID, searchId)
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - Helper Methods
    
    private func createAuthorizedSettings() -> UNNotificationSettings {
        return MockUNNotificationSettings(authorizationStatus: .authorized)
    }
    
    private func createDeniedSettings() -> UNNotificationSettings {
        return MockUNNotificationSettings(authorizationStatus: .denied)
    }
}

// MARK: - Mock Classes

class MockUNUserNotificationCenter: UNUserNotificationCenter {
    var authorizationResult = false
    var authorizationError: Error?
    var requestAuthorizationCalled = false
    var addNotificationCalled = false
    var removePendingNotificationsCalled = false
    var removeAllPendingNotificationsCalled = false
    var lastNotificationRequest: UNNotificationRequest?
    var removedIdentifiers: [String] = []
    var notificationSettings: UNNotificationSettings = MockUNNotificationSettings(authorizationStatus: .notDetermined)
    
    override func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCalled = true
        
        if let error = authorizationError {
            throw error
        }
        
        return authorizationResult
    }
    
    override func add(_ request: UNNotificationRequest) async throws {
        addNotificationCalled = true
        lastNotificationRequest = request
    }
    
    override func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removePendingNotificationsCalled = true
        removedIdentifiers = identifiers
    }
    
    override func removeAllPendingNotificationRequests() {
        removeAllPendingNotificationsCalled = true
    }
    
    override func notificationSettings() async -> UNNotificationSettings {
        return notificationSettings
    }
}

class MockUNNotificationSettings: UNNotificationSettings {
    private let _authorizationStatus: UNAuthorizationStatus
    
    init(authorizationStatus: UNAuthorizationStatus) {
        self._authorizationStatus = authorizationStatus
        super.init()
    }
    
    override var authorizationStatus: UNAuthorizationStatus {
        return _authorizationStatus
    }
}

class MockDataPersistenceService: DataPersistenceServiceProtocol {
    var savedSearches: [SavedSearch] = []
    var cachedJobs: [String: Job] = [:]
    var updateSavedSearchCalled = false
    
    func saveFavoriteJob(_ job: Job) async throws {}
    func removeFavoriteJob(jobId: String) async throws {}
    func getFavoriteJobs() async throws -> [Job] { return [] }
    func toggleFavoriteStatus(jobId: String) async throws -> Bool { return false }
    
    func saveSavedSearch(_ search: SavedSearch) async throws {}
    
    func getSavedSearches() async throws -> [SavedSearch] {
        return savedSearches
    }
    
    func deleteSavedSearch(searchId: UUID) async throws {}
    
    func updateSavedSearch(_ search: SavedSearch) async throws {
        updateSavedSearchCalled = true
    }
    
    func saveApplicationTracking(_ application: ApplicationTracking) async throws {}
    func getApplicationTrackings() async throws -> [ApplicationTracking] { return [] }
    func updateApplicationStatus(jobId: String, status: ApplicationTracking.Status) async throws {}
    func deleteApplicationTracking(jobId: String) async throws {}
    func getApplicationTracking(for jobId: String) async throws -> ApplicationTracking? { return nil }
    
    func cacheJob(_ job: Job) async throws {}
    
    func getCachedJob(jobId: String) async throws -> Job? {
        return cachedJobs[jobId]
    }
    
    func clearExpiredCache() async throws {}
}

class MockUSAJobsAPIService: USAJobsAPIServiceProtocol {
    var searchResponse: JobSearchResponse?
    var searchJobsCalled = false
    
    func searchJobs(criteria: SearchCriteria) async throws -> JobSearchResponse {
        searchJobsCalled = true
        return searchResponse ?? JobSearchResponse(searchResult: SearchResult(searchResultItems: [], searchResultCount: 0, searchResultCountAll: 0))
    }
    
    func getJobDetails(jobId: String) async throws -> JobDescriptor {
        throw APIError.noData
    }
    
    func validateAPIConnection() async throws -> Bool {
        return true
    }
}

// MARK: - Mock UNNotificationResponse

extension UNNotificationResponse {
    convenience init(notification: UNNotification, actionIdentifier: String) {
        // This is a simplified mock - in real tests you might need a more sophisticated approach
        self.init()
        setValue(notification, forKey: "notification")
        setValue(actionIdentifier, forKey: "actionIdentifier")
    }
}

extension UNNotification {
    convenience init(request: UNNotificationRequest, date: Date) {
        self.init()
        setValue(request, forKey: "request")
        setValue(date, forKey: "date")
    }
}