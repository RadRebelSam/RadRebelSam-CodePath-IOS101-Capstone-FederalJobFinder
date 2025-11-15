//
//  SavedSearchViewModel.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for managing saved searches functionality
@MainActor
class SavedSearchViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// List of saved searches
    @Published var savedSearches: [SavedSearch] = []
    
    /// Loading state for saved searches fetch
    @Published var isLoading = false
    
    /// Loading state for executing a search
    @Published var isExecutingSearch = false
    
    /// Error message to display to user
    @Published var errorMessage: String?
    
    /// Search text for filtering saved searches
    @Published var searchText = ""
    
    /// Currently selected saved search for editing
    @Published var selectedSearch: SavedSearch?
    
    /// Whether the create/edit sheet is presented
    @Published var showingCreateEditSheet = false
    
    /// Whether the delete confirmation alert is shown
    @Published var showingDeleteAlert = false
    
    /// Search to be deleted (for confirmation)
    @Published var searchToDelete: SavedSearch?
    
    /// New job counts for each saved search
    @Published var newJobCounts: [UUID: Int] = [:]
    
    // MARK: - Private Properties
    
    private let persistenceService: DataPersistenceServiceProtocol
    private let apiService: USAJobsAPIServiceProtocol
    private let notificationService: NotificationServiceProtocol
    
    // MARK: - Initialization
    
    init(
        persistenceService: DataPersistenceServiceProtocol,
        apiService: USAJobsAPIServiceProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.persistenceService = persistenceService
        self.apiService = apiService
        self.notificationService = notificationService
    }
    
    // MARK: - Public Methods
    
    /// Load all saved searches from persistence
    func loadSavedSearches() async {
        isLoading = true
        errorMessage = nil
        
        do {
            savedSearches = try await persistenceService.getSavedSearches()
            await checkForNewJobs()
        } catch {
            handleError(error, message: "Failed to load saved searches")
        }
        
        isLoading = false
    }
    
    /// Create a new saved search
    func createSavedSearch(name: String, criteria: SearchCriteria) async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Search name cannot be empty"
            return
        }
        
        do {
            let coreDataStack = CoreDataStack.shared
            let context = coreDataStack.context
            
            let savedSearch = SavedSearch(context: context, name: name)
            savedSearch.keywords = criteria.keyword
            savedSearch.location = criteria.location
            savedSearch.department = criteria.department
            savedSearch.salaryMin = Int32(criteria.salaryMin ?? 0)
            savedSearch.salaryMax = Int32(criteria.salaryMax ?? 0)
            savedSearch.isNotificationEnabled = false
            savedSearch.lastChecked = Date()
            
            try await persistenceService.saveSavedSearch(savedSearch)
            await loadSavedSearches()
            
        } catch {
            handleError(error, message: "Failed to create saved search")
        }
    }
    
    /// Update an existing saved search
    func updateSavedSearch(_ search: SavedSearch, name: String, criteria: SearchCriteria) async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Search name cannot be empty"
            return
        }
        
        do {
            search.name = name
            search.keywords = criteria.keyword
            search.location = criteria.location
            search.department = criteria.department
            search.salaryMin = Int32(criteria.salaryMin ?? 0)
            search.salaryMax = Int32(criteria.salaryMax ?? 0)
            
            try await persistenceService.updateSavedSearch(search)
            await loadSavedSearches()
            
        } catch {
            handleError(error, message: "Failed to update saved search")
        }
    }
    
    /// Delete a saved search
    func deleteSavedSearch(_ search: SavedSearch) async {
        guard let searchId = search.searchId else { return }
        
        do {
            // Cancel any pending notifications for this search
            await notificationService.cancelNewJobsNotification(for: searchId)
            
            try await persistenceService.deleteSavedSearch(searchId: searchId)
            
            // Remove from local array immediately for UI responsiveness
            savedSearches.removeAll { $0.searchId == searchId }
            newJobCounts.removeValue(forKey: searchId)
            
        } catch {
            handleError(error, message: "Failed to delete saved search")
            // Reload saved searches to ensure consistency
            await loadSavedSearches()
        }
    }
    
    /// Execute a saved search and return results
    func executeSavedSearch(_ search: SavedSearch) async -> JobSearchResponse? {
        guard let searchId = search.searchId else { return nil }
        
        isExecutingSearch = true
        errorMessage = nil
        
        do {
            let criteria = searchCriteriaFromSavedSearch(search)
            let response = try await apiService.searchJobs(criteria: criteria)
            
            // Update last checked timestamp
            search.updateLastChecked()
            try await persistenceService.updateSavedSearch(search)
            
            // Reset new job count for this search
            newJobCounts[searchId] = 0
            
            return response
            
        } catch {
            handleError(error, message: "Failed to execute saved search")
            return nil
        }
        
        isExecutingSearch = false
    }
    
    /// Toggle notification status for a saved search
    func toggleNotifications(for search: SavedSearch) async {
        do {
            // If enabling notifications, check permissions first
            if !search.isNotificationEnabled {
                let hasPermission = try await notificationService.requestNotificationPermissions()
                if !hasPermission {
                    errorMessage = "Notification permissions are required to receive job alerts"
                    return
                }
            }
            
            search.toggleNotifications()
            try await persistenceService.updateSavedSearch(search)
            
            // Cancel notifications if disabled
            if !search.isNotificationEnabled, let searchId = search.searchId {
                await notificationService.cancelNewJobsNotification(for: searchId)
            }
            
            // Update local array to reflect the change
            if let index = savedSearches.firstIndex(where: { $0.searchId == search.searchId }) {
                savedSearches[index] = search
            }
            
        } catch {
            handleError(error, message: "Failed to update notification settings")
        }
    }
    
    /// Check for new jobs matching saved searches
    func checkForNewJobs() async {
        for search in savedSearches {
            guard let searchId = search.searchId else { continue }
            
            do {
                let criteria = searchCriteriaFromSavedSearch(search)
                let response = try await apiService.searchJobs(criteria: criteria)
                
                // Calculate new jobs since last check
                let lastChecked = search.lastChecked ?? Date.distantPast
                let newJobs = response.jobs.filter { job in
                    guard let postedDate = job.matchedObjectDescriptor.publicationDate else { return false }
                    return postedDate > lastChecked
                }
                
                newJobCounts[searchId] = newJobs.count
                
            } catch {
                // Silently fail for individual searches to avoid disrupting the UI
                newJobCounts[searchId] = 0
            }
        }
    }
    
    /// Clear all error messages
    func clearError() {
        errorMessage = nil
    }
    
    /// Search within saved searches
    func searchSavedSearches(with text: String) {
        searchText = text
    }
    
    /// Show create search sheet
    func showCreateSearchSheet() {
        selectedSearch = nil
        showingCreateEditSheet = true
    }
    
    /// Show edit search sheet
    func showEditSearchSheet(for search: SavedSearch) {
        selectedSearch = search
        showingCreateEditSheet = true
    }
    
    /// Show delete confirmation alert
    func showDeleteConfirmation(for search: SavedSearch) {
        searchToDelete = search
        showingDeleteAlert = true
    }
    
    /// Confirm deletion of saved search
    func confirmDelete() async {
        guard let search = searchToDelete else { return }
        await deleteSavedSearch(search)
        searchToDelete = nil
        showingDeleteAlert = false
    }
    
    /// Cancel deletion
    func cancelDelete() {
        searchToDelete = nil
        showingDeleteAlert = false
    }
    
    // MARK: - Private Helper Methods
    
    /// Handle errors and set appropriate error messages
    private func handleError(_ error: Error, message: String) {
        if let persistenceError = error as? DataPersistenceError {
            switch persistenceError {
            case .savedSearchNotFound:
                errorMessage = "Saved search not found"
            case .coreDataError(let coreDataError):
                errorMessage = "Database error: \(coreDataError.localizedDescription)"
            default:
                errorMessage = persistenceError.localizedDescription
            }
        } else if let apiError = error as? APIError {
            switch apiError {
            case .noInternetConnection:
                errorMessage = "No internet connection. Unable to check for new jobs."
            case .rateLimitExceeded:
                errorMessage = "Too many requests. Please try again later."
            default:
                errorMessage = "Unable to execute search: \(apiError.localizedDescription)"
            }
        } else {
            errorMessage = "\(message): \(error.localizedDescription)"
        }
    }
    
    /// Convert SavedSearch entity to SearchCriteria
    private func searchCriteriaFromSavedSearch(_ search: SavedSearch) -> SearchCriteria {
        return SearchCriteria(
            keyword: search.keywords?.isEmpty == false ? search.keywords : nil,
            location: search.location?.isEmpty == false ? search.location : nil,
            department: search.department?.isEmpty == false ? search.department : nil,
            salaryMin: search.salaryMin > 0 ? Int(search.salaryMin) : nil,
            salaryMax: search.salaryMax > 0 ? Int(search.salaryMax) : nil,
            page: 1,
            resultsPerPage: 25,
            remoteOnly: false
        )
    }
}

