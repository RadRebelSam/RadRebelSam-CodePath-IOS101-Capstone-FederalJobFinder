//
//  ErrorHandling.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation
import SwiftUI

// MARK: - App Error Types

/// Centralized error types for the application
enum AppError: Error, LocalizedError, Equatable {
    case network(NetworkError)
    case persistence(PersistenceError)
    case validation(ValidationError)
    case system(SystemError)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .network(let error):
            return error.localizedDescription
        case .persistence(let error):
            return error.localizedDescription
        case .validation(let error):
            return error.localizedDescription
        case .system(let error):
            return error.localizedDescription
        case .unknown(let message):
            return message
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .network(let error):
            return error.recoverySuggestion
        case .persistence(let error):
            return error.recoverySuggestion
        case .validation(let error):
            return error.recoverySuggestion
        case .system(let error):
            return error.recoverySuggestion
        case .unknown:
            return "Please try again or contact support if the problem persists."
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .network(let error):
            return error.isRetryable
        case .persistence(let error):
            return error.isRetryable
        case .validation:
            return false
        case .system(let error):
            return error.isRetryable
        case .unknown:
            return true
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .network(let error):
            return error.severity
        case .persistence(let error):
            return error.severity
        case .validation:
            return .warning
        case .system(let error):
            return error.severity
        case .unknown:
            return .error
        }
    }
}

// MARK: - Network Errors

enum NetworkError: Error, LocalizedError, Equatable {
    case noConnection
    case timeout
    case rateLimited
    case unauthorized
    case serverError(Int)
    case invalidResponse
    case decodingFailed
    case requestFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No Internet Connection"
        case .timeout:
            return "Request Timed Out"
        case .rateLimited:
            return "Too Many Requests"
        case .unauthorized:
            return "Access Denied"
        case .serverError(let code):
            return "Server Error (\(code))"
        case .invalidResponse:
            return "Invalid Server Response"
        case .decodingFailed:
            return "Data Processing Error"
        case .requestFailed(let message):
            return "Request Failed: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noConnection:
            return "Please check your internet connection and try again."
        case .timeout:
            return "The request took too long. Please try again."
        case .rateLimited:
            return "Please wait a moment before trying again."
        case .unauthorized:
            return "Please check your credentials or contact support."
        case .serverError:
            return "The server is experiencing issues. Please try again later."
        case .invalidResponse:
            return "Please try again or contact support if the problem persists."
        case .decodingFailed:
            return "There was an issue processing the data. Please try again."
        case .requestFailed:
            return "Please try again or contact support if the problem persists."
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .noConnection, .timeout, .rateLimited, .serverError, .invalidResponse, .decodingFailed, .requestFailed:
            return true
        case .unauthorized:
            return false
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .noConnection, .timeout:
            return .warning
        case .rateLimited:
            return .info
        case .unauthorized, .serverError:
            return .error
        case .invalidResponse, .decodingFailed, .requestFailed:
            return .error
        }
    }
}

// MARK: - Persistence Errors

enum PersistenceError: Error, LocalizedError, Equatable {
    case saveFailed
    case loadFailed
    case deleteFailed
    case notFound
    case corruptedData
    case storageQuotaExceeded
    case migrationFailed
    
    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Save Failed"
        case .loadFailed:
            return "Load Failed"
        case .deleteFailed:
            return "Delete Failed"
        case .notFound:
            return "Data Not Found"
        case .corruptedData:
            return "Corrupted Data"
        case .storageQuotaExceeded:
            return "Storage Full"
        case .migrationFailed:
            return "Data Migration Failed"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .saveFailed:
            return "Please try saving again or free up storage space."
        case .loadFailed:
            return "Please try refreshing the data."
        case .deleteFailed:
            return "Please try again or restart the app."
        case .notFound:
            return "The requested data could not be found."
        case .corruptedData:
            return "Please restart the app or contact support."
        case .storageQuotaExceeded:
            return "Please free up storage space and try again."
        case .migrationFailed:
            return "Please restart the app or contact support."
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .saveFailed, .loadFailed, .deleteFailed:
            return true
        case .notFound, .corruptedData, .storageQuotaExceeded, .migrationFailed:
            return false
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .saveFailed, .loadFailed, .deleteFailed, .notFound:
            return .warning
        case .corruptedData, .migrationFailed:
            return .error
        case .storageQuotaExceeded:
            return .info
        }
    }
}

// MARK: - Validation Errors

enum ValidationError: Error, LocalizedError, Equatable {
    case emptySearchCriteria
    case invalidSearchTerm
    case invalidDateRange
    case invalidSalaryRange
    case missingRequiredField(String)
    
