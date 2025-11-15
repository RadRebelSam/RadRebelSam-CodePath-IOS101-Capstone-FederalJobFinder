//
//  NetworkConfiguration.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation
import OSLog

/// Network configuration constants for USAJobs API
struct NetworkConfiguration {
    private static let logger = Logger(subsystem: "com.federaljobfinder.usajobs", category: "Network")

    static let baseURL = "https://data.usajobs.gov/api"
    static let searchEndpoint = "/search"
    static let userAgent = "FederalJobFinder/1.0 (iOS)"

    // API Key should be stored securely in production
    // For development, this can be set via environment variable or configuration
    static var apiKey: String {
        // Try to get from environment variable first
        if let envKey = ProcessInfo.processInfo.environment["USAJOBS_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        // Try to get from Info.plist
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "USAJobsAPIKey") as? String, !plistKey.isEmpty {
            return plistKey
        }

        // Fallback for development (should be replaced with actual key)
        logger.warning("⚠️ USAJobs API key not configured! API requests will fail.")
        return "YOUR_API_KEY_HERE"
    }
    
    static var defaultHeaders: [String: String] {
        return [
            "User-Agent": userAgent,
            "Authorization-Key": apiKey,
            "Content-Type": "application/json"
        ]
    }
    
    static let requestTimeout: TimeInterval = 30.0
    static let maxRetryAttempts = 3
    
    /// Check if API key is configured
    static var isAPIKeyConfigured: Bool {
        return apiKey != "YOUR_API_KEY_HERE" && !apiKey.isEmpty
    }
}