// MARK: - Computed Properties

extension SavedSearchViewModel {
    
    /// Filtered saved searches based on search text
    var filteredSavedSearches: [SavedSearch] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return savedSearches
        }
        
        let searchTerm = searchText.lowercased()
        return savedSearches.filter { search in
            (search.name?.lowercased().contains(searchTerm) ?? false) ||
            (search.keywords?.lowercased().contains(searchTerm) ?? false) ||
            (search.location?.lowercased().contains(searchTerm) ?? false) ||
            (search.department?.lowercased().contains(searchTerm) ?? false)
        }
    }
    
    /// Whether the saved searches list is empty
    var isEmpty: Bool {
        return savedSearches.isEmpty
    }
    
    /// Whether the filtered list is empty
    var isFilteredListEmpty: Bool {
        return filteredSavedSearches.isEmpty
    }
    
    /// Whether to show the empty state
    var shouldShowEmptyState: Bool {
        return isEmpty && !isLoading
    }
    
    /// Whether to show the no results state (when search returns no results)
    var shouldShowNoResultsState: Bool {
        return !isEmpty && isFilteredListEmpty && !isLoading
    }
    
    /// Count of searches with notifications enabled
    var notificationEnabledCount: Int {
        return savedSearches.filter { $0.isNotificationEnabled }.count
    }
    
    /// Total count of new jobs across all searches
    var totalNewJobsCount: Int {
        return newJobCounts.values.reduce(0, +)
    }
    
    /// Summary text for saved searches
    var summaryText: String {
        let total = savedSearches.count
        let withNotifications = notificationEnabledCount
        let newJobs = totalNewJobsCount
        
        if total == 0 {
            return "No saved searches"
        } else if newJobs > 0 {
            return "\(total) saved search\(total == 1 ? "" : "es"), \(newJobs) new job\(newJobs == 1 ? "" : "s")"
        } else if withNotifications > 0 {
            return "\(total) saved search\(total == 1 ? "" : "es"), \(withNotifications) with notifications"
        } else {
            return "\(total) saved search\(total == 1 ? "" : "es")"
        }
    }
}

