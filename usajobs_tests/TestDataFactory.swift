//
//  TestDataFactory.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation
import CoreData
@testable import usajobs

/// Factory class for creating test data objects
class TestDataFactory {
    
    // MARK: - Core Data Context
    
    static func createInMemoryContext() -> NSManagedObjectContext {
        let coreDataStack = CoreDataStack(inMemory: true)
        return coreDataStack.context
    }
    
    // MARK: - Job Creation
    
    static func createJob(
        context: NSManagedObjectContext,
        id: String = "test-job-\(UUID().uuidString)",
        title: String = "Software Developer",
        department: String = "Department of Defense",
        location: String = "Washington, DC",
        salaryMin: Int32 = 80000,
        salaryMax: Int32 = 120000,
        isFavorited: Bool = false,
        datePosted: Date = Date(),
        applicationDeadline: Date = Date().addingTimeInterval(86400 * 30)
    ) -> Job {
        let job = Job(context: context)
        job.jobId = id
        job.title = title
        job.department = department
        job.location = location
        job.salaryMin = salaryMin
        job.salaryMax = salaryMax
        job.isFavorited = isFavorited
        job.datePosted = datePosted
        job.applicationDeadline = applicationDeadline
        job.cachedAt = Date()
        return job
    }
    
    static func createJobs(
        context: NSManagedObjectContext,
        count: Int,
        baseTitle: String = "Test Job"
    ) -> [Job] {
        return (0..<count).map { index in
            createJob(
                context: context,
                id: "test-job-\(index)",
                title: "\(baseTitle) \(index)",
                department: "Department \(index % 5)",
                location: "Location \(index % 3)",
                salaryMin: Int32(50000 + (index * 1000)),
                salaryMax: Int32(80000 + (index * 1000)),
                isFavorited: index % 3 == 0
            )
        }
    }
    
    // MARK: - SavedSearch Creation
    
    static func createSavedSearch(
        context: NSManagedObjectContext,
        name: String = "Test Search",
        keywords: String? = "Software Developer",
        location: String? = "Washington, DC",
        department: String? = "Department of Defense",
        salaryMin: Int32 = 0,
        salaryMax: Int32 = 0,
        isNotificationEnabled: Bool = true
    ) -> SavedSearch {
        let search = SavedSearch(context: context)
        search.searchId = UUID()
        search.name = name
        search.keywords = keywords
        search.location = location
        search.department = department
        search.salaryMin = salaryMin
        search.salaryMax = salaryMax
        search.isNotificationEnabled = isNotificationEnabled
        search.lastChecked = Date()
        return search
    }
    
    static func createSavedSearches(
        context: NSManagedObjectContext,
        count: Int
    ) -> [SavedSearch] {
        return (0..<count).map { index in
            createSavedSearch(
                context: context,
                name: "Test Search \(index)",
                keywords: "Keyword \(index)",
                location: "Location \(index)",
                department: "Department \(index % 3)"
            )
        }
    }
    
    // MARK: - ApplicationTracking Creation
    
    static func createApplicationTracking(
        context: NSManagedObjectContext,
        jobId: String = "test-job-\(UUID().uuidString)",
        status: ApplicationTracking.Status = .applied,
        applicationDate: Date = Date(),
        notes: String? = "Test application notes",
        reminderDate: Date? = nil
    ) -> ApplicationTracking {
        let application = ApplicationTracking(context: context)
        application.jobId = jobId
        application.status = status.rawValue
        application.applicationDate = applicationDate
        application.notes = notes
        application.reminderDate = reminderDate ?? Date().addingTimeInterval(86400 * 7)
        return application
    }
    
    static func createApplicationTrackings(
        context: NSManagedObjectContext,
        count: Int
    ) -> [ApplicationTracking] {
        let statuses: [ApplicationTracking.Status] = [.applied, .interviewed, .offered, .rejected]
        
        return (0..<count).map { index in
            createApplicationTracking(
                context: context,
                jobId: "test-job-\(index)",
                status: statuses[index % statuses.count],
                applicationDate: Date().addingTimeInterval(TimeInterval(-index * 86400)),
                notes: "Application notes for job \(index)"
            )
        }
    }
    
    // MARK: - API Response Models
    
