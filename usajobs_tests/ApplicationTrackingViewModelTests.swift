//
//  ApplicationTrackingViewModelTests.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import XCTest
import CoreData
@testable import usajobs

/// Unit tests for ApplicationTrackingViewModel
@MainActor
final class ApplicationTrackingViewModelTests: XCTestCase {
    
    // MARK: - Properties
    
    private var viewModel: ApplicationTrackingViewModel!
    private var mockPersistenceService: MockDataPersistenceService!
    private var mockNotificationService: MockNotificationService!
    private var testContext: NSManagedObjectContext!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory Core Data stack for testing
        let container = NSPersistentContainer(name: "FederalJobFinder")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }
        
        testContext = container.viewContext
        
        // Create mock services
        mockPersistenceService = MockDataPersistenceService()
        mockNotificationService = MockNotificationService()
        
        // Create view model with mocks
        viewModel = ApplicationTrackingViewModel(
            persistenceService: mockPersistenceService,
            notificationService: mockNotificationService
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockPersistenceService = nil
        mockNotificationService = nil
        testContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Test Cases
    
    func testInitialization() async throws {
        // Given: A new view model
        // When: It's initialized
        // Then: It should load applications
        XCTAssertTrue(mockPersistenceService.getApplicationTrackingsCalled)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.applications.count, 0)
    }
    
    func testLoadApplications() async throws {
        // Given: Mock applications in persistence service
        let mockApplication = createMockApplication(jobId: "test-job-1")
        mockPersistenceService.mockApplications = [mockApplication]
        
        // When: Loading applications
        await viewModel.loadApplications()
        
        // Then: Applications should be loaded
        XCTAssertEqual(viewModel.applications.count, 1)
        XCTAssertEqual(viewModel.applications.first?.jobId, "test-job-1")
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testCreateApplication() async throws {
        // Given: A job ID
        let jobId = "new-job-123"
        
        // When: Creating a new application
        await viewModel.createApplication(for: jobId)
        
        // Then: Application should be saved and notification scheduled
        XCTAssertTrue(mockPersistenceService.saveApplicationTrackingCalled)
        XCTAssertTrue(mockNotificationService.scheduleDeadlineReminderCalled)
        XCTAssertTrue(mockPersistenceService.getApplicationTrackingsCalled)
    }
    
    func testUpdateApplicationStatus() async throws {
        // Given: An existing application
        let application = createMockApplication(jobId: "test-job-1")
        mockPersistenceService.mockApplications = [application]
        await viewModel.loadApplications()
        
        // When: Updating application status
        await viewModel.updateApplicationStatus(application, to: .interviewed)
        
        // Then: Status should be updated
        XCTAssertTrue(mockPersistenceService.updateApplicationStatusCalled)
        XCTAssertEqual(mockPersistenceService.lastUpdatedStatus, .interviewed)
        XCTAssertEqual(mockPersistenceService.lastUpdatedJobId, "test-job-1")
    }
    
    func testDeleteApplication() async throws {
        // Given: An existing application
        let application = createMockApplication(jobId: "test-job-1")
        mockPersistenceService.mockApplications = [application]
        await viewModel.loadApplications()
        
        // When: Deleting the application
        await viewModel.deleteApplication(application)
        
        // Then: Application should be deleted and notification cancelled
        XCTAssertTrue(mockPersistenceService.deleteApplicationTrackingCalled)
        XCTAssertTrue(mockNotificationService.cancelDeadlineReminderCalled)
        XCTAssertEqual(mockPersistenceService.lastDeletedJobId, "test-job-1")
        XCTAssertEqual(mockNotificationService.lastCancelledJobId, "test-job-1")
    }
    
    func testSetReminder() async throws {
        // Given: An existing application
        let application = createMockApplication(jobId: "test-job-1")
        mockPersistenceService.mockApplications = [application]
        await viewModel.loadApplications()
        
        // When: Setting a reminder
        await viewModel.setReminder(for: application, daysFromNow: 5)
        
        // Then: Reminder should be set and notification scheduled
        XCTAssertTrue(mockPersistenceService.saveApplicationTrackingCalled)
        XCTAssertTrue(mockNotificationService.scheduleDeadlineReminderCalled)
        XCTAssertNotNil(application.reminderDate)
    }
    
    func testClearReminder() async throws {
        // Given: An application with a reminder
        let application = createMockApplication(jobId: "test-job-1")
        application.setReminder(daysFromNow: 3)
        mockPersistenceService.mockApplications = [application]
        await viewModel.loadApplications()
        
        // When: Clearing the reminder
        await viewModel.clearReminder(for: application)
        
        // Then: Reminder should be cleared and notification cancelled
        XCTAssertTrue(mockPersistenceService.saveApplicationTrackingCalled)
        XCTAssertTrue(mockNotificationService.cancelDeadlineReminderCalled)
        XCTAssertNil(application.reminderDate)
    }
    
    func testUpdateNotes() async throws {
        // Given: An existing application
        let application = createMockApplication(jobId: "test-job-1")
        mockPersistenceService.mockApplications = [application]
        await viewModel.loadApplications()
        
        // When: Updating notes
        let testNotes = "Interview scheduled for next week"
        await viewModel.updateNotes(for: application, notes: testNotes)
        
        // Then: Notes should be updated
        XCTAssertTrue(mockPersistenceService.saveApplicationTrackingCalled)
        XCTAssertEqual(application.notes, testNotes)
    }
    
    func testUpdateNotesWithEmptyString() async throws {
        // Given: An application with existing notes
        let application = createMockApplication(jobId: "test-job-1")
        application.notes = "Old notes"
        mockPersistenceService.mockApplications = [application]
        await viewModel.loadApplications()
        
        // When: Updating with empty notes
        await viewModel.updateNotes(for: application, notes: "")
        
        // Then: Notes should be cleared
        XCTAssertTrue(mockPersistenceService.saveApplicationTrackingCalled)
        XCTAssertNil(application.notes)
    }
    
    func testGetApplication() async throws {
        // Given: An existing application
        let application = createMockApplication(jobId: "test-job-1")
        mockPersistenceService.mockApplication = application
        
        // When: Getting application by job ID
        let result = await viewModel.getApplication(for: "test-job-1")
        
        // Then: Application should be returned
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.jobId, "test-job-1")
        XCTAssertTrue(mockPersistenceService.getApplicationTrackingCalled)
    }
    
    func testIsJobTracked() async throws {
        // Given: Applications loaded
        let application1 = createMockApplication(jobId: "job-1")
        let application2 = createMockApplication(jobId: "job-2")
        mockPersistenceService.mockApplications = [application1, application2]
        await viewModel.loadApplications()
        
        // When: Checking if jobs are tracked
        let isJob1Tracked = viewModel.isJobTracked("job-1")
        let isJob2Tracked = viewModel.isJobTracked("job-2")
        let isJob3Tracked = viewModel.isJobTracked("job-3")
        
        // Then: Should return correct tracking status
        XCTAssertTrue(isJob1Tracked)
        XCTAssertTrue(isJob2Tracked)
        XCTAssertFalse(isJob3Tracked)
    }
    
    func testApplicationsByStatus() async throws {
        // Given: Applications with different statuses
        let appliedApp = createMockApplication(jobId: "job-1", status: .applied)
        let interviewApp = createMockApplication(jobId: "job-2", status: .interview)
        let offerApp = createMockApplication(jobId: "job-3", status: .offer)
        mockPersistenceService.mockApplications = [appliedApp, interviewApp, offerApp]
        await viewModel.loadApplications()
        
        // When: Getting applications by status
        let appliedApps = viewModel.applications(with: .applied)
        let interviewApps = viewModel.applications(with: .interview)
        let offerApps = viewModel.applications(with: .offer)
        let rejectedApps = viewModel.applications(with: .rejected)
        
        // Then: Should return correct applications for each status
        XCTAssertEqual(appliedApps.count, 1)
        XCTAssertEqual(interviewApps.count, 1)
        XCTAssertEqual(offerApps.count, 1)
        XCTAssertEqual(rejectedApps.count, 0)
        XCTAssertEqual(appliedApps.first?.jobId, "job-1")
        XCTAssertEqual(interviewApps.first?.jobId, "job-2")
        XCTAssertEqual(offerApps.first?.jobId, "job-3")
    }
    
    func testApplicationsWithUpcomingDeadlines() async throws {
        // Given: Applications with different reminder dates
        let upcomingApp = createMockApplication(jobId: "job-1")
        upcomingApp.setReminder(daysFromNow: 3) // Within 7 days
        
        let farApp = createMockApplication(jobId: "job-2")
        farApp.setReminder(daysFromNow: 10) // Beyond 7 days
        
        let pastApp = createMockApplication(jobId: "job-3")
        pastApp.reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) // Past
        
        let noReminderApp = createMockApplication(jobId: "job-4")
        // No reminder set
        
        mockPersistenceService.mockApplications = [upcomingApp, farApp, pastApp, noReminderApp]
        await viewModel.loadApplications()
        
        // When: Getting applications with upcoming deadlines
        let upcomingDeadlines = viewModel.applicationsWithUpcomingDeadlines()
        
        // Then: Should return only applications with deadlines within 7 days
        XCTAssertEqual(upcomingDeadlines.count, 1)
        XCTAssertEqual(upcomingDeadlines.first?.jobId, "job-1")
    }
    
    func testComputedProperties() async throws {
        // Given: Applications with different statuses
        let appliedApp1 = createMockApplication(jobId: "job-1", status: .applied)
        let appliedApp2 = createMockApplication(jobId: "job-2", status: .applied)
        let interviewApp = createMockApplication(jobId: "job-3", status: .interview)
        let offerApp = createMockApplication(jobId: "job-4", status: .offer)
        let rejectedApp = createMockApplication(jobId: "job-5", status: .rejected)
        
        mockPersistenceService.mockApplications = [appliedApp1, appliedApp2, interviewApp, offerApp, rejectedApp]
        await viewModel.loadApplications()
        
        // When: Accessing computed properties
        let totalApplications = viewModel.totalApplications
        let activeApplications = viewModel.activeApplications
        let offersReceived = viewModel.offersReceived
        let applicationsByStatus = viewModel.applicationsByStatus
        
        // Then: Should return correct values
        XCTAssertEqual(totalApplications, 5)
        XCTAssertEqual(activeApplications, 3) // applied + interview
        XCTAssertEqual(offersReceived, 1)
        XCTAssertEqual(applicationsByStatus[.applied]?.count, 2)
        XCTAssertEqual(applicationsByStatus[.interview]?.count, 1)
        XCTAssertEqual(applicationsByStatus[.offer]?.count, 1)
        XCTAssertEqual(applicationsByStatus[.rejected]?.count, 1)
    }
    
    func testErrorHandling() async throws {
        // Given: Mock service that throws an error
        mockPersistenceService.shouldThrowError = true
        
        // When: Loading applications
        await viewModel.loadApplications()
        
        // Then: Error should be handled
        XCTAssertTrue(viewModel.showingError)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testRefresh() async throws {
        // Given: A view model with existing data
        let application = createMockApplication(jobId: "test-job-1")
        mockPersistenceService.mockApplications = [application]
        await viewModel.loadApplications()
        
        // Reset call tracking
        mockPersistenceService.getApplicationTrackingsCalled = false
        
        // When: Refreshing
        await viewModel.refresh()
        
        // Then: Applications should be reloaded
        XCTAssertTrue(mockPersistenceService.getApplicationTrackingsCalled)
    }
    
    func testClearError() async throws {
        // Given: A view model with an error
        viewModel.errorMessage = "Test error"
        viewModel.showingError = true
        
        // When: Clearing the error
        viewModel.clearError()
        
        // Then: Error state should be cleared
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showingError)
    }
    
    // MARK: - Helper Methods
    
    private func createMockApplication(
        jobId: String,
        status: ApplicationTracking.Status = .applied
    ) -> ApplicationTracking {
        let application = ApplicationTracking(context: testContext, jobId: jobId)
        application.applicationStatus = status
        return application
    }
}

