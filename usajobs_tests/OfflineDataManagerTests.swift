//
//  OfflineDataManagerTests.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import XCTest
import CoreData
@testable import usajobs

@MainActor
final class OfflineDataManagerTests: XCTestCase {
    
    var offlineManager: OfflineDataManager!
    var mockNetworkMonitor: MockNetworkMonitor!
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
        mockNetworkMonitor = MockNetworkMonitor()
        mockPersistenceService = MockDataPersistenceService()
        mockAPIService = MockUSAJobsAPIService()
        
        // Create offline manager with mocks
        offlineManager = OfflineDataManager(
            networkMonitor: mockNetworkMonitor,
            persistenceService: mockPersistenceService,
            apiService: mockAPIService
        )
    }
    
    override func tearDown() async throws {
        offlineManager = nil
        mockNetworkMonitor = nil
        mockPersistenceService = nil
        mockAPIService = nil
        testContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Offline Mode Detection Tests
    
    func testOfflineModeDetection() async throws {
        // Initially online
        mockNetworkMonitor.isConnected = true
        XCTAssertFalse(offlineManager.isOfflineMode)
        
        // Go offline
        mockNetworkMonitor.isConnected = false
        mockNetworkMonitor.triggerConnectionChange()
        
        // Wait for async update
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertTrue(offlineManager.isOfflineMode)
    }
    
    func testAutoSyncWhenConnectionRestored() async throws {
        // Start offline with pending changes
        mockNetworkMonitor.isConnected = false
        offlineManager.markPendingChanges()
        XCTAssertTrue(offlineManager.hasPendingChanges)
        
        // Go online
        mockNetworkMonitor.isConnected = true
        mockNetworkMonitor.triggerConnectionChange()
        
        // Wait for auto-sync
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        XCTAssertTrue(mockPersistenceService.clearExpiredCacheCalled)
    }
    
    // MARK: - Cache Management Tests
    
    func testCacheJobForOffline() async throws {
        let jobDetails = createTestJobDescriptor()
        
        try await offlineManager.cacheJobForOffline(jobDetails)
        
        XCTAssertTrue(mockPersistenceService.cacheJobDetailsCalled)
        XCTAssertEqual(mockPersistenceService.lastCachedJobDetails?.positionId, jobDetails.positionId)
    }
    
    func testGetCachedJobs() async throws {
        let testJobs = createTestJobs()
        mockPersistenceService.cachedJobs = testJobs
        
        let cachedJobs = try await offlineManager.getCachedJobs(limit: 10)
        
        XCTAssertEqual(cachedJobs.count, testJobs.count)
        XCTAssertTrue(mockPersistenceService.getCachedJobsCalled)
    }
    
    func testClearCache() async throws {
        try await offlineManager.clearCache()
        
        XCTAssertTrue(mockPersistenceService.clearAllCacheCalled)
    }
    
    // MARK: - Data Synchronization Tests
    
    func testSyncDataWhenOnline() async throws {
        mockNetworkMonitor.isConnected = true
        
        // Add some favorite jobs to sync
        let favoriteJobs = createTestJobs()
        mockPersistenceService.favoriteJobs = favoriteJobs
        
        await offlineManager.syncData()
        
        XCTAssertTrue(mockPersistenceService.getFavoriteJobsCalled)
        XCTAssertTrue(mockAPIService.getJobDetailsCalled)
        XCTAssertTrue(mockPersistenceService.clearExpiredCacheCalled)
        XCTAssertFalse(offlineManager.hasPendingChanges)
        XCTAssertNotNil(offlineManager.lastSyncDate)
    }
    
    func testSyncDataWhenOffline() async throws {
        mockNetworkMonitor.isConnected = false
        
        await offlineManager.syncData()
        
        // Should not attempt sync when offline
        XCTAssertFalse(mockPersistenceService.getFavoriteJobsCalled)
        XCTAssertFalse(mockAPIService.getJobDetailsCalled)
    }
    
    func testSyncDataAlreadyInProgress() async throws {
        mockNetworkMonitor.isConnected = true
        
        // Start first sync
        let syncTask1 = Task {
            await offlineManager.syncData()
        }
        
        // Try to start second sync immediately
        let syncTask2 = Task {
            await offlineManager.syncData()
        }
        
        await syncTask1.value
        await syncTask2.value
        
        // Should only sync once
        XCTAssertEqual(mockPersistenceService.getFavoriteJobsCallCount, 1)
    }
    
    // MARK: - Cache Statistics Tests
    
    func testGetCacheStatistics() async throws {
        // Set up test data
        mockPersistenceService.cacheSize = 25
        mockPersistenceService.favoriteJobs = createTestJobs(count: 5)
        mockPersistenceService.cachedJobs = createTestJobs(count: 25)
        
        let stats = try await offlineManager.getCacheStatistics()
        
        XCTAssertEqual(stats.totalCachedJobs, 25)
        XCTAssertEqual(stats.favoritedJobs, 5)
        XCTAssertEqual(stats.nonFavoritedJobs, 20)
    }
    
    // MARK: - Feature Availability Tests
    
    func testOfflineFeatureAvailability() {
        // Test features that should be available offline
        XCTAssertTrue(offlineManager.isFeatureAvailableOffline(.viewFavorites))
        XCTAssertTrue(offlineManager.isFeatureAvailableOffline(.viewApplicationTracking))
        XCTAssertTrue(offlineManager.isFeatureAvailableOffline(.viewSavedSearches))
        
        // Test features that require network
        XCTAssertFalse(offlineManager.isFeatureAvailableOffline(.searchJobs))
        XCTAssertFalse(offlineManager.isFeatureAvailableOffline(.applyToJobs))
        
        // Test cached jobs availability (depends on cache count)
        offlineManager.cachedJobsCount = 0
        XCTAssertFalse(offlineManager.isFeatureAvailableOffline(.viewCachedJobs))
        
        offlineManager.cachedJobsCount = 10
        XCTAssertTrue(offlineManager.isFeatureAvailableOffline(.viewCachedJobs))
    }
    
    // MARK: - Helper Methods
    
    private func createTestJobDescriptor() -> JobDescriptor {
        return JobDescriptor(
            positionId: "test-job-123",
            positionTitle: "Test Software Developer",
            departmentName: "Department of Test",
            primaryLocation: "Washington, DC",
            salaryRange: SalaryRange(min: 80000, max: 120000),
            applicationDeadline: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            publicationDate: Date(),
            applicationUri: "https://www.usajobs.gov/job/test-job-123",
            isRemoteEligible: true,
            majorDutiesText: "Test duties",
            keyRequirementsText: "Test requirements",
            gradeDisplay: "GS-13"
        )
    }
    
    private func createTestJobs(count: Int = 3) -> [Job] {
        var jobs: [Job] = []
        
        for i in 0..<count {
            let job = Job(
                context: testContext,
                jobId: "test-job-\(i)",
                title: "Test Job \(i)",
                department: "Test Department",
                location: "Test Location"
            )
            job.salaryMin = 50000
            job.salaryMax = 100000
            job.isFavorited = i < 2 // First 2 are favorites
            job.cachedAt = Date()
            jobs.append(job)
        }
        
        return jobs
    }
}

