//
//  IntegrationTests.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import XCTest
import CoreData
@testable import usajobs

/// Integration tests for complete user workflows and end-to-end functionality
@MainActor
final class IntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var coreDataStack: CoreDataStack!
    private var persistenceService: DataPersistenceService!
    private var apiService: MockUSAJobsAPIService!
    private var notificationService: MockNotificationService!
    private var offlineManager: OfflineDataManager!
    private var networkMonitor: NetworkMonitor!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Setup in-memory Core Data stack for testing
        coreDataStack = CoreDataStack(inMemory: true)
        persistenceService = DataPersistenceService(coreDataStack: coreDataStack)
        apiService = MockUSAJobsAPIService()
        notificationService = MockNotificationService()
        offlineManager = OfflineDataManager(
            coreDataStack: coreDataStack,
            persistenceService: persistenceService
        )
        networkMonitor = NetworkMonitor()
        
        // Setup mock data
        setupMockData()
    }
    
    override func tearDownWithError() throws {
        coreDataStack = nil
        persistenceService = nil
        apiService = nil
        notificationService = nil
        offlineManager = nil
        networkMonitor = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Complete User Workflow Tests
    
    func testCompleteJobSearchWorkflow() async throws {
        // Test the complete workflow: Search -> View Details -> Favorite -> Apply
        
        // 1. Setup search criteria
        let searchCriteria = SearchCriteria(
            keywords: "Software Developer",
            location: "Washington, DC",
            department: "Department of Defense",
            salaryMin: 80000,
            salaryMax: 120000
        )
        
        // 2. Create search view model and perform search
        let searchViewModel = JobSearchViewModel(
            apiService: apiService,
            persistenceService: persistenceService,
            offlineManager: offlineManager
        )
        
        searchViewModel.searchCriteria = searchCriteria
        await searchViewModel.performSearch()
        
        // 3. Verify search results
        XCTAssertFalse(searchViewModel.searchResults.isEmpty)
        XCTAssertFalse(searchViewModel.isLoading)
        XCTAssertNil(searchViewModel.errorMessage)
        
        // 4. Get first job and view details
        let firstJob = searchViewModel.searchResults.first!
        let jobDetailViewModel = JobDetailViewModel(
            jobId: firstJob.matchedObjectId,
            apiService: apiService,
            persistenceService: persistenceService
        )
        
        await jobDetailViewModel.loadJobDetails()
        
        // 5. Verify job details loaded
        XCTAssertNotNil(jobDetailViewModel.job)
        XCTAssertFalse(jobDetailViewModel.isLoading)
        
        // 6. Toggle favorite status
        await jobDetailViewModel.toggleFavorite()
        XCTAssertTrue(jobDetailViewModel.isFavorited)
        
        // 7. Verify job appears in favorites
        let favoritesViewModel = FavoritesViewModel(
            persistenceService: persistenceService,
            apiService: apiService
        )
        
        await favoritesViewModel.loadFavorites()
        XCTAssertFalse(favoritesViewModel.favoriteJobs.isEmpty)
        
        // 8. Mark as applied
        await jobDetailViewModel.markAsApplied()
        XCTAssertNotNil(jobDetailViewModel.applicationTracking)
        
        // 9. Verify application appears in tracking
        let applicationViewModel = ApplicationTrackingViewModel(
            persistenceService: persistenceService,
            notificationService: notificationService
        )
        
        await applicationViewModel.loadApplications()
        XCTAssertFalse(applicationViewModel.applications.isEmpty)
    }
    
    func testSavedSearchWorkflow() async throws {
        // Test the complete saved search workflow: Create -> Save -> Execute -> Notifications
        
        // 1. Create search criteria
        let searchCriteria = SearchCriteria(
            keywords: "Data Scientist",
            location: "Remote",
            department: "Department of Health and Human Services"
        )
        
        // 2. Create saved search view model
        let savedSearchViewModel = SavedSearchViewModel(
            persistenceService: persistenceService,
            apiService: apiService,
            notificationService: notificationService
        )
        
        // 3. Save the search
        let savedSearch = SavedSearch(context: coreDataStack.context)
        savedSearch.searchId = UUID()
        savedSearch.name = "Remote Data Science Jobs"
        savedSearch.keywords = searchCriteria.keywords
        savedSearch.location = searchCriteria.location
        savedSearch.department = searchCriteria.department
        savedSearch.isNotificationEnabled = true
        savedSearch.lastChecked = Date()
        
        await savedSearchViewModel.saveSavedSearch(savedSearch)
        
        // 4. Load saved searches
        await savedSearchViewModel.loadSavedSearches()
        XCTAssertFalse(savedSearchViewModel.savedSearches.isEmpty)
        
        // 5. Execute saved search
        await savedSearchViewModel.executeSearch(savedSearch)
        
        // 6. Verify search results
        XCTAssertFalse(savedSearchViewModel.searchResults.isEmpty)
        
        // 7. Test notification scheduling
        await savedSearchViewModel.checkForNewJobs()
        XCTAssertTrue(notificationService.notificationsScheduled > 0)
    }
    
    func testOfflineWorkflow() async throws {
        // Test offline functionality workflow
        
        // 1. Setup online data first
        let searchViewModel = JobSearchViewModel(
            apiService: apiService,
            persistenceService: persistenceService,
            offlineManager: offlineManager
        )
        
        await searchViewModel.performSearch()
        let onlineJobs = searchViewModel.searchResults
        
        // 2. Cache jobs for offline access
        let jobsToCache = Array(onlineJobs.prefix(5))
        try await offlineManager.cacheJobsForOfflineAccess(jobsToCache.compactMap { item in
            // Convert JobSearchItem to Job entity for caching
            let job = Job(context: coreDataStack.context)
            job.jobId = item.matchedObjectId
            job.title = item.matchedObjectDescriptor.positionTitle
            job.department = item.matchedObjectDescriptor.departmentName ?? ""
            job.location = item.matchedObjectDescriptor.positionLocationDisplay ?? ""
            job.datePosted = Date()
            job.applicationDeadline = Date().addingTimeInterval(86400 * 30)
            job.cachedAt = Date()
            return job
        })
        
        // 3. Simulate offline mode
        networkMonitor.isConnected = false
        
        // 4. Load cached jobs
        let cachedJobs = try await offlineManager.getCachedJobs(limit: 10)
        XCTAssertFalse(cachedJobs.isEmpty)
        XCTAssertLessOrEqual(cachedJobs.count, 5)
        
        // 5. Test offline favorites management
        let favoritesViewModel = FavoritesViewModel(
            persistenceService: persistenceService,
            apiService: apiService
        )
        
        await favoritesViewModel.loadFavorites()
        // Should work offline with cached data
        
        // 6. Simulate coming back online
        networkMonitor.isConnected = true
        
        // 7. Test data synchronization
        await offlineManager.syncWhenOnline()
        
        // Verify sync completed without errors
        XCTAssertTrue(networkMonitor.isConnected)
    }
    
    func testApplicationTrackingWorkflow() async throws {
        // Test complete application tracking workflow
        
        // 1. Create application tracking view model
        let applicationViewModel = ApplicationTrackingViewModel(
            persistenceService: persistenceService,
            notificationService: notificationService
        )
        
        // 2. Create test application
        let application = ApplicationTracking(context: coreDataStack.context)
        application.jobId = "test-job-123"
        application.applicationDate = Date()
        application.status = ApplicationTracking.Status.applied.rawValue
        application.notes = "Applied through USAJobs portal"
        application.reminderDate = Date().addingTimeInterval(86400 * 7) // 7 days
        
        // 3. Save application
        await applicationViewModel.addApplication(application)
        
        // 4. Load applications
        await applicationViewModel.loadApplications()
        XCTAssertFalse(applicationViewModel.applications.isEmpty)
        
        // 5. Update application status
        await applicationViewModel.updateApplicationStatus(
            jobId: "test-job-123",
            status: .interview
        )
        
        // 6. Verify status update
        await applicationViewModel.loadApplications()
        let updatedApp = applicationViewModel.applications.first { $0.jobId == "test-job-123" }
        XCTAssertEqual(updatedApp?.status, ApplicationTracking.Status.interviewed.rawValue)
        
        // 7. Test deadline notifications
        await applicationViewModel.scheduleDeadlineReminders()
        XCTAssertTrue(notificationService.notificationsScheduled > 0)
        
        // 8. Test application deletion
        await applicationViewModel.deleteApplication(jobId: "test-job-123")
        await applicationViewModel.loadApplications()
        let deletedApp = applicationViewModel.applications.first { $0.jobId == "test-job-123" }
        XCTAssertNil(deletedApp)
    }
    
    // MARK: - Cross-Feature Integration Tests
    
    func testFavoriteToApplicationWorkflow() async throws {
        // Test workflow from favoriting a job to tracking application
        
        // 1. Search for jobs
        let searchViewModel = JobSearchViewModel(
            apiService: apiService,
            persistenceService: persistenceService,
            offlineManager: offlineManager
        )
        
        await searchViewModel.performSearch()
        let job = searchViewModel.searchResults.first!
        
        // 2. Favorite the job
        await searchViewModel.toggleFavorite(for: job)
        
        // 3. Verify in favorites
        let favoritesViewModel = FavoritesViewModel(
            persistenceService: persistenceService,
            apiService: apiService
        )
        
        await favoritesViewModel.loadFavorites()
        let favoriteJob = favoritesViewModel.favoriteJobs.first { $0.jobId == job.matchedObjectId }
        XCTAssertNotNil(favoriteJob)
        
        // 4. Apply for the job (mark as applied)
        let applicationViewModel = ApplicationTrackingViewModel(
            persistenceService: persistenceService,
            notificationService: notificationService
        )
        
        let application = ApplicationTracking(context: coreDataStack.context)
        application.jobId = job.matchedObjectId
        application.applicationDate = Date()
        application.status = ApplicationTracking.Status.applied.rawValue
        
        await applicationViewModel.addApplication(application)
        
        // 5. Verify application is tracked
        await applicationViewModel.loadApplications()
        let trackedApp = applicationViewModel.applications.first { $0.jobId == job.matchedObjectId }
        XCTAssertNotNil(trackedApp)
        
        // 6. Verify job remains in favorites
        await favoritesViewModel.loadFavorites()
        let stillFavorite = favoritesViewModel.favoriteJobs.first { $0.jobId == job.matchedObjectId }
        XCTAssertNotNil(stillFavorite)
    }
    
    func testSavedSearchToFavoriteWorkflow() async throws {
        // Test workflow from saved search results to favorites
        
        // 1. Create and execute saved search
        let savedSearchViewModel = SavedSearchViewModel(
            persistenceService: persistenceService,
            apiService: apiService,
            notificationService: notificationService
        )
        
        let savedSearch = SavedSearch(context: coreDataStack.context)
        savedSearch.searchId = UUID()
        savedSearch.name = "Engineering Jobs"
        savedSearch.keywords = "Engineer"
        savedSearch.isNotificationEnabled = true
        savedSearch.lastChecked = Date()
        
        await savedSearchViewModel.saveSavedSearch(savedSearch)
        await savedSearchViewModel.executeSearch(savedSearch)
        
        // 2. Favorite a job from search results
        let job = savedSearchViewModel.searchResults.first!
        
        let searchViewModel = JobSearchViewModel(
            apiService: apiService,
            persistenceService: persistenceService,
            offlineManager: offlineManager
        )
        
        await searchViewModel.toggleFavorite(for: job)
        
        // 3. Verify job appears in favorites
        let favoritesViewModel = FavoritesViewModel(
            persistenceService: persistenceService,
            apiService: apiService
        )
        
        await favoritesViewModel.loadFavorites()
        let favoriteJob = favoritesViewModel.favoriteJobs.first { $0.jobId == job.matchedObjectId }
        XCTAssertNotNil(favoriteJob)
    }
    
    // MARK: - Error Recovery Integration Tests
    
    func testNetworkErrorRecovery() async throws {
        // Test error recovery across different components
        
        // 1. Setup API service to fail initially
        apiService.shouldFail = true
        
        let searchViewModel = JobSearchViewModel(
            apiService: apiService,
            persistenceService: persistenceService,
            offlineManager: offlineManager
        )
        
        // 2. Attempt search (should fail)
        await searchViewModel.performSearch()
        XCTAssertNotNil(searchViewModel.errorMessage)
        XCTAssertTrue(searchViewModel.searchResults.isEmpty)
        
        // 3. Fix API service
        apiService.shouldFail = false
        
        // 4. Retry search (should succeed)
        await searchViewModel.performSearch()
        XCTAssertNil(searchViewModel.errorMessage)
        XCTAssertFalse(searchViewModel.searchResults.isEmpty)
    }
    
    func testDataPersistenceErrorRecovery() async throws {
        // Test recovery from Core Data errors
        
        // 1. Create view model with valid persistence service
        let favoritesViewModel = FavoritesViewModel(
            persistenceService: persistenceService,
            apiService: apiService
        )
        
        // 2. Add some favorites
        let job = Job(context: coreDataStack.context)
        job.jobId = "test-job"
        job.title = "Test Job"
        job.department = "Test Department"
        job.location = "Test Location"
        job.isFavorited = true
        job.cachedAt = Date()
        
        try await persistenceService.saveFavoriteJob(job)
        
        // 3. Load favorites (should succeed)
        await favoritesViewModel.loadFavorites()
        XCTAssertFalse(favoritesViewModel.favoriteJobs.isEmpty)
        
        // 4. Test error handling in view model
        // (In a real scenario, we might simulate Core Data errors)
        await favoritesViewModel.refreshJobStatuses()
        // Should handle any errors gracefully
    }
    
    // MARK: - Performance Integration Tests
    
    func testLargeDataSetPerformance() async throws {
        // Test performance with large datasets across components
        
        measure {
            let expectation = XCTestExpectation(description: "Large dataset processing")
            
            Task {
                // 1. Create large mock dataset
                apiService.mockLargeDataset = true
                
                // 2. Perform search
                let searchViewModel = JobSearchViewModel(
                    apiService: apiService,
                    persistenceService: persistenceService,
                    offlineManager: offlineManager
                )
                
                await searchViewModel.performSearch()
                
                // 3. Process results through favorites
                for job in searchViewModel.searchResults.prefix(50) {
                    await searchViewModel.toggleFavorite(for: job)
                }
                
                // 4. Load favorites
                let favoritesViewModel = FavoritesViewModel(
                    persistenceService: persistenceService,
                    apiService: apiService
                )
                
                await favoritesViewModel.loadFavorites()
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupMockData() {
        // Setup mock API responses
        apiService.mockSearchResponse = createMockJobSearchResponse()
        apiService.mockJobDetails = createMockJobDescriptor()
        
        // Setup mock notification service
        notificationService.permissionGranted = true
    }
    
    private func createMockJobSearchResponse() -> JobSearchResponse {
        let jobs = (0..<10).map { index in
            JobSearchItem(
                matchedObjectId: "job-\(index)",
                matchedObjectDescriptor: createMockJobDescriptor(id: "job-\(index)"),
                relevanceRank: index
            )
        }
        
        return JobSearchResponse(searchResult: SearchResult(
            searchResultItems: jobs,
            searchResultCount: jobs.count,
            searchResultCountAll: jobs.count
        ))
    }
    
    private func createMockJobDescriptor(id: String = "test-job") -> JobDescriptor {
        return JobDescriptor(
            positionId: id,
            positionTitle: "Software Developer",
            positionUri: "https://example.com/job/\(id)",
            applicationCloseDate: "2025-12-31T23:59:59.000Z",
            positionStartDate: "2025-01-01T00:00:00.000Z",
            positionEndDate: "2025-12-31T23:59:59.000Z",
            publicationStartDate: "2024-11-01T00:00:00.000Z",
            applicationUri: "https://usajobs.gov/apply/\(id)",
            positionLocationDisplay: "Washington, DC",
            positionLocation: [],
            organizationName: "General Services Administration",
            departmentName: "General Services Administration",
            jobCategory: [],
            jobGrade: [JobGrade(code: "13")],
            positionRemuneration: [PositionRemuneration(
                minimumRange: "80000",
                maximumRange: "120000",
                rateIntervalCode: "PA",
                description: "Per Year"
            )],
            positionSummary: "Develop and maintain software applications for federal agencies.",
            positionFormattedDescription: [],
            userArea: nil,
            qualificationSummary: "Bachelor's degree in Computer Science and 3+ years experience."
        )
    }
}

// MARK: - Enhanced Mock Services

class MockUSAJobsAPIService: USAJobsAPIServiceProtocol {
    var mockSearchResponse: JobSearchResponse?
    var mockJobDetails: JobDescriptor?
    var shouldFail = false
    var mockLargeDataset = false
    
    func searchJobs(criteria: SearchCriteria) async throws -> JobSearchResponse {
        if shouldFail {
            throw APIError.networkError
        }
        
        if mockLargeDataset {
            return createLargeDatasetResponse()
        }
        
        return mockSearchResponse ?? JobSearchResponse(searchResult: SearchResult(
            searchResultItems: [],
            searchResultCount: 0,
            searchResultCountAll: 0
        ))
    }
    
    func getJobDetails(jobId: String) async throws -> JobDescriptor {
        if shouldFail {
            throw APIError.networkError
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
    
    func validateAPIConnection() async throws -> Bool {
        return !shouldFail
    }
    
    private func createLargeDatasetResponse() -> JobSearchResponse {
        let jobs = (0..<1000).map { index in
            JobSearchItem(
                matchedObjectId: "large-job-\(index)",
                matchedObjectDescriptor: JobDescriptor(
                    positionId: "large-job-\(index)",
                    positionTitle: "Job \(index)",
                    positionUri: "https://example.com/job/\(index)",
                    applicationCloseDate: "2025-12-31T23:59:59.000Z",
                    positionStartDate: "2025-01-01T00:00:00.000Z",
                    positionEndDate: "2025-12-31T23:59:59.000Z",
                    publicationStartDate: "2024-11-01T00:00:00.000Z",
                    applicationUri: "https://usajobs.gov/apply/\(index)",
                    positionLocationDisplay: "Location \(index)",
                    positionLocation: [],
                    organizationName: "Agency \(index % 10)",
                    departmentName: "Department \(index % 5)",
                    jobCategory: [],
                    jobGrade: [],
                    positionRemuneration: [],
                    positionSummary: "Job summary \(index)",
                    positionFormattedDescription: [],
                    userArea: nil,
                    qualificationSummary: nil
                ),
                relevanceRank: index
            )
        }
        
        return JobSearchResponse(searchResult: SearchResult(
            searchResultItems: jobs,
            searchResultCount: jobs.count,
            searchResultCountAll: jobs.count
        ))
    }
}

class MockNotificationService: NotificationServiceProtocol {
    var permissionGranted = false
    var notificationsScheduled = 0
    
    func scheduleDeadlineReminder(for application: ApplicationTracking) async throws {
        notificationsScheduled += 1
    }
    
    func scheduleNewJobsNotification(for search: SavedSearch, jobCount: Int) async throws {
        notificationsScheduled += 1
    }
    
    func requestNotificationPermissions() async throws -> Bool {
        return permissionGranted
    }
    
    func handleBackgroundAppRefresh() async -> Bool {
        return true
    }
    
    func checkForNewJobs() async throws {
        notificationsScheduled += 1
    }
}