// MARK: - Mock Services

class MockDataPersistenceService: DataPersistenceServiceProtocol {
    
    // MARK: - Mock Data
    
    var mockApplications: [ApplicationTracking] = []
    var mockApplication: ApplicationTracking?
    var shouldThrowError = false
    
    // MARK: - Call Tracking
    
    var getApplicationTrackingsCalled = false
    var saveApplicationTrackingCalled = false
    var updateApplicationStatusCalled = false
    var deleteApplicationTrackingCalled = false
    var getApplicationTrackingCalled = false
    
    var lastUpdatedJobId: String?
    var lastUpdatedStatus: ApplicationTracking.Status?
    var lastDeletedJobId: String?
    
    // MARK: - DataPersistenceServiceProtocol Implementation
    
    func getApplicationTrackings() async throws -> [ApplicationTracking] {
        getApplicationTrackingsCalled = true
        if shouldThrowError {
            throw DataPersistenceError.coreDataError(NSError(domain: "Test", code: 1))
        }
        return mockApplications
    }
    
    func saveApplicationTracking(_ application: ApplicationTracking) async throws {
        saveApplicationTrackingCalled = true
        if shouldThrowError {
            throw DataPersistenceError.coreDataError(NSError(domain: "Test", code: 1))
        }
    }
    