    static func createJobSearchResponse(
        jobCount: Int = 10,
        totalCount: Int? = nil
    ) -> JobSearchResponse {
        let jobs = createJobSearchItems(count: jobCount)
        let total = totalCount ?? jobCount
        
        return JobSearchResponse(
            searchResult: SearchResult(
                searchResultItems: jobs,
                searchResultCount: jobCount,
                searchResultCountAll: total
            )
        )
    }
    
    static func createJobSearchItems(count: Int) -> [JobSearchItem] {
        return (0..<count).map { index in
            createJobSearchItem(index: index)
        }
    }
    
    static func createJobSearchItem(
        index: Int = 0,
        id: String? = nil,
        title: String? = nil,
        department: String? = nil,
        location: String? = nil
    ) -> JobSearchItem {
        let jobId = id ?? "test-job-\(index)"
        let jobTitle = title ?? "Test Job \(index)"
        let jobDepartment = department ?? "Test Department \(index % 5)"
        let jobLocation = location ?? "Test Location \(index % 3)"
        
        return JobSearchItem(
            matchedObjectId: jobId,
            matchedObjectDescriptor: createJobDescriptor(
                id: jobId,
                title: jobTitle,
                department: jobDepartment,
                location: jobLocation
            ),
            relevanceRank: index
        )
    }
    
    static func createJobDescriptor(
        id: String = "test-job",
        title: String = "Software Developer",
        department: String = "Department of Defense",
        location: String = "Washington, DC",
        salaryMin: String = "80000",
        salaryMax: String = "120000",
        summary: String? = nil,
        qualifications: String? = nil
    ) -> JobDescriptor {
        return JobDescriptor(
            positionId: id,
            positionTitle: title,
            positionUri: "https://example.com/job/\(id)",
            applicationCloseDate: "2025-12-31T23:59:59.000Z",
            positionStartDate: "2025-01-01T00:00:00.000Z",
            positionEndDate: "2025-12-31T23:59:59.000Z",
            publicationStartDate: "2024-11-01T00:00:00.000Z",
            applicationUri: "https://usajobs.gov/apply/\(id)",
            positionLocationDisplay: location,
            positionLocation: [createPositionLocation(city: location)],
            organizationName: "Test Organization",
            departmentName: department,
            jobCategory: [createJobCategory()],
            jobGrade: [createJobGrade()],
            positionRemuneration: [createPositionRemuneration(min: salaryMin, max: salaryMax)],
            positionSummary: summary ?? "Test job summary for \(title)",
            positionFormattedDescription: [createFormattedDescription()],
            userArea: createUserArea(),
            qualificationSummary: qualifications ?? "Test qualifications for \(title)"
        )
    }
    
    // MARK: - Supporting API Models
    
    static func createPositionLocation(
        city: String = "Washington",
        state: String = "District of Columbia",
        countryCode: String = "US"
    ) -> PositionLocation {
        return PositionLocation(
            locationName: "\(city), \(state)",
            countryCode: countryCode,
            countrySubDivisionCode: state,
            cityName: city,
            longitude: -77.0369,
            latitude: 38.9072
        )
    }
    
    static func createJobCategory(
        name: String = "Information Technology",
        code: String = "2210"
    ) -> JobCategory {
        return JobCategory(
            name: name,
            code: code
        )
    }
    
    static func createJobGrade(
        code: String = "13"
    ) -> JobGrade {
        return JobGrade(code: code)
    }
    
    static func createPositionRemuneration(
        min: String = "80000",
        max: String = "120000",
        intervalCode: String = "PA",
        description: String = "Per Year"
    ) -> PositionRemuneration {
        return PositionRemuneration(
            minimumRange: min,
            maximumRange: max,
            rateIntervalCode: intervalCode,
            description: description
        )
    }
    
    static func createFormattedDescription(
        label: String = "Job Summary",
        content: String = "This is a test job description with detailed information about the position requirements and responsibilities."
    ) -> PositionFormattedDescription {
        return PositionFormattedDescription(
            label: label,
            labelDescription: content
        )
    }
    