// MARK: - Mock Classes

class MockNetworkMonitor: NetworkMonitor {
    override var isConnected: Bool {
        get { _isConnected }
        set { 
            _isConnected = newValue
            objectWillChange.send()
        }
    }
    
    private var _isConnected = true
    
    func triggerConnectionChange() {
        objectWillChange.send()
    }
}

class MockDataPersistenceService: DataPersistenceServiceProtocol {
    var favoriteJobs: [Job] = []
    var cachedJobs: [Job] = []
    var cacheSize: Int = 0
    var lastCachedJobDetails: JobDescriptor?
    
    // Call tracking
    var getFavoriteJobsCalled = false
    var getFavoriteJobsCallCount = 0
    var getCachedJobsCalled = false
    var cacheJobDetailsCalled = false
    var clearExpiredCacheCalled = false
    var clearAllCacheCalled = false
    
    func saveFavoriteJob(_ job: Job) async throws {}
    func removeFavoriteJob(jobId: String) async throws {}
    
    func getFavoriteJobs() async throws -> [Job] {
        getFavoriteJobsCalled = true
        getFavoriteJobsCallCount += 1
        return favoriteJobs
    }
    
    func toggleFavoriteStatus(jobId: String) async throws -> Bool { return false }
    func saveSavedSearch(_ search: SavedSearch) async throws {}
    func getSavedSearches() async throws -> [SavedSearch] { return [] }
    func deleteSavedSearch(searchId: UUID) async throws {}
    func updateSavedSearch(_ search: SavedSearch) async throws {}
    func saveApplicationTracking(_ application: ApplicationTracking) async throws {}
    func getApplicationTrackings() async throws -> [ApplicationTracking] { return [] }
    func updateApplicationStatus(jobId: String, status: ApplicationTracking.Status) async throws {}
    func deleteApplicationTracking(jobId: String) async throws {}
    func getApplicationTracking(for jobId: String) async throws -> ApplicationTracking? { return nil }
    func cacheJob(_ job: Job) async throws {}
    func getCachedJob(jobId: String) async throws -> Job? { return nil }
    
    func clearExpiredCache() async throws {
        clearExpiredCacheCalled = true
    }
    
    func getCachedJobs(limit: Int?) async throws -> [Job] {
        getCachedJobsCalled = true
        return cachedJobs
    }
    
    func cacheJobDetails(_ jobDetails: JobDescriptor) async throws -> Job {
        cacheJobDetailsCalled = true
        lastCachedJobDetails = jobDetails
        return Job(context: CoreDataStack.shared.context, jobId: jobDetails.positionId, title: jobDetails.positionTitle, department: jobDetails.departmentName, location: jobDetails.primaryLocation)
    }
    
    func getCacheSize() async throws -> Int {
        return cacheSize
    }
    
    func clearAllCache() async throws {
        clearAllCacheCalled = true
    }
}

class MockUSAJobsAPIService: USAJobsAPIServiceProtocol {
    var getJobDetailsCalled = false
    
    func searchJobs(criteria: SearchCriteria) async throws -> JobSearchResponse {
        return JobSearchResponse(searchResult: SearchResult(searchResultItems: [], searchResultCount: 0, searchResultCountAll: 0))
    }
    
    func getJobDetails(jobId: String) async throws -> JobDescriptor {
        getJobDetailsCalled = true
        return JobDescriptor(
            positionId: jobId,
            positionTitle: "Test Job",
            departmentName: "Test Department",
            primaryLocation: "Test Location",
            salaryRange: SalaryRange(min: 50000, max: 100000),
            applicationDeadline: nil,
            publicationDate: Date(),
            applicationUri: "https://test.com",
            isRemoteEligible: false,
            majorDutiesText: nil,
            keyRequirementsText: nil,
            gradeDisplay: nil
        )
    }
    
    func validateAPIConnection() async throws -> Bool { return true }
}