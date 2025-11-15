//
//  FavoritesViewModel.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for managing favorite jobs functionality
@MainActor
class FavoritesViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// List of favorite jobs
    @Published var favoriteJobs: [Job] = []
    
    /// Loading state for favorites fetch
    @Published var isLoading = false
    
    /// Loading state for status refresh
    @Published var isRefreshingStatuses = false
    
    /// Error message to display to user
    @Published var errorMessage: String?
    
    /// Search text for filtering favorites
    @Published var searchText = ""
    
    /// Selected filter option
    @Published var selectedFilter: FavoriteFilter = .all
    
    // MARK: - Private Properties
    
    private let persistenceService: DataPersistenceServiceProtocol
    private let apiService: USAJobsAPIServiceProtocol
    private let loadingStateManager: LoadingStateManager
    private let errorHandler: ErrorHandlerProtocol
    
    // MARK: - Initialization

    init(
        persistenceService: DataPersistenceServiceProtocol,
        apiService: USAJobsAPIServiceProtocol,
        loadingStateManager: LoadingStateManager? = nil,
        errorHandler: ErrorHandlerProtocol? = nil
    ) {
        self.persistenceService = persistenceService
        self.apiService = apiService
        self.loadingStateManager = loadingStateManager ?? LoadingStateManager()
        self.errorHandler = errorHandler ?? DefaultErrorHandler()
    }
    
    // MARK: - Public Methods
    
    /// Load all favorite jobs from persistence
    func loadFavorites() async {
        let result = await loadingStateManager.executeOperationWithRetry(.loadFavorites) {
            return try await self.persistenceService.getFavoriteJobs()
        }
        
        switch result {
        case .success(let jobs):
            favoriteJobs = jobs
            
        case .failure(let appError):
            errorMessage = appError.localizedDescription
        }
        
        // Update legacy loading state for UI compatibility
        isLoading = loadingStateManager.isLoading(.loadFavorites)
    }
    
    /// Remove a job from favorites
    func removeFavorite(job: Job) async {
        guard let jobId = job.jobId else { return }
        
        let result = await loadingStateManager.executeOperation(.toggleFavorite) {
            try await self.persistenceService.removeFavoriteJob(jobId: jobId)
        }
        
        switch result {
        case .success:
            // Remove from local array immediately for UI responsiveness
            favoriteJobs.removeAll { $0.jobId == jobId }
            
        case .failure(let appError):
            errorMessage = appError.localizedDescription
            // Reload favorites to ensure consistency
            await loadFavorites()
        }
    }
    
    /// Remove multiple jobs from favorites
    func removeFavorites(jobs: [Job]) async {
        for job in jobs {
            await removeFavorite(job: job)
        }
    }
    
    /// Refresh job statuses by checking with API
    func refreshJobStatuses() async {
        guard !favoriteJobs.isEmpty else { return }
        
        let result = await loadingStateManager.executeOperationWithRetry(.refreshJobStatuses) {
            var updatedJobs: [Job] = []
            
            for job in self.favoriteJobs {
                guard let jobId = job.jobId else {
                    updatedJobs.append(job)
                    continue
                }
                
                do {
                    // Try to fetch updated job details from API
                    let updatedDetails = try await self.apiService.getJobDetails(jobId: jobId)
                    
                    // Update the job entity with fresh data
                    self.updateJobEntity(job, with: updatedDetails)
                    updatedJobs.append(job)
                    
                } catch {
                    // If API call fails, keep the existing job but mark it as potentially stale
                    updatedJobs.append(job)
                }
            }
            
            // Save updated jobs to persistence
            for job in updatedJobs {
                try await self.persistenceService.cacheJob(job)
            }
            
            return updatedJobs
        }
        
        switch result {
        case .success:
            // Reload favorites to get the updated data
            await loadFavorites()
            
        case .failure(let appError):
            errorMessage = appError.localizedDescription
        }
        
        // Update legacy loading state for UI compatibility
        isRefreshingStatuses = loadingStateManager.isLoading(.refreshJobStatuses)
    }
    
    /// Toggle favorite status for a job (used when job is unfavorited from other screens)
    func toggleFavoriteStatus(jobId: String) async {
        do {
            let isFavorited = try await persistenceService.toggleFavoriteStatus(jobId: jobId)
            
            if !isFavorited {
                // Job was unfavorited, remove from local list
                favoriteJobs.removeAll { $0.jobId == jobId }
            } else {
                // Job was favorited, reload favorites to include it
                await loadFavorites()
            }
            
        } catch {
            handleError(error, message: "Failed to update favorite status")
        }
    }
    
    /// Clear all error messages
    func clearError() {
        errorMessage = nil
    }
    
    /// Search within favorites
    func searchFavorites(with text: String) {
        searchText = text
    }
    
    /// Apply filter to favorites
    func applyFilter(_ filter: FavoriteFilter) {
        selectedFilter = filter
    }
    
    /// Retry failed operations
    func retryFailedOperation() async {
        if loadingStateManager.hasFailed(.loadFavorites) {
            await loadFavorites()
        } else if loadingStateManager.hasFailed(.refreshJobStatuses) {
            await refreshJobStatuses()
        } else if loadingStateManager.hasFailed(.toggleFavorite) {
            // Clear the error state for retry
            loadingStateManager.clearError(.toggleFavorite)
        }
    }
    
    /// Clear all errors
    func clearAllErrors() {
        loadingStateManager.clearAllErrors()
        errorMessage = nil
    }
    
    /// Get current loading state for specific operation
    func getLoadingState(_ operation: LoadingOperation) -> LoadingState {
        return loadingStateManager.getState(operation)
    }
    
    /// Check if any operation is currently loading
    var isAnyOperationLoading: Bool {
        return loadingStateManager.isAnyLoading
    }
    
    /// Get primary loading message
    var primaryLoadingMessage: String? {
        return loadingStateManager.primaryLoadingMessage
    }
    
    // MARK: - Private Helper Methods
    
    /// Handle errors and set appropriate error messages
    private func handleError(_ error: Error, message: String) {
        if let persistenceError = error as? DataPersistenceError {
            switch persistenceError {
            case .jobNotFound:
                errorMessage = "Job not found in favorites"
            case .coreDataError(let coreDataError):
                errorMessage = "Database error: \(coreDataError.localizedDescription)"
            default:
                errorMessage = persistenceError.localizedDescription
            }
        } else if let apiError = error as? APIError {
            switch apiError {
            case .noInternetConnection:
                errorMessage = "No internet connection. Showing cached data."
            case .rateLimitExceeded:
                errorMessage = "Too many requests. Status refresh temporarily unavailable."
            default:
                errorMessage = "Unable to refresh job statuses"
            }
        } else {
            errorMessage = "\(message): \(error.localizedDescription)"
        }
    }
    
    /// Update job entity with fresh API data
    private func updateJobEntity(_ job: Job, with details: JobDescriptor) {
        let salaryRange = details.salaryRange
        job.salaryMin = Int32(salaryRange.min ?? 0)
        job.salaryMax = Int32(salaryRange.max ?? 0)
        job.applicationDeadline = details.applicationDeadline
        job.datePosted = details.publicationDate
        job.updateCacheTimestamp()
    }
}

