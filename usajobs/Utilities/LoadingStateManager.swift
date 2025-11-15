//
//  LoadingStateManager.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Loading State Types

/// Represents different types of loading operations
enum LoadingOperation: String, CaseIterable {
    case searchJobs = "searchJobs"
    case loadJobDetails = "loadJobDetails"
    case loadFavorites = "loadFavorites"
    case toggleFavorite = "toggleFavorite"
    case loadSavedSearches = "loadSavedSearches"
    case saveSavedSearch = "saveSavedSearch"
    case loadApplications = "loadApplications"
    case updateApplicationStatus = "updateApplicationStatus"
    case refreshJobStatuses = "refreshJobStatuses"
    case loadMoreResults = "loadMoreResults"
    case syncOfflineData = "syncOfflineData"
    case sendNotification = "sendNotification"
    
    var displayName: String {
        switch self {
        case .searchJobs:
            return "Searching jobs..."
        case .loadJobDetails:
            return "Loading job details..."
        case .loadFavorites:
            return "Loading favorites..."
        case .toggleFavorite:
            return "Updating favorites..."
        case .loadSavedSearches:
            return "Loading saved searches..."
        case .saveSavedSearch:
            return "Saving search..."
        case .loadApplications:
            return "Loading applications..."
        case .updateApplicationStatus:
            return "Updating application..."
        case .refreshJobStatuses:
            return "Refreshing job statuses..."
        case .loadMoreResults:
            return "Loading more results..."
        case .syncOfflineData:
            return "Syncing data..."
        case .sendNotification:
            return "Sending notification..."
        }
    }
    
    var priority: LoadingPriority {
        switch self {
        case .searchJobs, .loadJobDetails:
            return .high
        case .loadFavorites, .loadSavedSearches, .loadApplications:
            return .medium
        case .toggleFavorite, .updateApplicationStatus, .saveSavedSearch:
            return .high
        case .refreshJobStatuses, .loadMoreResults:
            return .low
        case .syncOfflineData, .sendNotification:
            return .background
        }
    }
    
    var timeout: TimeInterval {
        switch self {
        case .searchJobs, .loadJobDetails, .refreshJobStatuses:
            return 30.0
        case .loadFavorites, .loadSavedSearches, .loadApplications:
            return 15.0
        case .toggleFavorite, .updateApplicationStatus, .saveSavedSearch:
            return 10.0
        case .loadMoreResults:
            return 20.0
        case .syncOfflineData:
            return 60.0
        case .sendNotification:
            return 5.0
        }
    }
}

/// Priority levels for loading operations
enum LoadingPriority: Int, Comparable {
    case background = 0
    case low = 1
    case medium = 2
    case high = 3
    
