//
//  CriticalUserJourneyUITests.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import XCTest
import SwiftUI
@testable import usajobs

/// UI tests for critical user journeys and user experience flows
@MainActor
final class CriticalUserJourneyUITests: XCTestCase {
    
    // MARK: - Properties
    
    private var app: XCUIApplication!
    private var mockServices: MockServiceContainer!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        mockServices = MockServiceContainer()
        
        // Setup launch arguments for testing
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
        mockServices = nil
    }
    
    // MARK: - Critical User Journey Tests
    
    func testJobSearchToApplicationJourney() throws {
        // Test the complete journey from search to application
        
        // 1. Navigate to Search tab
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.exists)
        searchTab.tap()
        
        // 2. Enter search criteria
        let searchField = app.textFields["Job search"]
        XCTAssertTrue(searchField.exists)
        searchField.tap()
        searchField.typeText("Software Developer")
        
        // 3. Tap search button
        let searchButton = app.buttons["Search"]
        XCTAssertTrue(searchButton.exists)
        searchButton.tap()
        
        // 4. Wait for results to load
        let firstJobResult = app.cells.firstMatch
        let exists = NSPredicate(format: "exists == true")
        expectation(for: exists, evaluatedWith: firstJobResult, handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
        
        // 5. Tap on first job result
        firstJobResult.tap()
        
        // 6. Verify job detail view appears
        let jobDetailView = app.scrollViews["JobDetailView"]
        XCTAssertTrue(jobDetailView.waitForExistence(timeout: 3))
        
        // 7. Tap favorite button
        let favoriteButton = app.buttons["Add to favorites"]
        XCTAssertTrue(favoriteButton.exists)
        favoriteButton.tap()
        
        // 8. Verify favorite status changed
        let favoriteActiveButton = app.buttons["Remove from favorites"]
        XCTAssertTrue(favoriteActiveButton.waitForExistence(timeout: 2))
        
        // 9. Tap apply button
        let applyButton = app.buttons["Apply on USAJobs"]
        XCTAssertTrue(applyButton.exists)
        applyButton.tap()
        
        // 10. Verify external link handling (Safari should open)
        // Note: In actual UI tests, we might check for Safari app launch
        // For this test, we verify the button interaction works
    }
    
    func testFavoritesManagementJourney() throws {
        // Test the favorites management user journey
        
        // 1. First, add a job to favorites (prerequisite)
        addJobToFavorites()
        
        // 2. Navigate to Favorites tab
        let favoritesTab = app.tabBars.buttons["Favorites"]
        XCTAssertTrue(favoritesTab.exists)
        favoritesTab.tap()
        
        // 3. Verify favorites list appears
        let favoritesList = app.tables["FavoritesList"]
        XCTAssertTrue(favoritesList.waitForExistence(timeout: 3))
        
        // 4. Verify favorite job appears
        let favoriteJob = favoritesList.cells.firstMatch
        XCTAssertTrue(favoriteJob.exists)
        
        // 5. Tap on favorite job to view details
        favoriteJob.tap()
        
        // 6. Verify job detail view appears
        let jobDetailView = app.scrollViews["JobDetailView"]
        XCTAssertTrue(jobDetailView.waitForExistence(timeout: 3))
        
        // 7. Go back to favorites
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        backButton.tap()
        
        // 8. Test swipe to remove favorite
        favoriteJob.swipeLeft()
        
        let removeButton = app.buttons["Remove"]
        XCTAssertTrue(removeButton.waitForExistence(timeout: 2))
        removeButton.tap()
        
        // 9. Verify job removed from favorites
        XCTAssertFalse(favoriteJob.exists)
    }
    
    func testSavedSearchJourney() throws {
        // Test the saved search creation and execution journey
        
        // 1. Navigate to Saved Searches tab
        let savedTab = app.tabBars.buttons["Saved Searches"]
        XCTAssertTrue(savedTab.exists)
        savedTab.tap()
        
        // 2. Tap create new search button
        let createButton = app.buttons["Create New Search"]
        XCTAssertTrue(createButton.exists)
        createButton.tap()
        
        // 3. Fill in search criteria
        let nameField = app.textFields["Search Name"]
        XCTAssertTrue(nameField.exists)
        nameField.tap()
        nameField.typeText("My Engineering Jobs")
        
        let keywordsField = app.textFields["Keywords"]
        XCTAssertTrue(keywordsField.exists)
        keywordsField.tap()
        keywordsField.typeText("Engineer")
        
        let locationField = app.textFields["Location"]
        XCTAssertTrue(locationField.exists)
        locationField.tap()
        locationField.typeText("Washington, DC")
        
        // 4. Enable notifications
        let notificationToggle = app.switches["Enable Notifications"]
        XCTAssertTrue(notificationToggle.exists)
        if notificationToggle.value as? String == "0" {
            notificationToggle.tap()
        }
        
        // 5. Save the search
        let saveButton = app.buttons["Save Search"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()
        
        // 6. Verify search appears in list
        let savedSearchesList = app.tables["SavedSearchesList"]
        XCTAssertTrue(savedSearchesList.waitForExistence(timeout: 3))
        
        let savedSearch = savedSearchesList.cells.containing(.staticText, identifier: "My Engineering Jobs").firstMatch
        XCTAssertTrue(savedSearch.exists)
        
        // 7. Execute the saved search
        let executeButton = savedSearch.buttons["Execute Search"]
        XCTAssertTrue(executeButton.exists)
        executeButton.tap()
        
        // 8. Verify search results appear
        let searchResults = app.tables["SearchResults"]
        XCTAssertTrue(searchResults.waitForExistence(timeout: 5))
    }
    
    func testApplicationTrackingJourney() throws {
        // Test the application tracking user journey
        
        // 1. First, apply for a job (prerequisite)
        applyForJob()
        
        // 2. Navigate to Applications tab
        let applicationsTab = app.tabBars.buttons["Applications"]
        XCTAssertTrue(applicationsTab.exists)
        applicationsTab.tap()
        
        // 3. Verify applications list appears
        let applicationsList = app.tables["ApplicationsList"]
        XCTAssertTrue(applicationsList.waitForExistence(timeout: 3))
        
        // 4. Verify application appears
        let application = applicationsList.cells.firstMatch
        XCTAssertTrue(application.exists)
        
        // 5. Tap on application to view details
        application.tap()
        
        // 6. Update application status
        let statusButton = app.buttons["Update Status"]
        XCTAssertTrue(statusButton.exists)
        statusButton.tap()
        
        // 7. Select new status
        let interviewStatus = app.buttons["Interview Scheduled"]
        XCTAssertTrue(interviewStatus.waitForExistence(timeout: 2))
        interviewStatus.tap()
        
        // 8. Add notes
        let notesField = app.textViews["Application Notes"]
        XCTAssertTrue(notesField.exists)
        notesField.tap()
        notesField.typeText("Interview scheduled for next week")
        
        // 9. Save changes
        let saveButton = app.buttons["Save Changes"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()
        
        // 10. Verify status updated
        let updatedStatus = app.staticTexts["Interview Scheduled"]
        XCTAssertTrue(updatedStatus.waitForExistence(timeout: 2))
    }
    
    func testOfflineModeJourney() throws {
        // Test the offline mode user experience
        
        // 1. First, cache some data while online
        cacheDataForOfflineUse()
        
        // 2. Simulate offline mode (in real tests, this might involve network conditions)
        // For UI tests, we assume the app handles offline state
        
        // 3. Navigate to Favorites (should work offline)
        let favoritesTab = app.tabBars.buttons["Favorites"]
        XCTAssertTrue(favoritesTab.exists)
        favoritesTab.tap()
        
        // 4. Verify offline indicator appears
        let offlineIndicator = app.staticTexts["Offline Mode"]
        XCTAssertTrue(offlineIndicator.waitForExistence(timeout: 3))
        
        // 5. Verify cached favorites are accessible
        let favoritesList = app.tables["FavoritesList"]
        XCTAssertTrue(favoritesList.exists)
        
        // 6. Try to perform search (should show offline message)
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let searchButton = app.buttons["Search"]
        searchButton.tap()
        
        let offlineMessage = app.alerts["Offline Mode"].staticTexts["Search is not available offline. Please check your internet connection."]
        XCTAssertTrue(offlineMessage.waitForExistence(timeout: 3))
        
        // 7. Dismiss alert
        let okButton = app.alerts["Offline Mode"].buttons["OK"]
        okButton.tap()
    }
    
    func testAccessibilityJourney() throws {
        // Test the app with accessibility features enabled
        
        // 1. Enable VoiceOver simulation (in real tests)
        // For UI tests, we verify accessibility elements exist
        
        // 2. Navigate through tabs using accessibility
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.isAccessibilityElement)
        XCTAssertEqual(searchTab.accessibilityLabel, "Search tab")
        
        let favoritesTab = app.tabBars.buttons["Favorites"]
        XCTAssertTrue(favoritesTab.isAccessibilityElement)
        XCTAssertEqual(favoritesTab.accessibilityLabel, "Favorites tab")
        
        // 3. Test search accessibility
        searchTab.tap()
        
        let searchField = app.textFields["Job search"]
        XCTAssertTrue(searchField.isAccessibilityElement)
        XCTAssertNotNil(searchField.accessibilityLabel)
        
        // 4. Test job list accessibility
        performSearch()
        
        let jobCell = app.cells.firstMatch
        XCTAssertTrue(jobCell.isAccessibilityElement)
        XCTAssertNotNil(jobCell.accessibilityLabel)
        
        // 5. Test job detail accessibility
        jobCell.tap()
        
        let favoriteButton = app.buttons["Add to favorites"]
        XCTAssertTrue(favoriteButton.isAccessibilityElement)
        XCTAssertNotNil(favoriteButton.accessibilityHint)
    }
    
    func testErrorRecoveryJourney() throws {
        // Test error handling and recovery user experience
        
        // 1. Navigate to search
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        // 2. Perform search that might fail
        let searchField = app.textFields["Job search"]
        searchField.tap()
        searchField.typeText("Test Search")
        
        let searchButton = app.buttons["Search"]
        searchButton.tap()
        
        // 3. Handle potential error state
        let errorAlert = app.alerts["Error"]
        if errorAlert.waitForExistence(timeout: 5) {
            // 4. Verify error message is user-friendly
            let errorMessage = errorAlert.staticTexts.element(boundBy: 1)
            XCTAssertTrue(errorMessage.exists)
            
            // 5. Test retry functionality
            let retryButton = errorAlert.buttons["Retry"]
            if retryButton.exists {
                retryButton.tap()
                
                // 6. Verify retry attempt
                let loadingIndicator = app.activityIndicators.firstMatch
                XCTAssertTrue(loadingIndicator.waitForExistence(timeout: 2))
            } else {
                // Dismiss error if no retry option
                let okButton = errorAlert.buttons["OK"]
                okButton.tap()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func addJobToFavorites() {
        // Helper to add a job to favorites for testing
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        performSearch()
        
        let firstJob = app.cells.firstMatch
        firstJob.tap()
        
        let favoriteButton = app.buttons["Add to favorites"]
        if favoriteButton.exists {
            favoriteButton.tap()
        }
        
        // Navigate back
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
        }
    }
    
    private func performSearch() {
        let searchField = app.textFields["Job search"]
        if searchField.exists {
            searchField.tap()
            searchField.typeText("Software")
        }
        
        let searchButton = app.buttons["Search"]
        if searchButton.exists {
            searchButton.tap()
        }
        
        // Wait for results
        let firstResult = app.cells.firstMatch
        let exists = NSPredicate(format: "exists == true")
        expectation(for: exists, evaluatedWith: firstResult, handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    private func applyForJob() {
        // Helper to apply for a job for testing
        addJobToFavorites()
        
        let favoritesTab = app.tabBars.buttons["Favorites"]
        favoritesTab.tap()
        
        let favoriteJob = app.cells.firstMatch
        favoriteJob.tap()
        
        let applyButton = app.buttons["Apply on USAJobs"]
        if applyButton.exists {
            applyButton.tap()
        }
        
        // In a real scenario, we might track the application
        // For testing, we assume the application is tracked
    }
    
    private func cacheDataForOfflineUse() {
        // Helper to cache data for offline testing
        performSearch()
        
        // View a few job details to cache them
        let jobs = app.cells
        let jobCount = min(3, jobs.count)
        
        for i in 0..<jobCount {
            jobs.element(boundBy: i).tap()
            
            // Add to favorites to cache
            let favoriteButton = app.buttons["Add to favorites"]
            if favoriteButton.exists {
                favoriteButton.tap()
            }
            
            // Go back
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.exists {
                backButton.tap()
            }
        }
    }
}

// MARK: - Mock Service Container for UI Testing

class MockServiceContainer: ObservableObject {
    let persistenceService: MockDataPersistenceService
    let apiService: MockUSAJobsAPIService
    let notificationService: MockNotificationService
    
    init() {
        self.persistenceService = MockDataPersistenceService()
        self.apiService = MockUSAJobsAPIService()
        self.notificationService = MockNotificationService()
        
        setupMockData()
    }
    
    private func setupMockData() {
        // Setup mock responses for UI testing
        apiService.mockSearchResponse = createMockSearchResponse()
        apiService.mockJobDetails = createMockJobDetails()
    }
    
    private func createMockSearchResponse() -> JobSearchResponse {
        let jobs = (0..<5).map { index in
            JobSearchItem(
                matchedObjectId: "ui-test-job-\(index)",
                matchedObjectDescriptor: JobDescriptor(
                    positionId: "ui-test-job-\(index)",
                    positionTitle: "UI Test Job \(index)",
                    positionUri: "https://example.com/job/\(index)",
                    applicationCloseDate: "2025-12-31T23:59:59.000Z",
                    positionStartDate: "2025-01-01T00:00:00.000Z",
                    positionEndDate: "2025-12-31T23:59:59.000Z",
                    publicationStartDate: "2024-11-01T00:00:00.000Z",
                    applicationUri: "https://usajobs.gov/apply/\(index)",
                    positionLocationDisplay: "Washington, DC",
                    positionLocation: [],
                    organizationName: "Test Agency \(index)",
                    departmentName: "Test Department",
                    jobCategory: [],
                    jobGrade: [],
                    positionRemuneration: [],
                    positionSummary: "UI test job summary \(index)",
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
    
    private func createMockJobDetails() -> JobDescriptor {
        return JobDescriptor(
            positionId: "ui-test-detail",
            positionTitle: "UI Test Job Detail",
            positionUri: "https://example.com/job/detail",
            applicationCloseDate: "2025-12-31T23:59:59.000Z",
            positionStartDate: "2025-01-01T00:00:00.000Z",
            positionEndDate: "2025-12-31T23:59:59.000Z",
            publicationStartDate: "2024-11-01T00:00:00.000Z",
            applicationUri: "https://usajobs.gov/apply/detail",
            positionLocationDisplay: "Washington, DC",
            positionLocation: [],
            organizationName: "Test Agency",
            departmentName: "Test Department",
            jobCategory: [],
            jobGrade: [],
            positionRemuneration: [],
            positionSummary: "Detailed UI test job summary",
            positionFormattedDescription: [],
            userArea: nil,
            qualificationSummary: nil
        )
    }
}