// MARK: - Computed Properties

extension FavoritesViewModel {
    
    /// Filtered favorite jobs based on search text and selected filter
    var filteredFavoriteJobs: [Job] {
        var filtered = favoriteJobs
        
        // Apply text search filter
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let searchTerm = searchText.lowercased()
            filtered = filtered.filter { job in
                (job.title?.lowercased().contains(searchTerm) ?? false) ||
                (job.department?.lowercased().contains(searchTerm) ?? false) ||
                (job.location?.lowercased().contains(searchTerm) ?? false)
            }
        }
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break // No additional filtering
        case .active:
            filtered = filtered.filter { !$0.isExpired }
        case .expired:
            filtered = filtered.filter { $0.isExpired }
        case .recentlyAdded:
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            filtered = filtered.filter { job in
                guard let cachedAt = job.cachedAt else { return false }
                return cachedAt >= sevenDaysAgo
            }
        }
        
        return filtered
    }
    
    /// Whether the favorites list is empty
    var isEmpty: Bool {
        return favoriteJobs.isEmpty
    }
    
    /// Whether the filtered list is empty
    var isFilteredListEmpty: Bool {
        return filteredFavoriteJobs.isEmpty
    }
    
    /// Whether to show the empty state
    var shouldShowEmptyState: Bool {
        return isEmpty && !isLoading
    }
    
    /// Whether to show the no results state (when search/filter returns no results)
    var shouldShowNoResultsState: Bool {
        return !isEmpty && isFilteredListEmpty && !isLoading
    }
    
    /// Count of active (non-expired) jobs
    var activeJobsCount: Int {
        return favoriteJobs.filter { !$0.isExpired }.count
    }
    
    /// Count of expired jobs
    var expiredJobsCount: Int {
        return favoriteJobs.filter { $0.isExpired }.count
    }
    
    /// Summary text for favorites
    var summaryText: String {
        let total = favoriteJobs.count
        let active = activeJobsCount
        let expired = expiredJobsCount
        
        if total == 0 {
            return "No favorite jobs"
        } else if expired == 0 {
            return "\(total) favorite job\(total == 1 ? "" : "s")"
        } else {
            return "\(active) active, \(expired) expired"
        }
    }
}