    static func < (lhs: LoadingPriority, rhs: LoadingPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Current state of a loading operation
enum LoadingState: Equatable {
    case idle
    case loading(progress: Double? = nil)
    case success
    case failed(AppError)
    
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
    
    var error: AppError? {
        if case .failed(let error) = self {
            return error
        }
        return nil
    }
    
    var progress: Double? {
        if case .loading(let progress) = self {
            return progress
        }
        return nil
    }
}

// MARK: - Loading State Manager

/// Centralized manager for handling loading states across the app
@MainActor
class LoadingStateManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Dictionary of current loading states for each operation
    @Published private(set) var loadingStates: [LoadingOperation: LoadingState] = [:]
    
    /// Whether any high-priority operation is currently loading
    @Published private(set) var isHighPriorityLoading = false
    
    /// Whether any operation is currently loading
    @Published private(set) var isAnyLoading = false
    
    /// Current primary loading message to display
    @Published private(set) var primaryLoadingMessage: String?
    
    /// Queue of pending operations
    @Published private(set) var pendingOperations: [LoadingOperation] = []
    
    // MARK: - Private Properties
    
    private var operationTasks: [LoadingOperation: Task<Void, Never>] = [:]
    private var operationTimeouts: [LoadingOperation: Task<Void, Never>] = [:]
    private let errorHandler: ErrorHandlerProtocol
    
    // MARK: - Initialization
    
    init(errorHandler: ErrorHandlerProtocol = DefaultErrorHandler()) {
        self.errorHandler = errorHandler
        
        // Initialize all operations as idle
        for operation in LoadingOperation.allCases {
            loadingStates[operation] = .idle
        }
    }
    
    // MARK: - Public Methods
    
    /// Start a loading operation
    func startLoading(_ operation: LoadingOperation, progress: Double? = nil) {
        loadingStates[operation] = .loading(progress: progress)
        updateGlobalStates()
        startTimeoutTimer(for: operation)
    }
    
    /// Update progress for a loading operation
    func updateProgress(_ operation: LoadingOperation, progress: Double) {
        if case .loading = loadingStates[operation] {
            loadingStates[operation] = .loading(progress: progress)
        }
    }
    
    /// Mark an operation as successful
    func setSuccess(_ operation: LoadingOperation) {
        loadingStates[operation] = .success
        cancelTimeout(for: operation)
        updateGlobalStates()
        
        // Auto-reset to idle after a short delay
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            if loadingStates[operation] == .success {
                loadingStates[operation] = .idle
                updateGlobalStates()
            }
        }
    }
    
    /// Mark an operation as failed
    func setError(_ operation: LoadingOperation, error: Error) {
        let appError = errorHandler.handle(error)
        loadingStates[operation] = .failed(appError)
        cancelTimeout(for: operation)
        updateGlobalStates()
    }
    
    /// Clear error state for an operation
    func clearError(_ operation: LoadingOperation) {
        if case .failed = loadingStates[operation] {
            loadingStates[operation] = .idle
            updateGlobalStates()
        }
    }
    
    /// Clear all error states
    func clearAllErrors() {
        for operation in LoadingOperation.allCases {
            if case .failed = loadingStates[operation] {
                loadingStates[operation] = .idle
            }
        }
        updateGlobalStates()
    }
    
    /// Cancel a loading operation
    func cancelLoading(_ operation: LoadingOperation) {
        operationTasks[operation]?.cancel()
        operationTasks.removeValue(forKey: operation)
        cancelTimeout(for: operation)
        
        if case .loading = loadingStates[operation] {
            loadingStates[operation] = .idle
            updateGlobalStates()
        }
    }
    
    /// Cancel all loading operations
    func cancelAllLoading() {
        for operation in LoadingOperation.allCases {
            cancelLoading(operation)
        }
    }
    
    /// Get the current state of an operation
    func getState(_ operation: LoadingOperation) -> LoadingState {
        return loadingStates[operation] ?? .idle
    }
    
    /// Check if an operation is currently loading
    func isLoading(_ operation: LoadingOperation) -> Bool {
        return getState(operation).isLoading
    }
    
    /// Check if an operation has failed
    func hasFailed(_ operation: LoadingOperation) -> Bool {
        return getState(operation).isFailed
    }
    
    /// Get error for an operation
    func getError(_ operation: LoadingOperation) -> AppError? {
        return getState(operation).error
    }
    
    /// Execute an operation with automatic state management
    func executeOperation<T>(
        _ operation: LoadingOperation,
        task: @escaping () async throws -> T
    ) async -> Result<T, AppError> {
        startLoading(operation)
        
        do {
            let result = try await task()
            setSuccess(operation)
            return .success(result)
        } catch {
            let appError = errorHandler.handle(error)
            setError(operation, error: appError)
            return .failure(appError)
        }
    }
    
