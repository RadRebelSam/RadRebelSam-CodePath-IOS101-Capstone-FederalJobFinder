//
//  AppConfiguration.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation
import OSLog

/// Application configuration and constants
struct AppConfiguration {

    private static let logger = Logger(subsystem: "com.federaljobfinder.usajobs", category: "Configuration")

    // MARK: - App Information
    static let appName = "Federal Job Finder"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    // MARK: - API Configuration
    struct API {
        static let baseURL = "https://data.usajobs.gov/api"
        static let version = "v1"
        static let timeout: TimeInterval = 30.0
        static let maxRetries = 3
        static let rateLimitDelay: TimeInterval = 1.0

        // API Key - In production, this should be loaded from a secure location
        static let key: String = {
            // Try to load from environment variable first
            if let envKey = ProcessInfo.processInfo.environment["USAJOBS_API_KEY"], !envKey.isEmpty {
                return envKey
            }

            // Try to get from Info.plist
            if let plistKey = Bundle.main.object(forInfoDictionaryKey: "USAJobsAPIKey") as? String, !plistKey.isEmpty {
                return plistKey
            }

            // Fallback to placeholder - log warning
            logger.warning("⚠️ USAJobs API key not configured! Set USAJOBS_API_KEY environment variable or add USAJobsAPIKey to Info.plist")
            return "YOUR_API_KEY_HERE"
        }()

        /// Check if API key is properly configured
        static var isConfigured: Bool {
            return key != "YOUR_API_KEY_HERE" && !key.isEmpty
        }
    }
    
    // MARK: - Core Data Configuration
    struct CoreData {
        static let modelName = "FederalJobFinder"
        static let maxCacheAge: TimeInterval = 24 * 60 * 60 // 24 hours
        static let maxCachedJobs = 1000
    }
    
    // MARK: - Notification Configuration
    struct Notifications {
        static let categoryIdentifier = "JOB_ALERTS"
        static let newJobsIdentifier = "NEW_JOBS"
        static let deadlineReminderIdentifier = "DEADLINE_REMINDER"
        static let defaultReminderDays = 3
    }
    
    // MARK: - UI Configuration
    struct UI {
        static let animationDuration: Double = 0.3
        static let cornerRadius: CGFloat = 12.0
        static let shadowRadius: CGFloat = 4.0
        static let minimumTouchTarget: CGFloat = 44.0
    }
    
    // MARK: - Feature Flags
    struct FeatureFlags {
        static let enablePushNotifications = true
        static let enableOfflineMode = true
        static let enableAnalytics = true // Enabled for release
        static let enableDebugLogging = isDebug // Only in debug builds
    }
    
    // MARK: - Environment Detection
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}