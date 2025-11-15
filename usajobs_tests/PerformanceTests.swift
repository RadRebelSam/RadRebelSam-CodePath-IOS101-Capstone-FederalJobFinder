//
//  PerformanceTests.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import XCTest
import CoreData
@testable import usajobs

/// Performance tests for critical app operations
class PerformanceTests: XCTestCase {
    
    var coreDataStack: CoreDataStack!
    var persistenceService: DataPersistenceService!
    var imageCache: ImageCacheService!
    var memoryManager: MemoryManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Setup in-memory Core Data stack for testing
        coreDataStack = CoreDataStack(inMemory: true)
        persistenceService = DataPersistenceService(coreDataStack: coreDataStack)
        imageCache = ImageCacheService.shared
        memoryManager = MemoryManager.shared
        
        // Clear any existing cache
        imageCache.clearCache()
        memoryManager.clearCache()
    }
    
    override func tearDownWithError() throws {
        imageCache.clearCache()
        memoryManager.clearCache()
        coreDataStack = nil
        persistenceService = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Core Data Performance Tests
    
    func testCoreDataBulkInsertPerformance() throws {
        let jobs = createTestJobs(count: 1000)
        
        measure {
            let expectation = XCTestExpectation(description: "Bulk insert jobs")
            
            Task {
                do {
                    for job in jobs {
                        try await persistenceService.cacheJob(job)
                    }
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to insert jobs: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testCoreDataQueryPerformance() throws {
        // First, insert test data
        let jobs = createTestJobs(count: 1000)
        let insertExpectation = XCTestExpectation(description: "Insert test jobs")
        
        Task {
            for job in jobs {
                try await persistenceService.cacheJob(job)
            }
            insertExpectation.fulfill()
        }
        
        wait(for: [insertExpectation], timeout: 10.0)
        
        // Now measure query performance
        measure {
            let expectation = XCTestExpectation(description: "Query favorite jobs")
            
            Task {
                do {
                    _ = try await persistenceService.getFavoriteJobs()
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to query jobs: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testCoreDataFilteredQueryPerformance() throws {
        // Insert test data with various departments
        let departments = ["Department of Defense", "Department of Health", "Department of Education", "Department of Agriculture", "Department of Commerce"]
        var jobs: [Job] = []
        
        for i in 0..<1000 {
            let job = createTestJob(
                id: "job-\(i)",
                title: "Test Job \(i)",
                department: departments[i % departments.count]
            )
            jobs.append(job)
        }
        
        let insertExpectation = XCTestExpectation(description: "Insert test jobs")
        Task {
            for job in jobs {
                try await persistenceService.cacheJob(job)
            }
            insertExpectation.fulfill()
        }
        wait(for: [insertExpectation], timeout: 10.0)
        
        // Measure filtered query performance
        measure {
            let context = coreDataStack.context
            let request: NSFetchRequest<Job> = Job.fetchRequest()
            request.predicate = NSPredicate(format: "department == %@", "Department of Defense")
            request.sortDescriptors = [NSSortDescriptor(key: "datePosted", ascending: false)]
            
            do {
                _ = try context.fetch(request)
            } catch {
                XCTFail("Failed to perform filtered query: \(error)")
            }
        }
    }
    
    // MARK: - Image Cache Performance Tests
    
    func testImageCacheMemoryPerformance() throws {
        let testImages = createTestImages(count: 50)
        let testURLs = testImages.map { URL(string: "https://example.com/image\($0.hashValue).jpg")! }
        
        measure {
            for (index, url) in testURLs.enumerated() {
                let image = testImages[index]
                let cacheKey = url.absoluteString
                imageCache.memoryCache.setObject(image, forKey: cacheKey as NSString)
            }
            
            // Retrieve all images
            for url in testURLs {
                let cacheKey = url.absoluteString
                _ = imageCache.memoryCache.object(forKey: cacheKey as NSString)
            }
        }
    }
    
    func testImageCacheDiskPerformance() throws {
        let testImages = createTestImages(count: 20)
        
        measure {
            let expectation = XCTestExpectation(description: "Cache images to disk")
            
            Task {
                for (index, image) in testImages.enumerated() {
                    let url = URL(string: "https://example.com/test\(index).jpg")!
                    _ = await imageCache.loadImage(from: url)
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 15.0)
        }
    }
    
    // MARK: - Memory Management Performance Tests
    
    func testMemoryManagerBatchProcessing() throws {
        let largeDataSet = Array(0..<10000)
        
        measure {
            let expectation = XCTestExpectation(description: "Process large dataset in batches")
            
            Task {
                do {
                    let results = try await memoryManager.processBatch(
                        items: largeDataSet,
                        batchSize: 100
                    ) { batch in
                        // Simulate processing work
                        return batch.map { $0 * 2 }
                    }
                    
                    XCTAssertEqual(results.count, largeDataSet.count)
                    expectation.fulfill()
                } catch {
                    XCTFail("Batch processing failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testMemoryUsageMonitoring() throws {
        measure {
            let (used, available) = memoryManager.getCurrentMemoryUsage()
            XCTAssertGreaterThan(used, 0)
            XCTAssertGreaterThan(available, 0)
            
            let isHigh = memoryManager.isMemoryUsageHigh()
            XCTAssertNotNil(isHigh)
        }
    }
    
    // MARK: - View Model Performance Tests
    
    func testJobSearchViewModelPerformance() throws {
        let mockAPIService = MockUSAJobsAPIService()
        let mockPersistenceService = MockDataPersistenceService()
        let mockOfflineManager = MockOfflineDataManager()
        
        let viewModel = JobSearchViewModel(
            apiService: mockAPIService,
            persistenceService: mockPersistenceService,
            offlineManager: mockOfflineManager
        )
        
        // Setup mock data
        mockAPIService.mockSearchResponse = createMockJobSearchResponse(jobCount: 500)
        
        measure {
            let expectation = XCTestExpectation(description: "Search jobs performance")
            
            Task {
                await viewModel.performSearch()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testFavoritesViewModelPerformance() throws {
        let mockAPIService = MockUSAJobsAPIService()
        let mockPersistenceService = MockDataPersistenceService()
        
        let viewModel = FavoritesViewModel(
            persistenceService: mockPersistenceService,
            apiService: mockAPIService
        )
        
        // Setup mock data
        mockPersistenceService.mockFavoriteJobs = createTestJobs(count: 200)
        
        measure {
            let expectation = XCTestExpectation(description: "Load favorites performance")
            
            Task {
                await viewModel.loadFavorites()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - LazyVStack Performance Tests
    
    func testLazyVStackRenderingPerformance() throws {
        // This would typically be tested in UI tests, but we can test the data preparation
        let jobs = createTestJobs(count: 1000)
        
        measure {
            // Simulate the filtering and sorting that would happen in a LazyVStack
            let filteredJobs = jobs.filter { job in
                job.isFavorited == true
            }
            
            let sortedJobs = filteredJobs.sorted { job1, job2 in
                (job1.datePosted ?? Date.distantPast) > (job2.datePosted ?? Date.distantPast)
            }
            
            XCTAssertLessThanOrEqual(sortedJobs.count, jobs.count)
        }
    }
    
    // MARK: - Cleanup Performance Tests
    
    func testResourceCleanupPerformance() throws {
        // Fill up caches with test data
        let jobs = createTestJobs(count: 500)
        let images = createTestImages(count: 50)
        
        // Cache jobs
        let cacheExpectation = XCTestExpectation(description: "Cache test data")
        Task {
            for job in jobs {
                try await persistenceService.cacheJob(job)
            }
            
            for (index, image) in images.enumerated() {
                let cacheKey = "test-image-\(index)"
                imageCache.memoryCache.setObject(image, forKey: cacheKey as NSString)
            }
            
            cacheExpectation.fulfill()
        }
        wait(for: [cacheExpectation], timeout: 10.0)
        
        // Measure cleanup performance
        measure {
            memoryManager.performMemoryCleanup()
            imageCache.clearExpiredCache()
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestJobs(count: Int) -> [Job] {
        var jobs: [Job] = []
        let context = coreDataStack.context
        
        for i in 0..<count {
            let job = Job(context: context)
            job.jobId = "test-job-\(i)"
            job.title = "Test Job \(i)"
            job.department = "Test Department \(i % 10)"
            job.location = "Test Location \(i % 5)"
            job.salaryMin = Int32(50000 + (i * 1000))
            job.salaryMax = Int32(80000 + (i * 1000))
            job.datePosted = Date().addingTimeInterval(TimeInterval(-i * 3600))
            job.applicationDeadline = Date().addingTimeInterval(TimeInterval(i * 3600))
            job.isFavorited = i % 3 == 0
            job.cachedAt = Date()
            
            jobs.append(job)
        }
        
        return jobs
    }
    
    private func createTestJob(id: String, title: String, department: String) -> Job {
        let context = coreDataStack.context
        let job = Job(context: context)
        job.jobId = id
        job.title = title
        job.department = department
        job.location = "Test Location"
        job.salaryMin = 50000
        job.salaryMax = 80000
        job.datePosted = Date()
        job.applicationDeadline = Date().addingTimeInterval(86400 * 30) // 30 days
        job.isFavorited = true
        job.cachedAt = Date()
        return job
    }
    
    private func createTestImages(count: Int) -> [UIImage] {
        var images: [UIImage] = []
        
        for i in 0..<count {
            let size = CGSize(width: 100, height: 100)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            let image = renderer.image { context in
                let color = UIColor(
                    red: CGFloat(i % 255) / 255.0,
                    green: CGFloat((i * 2) % 255) / 255.0,
                    blue: CGFloat((i * 3) % 255) / 255.0,
                    alpha: 1.0
                )
                color.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            
            images.append(image)
        }
        
        return images
    }
    
    private func createMockJobSearchResponse(jobCount: Int) -> JobSearchResponse {
        var jobs: [JobSearchItem] = []
        
        for i in 0..<jobCount {
            let descriptor = JobDescriptor(
                positionId: "mock-job-\(i)",
                positionTitle: "Mock Job \(i)",
                positionUri: "https://example.com/job/\(i)",
                applicationCloseDate: "2025-12-31T23:59:59.000Z",
                positionStartDate: "2025-01-01T00:00:00.000Z",
                positionEndDate: "2025-12-31T23:59:59.000Z",
                publicationStartDate: "2024-11-01T00:00:00.000Z",
                applicationUri: "https://usajobs.gov/apply/\(i)",
                positionLocationDisplay: "Mock Location \(i)",
                positionLocation: [],
                organizationName: "Mock Agency \(i % 10)",
                departmentName: "Mock Department \(i % 5)",
                jobCategory: [],
                jobGrade: [JobGrade(code: "\(12 + (i % 3))")],
                positionRemuneration: [PositionRemuneration(
                    minimumRange: "\(50000 + (i * 1000))",
                    maximumRange: "\(80000 + (i * 1000))",
                    rateIntervalCode: "PA",
                    description: "Per Year"
                )],
                positionSummary: "Mock job summary for position \(i)",
                positionFormattedDescription: [],
                userArea: nil,
                qualificationSummary: nil
            )
            
            let job = JobSearchItem(
                matchedObjectId: "mock-job-\(i)",
                matchedObjectDescriptor: descriptor,
                relevanceRank: i
            )
            
            jobs.append(job)
        }
        
        return JobSearchResponse(searchResult: SearchResult(
            searchResultItems: jobs,
            searchResultCount: jobCount,
            searchResultCountAll: jobCount
        ))
    }
}

// MARK: - Mock Services for Testing

class MockUSAJobsAPIService: USAJobsAPIServiceProtocol {
    var mockSearchResponse: JobSearchResponse?
    var mockJobDetails: JobDescriptor?
    
    func searchJobs(criteria: SearchCriteria) async throws -> JobSearchResponse {
        if let response = mockSearchResponse {
            return response
        }
        throw APIError.noData
    }
    
    func getJobDetails(jobId: String) async throws -> JobDescriptor {
        if let details = mockJobDetails {
            return details
        }
        throw APIError.noData
    }
    
    func validateAPIConnection() async throws -> Bool {
        return true
    }
}

class MockDataPersistenceService: DataPersistenceServiceProtocol {
    var mockFavoriteJobs: [Job] = []
    var mockSavedSearches: [SavedSearch] = []
    var mockApplicationTrackings: [ApplicationTracking] = []
    
    func saveFavoriteJob(_ job: Job) async throws {
        mockFavoriteJobs.append(job)
    }
    
    func removeFavoriteJob(jobId: String) async throws {
        mockFavoriteJobs.removeAll { $0.jobId == jobId }
    }
    
    func getFavoriteJobs() async throws -> [Job] {
        return mockFavoriteJobs
    }
    
    func toggleFavoriteStatus(jobId: String) async throws -> Bool {
        if let index = mockFavoriteJobs.firstIndex(where: { $0.jobId == jobId }) {
            mockFavoriteJobs.remove(at: index)
            return false
        } else {
            // Would create a new job, but for testing just return true
            return true
        }
    }
    
    func saveSavedSearch(_ search: SavedSearch) async throws {
        mockSavedSearches.append(search)
    }
    
    func getSavedSearches() async throws -> [SavedSearch] {
        return mockSavedSearches
    }
    
    func deleteSavedSearch(searchId: UUID) async throws {
        mockSavedSearches.removeAll { $0.searchId == searchId }
    }
    
    func updateSavedSearch(_ search: SavedSearch) async throws {
        // Mock implementation
    }
    
    func saveApplicationTracking(_ application: ApplicationTracking) async throws {
        mockApplicationTrackings.append(application)
    }
    
    func getApplicationTrackings() async throws -> [ApplicationTracking] {
        return mockApplicationTrackings
    }
    
    func updateApplicationStatus(jobId: String, status: ApplicationTracking.Status) async throws {
        // Mock implementation
    }
    
    func deleteApplicationTracking(jobId: String) async throws {
        mockApplicationTrackings.removeAll { $0.jobId == jobId }
    }
    
    func getApplicationTracking(for jobId: String) async throws -> ApplicationTracking? {
        return mockApplicationTrackings.first { $0.jobId == jobId }
    }
    
    func cacheJob(_ job: Job) async throws {
        // Mock implementation
    }
    
    func getCachedJob(jobId: String) async throws -> Job? {
        return mockFavoriteJobs.first { $0.jobId == jobId }
    }
    
    func clearExpiredCache() async throws {
        // Mock implementation
    }
}

class MockOfflineDataManager: OfflineDataManager {
    var mockCachedJobs: [Job] = []
    
    override func getCachedJobs(limit: Int) async throws -> [Job] {
        return Array(mockCachedJobs.prefix(limit))
    }
    
    override func cacheJobsForOfflineAccess(_ jobs: [Job]) async throws {
        mockCachedJobs.append(contentsOf: jobs)
    }
}