    static func createUserArea() -> UserArea {
        return UserArea(
            details: UserAreaDetails(
                majorDuties: ["Develop software applications", "Maintain existing systems", "Collaborate with team members"],
                education: "Bachelor's degree in Computer Science or related field",
                requirements: "3+ years of software development experience",
                evaluations: "Experience will be evaluated based on portfolio and interview",
                howToApply: "Apply online through USAJobs.gov",
                whatToExpect: "Expect a thorough review process including technical assessment",
                requiredDocuments: ["Resume", "Cover Letter", "Transcripts"],
                benefits: "Federal benefits package including health insurance and retirement",
                benefitsUrl: "https://usajobs.gov/benefits",
                keyRequirements: ["Security clearance eligible", "US Citizenship required"],
                jobSummary: "Exciting opportunity to work on cutting-edge federal technology projects",
                organizationCodes: "ABC123",
                travelCode: "0",
                applyOnlineUrl: "https://usajobs.gov/apply/test-job"
            )
        )
    }
    
    // MARK: - Search Criteria
    
    static func createSearchCriteria(
        keywords: String? = "Software Developer",
        location: String? = "Washington, DC",
        department: String? = "Department of Defense",
        salaryMin: Int? = 80000,
        salaryMax: Int? = 120000,
        payGradeMin: Int? = 12,
        payGradeMax: Int? = 15,
        isRemote: Bool = false,
        sortBy: SearchCriteria.SortOption = .relevance
    ) -> SearchCriteria {
        return SearchCriteria(
            keywords: keywords,
            location: location,
            department: department,
            salaryMin: salaryMin,
            salaryMax: salaryMax,
            payGradeMin: payGradeMin,
            payGradeMax: payGradeMax,
            isRemote: isRemote,
            sortBy: sortBy
        )
    }
    
    // MARK: - Batch Creation Methods
    
    static func createCompleteTestDataSet(context: NSManagedObjectContext) -> TestDataSet {
        let jobs = createJobs(context: context, count: 20)
        let savedSearches = createSavedSearches(context: context, count: 5)
        let applications = createApplicationTrackings(context: context, count: 8)
        
        // Save context
        try? context.save()
        
        return TestDataSet(
            jobs: jobs,
            savedSearches: savedSearches,
            applications: applications
        )
    }
    
    static func createLargeTestDataSet(context: NSManagedObjectContext, scale: Int = 100) -> TestDataSet {
        let jobs = createJobs(context: context, count: scale * 10)
        let savedSearches = createSavedSearches(context: context, count: scale)
        let applications = createApplicationTrackings(context: context, count: scale * 2)
        
        // Save in batches to avoid memory issues
        let batchSize = 100
        for i in stride(from: 0, to: jobs.count, by: batchSize) {
            try? context.save()
        }
        
        return TestDataSet(
            jobs: jobs,
            savedSearches: savedSearches,
            applications: applications
        )
    }
    
    // MARK: - Specialized Test Data
    
    static func createExpiredJobs(context: NSManagedObjectContext, count: Int = 5) -> [Job] {
        return (0..<count).map { index in
            createJob(
                context: context,
                id: "expired-job-\(index)",
                title: "Expired Job \(index)",
                applicationDeadline: Date().addingTimeInterval(-86400 * Double(index + 1)) // Past dates
            )
        }
    }
    
    static func createHighSalaryJobs(context: NSManagedObjectContext, count: Int = 5) -> [Job] {
        return (0..<count).map { index in
            createJob(
                context: context,
                id: "high-salary-job-\(index)",
                title: "Senior Position \(index)",
                salaryMin: Int32(120000 + (index * 10000)),
                salaryMax: Int32(180000 + (index * 10000))
            )
        }
    }
    
    static func createRemoteJobs(context: NSManagedObjectContext, count: Int = 5) -> [Job] {
        return (0..<count).map { index in
            createJob(
                context: context,
                id: "remote-job-\(index)",
                title: "Remote Position \(index)",
                location: "Remote"
            )
        }
    }
    
    static func createJobsWithNotifications(context: NSManagedObjectContext, count: Int = 3) -> [SavedSearch] {
        return (0..<count).map { index in
            createSavedSearch(
                context: context,
                name: "Notification Search \(index)",
                keywords: "Notification Job \(index)",
                isNotificationEnabled: true
            )
        }
    }
}

