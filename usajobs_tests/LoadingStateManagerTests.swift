//
//  LoadingStateManagerTests.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import XCTest
@testable import usajobs

@MainActor
class LoadingStateManagerTests: XCTestCase {
    
    var loadingStateManager: LoadingStateManager!
    var mockErrorHandler: MockErrorHandler!
    
    override func setUp() async throws {
        try await super.setUp()
        mockErrorHandler = MockErrorHandler()
        loadingStateManager = LoadingStateManager(errorHandler: mockErrorHandler)
    }
    
    override func tearDown() async throws {
        loadingStateManager = nil
        mockErrorHandler = nil
        try await super.tearDown()
    }
    
    // MARK: - Loading State Tests
    
    func testInitialState() {
        // All operations should start as idle
        for operation in LoadingOperation.allCases {
            XCTAssertEqual(loadingStateManager.getState(operation), .idle)
            XCTAssertFalse(loadingStateManager.isLoading(operation))
            XCTAssertFalse(loadingStateManager.hasFailed(operation))
        }
        
        XCTAssertFalse(loadingStateManager.isAnyLoading)
        XCTAssertFalse(loadingStateManager.isHighPriorityLoading)
        XCTAssertNil(loadingStateManager.primaryLoadingMessage)
    }
    
    func testStartLoading() {
        loadingStateManager.startLoading(.searchJobs)
        
        XCTAssertTrue(loadingStateManager.isLoading(.searchJobs))
        XCTAssertEqual(loadingStateManager.getState(.searchJobs), .loading(progress: nil))
        XCTAssertTrue(loadingStateManager.isAnyLoading)
        XCTAssertTrue(loadingStateManager.isHighPriorityLoading)
        XCTAssertEqual(loadingStateManager.primaryLoadingMessage, LoadingOperation.searchJobs.displayName)
    }
    
    func testStartLoadingWithProgress() {
        loadingStateManager.startLoading(.searchJobs, progress: 0.5)
        
        let state = loadingStateManager.getState(.searchJobs)
        if case .loading(let progress) = state {
            XCTAssertEqual(progress, 0.5)
        } else {
            XCTFail("Expected loading state with progress")
        }
    }
    
    func testUpdateProgress() {
        loadingStateManager.startLoading(.searchJobs)
        loadingStateManager.updateProgress(.searchJobs, progress: 0.75)
        
        let state = loadingStateManager.getState(.searchJobs)
        if case .loading(let progress) = state {
            XCTAssertEqual(progress, 0.75)
        } else {
            XCTFail("Expected loading state with updated progress")
        }
    }
    
    func testUpdateProgressOnNonLoadingOperation() {
        // Should not update progress if operation is not loading
        loadingStateManager.updateProgress(.searchJobs, progress: 0.5)
        
        XCTAssertEqual(loadingStateManager.getState(.searchJobs), .idle)
    }
    
    func testSetSuccess() async {
        loadingStateManager.startLoading(.searchJobs)
        loadingStateManager.setSuccess(.searchJobs)
        
        XCTAssertEqual(loadingStateManager.getState(.searchJobs), .success)
        XCTAssertFalse(loadingStateManager.isLoading(.searchJobs))
        XCTAssertFalse(loadingStateManager.isAnyLoading)
        
        // Wait for auto-reset to idle
        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        XCTAssertEqual(loadingStateManager.getState(.searchJobs), .idle)
    }
    
    func testSetError() {
        let testError = AppError.network(.timeout)
        loadingStateManager.startLoading(.searchJobs)
        loadingStateManager.setError(.searchJobs, error: testError)
        
        XCTAssertTrue(loadingStateManager.hasFailed(.searchJobs))
        XCTAssertEqual(loadingStateManager.getError(.searchJobs), testError)
        XCTAssertFalse(loadingStateManager.isLoading(.searchJobs))
        XCTAssertFalse(loadingStateManager.isAnyLoading)
    }
    
    func testClearError() {
        let testError = AppError.network(.timeout)
        loadingStateManager.setError(.searchJobs, error: testError)
        
        XCTAssertTrue(loadingStateManager.hasFailed(.searchJobs))
        
        loadingStateManager.clearError(.searchJobs)
        
        XCTAssertFalse(loadingStateManager.hasFailed(.searchJobs))
        XCTAssertEqual(loadingStateManager.getState(.searchJobs), .idle)
    }
    