// MARK: - Convenience Methods for UI

extension SavedSearchViewModel {
    
    /// Get new job count for a specific search
    func newJobCount(for search: SavedSearch) -> Int {
        guard let searchId = search.searchId else { return 0 }
        return newJobCounts[searchId] ?? 0
    }
    
    /// Get formatted last checked display for a search
    func lastCheckedDisplay(for search: SavedSearch) -> String {
        guard let lastChecked = search.lastChecked else {
            return "Never checked"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return "Last checked \(formatter.localizedString(for: lastChecked, relativeTo: Date()))"
    }
    
    /// Get search criteria display string for a saved search
    func searchCriteriaDisplay(for search: SavedSearch) -> String {
        let criteria = searchCriteriaFromSavedSearch(search)
        return criteria.displayString
    }
    
    /// Check if a saved search has any criteria set
    func hasSearchCriteria(_ search: SavedSearch) -> Bool {
        let criteria = searchCriteriaFromSavedSearch(search)
        return criteria.hasFilters
    }
    
    /// Get notification status display for a search
    func notificationStatusDisplay(for search: SavedSearch) -> String {
        return search.isNotificationEnabled ? "Notifications on" : "Notifications off"
    }
    
    /// Get notification status color for a search
    func notificationStatusColor(for search: SavedSearch) -> Color {
        return search.isNotificationEnabled ? .green : .secondary
    }
    
    /// Get notification status system image for a search
    func notificationStatusImage(for search: SavedSearch) -> String {
        return search.isNotificationEnabled ? "bell.fill" : "bell.slash"
    }
}