// MARK: - Test Data Set Structure

struct TestDataSet {
    let jobs: [Job]
    let savedSearches: [SavedSearch]
    let applications: [ApplicationTracking]
    
    var totalCount: Int {
        return jobs.count + savedSearches.count + applications.count
    }
}

// MARK: - Mock Service Factory

class MockServiceFactory {
    
    static func createMockAPIService(
        withData dataSet: TestDataSet? = nil,
        shouldFail: Bool = false,
        delay: TimeInterval = 0
    ) -> MockUSAJobsAPIService {
        let service = MockUSAJobsAPIService()
        service.shouldFail = shouldFail
        service.responseDelay = delay
        
        if let dataSet = dataSet {
            // Convert Core Data jobs to API response format
            let jobItems = dataSet.jobs.map { job in
                TestDataFactory.createJobSearchItem(
                    id: job.jobId,
                    title: job.title,
                    department: job.department,
                    location: job.location
                )
            }
            
            service.mockSearchResponse = JobSearchResponse(
                searchResult: SearchResult(
                    searchResultItems: jobItems,
                    searchResultCount: jobItems.count,
                    searchResultCountAll: jobItems.count
                )
            )
        }
        
        return service
    }
    
    static func createMockPersistenceService(
        withData dataSet: TestDataSet? = nil,
        shouldFail: Bool = false
    ) -> MockDataPersistenceService {
        let service = MockDataPersistenceService()
        service.shouldFail = shouldFail
        
        if let dataSet = dataSet {
            service.mockFavoriteJobs = dataSet.jobs.filter { $0.isFavorited }
            service.mockSavedSearches = dataSet.savedSearches
            service.mockApplicationTrackings = dataSet.applications
        }
        
        return service
    }
    
    static func createMockNotificationService(
        permissionGranted: Bool = true,
        shouldFail: Bool = false
    ) -> MockNotificationService {
        let service = MockNotificationService()
        service.permissionGranted = permissionGranted
        service.shouldFail = shouldFail
        return service
    }
}

// MARK: - Enhanced Mock Services

class MockUSAJobsAPIService: USAJobsAPIServiceProtocol {
    var mockSearchResponse: JobSearchResponse?
    var mockJobDetails: JobDescriptor?
    var shouldFail = false
    var responseDelay: TimeInterval = 0
    var callCount = 0
    
    func searchJobs(criteria: SearchCriteria) async throws -> JobSearchResponse {
        callCount += 1
        
        if responseDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }
        
        if shouldFail {
            throw APIError.networkError
        }
        
        return mockSearchResponse ?? TestDataFactory.createJobSearchResponse()
    }
    
    func getJobDetails(jobId: String) async throws -> JobDescriptor {
        callCount += 1
        
        if responseDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }
        
        if shouldFail {
            throw APIError.networkError
        }
        
        return mockJobDetails ?? TestDataFactory.createJobDescriptor(id: jobId)
    }
    
    func validateAPIConnection() async throws -> Bool {
        callCount += 1
        return !shouldFail
    }
}

class MockDataPersistenceService: DataPersistenceServiceProtocol {
    var mockFavoriteJobs: [Job] = []
    var mockSavedSearches: [SavedSearch] = []
    var mockApplicationTrackings: [ApplicationTracking] = []
    var shouldFail = false
    var callCount = 0
    
    func saveFavoriteJob(_ job: Job) async throws {
        callCount += 1
        if shouldFail { throw PersistenceError.saveFailed }
        mockFavoriteJobs.append(job)
    }
    
    func removeFavoriteJob(jobId: String) async throws {
        callCount += 1
        if shouldFail { throw PersistenceError.deleteFailed }
        mockFavoriteJobs.removeAll { $0.jobId == jobId }
    }
    
    func getFavoriteJobs() async throws -> [Job] {
        callCount += 1
        if shouldFail { throw PersistenceError.fetchFailed }
        return mockFavoriteJobs
    }
    