    var errorDescription: String? {
        switch self {
        case .emptySearchCriteria:
            return "Empty Search Criteria"
        case .invalidSearchTerm:
            return "Invalid Search Term"
        case .invalidDateRange:
            return "Invalid Date Range"
        case .invalidSalaryRange:
            return "Invalid Salary Range"
        case .missingRequiredField(let field):
            return "Missing Required Field: \(field)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .emptySearchCriteria:
            return "Please enter at least one search criterion."
        case .invalidSearchTerm:
            return "Please enter a valid search term."
        case .invalidDateRange:
            return "Please select a valid date range."
        case .invalidSalaryRange:
            return "Please enter a valid salary range."
        case .missingRequiredField(let field):
            return "Please provide a value for \(field)."
        }
    }
}

// MARK: - System Errors

enum SystemError: Error, LocalizedError, Equatable {
    case permissionDenied
    case insufficientMemory
    case diskSpaceFull
    case backgroundTaskFailed
    case notificationPermissionDenied
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission Denied"
        case .insufficientMemory:
            return "Insufficient Memory"
        case .diskSpaceFull:
            return "Disk Space Full"
        case .backgroundTaskFailed:
            return "Background Task Failed"
        case .notificationPermissionDenied:
            return "Notification Permission Denied"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Please grant the necessary permissions in Settings."
        case .insufficientMemory:
            return "Please close other apps and try again."
        case .diskSpaceFull:
            return "Please free up storage space and try again."
        case .backgroundTaskFailed:
            return "Background updates may not work properly."
        case .notificationPermissionDenied:
            return "Enable notifications in Settings to receive job alerts."
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .permissionDenied, .notificationPermissionDenied:
            return false
        case .insufficientMemory, .diskSpaceFull, .backgroundTaskFailed:
            return true
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .permissionDenied, .notificationPermissionDenied:
            return .warning
        case .insufficientMemory, .diskSpaceFull:
            return .error
        case .backgroundTaskFailed:
            return .info
        }
    }
}

// MARK: - Error Severity

enum ErrorSeverity {
    case info
    case warning
    case error
    case critical
    
    var color: Color {
        switch self {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .purple
        }
    }
    
    var systemImage: String {
        switch self {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        case .critical:
            return "exclamationmark.octagon"
        }
    }
}

// MARK: - Error Conversion Extensions

extension APIError {
    func toAppError() -> AppError {
        switch self {
        case .noInternetConnection:
            return .network(.noConnection)
        case .timeout:
            return .network(.timeout)
        case .rateLimitExceeded:
            return .network(.rateLimited)
        case .unauthorized:
            return .network(.unauthorized)
        case .serverError(let code):
            return .network(.serverError(code))
        case .invalidResponse:
            return .network(.invalidResponse)
        case .decodingError:
            return .network(.decodingFailed)
        case .networkError(let error):
            return .network(.requestFailed(error.localizedDescription))
        case .invalidURL:
            return .network(.requestFailed("Invalid URL"))
        case .noData:
            return .network(.invalidResponse)
        }
    }
}

extension DataPersistenceError {
    func toAppError() -> AppError {
        switch self {
        case .jobNotFound, .applicationNotFound, .savedSearchNotFound:
            return .persistence(.notFound)
        case .coreDataError:
            return .persistence(.corruptedData)
        case .invalidData:
            return .persistence(.corruptedData)
        }
    }
}

// MARK: - Error Handler Protocol

protocol ErrorHandlerProtocol {
    func handle(_ error: Error) -> AppError
    func shouldRetry(_ error: AppError, attemptCount: Int) -> Bool
    func getRetryDelay(_ error: AppError, attemptCount: Int) -> TimeInterval
}

// MARK: - Default Error Handler

class DefaultErrorHandler: ErrorHandlerProtocol {
    private let maxRetryAttempts: Int
    private let baseRetryDelay: TimeInterval
    
    init(maxRetryAttempts: Int = 3, baseRetryDelay: TimeInterval = 1.0) {
        self.maxRetryAttempts = maxRetryAttempts
        self.baseRetryDelay = baseRetryDelay
    }
    
    func handle(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        } else if let apiError = error as? APIError {
            return apiError.toAppError()
        } else if let persistenceError = error as? DataPersistenceError {
            return persistenceError.toAppError()
        } else {
            return .unknown(error.localizedDescription)
        }
    }
    
    func shouldRetry(_ error: AppError, attemptCount: Int) -> Bool {
        guard attemptCount < maxRetryAttempts else { return false }
        return error.isRetryable
    }
    
    func getRetryDelay(_ error: AppError, attemptCount: Int) -> TimeInterval {
        // Exponential backoff with jitter
        let delay = baseRetryDelay * pow(2.0, Double(attemptCount))
        let jitter = Double.random(in: 0.8...1.2)
        return delay * jitter
    }
}