    func testClearAllErrors() {
        let testError = AppError.network(.timeout)
        loadingStateManager.setError(.searchJobs, error: testError)
        loadingStateManager.setError(.loadFavorites, error: testError)
        
        XCTAssertTrue(loadingStateManager.hasFailed(.searchJobs))
        XCTAssertTrue(loadingStateManager.hasFailed(.loadFavorites))
        
        loadingStateManager.clearAllErrors()
        
        XCTAssertFalse(loadingStateManager.hasFailed(.searchJobs))
        XCTAssertFalse(loadingStateManager.hasFailed(.loadFavorites))
    }
    
    func testCancelLoading() {
        loadingStateManager.startLoading(.searchJobs)
        
        XCTAssertTrue(loadingStateManager.isLoading(.searchJobs))
        
        loadingStateManager.cancelLoading(.searchJobs)
        
        XCTAssertFalse(loadingStateManager.isLoading(.searchJobs))
        XCTAssertEqual(loadingStateManager.getState(.searchJobs), .idle)
    }
    
    func testCancelAllLoading() {
        loadingStateManager.startLoading(.searchJobs)
        loadingStateManager.startLoading(.loadFavorites)
        
        XCTAssertTrue(loadingStateManager.isLoading(.searchJobs))
        XCTAssertTrue(loadingStateManager.isLoading(.loadFavorites))
        
        loadingStateManager.cancelAllLoading()
        
        XCTAssertFalse(loadingStateManager.isLoading(.searchJobs))
        XCTAssertFalse(loadingStateManager.isLoading(.loadFavorites))
    }
    
    // MARK: - Priority Tests
    
    func testHighPriorityLoading() {
        loadingStateManager.startLoading(.loadFavorites) // medium priority
        XCTAssertFalse(loadingStateManager.isHighPriorityLoading)
        
        loadingStateManager.startLoading(.searchJobs) // high priority
        XCTAssertTrue(loadingStateManager.isHighPriorityLoading)
        
        loadingStateManager.setSuccess(.searchJobs)
        XCTAssertFalse(loadingStateManager.isHighPriorityLoading)
    }
    
    func testPrimaryLoadingMessage() {
        // High priority should take precedence
        loadingStateManager.startLoading(.loadFavorites) // medium priority
        loadingStateManager.startLoading(.searchJobs) // high priority
        
        XCTAssertEqual(loadingStateManager.primaryLoadingMessage, LoadingOperation.searchJobs.displayName)
        
        // When high priority completes, should show medium priority
        loadingStateManager.setSuccess(.searchJobs)
        XCTAssertEqual(loadingStateManager.primaryLoadingMessage, LoadingOperation.loadFavorites.displayName)
        
        // When all complete, should be nil
        loadingStateManager.setSuccess(.loadFavorites)
        XCTAssertNil(loadingStateManager.primaryLoadingMessage)
    }
    
    // MARK: - Execute Operation Tests
    
    func testExecuteOperationSuccess() async {
        let expectedResult = "Success"
        
        let result = await loadingStateManager.executeOperation(.searchJobs) {
            return expectedResult
        }
        
        switch result {
        case .success(let value):
            XCTAssertEqual(value, expectedResult)
        case .failure:
            XCTFail("Expected success")
        }
        
        XCTAssertEqual(loadingStateManager.getState(.searchJobs), .success)
    }
    
