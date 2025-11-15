//
//  NavigationUITests.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import XCTest
import SwiftUI
@testable import usajobs

/// UI tests for navigation flows and tab structure
@MainActor
final class NavigationUITests: XCTestCase {
    
    // MARK: - Properties
    
    private var mockPersistenceService: MockDataPersistenceService!
    private var mockAPIService: MockUSAJobsAPIService!
    private var mockNotificationService: MockNotificationService!
    private var serviceContainer: ServiceContainer!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        mockPersistenceService = MockDataPersistenceService()
        mockAPIService = MockUSAJobsAPIService()
        mockNotificationService = MockNotificationService()
        
        serviceContainer = ServiceContainer(
            persistenceService: mockPersistenceService,
            apiService: mockAPIService,
            notificationService: mockNotificationService
        )
    }
    
    override func tearDown() {
        mockPersistenceService = nil
        mockAPIService = nil
        mockNotificationService = nil
        serviceContainer = nil
        super.tearDown()
    }
    
    // MARK: - Tab Navigation Tests
    
    func testTabViewStructure() throws {
        // Given
        let contentView = ContentView()
            .environmentObject(serviceContainer)
        
        // When - Create the view hierarchy
        let hostingController = UIHostingController(rootView: contentView)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        
        // Then - Verify tab structure exists
        XCTAssertNotNil(hostingController.view)
        
        // Verify all tabs are accessible
        let tabTitles = ["Search", "Favorites", "Saved Searches", "Applications"]
        for title in tabTitles {
            // In a real UI test, we would check for tab accessibility identifiers
            // For unit tests, we verify the enum structure
            XCTAssertTrue(ContentView.Tab.allCases.map(\.title).contains(title))
        }
    }
    
    func testTabSelection() throws {
        // Given
        let contentView = ContentView()
            .environmentObject(serviceContainer)
        
        // When - Test tab enum functionality
        let searchTab = ContentView.Tab.search
        let favoritesTab = ContentView.Tab.favorites
        let savedTab = ContentView.Tab.saved
        let applicationsTab = ContentView.Tab.applications
        
        // Then - Verify tab properties
        XCTAssertEqual(searchTab.title, "Search")
        XCTAssertEqual(searchTab.icon, "magnifyingglass")
        
        XCTAssertEqual(favoritesTab.title, "Favorites")
        XCTAssertEqual(favoritesTab.icon, "heart")
        
        XCTAssertEqual(savedTab.title, "Saved Searches")
        XCTAssertEqual(savedTab.icon, "bookmark")
        
        XCTAssertEqual(applicationsTab.title, "Applications")
        XCTAssertEqual(applicationsTab.icon, "doc.text")
    }
    
    // MARK: - Navigation Stack Tests
    
    func testJobSearchNavigationStack() throws {
        // Given
        let viewModel = JobSearchViewModel(
            apiService: mockAPIService,
            persistenceService: mockPersistenceService
        )
        
        let jobSearchView = JobSearchView(
            viewModel: viewModel,
            apiService: mockAPIService,
            persistenceService: mockPersistenceService
        )
        
        // When - Create navigation stack
        let navigationView = NavigationStack {
            jobSearchView
        }
        
        let hostingController = UIHostingController(rootView: navigationView)
        
        // Then - Verify navigation structure
        XCTAssertNotNil(hostingController.view)
        
        // Verify navigation title would be set
        // In a real UI test, we would check the navigation bar title
    }
    
    func testJobDetailNavigation() throws {
        // Given
        let jobDetailView = JobDetailView(
            jobId: "test-job-id",
            apiService: mockAPIService,
            persistenceService: mockPersistenceService
        )
        
        // When - Create navigation context
        let navigationView = NavigationStack {
            jobDetailView
        }
        
        let hostingController = UIHostingController(rootView: navigationView)
        
        // Then - Verify view can be created
        XCTAssertNotNil(hostingController.view)
    }
    
    // MARK: - Deep Linking Tests
    
    func testDeepLinkURLParsing() throws {
        // Given
        let contentView = ContentView()
            .environmentObject(serviceContainer)
        
        // When - Test deep link URL structures
        let jobURL = URL(string: "federaljobfinder://job/12345")!
        let searchURL = URL(string: "federaljobfinder://search")!
        let favoritesURL = URL(string: "federaljobfinder://favorites")!
        let savedURL = URL(string: "federaljobfinder://saved")!
        let applicationsURL = URL(string: "federaljobfinder://applications")!
        
        // Then - Verify URL structure
        XCTAssertEqual(jobURL.scheme, "federaljobfinder")
        XCTAssertEqual(jobURL.host, "job")
        XCTAssertEqual(jobURL.pathComponents.dropFirst().first, "12345")
        
        XCTAssertEqual(searchURL.host, "search")
        XCTAssertEqual(favoritesURL.host, "favorites")
        XCTAssertEqual(savedURL.host, "saved")
        XCTAssertEqual(applicationsURL.host, "applications")
    }
    
    func testDeepLinkJobItem() throws {
        // Given
        let jobId = "test-job-123"
        
        // When
        let deepLinkItem = DeepLinkJobItem(jobId: jobId)
        
        // Then
        XCTAssertEqual(deepLinkItem.jobId, jobId)
        XCTAssertNotNil(deepLinkItem.id)
    }
    
    // MARK: - Navigation Flow Tests
    
    func testJobRowNavigationFlow() throws {
        // Given
        let sampleJob = createSampleJobSearchItem()
        
        let jobRowView = JobRowView(
            job: sampleJob,
            onFavoriteToggle: {},
            apiService: mockAPIService,
            persistenceService: mockPersistenceService
        )
        
        // When - Create in navigation context
        let navigationView = NavigationStack {
            List {
                jobRowView
            }
        }
        
        let hostingController = UIHostingController(rootView: navigationView)
        
        // Then - Verify view structure
        XCTAssertNotNil(hostingController.view)
    }
    
    func testFavoritesNavigationFlow() throws {
        // Given
        let viewModel = FavoritesViewModel(
            persistenceService: mockPersistenceService,
            apiService: mockAPIService
        )
        
        let favoritesView = FavoritesView(
            viewModel: viewModel,
            apiService: mockAPIService,
            persistenceService: mockPersistenceService
        )
        
        // When - Create in navigation context
        let navigationView = NavigationStack {
            favoritesView
        }
        
        let hostingController = UIHostingController(rootView: navigationView)
        
        // Then - Verify view structure
        XCTAssertNotNil(hostingController.view)
    }
    
    func testSavedSearchesNavigationFlow() throws {
        // Given
        let viewModel = SavedSearchViewModel(
            persistenceService: mockPersistenceService,
            apiService: mockAPIService,
            notificationService: mockNotificationService
        )
        
        let savedSearchesView = SavedSearchesView(
            viewModel: viewModel,
            apiService: mockAPIService,
            persistenceService: mockPersistenceService
        )
        
        // When - Create in navigation context
        let navigationView = NavigationStack {
            savedSearchesView
        }
        
        let hostingController = UIHostingController(rootView: navigationView)
        
        // Then - Verify view structure
        XCTAssertNotNil(hostingController.view)
    }
    
    func testApplicationsNavigationFlow() throws {
        // Given
        let applicationsView = ApplicationsView(
            notificationService: mockNotificationService
        )
        
        // When - Create in navigation context
        let navigationView = NavigationStack {
            applicationsView
        }
        
        let hostingController = UIHostingController(rootView: navigationView)
        
        // Then - Verify view structure
        XCTAssertNotNil(hostingController.view)
    }
    
    // MARK: - Accessibility Tests
    
    func testNavigationAccessibility() throws {
        // Given
        let contentView = ContentView()
            .environmentObject(serviceContainer)
        
        // When - Create view with accessibility
        let hostingController = UIHostingController(rootView: contentView)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        
        // Then - Verify accessibility elements exist
        XCTAssertNotNil(hostingController.view)
        
        // In a real UI test, we would verify:
        // - Tab items have proper accessibility labels
        // - Navigation titles are accessible
        // - Back buttons have proper labels
        // - Deep link handling preserves accessibility
    }
    
    // MARK: - Helper Methods
    
    private func createSampleJobSearchItem() -> JobSearchItem {
        return JobSearchItem(
            matchedObjectId: "test-id",
            matchedObjectDescriptor: JobDescriptor(
                positionId: "12345",
                positionTitle: "Test Job",
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
                positionRemuneration: [],
                positionSummary: "Test job summary",
                positionFormattedDescription: [],
                userArea: nil,
                qualificationSummary: nil
            ),
            relevanceRank: 1
        )
    }
}

// MARK: - Mock Services

class MockUSAJobsAPIService: USAJobsAPIServiceProtocol {
    func searchJobs(criteria: SearchCriteria) async throws -> JobSearchResponse {
        return JobSearchResponse(searchResult: SearchResult(
            searchResultItems: [],
            searchResultCount: 0,
            searchResultCountAll: 0
        ))
    }
    
    func getJobDetails(jobId: String) async throws -> JobDescriptor {
        return JobDescriptor(
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
        return true
    }
}

class MockDataPersistenceService: DataPersistenceServiceProtocol {
    func saveFavoriteJob(_ job: Job) async throws {}
    func removeFavoriteJob(jobId: String) async throws {}
    func getFavoriteJobs() async throws -> [Job] { return [] }
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
    func clearExpiredCache() async throws {}
}

class MockNotificationService: NotificationServiceProtocol {
    func scheduleDeadlineReminder(for application: ApplicationTracking) async throws {}
    func scheduleNewJobsNotification(for search: SavedSearch, jobCount: Int) async throws {}
    func requestNotificationPermissions() async throws -> Bool { return true }
    func handleBackgroundAppRefresh() async -> Bool { return true }
    func checkForNewJobs() async throws {}
}