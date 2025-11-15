//
//  ErrorHandlingTests.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import XCTest
@testable import usajobs

class ErrorHandlingTests: XCTestCase {
    
    var errorHandler: DefaultErrorHandler!
    
    override func setUp() {
        super.setUp()
        errorHandler = DefaultErrorHandler(maxRetryAttempts: 3, baseRetryDelay: 0.1)
    }
    
    override func tearDown() {
        errorHandler = nil
        super.tearDown()
    }
    
    // MARK: - App Error Tests
    
    func testAppErrorEquality() {
        let error1 = AppError.network(.noConnection)
        let error2 = AppError.network(.noConnection)
        let error3 = AppError.network(.timeout)
        
        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }
    
    func testAppErrorLocalizedDescription() {
        let networkError = AppError.network(.noConnection)
        XCTAssertEqual(networkError.localizedDescription, "No Internet Connection")
        
        let persistenceError = AppError.persistence(.saveFailed)
        XCTAssertEqual(persistenceError.localizedDescription, "Save Failed")
        
        let validationError = AppError.validation(.emptySearchCriteria)
        XCTAssertEqual(validationError.localizedDescription, "Empty Search Criteria")
        
        let systemError = AppError.system(.permissionDenied)
        XCTAssertEqual(systemError.localizedDescription, "Permission Denied")
        
        let unknownError = AppError.unknown("Test error")
        XCTAssertEqual(unknownError.localizedDescription, "Test error")
    }
    
    func testAppErrorRecoverySuggestion() {
        let networkError = AppError.network(.noConnection)
        XCTAssertEqual(networkError.recoverySuggestion, "Please check your internet connection and try again.")
        
        let persistenceError = AppError.persistence(.saveFailed)
        XCTAssertEqual(persistenceError.recoverySuggestion, "Please try saving again or free up storage space.")
        
        let validationError = AppError.validation(.emptySearchCriteria)
        XCTAssertEqual(validationError.recoverySuggestion, "Please enter at least one search criterion.")
        
        let systemError = AppError.system(.permissionDenied)
        XCTAssertEqual(systemError.recoverySuggestion, "Please grant the necessary permissions in Settings.")
        
        let unknownError = AppError.unknown("Test error")
        XCTAssertEqual(unknownError.recoverySuggestion, "Please try again or contact support if the problem persists.")
    }
    
    func testAppErrorIsRetryable() {
        let retryableError = AppError.network(.timeout)
        XCTAssertTrue(retryableError.isRetryable)
        
        let nonRetryableError = AppError.validation(.emptySearchCriteria)
        XCTAssertFalse(nonRetryableError.isRetryable)
        
        let unauthorizedError = AppError.network(.unauthorized)
        XCTAssertFalse(unauthorizedError.isRetryable)
    }
    
    func testAppErrorSeverity() {
        let infoError = AppError.network(.rateLimited)
        XCTAssertEqual(infoError.severity, .info)
        
        let warningError = AppError.network(.noConnection)
        XCTAssertEqual(warningError.severity, .warning)
        
        let errorSeverity = AppError.network(.unauthorized)
        XCTAssertEqual(errorSeverity.severity, .error)
        
        let validationError = AppError.validation(.emptySearchCriteria)
        XCTAssertEqual(validationError.severity, .warning)
    }
    
    // MARK: - Network Error Tests
    
    func testNetworkErrorProperties() {
        let noConnectionError = NetworkError.noConnection
        XCTAssertEqual(noConnectionError.errorDescription, "No Internet Connection")
        XCTAssertTrue(noConnectionError.isRetryable)
        XCTAssertEqual(noConnectionError.severity, .warning)
        
        let unauthorizedError = NetworkError.unauthorized
        XCTAssertEqual(unauthorizedError.errorDescription, "Access Denied")
        XCTAssertFalse(unauthorizedError.isRetryable)
        XCTAssertEqual(unauthorizedError.severity, .error)
        
        let serverError = NetworkError.serverError(500)
        XCTAssertEqual(serverError.errorDescription, "Server Error (500)")
        XCTAssertTrue(serverError.isRetryable)
        XCTAssertEqual(serverError.severity, .error)
    }
    
    // MARK: - Persistence Error Tests
    
    func testPersistenceErrorProperties() {
        let saveFailedError = PersistenceError.saveFailed
        XCTAssertEqual(saveFailedError.errorDescription, "Save Failed")
        XCTAssertTrue(saveFailedError.isRetryable)
        XCTAssertEqual(saveFailedError.severity, .warning)
        
        let corruptedDataError = PersistenceError.corruptedData
        XCTAssertEqual(corruptedDataError.errorDescription, "Corrupted Data")
        XCTAssertFalse(corruptedDataError.isRetryable)
        XCTAssertEqual(corruptedDataError.severity, .error)
        
        let storageQuotaError = PersistenceError.storageQuotaExceeded
        XCTAssertEqual(storageQuotaError.errorDescription, "Storage Full")
        XCTAssertFalse(storageQuotaError.isRetryable)
        XCTAssertEqual(storageQuotaError.severity, .info)
    }
    
    // MARK: - Validation Error Tests
    
    func testValidationErrorProperties() {
        let emptySearchError = ValidationError.emptySearchCriteria
        XCTAssertEqual(emptySearchError.errorDescription, "Empty Search Criteria")
        XCTAssertEqual(emptySearchError.recoverySuggestion, "Please enter at least one search criterion.")
        
        let missingFieldError = ValidationError.missingRequiredField("Email")
        XCTAssertEqual(missingFieldError.errorDescription, "Missing Required Field: Email")
        XCTAssertEqual(missingFieldError.recoverySuggestion, "Please provide a value for Email.")
        
        let invalidSalaryError = ValidationError.invalidSalaryRange
        XCTAssertEqual(invalidSalaryError.errorDescription, "Invalid Salary Range")
        XCTAssertEqual(invalidSalaryError.recoverySuggestion, "Please enter a valid salary range.")
    }
    
