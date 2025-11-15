//
//  ViewModelErrorHandlingTests.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import XCTest
@testable import usajobs

@MainActor
class ViewModelErrorHandlingTests: XCTestCase {
    
    var mockAPIService: MockUSAJobsAPIService!
    var mockPersistenceService: MockDataPersistenceService!
    var mockOfflineManager: MockOfflineDataManager!
    var mockNetworkMonitor: MockNetworkMonitor!
    var loadingStateManager: LoadingStateManager!
    var errorHandler: DefaultErrorHandler!
    
    override func setUp() async throws {
        try await super.setUp()
        mockAPIService = MockUSAJobsAPIService()
        mockPersistenceService = MockDataPersistenceService()
        mockOfflineManager = MockOfflineDataManager()
        mockNetworkMonitor = MockNetworkMonitor()
        loadingStateManager = LoadingStateManager()
        errorHandler = DefaultErrorHandler()
    }
    
    override func tearDown() async throws {
        mockAPIService = nil
        mockPersistenceService = nil
        mockOfflineManager = nil
        mockNetworkMonitor = nil
        loadingStateManager = nil
        errorHandler = nil
        try await super.tearDown()
    }
    
    // MARK: - JobSearchViewModel Error Handling Tests
    
    func testJobSearchViewModelHandlesAPIError() async {
        let viewModel = JobSearchViewModel(
            apiService: mockAPIService,
            persistenceService: mockPersistenceService,
            offlineManager: mockOfflineManager,
            networkMonitor: mockNetworkMonitor,
            loadingStateManager: loadingStateManager,
            errorHandler: errorHandler
        )
        
        // Set up mock to return an error
        mockAPIService.shouldReturnError = true
        mockAPIService.errorToReturn = APIError.noInternetConnection
        
        // Set up search criteria
        viewModel.updateSearchCriteria(SearchCriteria(keyword: "engineer"))
        
        // Perform search
        await viewModel.performSearch()
        
        // Verify error handling
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("internet connection"))
        XCTAssertTrue(loadingStateManager.hasFailed(.searchJobs))
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testJobSearchViewModelHandlesValidationError() async {
        let viewModel = JobSearchViewModel(
            apiService: mockAPIService,
            persistenceService: mockPersistenceService,
            offlineManager: mockOfflineManager,
            networkMonitor: mockNetworkMonitor,
            loadingStateManager: loadingStateManager,
            errorHandler: errorHandler
        )
        
        // Don't set search criteria (should trigger validation error)
        await viewModel.performSearch()
        
        // Verify validation error handling
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("search criteria"))
        XCTAssertTrue(loadingStateManager.hasFailed(.searchJobs))
    }
    
    func testJobSearchViewModelRetryFunctionality() async {
        let viewModel = JobSearchViewModel(
            apiService: mockAPIService,
            persistenceService: mockPersistenceService,
            offlineManager: mockOfflineManager,
            networkMonitor: mockNetworkMonitor,
            loadingStateManager: loadingStateManager,
            errorHandler: errorHandler
        )
        
        // Set up mock to return error first, then success
        mockAPIService.shouldReturnError = true
        mockAPIService.errorToReturn = APIError.timeout
        
        viewModel.updateSearchCriteria(SearchCriteria(keyword: "engineer"))
        await viewModel.performSearch()
        
        // Verify error state
        XCTAssertTrue(loadingStateManager.hasFailed(.searchJobs))
        
        // Fix the mock and retry
        mockAPIService.shouldReturnError = false
        await viewModel.retryFailedOperation()
        
        // Verify success state
        XCTAssertFalse(loadingStateManager.hasFailed(.searchJobs))
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testJobSearchViewModelLoadMoreResultsErrorHandling() async {
        let viewModel = JobSearchViewModel(
            apiService: mockAPIService,
            persistenceService: mockPersistenceService,
            offlineManager: mockOfflineManager,
            networkMonitor: mockNetworkMonitor,
            loadingStateManager: loadingStateManager,
            errorHandler: errorHandler
        )
        
        // Set up initial successful search
        viewModel.updateSearchCriteria(SearchCriteria(keyword: "engineer"))
        await viewModel.performSearch()
        
        // Set up mock to return error for load more
        mockAPIService.shouldReturnError = true
        mockAPIService.errorToReturn = APIError.rateLimitExceeded
        
        // Simulate having more results
        viewModel.hasMoreResults = true
        
        await viewModel.loadMoreResults()
        
        // Verify error handling for load more
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("requests"))
        XCTAssertTrue(loadingStateManager.hasFailed(.loadMoreResults))
    }
    
    func testJobSearchViewModelToggleFavoriteErrorHandling() async {
        let viewModel = JobSearchViewModel(
            apiService: mockAPIService,
            persistenceService: mockPersistenceService,
            offlineManager: mockOfflineManager,
            networkMonitor: mockNetworkMonitor,
            loadingStateManager: loadingStateManager,
            errorHandler: errorHandler
        )
        
        // Set up mock to return error
        mockPersistenceService.shouldReturnError = true
        mockPersistenceService.errorToReturn = DataPersistenceError.saveFailed
        
        let mockJob = createMockJobSearchItem()
        await viewModel.toggleFavorite(for: mockJob)
        
        // Verify error handling
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(loadingStateManager.hasFailed(.toggleFavorite))
    }
    
    // MARK: - JobDetailViewModel Error Handling Tests
    
    func testJobDetailViewModelHandlesAPIError() async {
        let viewModel = JobDetailViewModel(
            apiService: mockAPIService,
            persistenceService: mockPersistenceService,
            offlineManager: mockOfflineManager,
            networkMonitor: mockNetworkMonitor,
            loadingStateManager: loadingStateManager,
            errorHandler: errorHandler
        )
        
        // Set up mock to return error
        mockAPIService.shouldReturnError = true
        mockAPIService.errorToReturn = APIError.noData
        mockNetworkMonitor.isConnected = true
        
        await viewModel.loadJobDetails(jobId: "test-job-id")
        
        // Verify error handling
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(loadingStateManager.hasFailed(.loadJobDetails))
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testJobDetailViewModelHandlesOfflineScenario() async {
        let viewModel = JobDetailViewModel(
            apiService: mockAPIService,
            persistenceService: mockPersistenceService,
            offlineManager: mockOfflineManager,
            networkMonitor: mockNetworkMonitor,
            loadingStateManager: loadingStateManager,
            errorHandler: errorHandler
        )
        
        // Set up offline scenario with no cached data
        mockNetworkMonitor.isConnected = false
        mockPersistenceService.shouldReturnNil = true
        
        await viewModel.loadJobDetails(jobId: "test-job-id")
        
        // Verify offline error handling
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("offline"))
    }
    
    func testJobDetailViewModelToggleFavoriteErrorHandling() async {
        let viewModel = JobDetailViewModel(
            apiService: mockAPIService,
            persistenceService: mockPersistenceService,
            offlineManager: mockOfflineManager,
            networkMonitor: mockNetworkMonitor,
            loadingStateManager: loadingStateManager,
            errorHandler: errorHandler
        )
        
        // Set up job detail
        viewModel.jobDetail = createMockJobDescriptor()
        
        // Set up mock to return error
        mockPersistenceService.shouldReturnError = true
        mockPersistenceService.errorToReturn = DataPersistenceError.saveFailed
        
        await viewModel.toggleFavorite()
        
        // Verify error handling
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(loadingStateManager.hasFailed(.toggleFavorite))
    }
    
    func testJobDetailViewModelMarkAsAppliedErrorHandling() async {
        let viewModel = JobDetailViewModel(
            apiService: mockAPIService,
            persistenceService: mockPersistenceService,
            offlineManager: mockOfflineManager,
            networkMonitor: mockNetworkMonitor,
            loadingStateManager: loadingStateManager,
            errorHandler: errorHandler
        )
        
        // Set up job detail
        viewModel.jobDetail = createMockJobDescriptor()
        
        // Set up mock to return error
        mockPersistenceService.shouldReturnError = true
        mockPersistenceService.errorToReturn = DataPersistenceError.saveFailed
        
        await viewModel.markAsApplied()
        
        // Verify error handling
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(loadingStateManager.hasFailed(.updateApplicationStatus))
    }
    
    // MARK: - FavoritesViewModel Error Handling Tests
    
    func testFavoritesViewModelLoadFavoritesErrorHandling() async {
        let viewModel = FavoritesViewModel(
            persistenceService: mockPersistenceService,
            apiService: mockAPIService,
            loadingStateManager: loadingStateManager,
            errorHandler: errorHandler
        )
        
        // Set up mock to return error
        mockPersistenceService.shouldReturnError = true
        mockPersistenceService.errorToReturn = DataPersistenceError.loadFailed
        
        await viewModel.loadFavorites()
        
        // Verify error handling
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(loadingStateManager.hasFailed(.loadFavorites))
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testFavoritesViewModelRemoveFavoriteErrorHandling() async {
        let viewModel = FavoritesViewModel(
            persistenceService: mockPersistenceService,
            apiService: mockAPIService,
            loadingStateManager: loadingStateManager,
            errorHandler: errorHandler
        )
        
        // Set up mock to return error
        mockPersistenceService.shouldReturnError = true
        mockPersistenceService.errorToReturn = DataPersistenceError.deleteFailed
        
        let mockJob = createMockJob()
        await viewModel.removeFavorite(job: mockJob)
        
        // Verify error handling
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(loadingStateManager.hasFailed(.toggleFavorite))
    }
    
    func testFavoritesViewModelRefreshStatusesErrorHandling() async {
        let viewModel = FavoritesViewModel(
            persistenceService: mockPersistenceService,
            apiService: mockAPIService,
            loadingStateManager: loadingStateManager,
            errorHandler: errorHandler
        )
        
        // Set up some favorite jobs
        viewModel.favoriteJobs = [createMockJob()]
        
        // Set up mock to return error
        mockAPIService.shouldReturnError = true
        mockAPIService.errorToReturn = APIError.serverError(500)
        
        await viewModel.refreshJobStatuses()
        
        // Verify error handling
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(loadingStateManager.hasFailed(.refreshJobStatuses))
    }
    
    // MARK: - Loading State Integration Tests
    
    func testViewModelLoadingStateIntegration() async {
        let viewModel = JobSearchViewModel(
            apiService: mockAPIService,
            persistenceService: mockPersistenceService,
            offlineManager: mockOfflineManager,
            networkMonitor: mockNetworkMonitor,
            loadingStateManager: loadingStateManager,
            errorHandler: errorHandler
        )
        
        // Verify initial state
        XCTAssertFalse(viewModel.isAnyOperationLoading)
        XCTAssertNil(viewModel.primaryLoadingMessage)
        
        // Start search
        viewModel.updateSearchCriteria(SearchCriteria(keyword: "engineer"))
        
        // Start search in background to test loading state
        let searchTask = Task {
            await viewModel.performSearch()
        }
        
        // Give it a moment to start
        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        // Verify loading state
        XCTAssertTrue(viewModel.isAnyOperationLoading)
        XCTAssertNotNil(viewModel.primaryLoadingMessage)
        XCTAssertEqual(viewModel.getLoadingState(.searchJobs), .loading(progress: nil))
        
        // Wait for completion
        await searchTask.value
        
        // Verify completion state
        XCTAssertFalse(viewModel.isAnyOperationLoading)
    }
    
    func testViewModelErrorClearingFunctionality() async {
        let viewModel = JobSearchViewModel(
            apiService: mockAPIService,
            persistenceService: mockPersistenceService,
            offlineManager: mockOfflineManager,
            networkMonitor: mockNetworkMonitor,
            loadingStateManager: loadingStateManager,
            errorHandler: errorHandler
        )
        
        // Set up error
        mockAPIService.shouldReturnError = true
        mockAPIService.errorToReturn = APIError.timeout
        
        viewModel.updateSearchCriteria(SearchCriteria(keyword: "engineer"))
        await viewModel.performSearch()
        
        // Verify error state
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(loadingStateManager.hasFailed(.searchJobs))
        
        // Clear errors
        viewModel.clearAllErrors()
        
        // Verify cleared state
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(loadingStateManager.hasFailed(.searchJobs))
    }
    
    // MARK: - Helper Methods
    
    private func createMockJobSearchItem() -> JobSearchItem {
        let descriptor = JobDescriptor(
            positionId: "test-job-id",
            positionTitle: "Test Job",
            departmentName: "Test Department",
            primaryLocation: "Test Location",
            salaryRange: SalaryRange(min: 50000, max: 80000),
            applicationDeadline: Date().addingTimeInterval(86400 * 30), // 30 days from now
            publicationDate: Date(),
            applicationUri: "https://test.com/apply",
            isRemoteEligible: false,
            majorDutiesText: "Test duties",
            keyRequirementsText: "Test requirements",
            gradeDisplay: "GS-12"
        )
        
        return JobSearchItem(
            matchedObjectId: "test-job-id",
            matchedObjectDescriptor: descriptor,
            relevanceRank: 1
        )
    }
    
    private func createMockJobDescriptor() -> JobDescriptor {
        return JobDescriptor(
            positionId: "test-job-id",
            positionTitle: "Test Job",
            departmentName: "Test Department",
            primaryLocation: "Test Location",
            salaryRange: SalaryRange(min: 50000, max: 80000),
            applicationDeadline: Date().addingTimeInterval(86400 * 30), // 30 days from now
            publicationDate: Date(),
            applicationUri: "https://test.com/apply",
            isRemoteEligible: false,
            majorDutiesText: "Test duties",
            keyRequirementsText: "Test requirements",
            gradeDisplay: "GS-12"
        )
    }
    
    private func createMockJob() -> Job {
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
        let job = Job(
            context: context,
            jobId: "test-job-id",
            title: "Test Job",
            department: "Test Department",
            location: "Test Location"
        )
        
        job.salaryMin = 50000
        job.salaryMax = 80000
        job.applicationDeadline = Date().addingTimeInterval(86400 * 30)
        job.datePosted = Date()
        job.isFavorited = true
        job.cachedAt = Date()
        
        return job
    }
}