    func toggleFavoriteStatus(jobId: String) async throws -> Bool {
        callCount += 1
        if shouldFail { throw PersistenceError.saveFailed }
        
        if let index = mockFavoriteJobs.firstIndex(where: { $0.jobId == jobId }) {
            mockFavoriteJobs.remove(at: index)
            return false
        } else {
            // Create a mock job for testing
            let context = TestDataFactory.createInMemoryContext()
            let job = TestDataFactory.createJob(context: context, id: jobId, isFavorited: true)
            mockFavoriteJobs.append(job)
            return true
        }
    }
    
    func saveSavedSearch(_ search: SavedSearch) async throws {
        callCount += 1
        if shouldFail { throw PersistenceError.saveFailed }
        mockSavedSearches.append(search)
    }
    
    func getSavedSearches() async throws -> [SavedSearch] {
        callCount += 1
        if shouldFail { throw PersistenceError.fetchFailed }
        return mockSavedSearches
    }
    
    func deleteSavedSearch(searchId: UUID) async throws {
        callCount += 1
        if shouldFail { throw PersistenceError.deleteFailed }
        mockSavedSearches.removeAll { $0.searchId == searchId }
    }
    
    func updateSavedSearch(_ search: SavedSearch) async throws {
        callCount += 1
        if shouldFail { throw PersistenceError.saveFailed }
        // Mock implementation
    }
    
    func saveApplicationTracking(_ application: ApplicationTracking) async throws {
        callCount += 1
        if shouldFail { throw PersistenceError.saveFailed }
        mockApplicationTrackings.append(application)
    }
    
    func getApplicationTrackings() async throws -> [ApplicationTracking] {
        callCount += 1
        if shouldFail { throw PersistenceError.fetchFailed }
        return mockApplicationTrackings
    }
    
    func updateApplicationStatus(jobId: String, status: ApplicationTracking.Status) async throws {
        callCount += 1
        if shouldFail { throw PersistenceError.saveFailed }
        
        if let application = mockApplicationTrackings.first(where: { $0.jobId == jobId }) {
            application.status = status.rawValue
        }
    }
    
    func deleteApplicationTracking(jobId: String) async throws {
        callCount += 1
        if shouldFail { throw PersistenceError.deleteFailed }
        mockApplicationTrackings.removeAll { $0.jobId == jobId }
    }
    
    func getApplicationTracking(for jobId: String) async throws -> ApplicationTracking? {
        callCount += 1
        if shouldFail { throw PersistenceError.fetchFailed }
        return mockApplicationTrackings.first { $0.jobId == jobId }
    }
    
    func cacheJob(_ job: Job) async throws {
        callCount += 1
        if shouldFail { throw PersistenceError.saveFailed }
        // Mock implementation
    }
    
    func getCachedJob(jobId: String) async throws -> Job? {
        callCount += 1
        if shouldFail { throw PersistenceError.fetchFailed }
        return mockFavoriteJobs.first { $0.jobId == jobId }
    }
    
    func clearExpiredCache() async throws {
        callCount += 1
        if shouldFail { throw PersistenceError.deleteFailed }
        // Mock implementation
    }
}

class MockNotificationService: NotificationServiceProtocol {
    var permissionGranted = true
    var shouldFail = false
    var notificationsScheduled = 0
    var callCount = 0
    
    func scheduleDeadlineReminder(for application: ApplicationTracking) async throws {
        callCount += 1
        if shouldFail { throw NotificationError.schedulingFailed }
        notificationsScheduled += 1
    }
    
    func scheduleNewJobsNotification(for search: SavedSearch, jobCount: Int) async throws {
        callCount += 1
        if shouldFail { throw NotificationError.schedulingFailed }
        notificationsScheduled += 1
    }
    
    func requestNotificationPermissions() async throws -> Bool {
        callCount += 1
        if shouldFail { throw NotificationError.permissionDenied }
        return permissionGranted
    }
    
    func handleBackgroundAppRefresh() async -> Bool {
        callCount += 1
        return !shouldFail
    }
    
    func checkForNewJobs() async throws {
        callCount += 1
        if shouldFail { throw NotificationError.checkFailed }
        notificationsScheduled += 1
    }
}

// MARK: - Error Types for Testing

enum PersistenceError: Error {
    case saveFailed
    case fetchFailed
    case deleteFailed
}

enum NotificationError: Error {
    case schedulingFailed
    case permissionDenied
    case checkFailed
}