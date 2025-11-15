//
//  FavoritesViewModelTests.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import XCTest
import CoreData
@testable import usajobs

@MainActor
final class FavoritesViewModelTests: XCTestCase {
    
    var viewModel: FavoritesViewModel!
    var mockPersistenceService: MockDataPersistenceService!
    var mockAPIService: MockUSAJobsAPIService!
    var testContext: NSManagedObjectContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Set up in-memory Core Data stack for testing
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
        
        // Set up mock services
        mockPersistenceService = MockDataPersistenceService()
        mockAPIService = MockUSAJobsAPIService()
        
        // Create view model
        viewModel = FavoritesViewModel(
            persistenceService: mockPersistenceService,
            apiService: mockAPIService
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockPersistenceService = nil
        mockAPIService = nil
        testContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Load Favorites Tests
    
    func testLoadFavorites_Success() async throws {
        // Given
        let expectedJobs = createMockJobs(count: 3)
        mockPersistenceService.mockFavoriteJobs = expectedJobs
        
        // When
        await viewModel.loadFavorites()
        
        // Then
        XCTAssertEqual(viewModel.favoriteJobs.count, 3)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(mockPersistenceService.getFavoriteJobsCalled)
    }
    
    func testLoadFavorites_EmptyList() async throws {
        // Given
        mockPersistenceService.mockFavoriteJobs = []
        
        // When
        await viewModel.loadFavorites()
        
        // Then
        XCTAssertTrue(viewModel.favoriteJobs.isEmpty)
        XCTAssertTrue(viewModel.isEmpty)
        XCTAssertTrue(viewModel.shouldShowEmptyState)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testLoadFavorites_Error() async throws {
        // Given
        mockPersistenceService.shouldThrowError = true
        mockPersistenceService.errorToThrow = DataPersistenceError.coreDataError(NSError(domain: "Test", code: 1))
        
        // When
        await viewModel.loadFavorites()
        
        // Then
        XCTAssertTrue(viewModel.favoriteJobs.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.errorMessage?.contains("Failed to load favorite jobs") == true)
    }
    
    func testLoadFavorites_LoadingState() async throws {
        // Given
        mockPersistenceService.shouldDelay = true
        
        // When
        let loadTask = Task {
            await viewModel.loadFavorites()
        }
        
        // Check loading state immediately
        XCTAssertTrue(viewModel.isLoading)
        
        // Wait for completion
        await loadTask.value
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Remove Favorite Tests
    
    func testRemoveFavorite_Success() async throws {
        // Given
        let jobs = createMockJobs(count: 3)
        viewModel.favoriteJobs = jobs
        let jobToRemove = jobs[1]
        
        // When
        await viewModel.removeFavorite(job: jobToRemove)
        
        // Then
        XCTAssertEqual(viewModel.favoriteJobs.count, 2)
        XCTAssertFalse(viewModel.favoriteJobs.contains(jobToRemove))
        XCTAssertTrue(mockPersistenceService.removeFavoriteJobCalled)
        XCTAssertEqual(mockPersistenceService.lastRemovedJobId, jobToRemove.jobId)
    }
    
    func testRemoveFavorite_Error() async throws {
        // Given
        let jobs = createMockJobs(count: 2)
        viewModel.favoriteJobs = jobs
        let jobToRemove = jobs[0]
        
        mockPersistenceService.shouldThrowError = true
        mockPersistenceService.errorToThrow = DataPersistenceError.jobNotFound
        
        // When
        await viewModel.removeFavorite(job: jobToRemove)
        
        // Then
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("Failed to remove job from favorites") == true)
        XCTAssertTrue(mockPersistenceService.getFavoriteJobsCalled) // Should reload after error
    }
    
    func testRemoveFavorite_JobWithoutId() async throws {
        // Given
        let job = Job(context: testContext)
        job.jobId = nil // No job ID
        viewModel.favoriteJobs = [job]
        
        // When
        await viewModel.removeFavorite(job: job)
        
        // Then
        XCTAssertFalse(mockPersistenceService.removeFavoriteJobCalled)
        XCTAssertEqual(viewModel.favoriteJobs.count, 1) // Should remain unchanged
    }
    
    // MARK: - Refresh Job Statuses Tests
    
    func testRefreshJobStatuses_Success() async throws {
        // Given
        let jobs = createMockJobs(count: 2)
        viewModel.favoriteJobs = jobs
        
        let updatedJobDescriptor = createMockJobDescriptor(jobId: jobs[0].jobId!)
        mockAPIService.mockJobDetails = updatedJobDescriptor
        
        // When
        await viewModel.refreshJobStatuses()
        
        // Then
        XCTAssertFalse(viewModel.isRefreshingStatuses)
        XCTAssertTrue(mockAPIService.getJobDetailsCalled)
        XCTAssertTrue(mockPersistenceService.cacheJobCalled)
        XCTAssertTrue(mockPersistenceService.getFavoriteJobsCalled) // Should reload after update
    }
    
    func testRefreshJobStatuses_EmptyList() async throws {
        // Given
        viewModel.favoriteJobs = []
        
        // When
        await viewModel.refreshJobStatuses()
        
        // Then
        XCTAssertFalse(viewModel.isRefreshingStatuses)
        XCTAssertFalse(mockAPIService.getJobDetailsCalled)
    }
    
    func testRefreshJobStatuses_APIError() async throws {
        // Given
        let jobs = createMockJobs(count: 1)
        viewModel.favoriteJobs = jobs
        
        mockAPIService.shouldThrowError = true
        mockAPIService.errorToThrow = APIError.noInternetConnection
        
        // When
        await viewModel.refreshJobStatuses()
        
        // Then
        XCTAssertFalse(viewModel.isRefreshingStatuses)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("No internet connection") == true)
    }
    
    func testRefreshJobStatuses_LoadingState() async throws {
        // Given
        let jobs = createMockJobs(count: 1)
        viewModel.favoriteJobs = jobs
        mockAPIService.shouldDelay = true
        
        // When
        let refreshTask = Task {
            await viewModel.refreshJobStatuses()
        }
        
        // Check loading state immediately
        XCTAssertTrue(viewModel.isRefreshingStatuses)
        
        // Wait for completion
        await refreshTask.value
        
        // Then
        XCTAssertFalse(viewModel.isRefreshingStatuses)
    }
    
    // MARK: - Toggle Favorite Status Tests
    
    func testToggleFavoriteStatus_RemoveFromFavorites() async throws {
        // Given
        let jobs = createMockJobs(count: 2)
        viewModel.favoriteJobs = jobs
        let jobId = jobs[0].jobId!
        
        mockPersistenceService.mockToggleFavoriteResult = false // Job was unfavorited
        
        // When
        await viewModel.toggleFavoriteStatus(jobId: jobId)
        
        // Then
        XCTAssertEqual(viewModel.favoriteJobs.count, 1)
        XCTAssertFalse(viewModel.favoriteJobs.contains { $0.jobId == jobId })
        XCTAssertTrue(mockPersistenceService.toggleFavoriteStatusCalled)
    }
    
    func testToggleFavoriteStatus_AddToFavorites() async throws {
        // Given
        let jobs = createMockJobs(count: 1)
        viewModel.favoriteJobs = jobs
        let jobId = "new-job-id"
        
        mockPersistenceService.mockToggleFavoriteResult = true // Job was favorited
        
        // When
        await viewModel.toggleFavoriteStatus(jobId: jobId)
        
        // Then
        XCTAssertTrue(mockPersistenceService.getFavoriteJobsCalled) // Should reload favorites
        XCTAssertTrue(mockPersistenceService.toggleFavoriteStatusCalled)
    }
    
    // MARK: - Search and Filter Tests
    
    func testSearchFavorites() async throws {
        // Given
        let jobs = createMockJobs(count: 3)
        jobs[0].title = "Software Developer"
        jobs[1].title = "Data Analyst"
        jobs[2].title = "Program Manager"
        viewModel.favoriteJobs = jobs
        
        // When
        viewModel.searchFavorites(with: "Software")
        
        // Then
        XCTAssertEqual(viewModel.searchText, "Software")
        XCTAssertEqual(viewModel.filteredFavoriteJobs.count, 1)
        XCTAssertEqual(viewModel.filteredFavoriteJobs[0].title, "Software Developer")
    }
    
    func testApplyFilter_Active() async throws {
        // Given
        let jobs = createMockJobs(count: 3)
        // Make one job expired
        jobs[0].applicationDeadline = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        // Make others active
        jobs[1].applicationDeadline = Calendar.current.date(byAdding: .day, value: 10, to: Date())
        jobs[2].applicationDeadline = Calendar.current.date(byAdding: .day, value: 20, to: Date())
        viewModel.favoriteJobs = jobs
        
        // When
        viewModel.applyFilter(.active)
        
        // Then
        XCTAssertEqual(viewModel.selectedFilter, .active)
        XCTAssertEqual(viewModel.filteredFavoriteJobs.count, 2)
        XCTAssertFalse(viewModel.filteredFavoriteJobs.contains(jobs[0]))
    }
    
    func testApplyFilter_Expired() async throws {
        // Given
        let jobs = createMockJobs(count: 3)
        // Make one job expired
        jobs[0].applicationDeadline = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        // Make others active
        jobs[1].applicationDeadline = Calendar.current.date(byAdding: .day, value: 10, to: Date())
        jobs[2].applicationDeadline = Calendar.current.date(byAdding: .day, value: 20, to: Date())
        viewModel.favoriteJobs = jobs
        
        // When
        viewModel.applyFilter(.expired)
        
        // Then
        XCTAssertEqual(viewModel.selectedFilter, .expired)
        XCTAssertEqual(viewModel.filteredFavoriteJobs.count, 1)
        XCTAssertTrue(viewModel.filteredFavoriteJobs.contains(jobs[0]))
    }
    
    func testApplyFilter_RecentlyAdded() async throws {
        // Given
        let jobs = createMockJobs(count: 3)
        // Make one job recently added
        jobs[0].cachedAt = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        // Make others older
        jobs[1].cachedAt = Calendar.current.date(byAdding: .day, value: -10, to: Date())
        jobs[2].cachedAt = Calendar.current.date(byAdding: .day, value: -15, to: Date())
        viewModel.favoriteJobs = jobs
        
        // When
        viewModel.applyFilter(.recentlyAdded)
        
        // Then
        XCTAssertEqual(viewModel.selectedFilter, .recentlyAdded)
        XCTAssertEqual(viewModel.filteredFavoriteJobs.count, 1)
        XCTAssertTrue(viewModel.filteredFavoriteJobs.contains(jobs[0]))
    }
    
    // MARK: - Computed Properties Tests
    
    func testComputedProperties() async throws {
        // Given
        let jobs = createMockJobs(count: 4)
        // Make some expired
        jobs[0].applicationDeadline = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        jobs[1].applicationDeadline = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        // Make others active
        jobs[2].applicationDeadline = Calendar.current.date(byAdding: .day, value: 10, to: Date())
        jobs[3].applicationDeadline = Calendar.current.date(byAdding: .day, value: 20, to: Date())
        viewModel.favoriteJobs = jobs
        
        // Then
        XCTAssertEqual(viewModel.activeJobsCount, 2)
        XCTAssertEqual(viewModel.expiredJobsCount, 2)
        XCTAssertFalse(viewModel.isEmpty)
        XCTAssertFalse(viewModel.shouldShowEmptyState)
        XCTAssertEqual(viewModel.summaryText, "2 active, 2 expired")
    }
    
    func testSummaryText_AllActive() async throws {
        // Given
        let jobs = createMockJobs(count: 3)
        for job in jobs {
            job.applicationDeadline = Calendar.current.date(byAdding: .day, value: 10, to: Date())
        }
        viewModel.favoriteJobs = jobs
        
        // Then
        XCTAssertEqual(viewModel.summaryText, "3 favorite jobs")
    }
    
    func testSummaryText_Empty() async throws {
        // Given
        viewModel.favoriteJobs = []
        
        // Then
        XCTAssertEqual(viewModel.summaryText, "No favorite jobs")
    }
    
    // MARK: - Error Handling Tests
    
    func testClearError() async throws {
        // Given
        viewModel.errorMessage = "Test error"
        
        // When
        viewModel.clearError()
        
        // Then
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Helper Methods
    
    private func createMockJobs(count: Int) -> [Job] {
        var jobs: [Job] = []
        
        for i in 0..<count {
            let job = Job(
                context: testContext,
                jobId: "job-\(i)",
                title: "Test Job \(i)",
                department: "Test Department \(i)",
                location: "Test Location \(i)"
            )
            job.salaryMin = Int32(50000 + i * 10000)
            job.salaryMax = Int32(80000 + i * 10000)
            job.applicationDeadline = Calendar.current.date(byAdding: .day, value: 30, to: Date())
            job.datePosted = Calendar.current.date(byAdding: .day, value: -10, to: Date())
            job.isFavorited = true
            job.cachedAt = Date()
            
            jobs.append(job)
        }
        
        return jobs
    }
    
    private func createMockJobDescriptor(jobId: String) -> JobDescriptor {
        return JobDescriptor(
            positionId: jobId,
            positionTitle: "Updated Job Title",
            positionUri: "https://example.com",
            applicationCloseDate: "2025-12-31T23:59:59.000Z",
            positionStartDate: "2025-01-01T00:00:00.000Z",
            positionEndDate: "2025-12-31T23:59:59.000Z",
            publicationStartDate: "2024-11-01T00:00:00.000Z",
            applicationUri: "https://usajobs.gov/apply",
            positionLocationDisplay: "Washington, DC",
            positionLocation: [],
            organizationName: "Test Agency",
            departmentName: "Test Department",
            jobCategory: [],
            jobGrade: [],
            positionRemuneration: [PositionRemuneration(
                minimumRange: "60000",
                maximumRange: "90000",
                rateIntervalCode: "PA",
                description: "Per Year"
            )],
            positionSummary: "Updated job summary",
            positionFormattedDescription: [],
            userArea: nil,
            qualificationSummary: nil
        )
    }
}

// MARK: - Mock Services

class MockDataPersistenceService: DataPersistenceServiceProtocol {
    
    // Mock data
    var mockFavoriteJobs: [Job] = []
    var mockToggleFavoriteResult = false
    
    // Call tracking
    var getFavoriteJobsCalled = false
    var removeFavoriteJobCalled = false
    var toggleFavoriteStatusCalled = false
    var cacheJobCalled = false
    var lastRemovedJobId: String?
    
    // Error simulation
    var shouldThrowError = false
    var errorToThrow: Error = DataPersistenceError.invalidData
    var shouldDelay = false
    
    func getFavoriteJobs() async throws -> [Job] {
        getFavoriteJobsCalled = true
        
        if shouldDelay {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockFavoriteJobs
    }
    
    func removeFavoriteJob(jobId: String) async throws {
        removeFavoriteJobCalled = true
        lastRemovedJobId = jobId
        
        if shouldThrowError {
            throw errorToThrow
        }
    }
    
    func toggleFavoriteStatus(jobId: String) async throws -> Bool {
        toggleFavoriteStatusCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockToggleFavoriteResult
    }
    
    func cacheJob(_ job: Job) async throws {
        cacheJobCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
    }
    
    // Unused methods for this test
    func saveFavoriteJob(_ job: Job) async throws {}
    func saveSavedSearch(_ search: SavedSearch) async throws {}
    func getSavedSearches() async throws -> [SavedSearch] { return [] }
    func deleteSavedSearch(searchId: UUID) async throws {}
    func updateSavedSearch(_ search: SavedSearch) async throws {}
    func saveApplicationTracking(_ application: ApplicationTracking) async throws {}
    func getApplicationTrackings() async throws -> [ApplicationTracking] { return [] }
    func updateApplicationStatus(jobId: String, status: ApplicationTracking.Status) async throws {}
    func deleteApplicationTracking(jobId: String) async throws {}
    func getApplicationTracking(for jobId: String) async throws -> ApplicationTracking? { return nil }
    func getCachedJob(jobId: String) async throws -> Job? { return nil }
    func clearExpiredCache() async throws {}
}

class MockUSAJobsAPIService: USAJobsAPIServiceProtocol {
    
    // Mock data
    var mockJobDetails: JobDescriptor?
    
    // Call tracking
    var getJobDetailsCalled = false
    
    // Error simulation
    var shouldThrowError = false
    var errorToThrow: Error = APIError.noData
    var shouldDelay = false
    
    func getJobDetails(jobId: String) async throws -> JobDescriptor {
        getJobDetailsCalled = true
        
        if shouldDelay {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockJobDetails ?? JobDescriptor(
            positionId: jobId,
            positionTitle: "Mock Job",
            positionUri: "https://example.com",
            applicationCloseDate: "2025-12-31T23:59:59.000Z",
            positionStartDate: "2025-01-01T00:00:00.000Z",
            positionEndDate: "2025-12-31T23:59:59.000Z",
            publicationStartDate: "2024-11-01T00:00:00.000Z",
            applicationUri: "https://usajobs.gov/apply",
            positionLocationDisplay: "Washington, DC",
            positionLocation: [],
            organizationName: "Mock Agency",
            departmentName: "Mock Department",
            jobCategory: [],
            jobGrade: [],
            positionRemuneration: [],
            positionSummary: "Mock job summary",
            positionFormattedDescription: [],
            userArea: nil,
            qualificationSummary: nil
        )
    }
    
    // Unused methods for this test
    func searchJobs(criteria: SearchCriteria) async throws -> JobSearchResponse {
        return JobSearchResponse(searchResult: SearchResult(
            searchResultItems: [],
            searchResultCount: 0,
            searchResultCountAll: 0
        ))
    }
    
    func validateAPIConnection() async throws -> Bool {
        return true
    }
}