// MARK: - Mock Services

class MockUSAJobsAPIService: USAJobsAPIServiceProtocol {
    var shouldReturnError = false
    var errorToReturn: APIError = .noInternetConnection
    
    func searchJobs(criteria: SearchCriteria) async throws -> JobSearchResponse {
        if shouldReturnError {
            throw errorToReturn
        }
        
        return JobSearchResponse(
            jobs: [],
            totalJobCount: 0,
            hasMoreResults: false
        )
    }
    
    func getJobDetails(jobId: String) async throws -> JobDescriptor {
        if shouldReturnError {
            throw errorToReturn
        }
        
        return JobDescriptor(
            positionId: jobId,
            positionTitle: "Test Job",
            departmentName: "Test Department",
            primaryLocation: "Test Location",
            salaryRange: SalaryRange(min: 50000, max: 80000),
            applicationDeadline: Date().addingTimeInterval(86400 * 30),
            publicationDate: Date(),
            applicationUri: "https://test.com/apply",
            isRemoteEligible: false,
            majorDutiesText: "Test duties",
            keyRequirementsText: "Test requirements",
            gradeDisplay: "GS-12"
        )
    }
    
    func validateAPIConnection() async throws -> Bool {
        if shouldReturnError {
            throw errorToReturn
        }
        return true
    }
}