    // MARK: - System Error Tests
    
    func testSystemErrorProperties() {
        let permissionError = SystemError.permissionDenied
        XCTAssertEqual(permissionError.errorDescription, "Permission Denied")
        XCTAssertFalse(permissionError.isRetryable)
        XCTAssertEqual(permissionError.severity, .warning)
        
        let memoryError = SystemError.insufficientMemory
        XCTAssertEqual(memoryError.errorDescription, "Insufficient Memory")
        XCTAssertTrue(memoryError.isRetryable)
        XCTAssertEqual(memoryError.severity, .error)
        
        let notificationError = SystemError.notificationPermissionDenied
        XCTAssertEqual(notificationError.errorDescription, "Notification Permission Denied")
        XCTAssertFalse(notificationError.isRetryable)
        XCTAssertEqual(notificationError.severity, .warning)
    }
    
    // MARK: - Error Conversion Tests
    
    func testAPIErrorToAppErrorConversion() {
        let apiError = APIError.noInternetConnection
        let appError = apiError.toAppError()
        
        if case .network(let networkError) = appError {
            XCTAssertEqual(networkError, .noConnection)
        } else {
            XCTFail("Expected network error")
        }
    }
    
    func testDataPersistenceErrorToAppErrorConversion() {
        let persistenceError = DataPersistenceError.saveFailed
        let appError = persistenceError.toAppError()
        
        if case .persistence(let persistError) = appError {
            XCTAssertEqual(persistError, .saveFailed)
        } else {
            XCTFail("Expected persistence error")
        }
    }
    
    // MARK: - Error Handler Tests
    
    func testErrorHandlerHandlesAppError() {
        let appError = AppError.network(.timeout)
        let handledError = errorHandler.handle(appError)
        
        XCTAssertEqual(handledError, appError)
    }
    
    func testErrorHandlerHandlesAPIError() {
        let apiError = APIError.rateLimitExceeded
        let handledError = errorHandler.handle(apiError)
        
        if case .network(let networkError) = handledError {
            XCTAssertEqual(networkError, .rateLimited)
        } else {
            XCTFail("Expected network error")
        }
    }
    
    func testErrorHandlerHandlesUnknownError() {
        let unknownError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let handledError = errorHandler.handle(unknownError)
        
        if case .unknown(let message) = handledError {
            XCTAssertEqual(message, "Test error")
        } else {
            XCTFail("Expected unknown error")
        }
    }
    
    func testErrorHandlerShouldRetry() {
        let retryableError = AppError.network(.timeout)
        XCTAssertTrue(errorHandler.shouldRetry(retryableError, attemptCount: 1))
        XCTAssertTrue(errorHandler.shouldRetry(retryableError, attemptCount: 2))
        XCTAssertFalse(errorHandler.shouldRetry(retryableError, attemptCount: 3))
        
        let nonRetryableError = AppError.network(.unauthorized)
        XCTAssertFalse(errorHandler.shouldRetry(nonRetryableError, attemptCount: 1))
    }
    
    func testErrorHandlerRetryDelay() {
        let error = AppError.network(.timeout)
        
        let delay1 = errorHandler.getRetryDelay(error, attemptCount: 1)
        let delay2 = errorHandler.getRetryDelay(error, attemptCount: 2)
        
        // Delay should increase with attempt count (exponential backoff)
        XCTAssertGreaterThan(delay2, delay1)
        
        // Delays should be reasonable (with jitter, should be around base * 2^attempt)
        XCTAssertGreaterThan(delay1, 0.08) // 0.1 * 2^1 * 0.8 (min jitter)
        XCTAssertLessThan(delay1, 0.24)    // 0.1 * 2^1 * 1.2 (max jitter)
        
        XCTAssertGreaterThan(delay2, 0.32) // 0.1 * 2^2 * 0.8 (min jitter)
        XCTAssertLessThan(delay2, 0.48)    // 0.1 * 2^2 * 1.2 (max jitter)
    }
    
    // MARK: - Error Severity Tests
    
    func testErrorSeverityColors() {
        XCTAssertEqual(ErrorSeverity.info.color, .blue)
        XCTAssertEqual(ErrorSeverity.warning.color, .orange)
        XCTAssertEqual(ErrorSeverity.error.color, .red)
        XCTAssertEqual(ErrorSeverity.critical.color, .purple)
    }
    
    func testErrorSeveritySystemImages() {
        XCTAssertEqual(ErrorSeverity.info.systemImage, "info.circle")
        XCTAssertEqual(ErrorSeverity.warning.systemImage, "exclamationmark.triangle")
        XCTAssertEqual(ErrorSeverity.error.systemImage, "xmark.circle")
        XCTAssertEqual(ErrorSeverity.critical.systemImage, "exclamationmark.octagon")
    }
}

// MARK: - Mock Errors for Testing

extension ErrorHandlingTests {
    
    enum MockError: Error {
        case testError
    }
    
    func testErrorHandlerHandlesMockError() {
        let mockError = MockError.testError
        let handledError = errorHandler.handle(mockError)
        
        if case .unknown(let message) = handledError {
            XCTAssertTrue(message.contains("testError"))
        } else {
            XCTFail("Expected unknown error")
        }
    }
}