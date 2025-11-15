//
//  ErrorView.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import SwiftUI

// MARK: - Error Display View

/// A reusable view for displaying errors with retry functionality
struct ErrorView: View {
    let error: AppError
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    init(
        error: AppError,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Error Icon
            Image(systemName: error.severity.systemImage)
                .font(.system(size: 48))
                .foregroundColor(error.severity.color)
            
            // Error Title
            Text(error.localizedDescription)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
            
            // Error Description
            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                if let onDismiss = onDismiss {
                    Button("Dismiss") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                }
                
                if let onRetry = onRetry, error.isRetryable {
                    Button("Try Again") {
                        onRetry()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Inline Error View

/// A compact error view for inline display
struct InlineErrorView: View {
    let error: AppError
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    init(
        error: AppError,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Error Icon
            Image(systemName: error.severity.systemImage)
                .foregroundColor(error.severity.color)
            
            // Error Text
            VStack(alignment: .leading, spacing: 4) {
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let recoverySuggestion = error.recoverySuggestion {
                    Text(recoverySuggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                if let onRetry = onRetry, error.isRetryable {
                    Button(action: onRetry) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(error.severity.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(error.severity.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Error Banner View

/// A banner-style error view that appears at the top of the screen
struct ErrorBannerView: View {
    let error: AppError
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    @State private var isVisible = true
    
    init(
        error: AppError,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Error Icon
                    Image(systemName: error.severity.systemImage)
                        .foregroundColor(.white)
                    
                    // Error Text
                    VStack(alignment: .leading, spacing: 2) {
                        Text(error.localizedDescription)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        if let recoverySuggestion = error.recoverySuggestion {
                            Text(recoverySuggestion)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    HStack(spacing: 8) {
                        if let onRetry = onRetry, error.isRetryable {
                            Button("Retry") {
                                onRetry()
                                withAnimation {
                                    isVisible = false
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.white.opacity(0.2))
                            )
                        }
                        
                        Button(action: {
                            withAnimation {
                                isVisible = false
                            }
                            onDismiss?()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(16)
                .background(error.severity.color)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Error State View

/// A full-screen error state view
struct ErrorStateView: View {
    let error: AppError
    let onRetry: (() -> Void)?
    
    init(error: AppError, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Error Illustration
            Image(systemName: error.severity.systemImage)
                .font(.system(size: 80))
                .foregroundColor(error.severity.color)
            
            // Error Content
            VStack(spacing: 12) {
                Text(error.localizedDescription)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                if let recoverySuggestion = error.recoverySuggestion {
                    Text(recoverySuggestion)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 32)
                }
            }
            
            // Retry Button
            if let onRetry = onRetry, error.isRetryable {
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.blue)
                    )
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Network Error View

/// Specialized view for network-related errors
struct NetworkErrorView: View {
    let error: NetworkError
    let onRetry: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            // Network Icon
            Image(systemName: networkIcon)
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            // Error Content
            VStack(spacing: 8) {
                Text(networkTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(networkMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            // Retry Button
            if let onRetry = onRetry, error.isRetryable {
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.blue)
                    )
                }
            }
        }
        .padding(32)
    }
    
    private var networkIcon: String {
        switch error {
        case .noConnection:
            return "wifi.slash"
        case .timeout:
            return "clock.badge.exclamationmark"
        case .rateLimited:
            return "exclamationmark.triangle"
        case .unauthorized:
            return "lock.slash"
        case .serverError:
            return "server.rack"
        default:
            return "exclamationmark.triangle"
        }
    }
    
    private var networkTitle: String {
        switch error {
        case .noConnection:
            return "No Internet Connection"
        case .timeout:
            return "Request Timed Out"
        case .rateLimited:
            return "Too Many Requests"
        case .unauthorized:
            return "Access Denied"
        case .serverError:
            return "Server Error"
        default:
            return "Network Error"
        }
    }
    
    private var networkMessage: String {
        switch error {
        case .noConnection:
            return "Please check your internet connection and try again."
        case .timeout:
            return "The request took too long to complete. Please try again."
        case .rateLimited:
            return "You've made too many requests. Please wait a moment before trying again."
        case .unauthorized:
            return "You don't have permission to access this resource."
        case .serverError:
            return "The server is experiencing issues. Please try again later."
        default:
            return "An unexpected network error occurred."
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Standard Error View
            ErrorView(
                error: .network(.noConnection),
                onRetry: {},
                onDismiss: {}
            )
            .previewDisplayName("Standard Error")
            
            // Inline Error View
            InlineErrorView(
                error: .persistence(.saveFailed),
                onRetry: {},
                onDismiss: {}
            )
            .previewDisplayName("Inline Error")
            
            // Error Banner
            ErrorBannerView(
                error: .network(.rateLimited),
                onRetry: {},
                onDismiss: {}
            )
            .previewDisplayName("Error Banner")
            
            // Error State View
            ErrorStateView(
                error: .validation(.emptySearchCriteria),
                onRetry: {}
            )
            .previewDisplayName("Error State")
            
            // Network Error View
            NetworkErrorView(
                error: .noConnection,
                onRetry: {}
            )
            .previewDisplayName("Network Error")
        }
    }
}
#endif