class MockDataPersistenceService: DataPersistenceServiceProtocol {
    var shouldReturnError = false
    var shouldReturnNil = false
    var errorToReturn: DataPersistenceError = .saveFailed
    
    func getFavoriteJobs() async throws -> [Job] {
        if shouldReturnError {
            throw errorToReturn
        }
        return []
    }
    
    func saveFavoriteJob(_ job: Job) async throws {
        if shouldReturnError {
            throw errorToReturn
        }
    }
    
    func removeFavoriteJob(jobId: String) async throws {
        if shouldReturnError {
            throw errorToReturn
        }
    }
    
    func toggleFavoriteStatus(jobId: String) async throws -> Bool {
        if shouldReturnError {
            throw errorToReturn
        }
        return true
    }
    
    func getCachedJob(jobId: String) async throws -> Job? {
        if shouldReturnError {
            throw errorToReturn
        }
        if shouldReturnNil {
            return nil
        }
        
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
        return Job(
            context: context,
            jobId: jobId,
            title: "Cached Job",
            department: "Cached Department",
            location: "Cached Location"
        )
    }
    
    func cacheJob(_ job: Job) async throws {
        if shouldReturnError {
            throw errorToReturn
        }
    }
    
    func getApplicationTracking(for jobId: String) async throws -> ApplicationTracking? {
        if shouldReturnError {
            throw errorToReturn
        }
        return nil
    }
    
    func saveApplicationTracking(_ tracking: ApplicationTracking) async throws {
        if shouldReturnError {
            throw errorToReturn
        }
    }
    
    func updateApplicationStatus(jobId: String, status: ApplicationTracking.Status) async throws {
        if shouldReturnError {
            throw errorToReturn
        }
    }
}

class MockOfflineDataManager: OfflineDataManager {
    var shouldReturnError = false
    var errorToReturn: Error = DataPersistenceError.loadFailed
    
    override func getCachedJobs(limit: Int) async throws -> [Job] {
        if shouldReturnError {
            throw errorToReturn
        }
        return []
    }
    
    override func cacheJobForOffline(_ jobDescriptor: JobDescriptor) async throws {
        if shouldReturnError {
            throw errorToReturn
        }
    }
}

class MockNetworkMonitor: NetworkMonitor {
    override var isConnected: Bool {
        get { _isConnected }
        set { _isConnected = newValue }
    }
    
    private var _isConnected = true
}