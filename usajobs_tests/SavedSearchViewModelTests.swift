//
//  SavedSearchViewModelTests.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import XCTest
import CoreData
@testable import usajobs

@MainActor
final class SavedSearchViewModelTests: XCTestCase {
    
    var viewModel: SavedSearchViewModel!
    var mockPersistenceService: MockDataPersistenceService!
    var mockAPIService: MockUSAJobsAPIService!
    var mockNotificationService: MockNotificationService!
    var testContext: NSManagedObjectContext!
    
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
        mockAPIService = MockUSAJobsAPIService()
        mockNotificationService = MockNotificationService()
        
        // Create view model
        viewModel = SavedSearchViewModel(
            persistenceService: mockPersistenceService,
            apiService: mockAPIService,
            notificationService: mockNotificationService
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockPersistenceService = nil
        mockAPIService = nil
        mockNotificationService = nil
        testContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Load Saved Searches Tests
    
    func testLoadSavedSearches_Success() async throws {
        // Given
        let expectedSearches = createMockSavedSearches()
        mockPersistenceService.savedSearchesToReturn = expectedSearches
        
        // When
        await viewModel.loadSavedSearches()
        
        // Then
        XCTAssertEqual(viewModel.savedSearches.count, expectedSearches.count)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(mockPersistenceService.getSavedSearchesCalled)
    }
    
    func testLoadSavedSearches_Failure() async throws {
        // Given
        mockPersistenceService.shouldThrowError = true
        mockPersistenceService.errorToThrow = DataPersistenceError.coreDataError(NSError(domain: "Test", code: 1))
        
        // When
        await viewModel.loadSavedSearches()
        
        // Then
        XCTAssertTrue(viewModel.savedSearches.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("Database error"))
    }
    
    // MARK: - Create Saved Search Tests
    
    func testCreateSavedSearch_Success() async throws {
        // Given
        let searchName = "Test Search"
        let criteria = SearchCriteria(keyword: "developer", location: "DC")
        
        // When
        await viewModel.createSavedSearch(name: searchName, criteria: criteria)
        
        // Then
        XCTAssertTrue(mockPersistenceService.saveSavedSearchCalled)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testCreateSavedSearch_EmptyName() async throws {
        // Given
        let searchName = "   "
        let criteria = SearchCriteria(keyword: "developer")
        
        // When
        await viewModel.createSavedSearch(name: searchName, criteria: criteria)
        
        // Then
        XCTAssertFalse(mockPersistenceService.saveSavedSearchCalled)
        XCTAssertEqual(viewModel.errorMessage, "Search name cannot be empty")
    }
    
    func testCreateSavedSearch_PersistenceFailure() async throws {
        // Given
        let searchName = "Test Search"
        let criteria = SearchCriteria(keyword: "developer")
        mockPersistenceService.shouldThrowError = true
        mockPersistenceService.errorToThrow = DataPersistenceError.coreDataError(NSError(domain: "Test", code: 1))
        
        // When
        await viewModel.createSavedSearch(name: searchName, criteria: criteria)
        
        // Then
        XCTAssertTrue(mockPersistenceService.saveSavedSearchCalled)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("Failed to create saved search"))
    }
    
    // MARK: - Update Saved Search Tests
    
    func testUpdateSavedSearch_Success() async throws {
        // Given
        let savedSearch = createMockSavedSearch(name: "Original Name")
        let newName = "Updated Name"
        let newCriteria = SearchCriteria(keyword: "updated", location: "NY")
        
        // When
        await viewModel.updateSavedSearch(savedSearch, name: newName, criteria: newCriteria)
        
        // Then
        XCTAssertEqual(savedSearch.name, newName)
        XCTAssertEqual(savedSearch.keywords, "updated")
        XCTAssertEqual(savedSearch.location, "NY")
        XCTAssertTrue(mockPersistenceService.updateSavedSearchCalled)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testUpdateSavedSearch_EmptyName() async throws {
        // Given
        let savedSearch = createMockSavedSearch(name: "Original Name")
        let newName = ""
        let newCriteria = SearchCriteria(keyword: "updated")
        
        // When
        await viewModel.updateSavedSearch(savedSearch, name: newName, criteria: newCriteria)
        
        // Then
        XCTAssertFalse(mockPersistenceService.updateSavedSearchCalled)
        XCTAssertEqual(viewModel.errorMessage, "Search name cannot be empty")
    }
    
    // MARK: - Delete Saved Search Tests
    
    func testDeleteSavedSearch_Success() async throws {
        // Given
        let savedSearch = createMockSavedSearch(name: "Test Search")
        let searchId = savedSearch.searchId!
        viewModel.savedSearches = [savedSearch]
        
        // When
        await viewModel.deleteSavedSearch(savedSearch)
        
        // Then
        XCTAssertTrue(mockPersistenceService.deleteSavedSearchCalled)
        XCTAssertEqual(mockPersistenceService.deletedSearchId, searchId)
        XCTAssertTrue(viewModel.savedSearches.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testDeleteSavedSearch_PersistenceFailure() async throws {
        // Given
        let savedSearch = createMockSavedSearch(name: "Test Search")
        viewModel.savedSearches = [savedSearch]
        mockPersistenceService.shouldThrowError = true
        mockPersistenceService.errorToThrow = DataPersistenceError.savedSearchNotFound
        
        // When
        await viewModel.deleteSavedSearch(savedSearch)
        
        // Then
        XCTAssertTrue(mockPersistenceService.deleteSavedSearchCalled)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("Failed to delete saved search"))
    }
    
    // MARK: - Execute Saved Search Tests
    
    func testExecuteSavedSearch_Success() async throws {
        // Given
        let savedSearch = createMockSavedSearch(name: "Test Search")
        let expectedResponse = createMockJobSearchResponse()
        mockAPIService.jobSearchResponseToReturn = expectedResponse
        
        // When
        let result = await viewModel.executeSavedSearch(savedSearch)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(mockAPIService.searchJobsCalled)
        XCTAssertTrue(mockPersistenceService.updateSavedSearchCalled)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isExecutingSearch)
    }
    
    func testExecuteSavedSearch_APIFailure() async throws {
        // Given
        let savedSearch = createMockSavedSearch(name: "Test Search")
        mockAPIService.shouldThrowError = true
        mockAPIService.errorToThrow = APIError.noInternetConnection
        
        // When
        let result = await viewModel.executeSavedSearch(savedSearch)
        
        // Then
        XCTAssertNil(result)
        XCTAssertTrue(mockAPIService.searchJobsCalled)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("Failed to execute saved search"))
    }
    
    // MARK: - Toggle Notifications Tests
    
    func testToggleNotifications_EnableSuccess() async throws {
        // Given
        let savedSearch = createMockSavedSearch(name: "Test Search")
        savedSearch.isNotificationEnabled = false
        viewModel.savedSearches = [savedSearch]
        mockNotificationService.permissionGranted = true
        
        // When
        await viewModel.toggleNotifications(for: savedSearch)
        
        // Then
        XCTAssertTrue(savedSearch.isNotificationEnabled)
        XCTAssertTrue(mockPersistenceService.updateSavedSearchCalled)
        XCTAssertTrue(mockNotificationService.requestNotificationPermissionsCalled)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testToggleNotifications_DisableSuccess() async throws {
        // Given
        let savedSearch = createMockSavedSearch(name: "Test Search")
        savedSearch.isNotificationEnabled = true
        viewModel.savedSearches = [savedSearch]
        
        // When
        await viewModel.toggleNotifications(for: savedSearch)
        
        // Then
        XCTAssertFalse(savedSearch.isNotificationEnabled)
        XCTAssertTrue(mockPersistenceService.updateSavedSearchCalled)
        XCTAssertTrue(mockNotificationService.cancelNewJobsNotificationCalled)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testToggleNotifications_PermissionDenied() async throws {
        // Given
        let savedSearch = createMockSavedSearch(name: "Test Search")
        savedSearch.isNotificationEnabled = false
        viewModel.savedSearches = [savedSearch]
        mockNotificationService.permissionGranted = false
        
        // When
        await viewModel.toggleNotifications(for: savedSearch)
        
        // Then
        XCTAssertFalse(savedSearch.isNotificationEnabled) // Should remain false
        XCTAssertFalse(mockPersistenceService.updateSavedSearchCalled)
        XCTAssertTrue(mockNotificationService.requestNotificationPermissionsCalled)
        XCTAssertEqual(viewModel.errorMessage, "Notification permissions are required to receive job alerts")
    }
    
    // MARK: - Search Filtering Tests
    
    func testFilteredSavedSearches_WithSearchText() async throws {
        // Given
        let search1 = createMockSavedSearch(name: "Developer Jobs")
        let search2 = createMockSavedSearch(name: "Manager Positions")
        let search3 = createMockSavedSearch(name: "Software Developer")
        viewModel.savedSearches = [search1, search2, search3]
        
        // When
        viewModel.searchSavedSearches(with: "developer")
        
        // Then
        let filtered = viewModel.filteredSavedSearches
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains(search1))
        XCTAssertTrue(filtered.contains(search3))
        XCTAssertFalse(filtered.contains(search2))
    }
    
    func testFilteredSavedSearches_EmptySearchText() async throws {
        // Given
        let searches = createMockSavedSearches()
        viewModel.savedSearches = searches
        
        // When
        viewModel.searchSavedSearches(with: "")
        
        // Then
        let filtered = viewModel.filteredSavedSearches
        XCTAssertEqual(filtered.count, searches.count)
    }
    
    // MARK: - Computed Properties Tests
    
    func testIsEmpty_WhenNoSearches() async throws {
        // Given
        viewModel.savedSearches = []
        
        // Then
        XCTAssertTrue(viewModel.isEmpty)
        XCTAssertTrue(viewModel.shouldShowEmptyState)
    }
    
    func testIsEmpty_WhenHasSearches() async throws {
        // Given
        viewModel.savedSearches = createMockSavedSearches()
        
        // Then
        XCTAssertFalse(viewModel.isEmpty)
        XCTAssertFalse(viewModel.shouldShowEmptyState)
    }
    
    func testNotificationEnabledCount() async throws {
        // Given
        let search1 = createMockSavedSearch(name: "Search 1")
        search1.isNotificationEnabled = true
        let search2 = createMockSavedSearch(name: "Search 2")
        search2.isNotificationEnabled = false
        let search3 = createMockSavedSearch(name: "Search 3")
        search3.isNotificationEnabled = true
        
        viewModel.savedSearches = [search1, search2, search3]
        
        // Then
        XCTAssertEqual(viewModel.notificationEnabledCount, 2)
    }
    
    func testTotalNewJobsCount() async throws {
        // Given
        let search1 = createMockSavedSearch(name: "Search 1")
        let search2 = createMockSavedSearch(name: "Search 2")
        let search3 = createMockSavedSearch(name: "Search 3")
        
        viewModel.newJobCounts = [
            search1.searchId!: 5,
            search2.searchId!: 3,
            search3.searchId!: 0
        ]
        
        // Then
        XCTAssertEqual(viewModel.totalNewJobsCount, 8)
    }
    
    // MARK: - Helper Methods
    
    private func createMockSavedSearches() -> [SavedSearch] {
        return [
            createMockSavedSearch(name: "Developer Jobs"),
            createMockSavedSearch(name: "Manager Positions"),
            createMockSavedSearch(name: "Remote Work")
        ]
    }
    
    private func createMockSavedSearch(name: String) -> SavedSearch {
        let savedSearch = SavedSearch(context: testContext, name: name)
        savedSearch.keywords = "test"
        savedSearch.location = "Washington, DC"
        savedSearch.salaryMin = 50000
        savedSearch.salaryMax = 100000
        savedSearch.isNotificationEnabled = false
        return savedSearch
    }
    
    private func createMockJobSearchResponse() -> JobSearchResponse {
        return JobSearchResponse(
            searchResult: SearchResult(
                searchResultItems: [],
                searchResultCount: 0,
                searchResultCountAll: 0
            )
        )
    }
}

// MARK: - Mock Services

class MockDataPersistenceService: DataPersistenceServiceProtocol {
    var shouldThrowError = false
    var errorToThrow: Error = DataPersistenceError.invalidData
    
    var savedSearchesToReturn: [SavedSearch] = []
    var getSavedSearchesCalled = false
    var saveSavedSearchCalled = false
    var updateSavedSearchCalled = false
    var deleteSavedSearchCalled = false
    var deletedSearchId: UUID?
    
    func saveFavoriteJob(_ job: Job) async throws {}
    func removeFavoriteJob(jobId: String) async throws {}
    func getFavoriteJobs() async throws -> [Job] { return [] }
    func toggleFavoriteStatus(jobId: String) async throws -> Bool { return false }
    
    func saveSavedSearch(_ search: SavedSearch) async throws {
        saveSavedSearchCalled = true
        if shouldThrowError { throw errorToThrow }
    }
    
    func getSavedSearches() async throws -> [SavedSearch] {
        getSavedSearchesCalled = true
        if shouldThrowError { throw errorToThrow }
        return savedSearchesToReturn
    }
    
    func deleteSavedSearch(searchId: UUID) async throws {
        deleteSavedSearchCalled = true
        deletedSearchId = searchId
        if shouldThrowError { throw errorToThrow }
    }
    
    func updateSavedSearch(_ search: SavedSearch) async throws {
        updateSavedSearchCalled = true
        if shouldThrowError { throw errorToThrow }
    }
    
    func saveApplicationTracking(_ application: ApplicationTracking) async throws {}
    func getApplicationTrackings() async throws -> [ApplicationTracking] { return [] }
    func updateApplicationStatus(jobId: String, status: ApplicationTracking.Status) async throws {}
    func deleteApplicationTracking(jobId: String) async throws {}
    func getApplicationTracking(for jobId: String) async throws -> ApplicationTracking? { return nil }
    func cacheJob(_ job: Job) async throws {}
    func getCachedJob(jobId: String) async throws -> Job? { return nil }
    func clearExpiredCache() async throws {}
}

class MockUSAJobsAPIService: USAJobsAPIServiceProtocol {
    var shouldThrowError = false
    var errorToThrow: Error = APIError.noInternetConnection
    
    var jobSearchResponseToReturn: JobSearchResponse?
    var searchJobsCalled = false
    
    func searchJobs(criteria: SearchCriteria) async throws -> JobSearchResponse {
        searchJobsCalled = true
        if shouldThrowError { throw errorToThrow }
        return jobSearchResponseToReturn ?? JobSearchResponse(
            searchResult: SearchResult(
                searchResultItems: [],
                searchResultCount: 0,
                searchResultCountAll: 0
            )
        )
    }
    
    func getJobDetails(jobId: String) async throws -> JobDescriptor {
        if shouldThrowError { throw errorToThrow }
        return JobDescriptor(
            positionId: jobId,
            positionTitle: "Test Job",
            positionUri: "https://example.com",
            applicationCloseDate: "2024-12-31T23:59:59.000Z",
            positionStartDate: "2024-01-01T00:00:00.000Z",
            positionEndDate: "2024-12-31T23:59:59.000Z",
            publicationStartDate: "2024-01-01T00:00:00.000Z",
            applicationUri: "https://usajobs.gov/apply",
            positionLocationDisplay: "Washington, DC",
            positionLocation: [],
            organizationName: "Test Agency",
            departmentName: "Test Department",
            jobCategory: [],
            jobGrade: [],
            positionRemuneration: [],
            positionSummary: "Test job summary",
            positionFormattedDescription: [],
            userArea: nil,
            qualificationSummary: nil
        )
    }
    
    func validateAPIConnection() async throws -> Bool {
        if shouldThrowError { throw errorToThrow }
        return true
    }
}

class MockNotificationService: NotificationServiceProtocol {
    var shouldThrowError = false
    var errorToThrow: Error = NotificationError.permissionDenied
    var permissionGranted = true
    
    var requestNotificationPermissionsCalled = false
    var scheduleDeadlineReminderCalled = false
    var scheduleNewJobsNotificationCalled = false
    var cancelDeadlineReminderCalled = false
    var cancelNewJobsNotificationCalled = false
    var cancelAllNotificationsCalled = false
    
    func requestNotificationPermissions() async throws -> Bool {
        requestNotificationPermissionsCalled = true
        if shouldThrowError { throw errorToThrow }
        return permissionGranted
    }
    
    func scheduleDeadlineReminder(for application: ApplicationTracking) async throws {
        scheduleDeadlineReminderCalled = true
        if shouldThrowError { throw errorToThrow }
    }
    
    func scheduleNewJobsNotification(for search: SavedSearch, jobCount: Int) async throws {
        scheduleNewJobsNotificationCalled = true
        if shouldThrowError { throw errorToThrow }
    }
    
    func cancelDeadlineReminder(for jobId: String) async {
        cancelDeadlineReminderCalled = true
    }
    
    func cancelNewJobsNotification(for searchId: UUID) async {
        cancelNewJobsNotificationCalled = true
    }
    
    func cancelAllNotifications() async {
        cancelAllNotificationsCalled = true
    }
    
    func getNotificationSettings() async -> UNNotificationSettings {
        return MockUNNotificationSettings(authorizationStatus: permissionGranted ? .authorized : .denied)
    }
    
    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        // Mock implementation
    }
}