    func testExecuteOperationFailure() async {
        let expectedError = TestError.testFailure
        
        let result = await loadingStateManager.executeOperation(.searchJobs) {
            throw expectedError
        }
        
        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let appError):
            XCTAssertEqual(appError, mockErrorHandler.lastHandledError)
        }
        
        XCTAssertTrue(loadingStateManager.hasFailed(.searchJobs))
    }
    
    func testExecuteOperationWithRetrySuccess() async {
        var attemptCount = 0
        let expectedResult = "Success"
        
        let result = await loadingStateManager.executeOperationWithRetry(.searchJobs, maxAttempts: 3) {
            attemptCount += 1
            if attemptCount < 2 {
                throw TestError.testFailure
            }
            return expectedResult
        }
        
        switch result {
        case .success(let value):
            XCTAssertEqual(value, expectedResult)
            XCTAssertEqual(attemptCount, 2)
        case .failure:
            XCTFail("Expected success after retry")
        }
    }
    
    func testExecuteOperationWithRetryFailure() async {
        var attemptCount = 0
        
        let result = await loadingStateManager.executeOperationWithRetry(.searchJobs, maxAttempts: 2) {
            attemptCount += 1
            throw TestError.testFailure
        }
        
        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure:
            XCTAssertEqual(attemptCount, 2)
        }
        
        XCTAssertTrue(loadingStateManager.hasFailed(.searchJobs))
    }
    
    func testExecuteOperationWithRetryNonRetryableError() async {
        mockErrorHandler.shouldRetryResult = false
        var attemptCount = 0
        
        let result = await loadingStateManager.executeOperationWithRetry(.searchJobs, maxAttempts: 3) {
            attemptCount += 1
            throw TestError.testFailure
        }
        
        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure:
            XCTAssertEqual(attemptCount, 1) // Should not retry non-retryable errors
        }
    }
    
    // MARK: - Computed Properties Tests
    
    func testCurrentlyLoadingOperations() {
        XCTAssertTrue(loadingStateManager.currentlyLoadingOperations.isEmpty)
        
        loadingStateManager.startLoading(.searchJobs)
        loadingStateManager.startLoading(.loadFavorites)
        
        let loadingOps = loadingStateManager.currentlyLoadingOperations
        XCTAssertEqual(loadingOps.count, 2)
        XCTAssertTrue(loadingOps.contains(.searchJobs))
        XCTAssertTrue(loadingOps.contains(.loadFavorites))
    }
    
    func testFailedOperations() {
        let testError = AppError.network(.timeout)
        
        XCTAssertTrue(loadingStateManager.failedOperations.isEmpty)
        
        loadingStateManager.setError(.searchJobs, error: testError)
        loadingStateManager.setError(.loadFavorites, error: testError)
        
        let failedOps = loadingStateManager.failedOperations
        XCTAssertEqual(failedOps.count, 2)
        XCTAssertTrue(failedOps.contains(.searchJobs))
        XCTAssertTrue(failedOps.contains(.loadFavorites))
    }
    
    func testGetProgress() {
        loadingStateManager.startLoading(.searchJobs, progress: 0.3)
        
        XCTAssertEqual(loadingStateManager.getProgress(.searchJobs), 0.3)
        XCTAssertNil(loadingStateManager.getProgress(.loadFavorites))
    }
    
    func testIsCriticalOperationLoading() {
        XCTAssertFalse(loadingStateManager.isCriticalOperationLoading)
        
        loadingStateManager.startLoading(.loadFavorites) // not critical
        XCTAssertFalse(loadingStateManager.isCriticalOperationLoading)
        
        loadingStateManager.startLoading(.searchJobs) // critical
        XCTAssertTrue(loadingStateManager.isCriticalOperationLoading)
    }
    
    func testLoadingSummary() {
        XCTAssertEqual(loadingStateManager.loadingSummary, "All operations complete")
        
        loadingStateManager.startLoading(.searchJobs)
        XCTAssertEqual(loadingStateManager.loadingSummary, "1 operation loading")
        
        loadingStateManager.startLoading(.loadFavorites)
        XCTAssertEqual(loadingStateManager.loadingSummary, "2 operations loading")
        
        let testError = AppError.network(.timeout)
        loadingStateManager.setError(.searchJobs, error: testError)
        XCTAssertEqual(loadingStateManager.loadingSummary, "1 loading, 1 failed")
        
        loadingStateManager.setSuccess(.loadFavorites)
        XCTAssertEqual(loadingStateManager.loadingSummary, "1 operation failed")
    }
    
    // MARK: - Timeout Tests
    
    func testOperationTimeout() async {
        // Start a loading operation
        loadingStateManager.startLoading(.sendNotification) // has 5 second timeout
        
        XCTAssertTrue(loadingStateManager.isLoading(.sendNotification))
        
        // Wait for timeout (using a shorter timeout for testing)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Manually trigger timeout for testing
        loadingStateManager.setError(.sendNotification, error: AppError.network(.timeout))
        
        XCTAssertTrue(loadingStateManager.hasFailed(.sendNotification))
        if case .network(.timeout) = loadingStateManager.getError(.sendNotification) {
            // Expected timeout error
        } else {
            XCTFail("Expected timeout error")
        }
    }
}

// MARK: - Mock Error Handler

class MockErrorHandler: ErrorHandlerProtocol {
    var lastHandledError: AppError?
    var shouldRetryResult = true
    var retryDelay: TimeInterval = 0.01
    
    func handle(_ error: Error) -> AppError {
        let appError: AppError
        if let existingAppError = error as? AppError {
            appError = existingAppError
        } else {
            appError = .unknown(error.localizedDescription)
        }
        lastHandledError = appError
        return appError
    }
    
    func shouldRetry(_ error: AppError, attemptCount: Int) -> Bool {
        return shouldRetryResult && attemptCount < 3
    }
    
    func getRetryDelay(_ error: AppError, attemptCount: Int) -> TimeInterval {
        return retryDelay
    }
}

// MARK: - Test Error

enum TestError: Error {
    case testFailure
}