// MARK: - Filter Options

enum FavoriteFilter: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case expired = "Expired"
    case recentlyAdded = "Recently Added"
    
    var displayName: String {
        return rawValue
    }
    
    var systemImage: String {
        switch self {
        case .all:
            return "list.bullet"
        case .active:
            return "checkmark.circle"
        case .expired:
            return "clock.badge.xmark"
        case .recentlyAdded:
            return "clock.arrow.circlepath"
        }
    }
}

// MARK: - Convenience Methods for UI

extension FavoritesViewModel {
    
    /// Get formatted salary display for a job
    func salaryDisplay(for job: Job) -> String {
        let min = job.salaryMin
        let max = job.salaryMax
        
        switch (min, max) {
        case (let minVal, let maxVal) where minVal > 0 && maxVal > 0:
            return "$\(Int(minVal).formatted()) - $\(Int(maxVal).formatted())"
        case (let minVal, _) where minVal > 0:
            return "$\(Int(minVal).formatted())+"
        case (_, let maxVal) where maxVal > 0:
            return "Up to $\(Int(maxVal).formatted())"
        default:
            return "Salary not specified"
        }
    }
    
    /// Get formatted application deadline for a job
    func applicationDeadlineDisplay(for job: Job) -> String {
        guard let deadline = job.applicationDeadline else {
            return "No deadline specified"
        }
        
        if job.isExpired {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Expired \(formatter.string(from: deadline))"
        } else {
            let daysUntil = job.daysUntilDeadline ?? 0
            if daysUntil <= 0 {
                return "Deadline today"
            } else if daysUntil == 1 {
                return "1 day remaining"
            } else if daysUntil <= 7 {
                return "\(daysUntil) days remaining"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "Apply by \(formatter.string(from: deadline))"
            }
        }
    }
    
    /// Check if a job application deadline is approaching (within 7 days)
    func isDeadlineApproaching(for job: Job) -> Bool {
        guard let daysUntil = job.daysUntilDeadline else { return false }
        return daysUntil <= 7 && daysUntil >= 0
    }
    
    /// Get status indicator color for a job
    func statusIndicatorColor(for job: Job) -> Color {
        if job.isExpired {
            return .red
        } else if isDeadlineApproaching(for: job) {
            return .orange
        } else {
            return .green
        }
    }
    
    /// Get status indicator system image for a job
    func statusIndicatorImage(for job: Job) -> String {
        if job.isExpired {
            return "clock.badge.xmark"
        } else if isDeadlineApproaching(for: job) {
            return "clock.badge.exclamationmark"
        } else {
            return "clock.badge.checkmark"
        }
    }
    
    /// Get formatted date when job was added to favorites
    func dateAddedDisplay(for job: Job) -> String {
        guard let cachedAt = job.cachedAt else {
            return "Date unknown"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return "Added \(formatter.localizedString(for: cachedAt, relativeTo: Date()))"
    }
    
    /// Clean up unused resources for memory optimization
    func cleanupUnusedResources() {
        // Clear error messages that are no longer relevant
        if !isLoading && !isRefreshingStatuses {
            errorMessage = nil
        }
        
        // Clear search text if it's not being used
        if filteredFavoriteJobs.count == favoriteJobs.count {
            searchText = ""
        }
        
        // Clear loading state manager cache
        loadingStateManager.clearCompletedOperations()
        
        // If we have too many favorite jobs cached, consider removing old expired ones
        let expiredJobs = favoriteJobs.filter { $0.isExpired }
        if expiredJobs.count > 50 {
            // Keep only the 25 most recently expired jobs
            let sortedExpired = expiredJobs.sorted { job1, job2 in
                (job1.applicationDeadline ?? Date.distantPast) > (job2.applicationDeadline ?? Date.distantPast)
            }
            
            let jobsToRemove = Array(sortedExpired.dropFirst(25))
            for job in jobsToRemove {
                favoriteJobs.removeAll { $0.objectID == job.objectID }
            }
        }
    }
}