    func updateApplicationStatus(jobId: String, status: ApplicationTracking.Status) async throws {
        updateApplicationStatusCalled = true
        lastUpdatedJobId = jobId
        lastUpdatedStatus = status
        if shouldThrowError {
            throw DataPersistenceError.coreDataError(NSError(domain: "Test", code: 1))
        }
    }
    
    func deleteApplicationTracking(jobId: String) async throws {
        deleteApplicationTrackingCalled = true
        lastDeletedJobId = jobId
        if shouldThrowError {
            throw DataPersistenceError.coreDataError(NSError(domain: "Test", code: 1))
        }
    }
    
    func getApplicationTracking(for jobId: String) async throws -> ApplicationTracking? {
        getApplicationTrackingCalled = true
        if shouldThrowError {
            throw DataPersistenceError.coreDataError(NSError(domain: "Test", code: 1))
        }
        return mockApplication
    }
    
    // MARK: - Other Protocol Methods (Not Used in Tests)
    
    func saveFavoriteJob(_ job: Job) async throws { }
    func removeFavoriteJob(jobId: String) async throws { }
    func getFavoriteJobs() async throws -> [Job] { return [] }
    func toggleFavoriteStatus(jobId: String) async throws -> Bool { return false }
    func saveSavedSearch(_ search: SavedSearch) async throws { }
    func getSavedSearches() async throws -> [SavedSearch] { return [] }
    func deleteSavedSearch(searchId: UUID) async throws { }
    func updateSavedSearch(_ search: SavedSearch) async throws { }
    func cacheJob(_ job: Job) async throws { }
    func getCachedJob(jobId: String) async throws -> Job? { return nil }
    func clearExpiredCache() async throws { }
}

class MockNotificationService: NotificationServiceProtocol {
    
    // MARK: - Call Tracking
    
    var scheduleDeadlineReminderCalled = false
    var cancelDeadlineReminderCalled = false
    var lastCancelledJobId: String?
    
    // MARK: - NotificationServiceProtocol Implementation
    
    func scheduleDeadlineReminder(for application: ApplicationTracking) async throws {
        scheduleDeadlineReminderCalled = true
    }
    
    func cancelDeadlineReminder(for jobId: String) async {
        cancelDeadlineReminderCalled = true
        lastCancelledJobId = jobId
    }
    
    // MARK: - Other Protocol Methods (Not Used in Tests)
    
    func requestNotificationPermissions() async throws -> Bool { return true }
    func scheduleNewJobsNotification(for search: SavedSearch, jobCount: Int) async throws { }
    func cancelNewJobsNotification(for searchId: UUID) async { }
    func cancelAllNotifications() async { }
    func getNotificationSettings() async -> UNNotificationSettings {
        return UNNotificationSettings()
    }
    func handleNotificationResponse(_ response: UNNotificationResponse) async { }
}