    /// Execute an operation with retry logic
    func executeOperationWithRetry<T>(
        _ operation: LoadingOperation,
        maxAttempts: Int = 3,
        task: @escaping () async throws -> T
    ) async -> Result<T, AppError> {
        var lastError: AppError?
        
        for attempt in 1...maxAttempts {
            startLoading(operation)
            
            do {
                let result = try await task()
                setSuccess(operation)
                return .success(result)
            } catch {
                let appError = errorHandler.handle(error)
                lastError = appError
                
                if attempt < maxAttempts && errorHandler.shouldRetry(appError, attemptCount: attempt) {
                    let delay = errorHandler.getRetryDelay(appError, attemptCount: attempt)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    setError(operation, error: appError)
                    return .failure(appError)
                }
            }
        }
        
        let finalError = lastError ?? .unknown("All retry attempts failed")
        setError(operation, error: finalError)
        return .failure(finalError)
    }
    
    // MARK: - Private Methods
    
    /// Update global loading states
    private func updateGlobalStates() {
        let loadingOperations = loadingStates.compactMap { (operation, state) in
            state.isLoading ? operation : nil
        }
        
        isAnyLoading = !loadingOperations.isEmpty
        isHighPriorityLoading = loadingOperations.contains { $0.priority == .high }
        
        // Update primary loading message
        if let highPriorityOperation = loadingOperations.first(where: { $0.priority == .high }) {
            primaryLoadingMessage = highPriorityOperation.displayName
        } else if let mediumPriorityOperation = loadingOperations.first(where: { $0.priority == .medium }) {
            primaryLoadingMessage = mediumPriorityOperation.displayName
        } else if let anyOperation = loadingOperations.first {
            primaryLoadingMessage = anyOperation.displayName
        } else {
            primaryLoadingMessage = nil
        }
    }
    
    /// Start timeout timer for an operation
    private func startTimeoutTimer(for operation: LoadingOperation) {
        cancelTimeout(for: operation)
        
        operationTimeouts[operation] = Task {
            try? await Task.sleep(nanoseconds: UInt64(operation.timeout * 1_000_000_000))
            
            if !Task.isCancelled && isLoading(operation) {
                setError(operation, error: AppError.network(.timeout))
            }
        }
    }
    
    /// Cancel timeout timer for an operation
    private func cancelTimeout(for operation: LoadingOperation) {
        operationTimeouts[operation]?.cancel()
        operationTimeouts.removeValue(forKey: operation)
    }
}

// MARK: - Convenience Extensions

extension LoadingStateManager {
    
    /// Get all currently loading operations
    var currentlyLoadingOperations: [LoadingOperation] {
        return loadingStates.compactMap { (operation, state) in
            state.isLoading ? operation : nil
        }
    }
    
    /// Get all failed operations
    var failedOperations: [LoadingOperation] {
        return loadingStates.compactMap { (operation, state) in
            state.isFailed ? operation : nil
        }
    }
    
    /// Get loading progress for operations that support it
    func getProgress(_ operation: LoadingOperation) -> Double? {
        return getState(operation).progress
    }
    
    /// Check if any critical operation is loading
    var isCriticalOperationLoading: Bool {
        let criticalOperations: [LoadingOperation] = [.searchJobs, .loadJobDetails, .toggleFavorite]
        return criticalOperations.contains { isLoading($0) }
    }
    
    /// Get summary of current loading state
    var loadingSummary: String {
        let loadingCount = currentlyLoadingOperations.count
        let failedCount = failedOperations.count
        
        if loadingCount > 0 && failedCount > 0 {
            return "\(loadingCount) loading, \(failedCount) failed"
        } else if loadingCount > 0 {
            return "\(loadingCount) operation\(loadingCount == 1 ? "" : "s") loading"
        } else if failedCount > 0 {
            return "\(failedCount) operation\(failedCount == 1 ? "" : "s") failed"
        } else {
            return "All operations complete"
        }
    }
    
    /// Clear completed operations to free memory
    func clearCompletedOperations() {
        for operation in LoadingOperation.allCases {
            let state = loadingStates[operation] ?? .idle
            if case .success = state {
                loadingStates[operation] = .idle
            }
        }
        
        // Clean up completed tasks
        operationTasks = operationTasks.filter { _, task in
            !task.isCancelled
        }
        
        updateGlobalStates()
    }
}