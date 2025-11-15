//
//  AnalyticsManager.swift
//  Federal Job Finder
//
//  Created by Federal Job Finder Team on 11/13/25.
//

import Foundation
import UIKit

/// Manages analytics events and crash reporting for the app
class AnalyticsManager {
    
    // MARK: - Singleton
    
    static let shared = AnalyticsManager()
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private var sessionId: String
    private var userId: String
    
    // MARK: - Initialization
    
    private init() {
        // Generate or retrieve user ID
        if let existingUserId = userDefaults.string(forKey: "analytics_user_id") {
            self.userId = existingUserId
        } else {
            self.userId = UUID().uuidString
            userDefaults.set(self.userId, forKey: "analytics_user_id")
        }
        
        // Generate session ID
        self.sessionId = UUID().uuidString
        
        setupCrashReporting()
    }
    
    // MARK: - Analytics Events
    
    /// Track a custom event with optional parameters
    func trackEvent(_ eventName: String, parameters: [String: Any] = [:]) {
        guard AppConfiguration.FeatureFlags.enableAnalytics else { return }
        
        let event = AnalyticsEvent(
            name: eventName,
            parameters: parameters,
            timestamp: Date(),
            sessionId: sessionId,
            userId: userId
        )
        
        // In a real app, you would send this to your analytics service
        // For now, we'll store locally and log in debug mode
        storeEventLocally(event)
        
        if AppConfiguration.FeatureFlags.enableDebugLogging {
            print("📊 Analytics Event: \(eventName)")
            if !parameters.isEmpty {
                print("   Parameters: \(parameters)")
            }
        }
    }
    
    /// Track screen view
    func trackScreenView(_ screenName: String, screenClass: String? = nil) {
        trackEvent("screen_view", parameters: [
            "screen_name": screenName,
            "screen_class": screenClass ?? screenName
        ])
    }
    
    /// Track user action
    func trackUserAction(_ action: String, target: String? = nil, value: Any? = nil) {
        var parameters: [String: Any] = ["action": action]
        
        if let target = target {
            parameters["target"] = target
        }
        
        if let value = value {
            parameters["value"] = value
        }
        
        trackEvent("user_action", parameters: parameters)
    }
    
    /// Track search performed
    func trackSearch(query: String, filters: [String: Any] = [:], resultCount: Int = 0) {
        var parameters: [String: Any] = [
            "search_query": query,
            "result_count": resultCount
        ]
        
        // Add filter information
        for (key, value) in filters {
            parameters["filter_\(key)"] = value
        }
        
        trackEvent("search_performed", parameters: parameters)
    }
    
    /// Track job interaction
    func trackJobInteraction(_ interaction: JobInteraction, jobId: String, jobTitle: String? = nil) {
        trackEvent("job_interaction", parameters: [
            "interaction_type": interaction.rawValue,
            "job_id": jobId,
            "job_title": jobTitle ?? "Unknown"
        ])
    }
    
    /// Track error occurrence
    func trackError(_ error: Error, context: String? = nil, fatal: Bool = false) {
        var parameters: [String: Any] = [
            "error_description": error.localizedDescription,
            "error_domain": (error as NSError).domain,
            "error_code": (error as NSError).code,
            "is_fatal": fatal
        ]
        
        if let context = context {
            parameters["error_context"] = context
        }
        
        trackEvent("error_occurred", parameters: parameters)
        
        // Also log to crash reporting
        logCrash(error: error, context: context, fatal: fatal)
    }
    
    // MARK: - User Properties
    
    /// Set user property
    func setUserProperty(_ property: String, value: Any) {
        guard AppConfiguration.FeatureFlags.enableAnalytics else { return }
        
        userDefaults.set(value, forKey: "user_property_\(property)")
        
        if AppConfiguration.FeatureFlags.enableDebugLogging {
            print("👤 User Property: \(property) = \(value)")
        }
    }
    
    /// Get user property
    func getUserProperty(_ property: String) -> Any? {
        return userDefaults.object(forKey: "user_property_\(property)")
    }
    
    // MARK: - Session Management
    
    /// Start new session
    func startNewSession() {
        sessionId = UUID().uuidString
        trackEvent("session_start")
    }
    
    /// End current session
    func endSession() {
        trackEvent("session_end")
    }
    
    // MARK: - Crash Reporting
    
    private func setupCrashReporting() {
        // Set up uncaught exception handler
        NSSetUncaughtExceptionHandler { exception in
            AnalyticsManager.shared.handleUncaughtException(exception)
        }
        
        // Set up signal handler for crashes
        signal(SIGABRT) { signal in
            AnalyticsManager.shared.handleSignal(signal)
        }
        signal(SIGILL) { signal in
            AnalyticsManager.shared.handleSignal(signal)
        }
        signal(SIGSEGV) { signal in
            AnalyticsManager.shared.handleSignal(signal)
        }
        signal(SIGFPE) { signal in
            AnalyticsManager.shared.handleSignal(signal)
        }
        signal(SIGBUS) { signal in
            AnalyticsManager.shared.handleSignal(signal)
        }
        signal(SIGPIPE) { signal in
            AnalyticsManager.shared.handleSignal(signal)
        }
    }
    
    private func handleUncaughtException(_ exception: NSException) {
        let crashReport = CrashReport(
            type: .exception,
            name: exception.name.rawValue,
            reason: exception.reason ?? "Unknown",
            callStack: exception.callStackSymbols,
            timestamp: Date(),
            sessionId: sessionId,
            userId: userId,
            appVersion: AppConfiguration.appVersion,
            buildNumber: AppConfiguration.buildNumber,
            deviceInfo: getDeviceInfo()
        )
        
        storeCrashReport(crashReport)
        
        if AppConfiguration.FeatureFlags.enableDebugLogging {
            print("💥 Uncaught Exception: \(exception.name.rawValue)")
            print("   Reason: \(exception.reason ?? "Unknown")")
        }
    }
    
    private func handleSignal(_ signal: Int32) {
        let crashReport = CrashReport(
            type: .signal,
            name: "Signal \(signal)",
            reason: getSignalDescription(signal),
            callStack: Thread.callStackSymbols,
            timestamp: Date(),
            sessionId: sessionId,
            userId: userId,
            appVersion: AppConfiguration.appVersion,
            buildNumber: AppConfiguration.buildNumber,
            deviceInfo: getDeviceInfo()
        )
        
        storeCrashReport(crashReport)
        
        if AppConfiguration.FeatureFlags.enableDebugLogging {
            print("💥 Signal Crash: \(signal)")
        }
    }
    
    private func logCrash(error: Error, context: String?, fatal: Bool) {
        let crashReport = CrashReport(
            type: .error,
            name: String(describing: type(of: error)),
            reason: error.localizedDescription,
            callStack: Thread.callStackSymbols,
            timestamp: Date(),
            sessionId: sessionId,
            userId: userId,
            appVersion: AppConfiguration.appVersion,
            buildNumber: AppConfiguration.buildNumber,
            deviceInfo: getDeviceInfo(),
            context: context,
            isFatal: fatal
        )
        
        storeCrashReport(crashReport)
    }
    
    // MARK: - Data Storage
    
    private func storeEventLocally(_ event: AnalyticsEvent) {
        // In a real app, you would batch these and send to your analytics service
        // For now, we'll just store the count
        let eventKey = "analytics_event_\(event.name)"
        let currentCount = userDefaults.integer(forKey: eventKey)
        userDefaults.set(currentCount + 1, forKey: eventKey)
    }
    
    private func storeCrashReport(_ crashReport: CrashReport) {
        // Store crash report locally
        let crashData = try? JSONEncoder().encode(crashReport)
        let crashKey = "crash_report_\(crashReport.timestamp.timeIntervalSince1970)"
        userDefaults.set(crashData, forKey: crashKey)
        
        // In a real app, you would send this to your crash reporting service
    }
    
    // MARK: - Device Information
    
    private func getDeviceInfo() -> DeviceInfo {
        let device = UIDevice.current
        
        return DeviceInfo(
            model: device.model,
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            identifierForVendor: device.identifierForVendor?.uuidString,
            screenScale: UIScreen.main.scale,
            screenSize: UIScreen.main.bounds.size
        )
    }
    
    private func getSignalDescription(_ signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT - Abort signal"
        case SIGILL: return "SIGILL - Illegal instruction"
        case SIGSEGV: return "SIGSEGV - Segmentation violation"
        case SIGFPE: return "SIGFPE - Floating point exception"
        case SIGBUS: return "SIGBUS - Bus error"
        case SIGPIPE: return "SIGPIPE - Broken pipe"
        default: return "Unknown signal"
        }
    }
    
    // MARK: - Public Utilities
    
    /// Get analytics summary
    func getAnalyticsSummary() -> AnalyticsSummary {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let eventCounts = allKeys
            .filter { $0.hasPrefix("analytics_event_") }
            .reduce(into: [String: Int]()) { result, key in
                let eventName = String(key.dropFirst("analytics_event_".count))
                result[eventName] = userDefaults.integer(forKey: key)
            }
        
        return AnalyticsSummary(
            userId: userId,
            sessionId: sessionId,
            eventCounts: eventCounts,
            totalEvents: eventCounts.values.reduce(0, +)
        )
    }
    
    /// Clear all analytics data
    func clearAnalyticsData() {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let analyticsKeys = allKeys.filter { 
            $0.hasPrefix("analytics_") || $0.hasPrefix("user_property_") || $0.hasPrefix("crash_report_")
        }
        
        analyticsKeys.forEach { userDefaults.removeObject(forKey: $0) }
        
        // Generate new user ID
        userId = UUID().uuidString
        userDefaults.set(userId, forKey: "analytics_user_id")
        
        trackEvent("analytics_data_cleared")
    }
}

// MARK: - Data Models

struct AnalyticsEvent: Codable {
    let name: String
    let parameters: [String: AnyCodable]
    let timestamp: Date
    let sessionId: String
    let userId: String
    
    init(name: String, parameters: [String: Any], timestamp: Date, sessionId: String, userId: String) {
        self.name = name
        self.parameters = parameters.mapValues { AnyCodable($0) }
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.userId = userId
    }
}

struct CrashReport: Codable {
    let type: CrashType
    let name: String
    let reason: String
    let callStack: [String]
    let timestamp: Date
    let sessionId: String
    let userId: String
    let appVersion: String
    let buildNumber: String
    let deviceInfo: DeviceInfo
    let context: String?
    let isFatal: Bool
    
    init(type: CrashType, name: String, reason: String, callStack: [String], 
         timestamp: Date, sessionId: String, userId: String, appVersion: String, 
         buildNumber: String, deviceInfo: DeviceInfo, context: String? = nil, isFatal: Bool = true) {
        self.type = type
        self.name = name
        self.reason = reason
        self.callStack = callStack
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.userId = userId
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.deviceInfo = deviceInfo
        self.context = context
        self.isFatal = isFatal
    }
}

struct DeviceInfo: Codable {
    let model: String
    let systemName: String
    let systemVersion: String
    let identifierForVendor: String?
    let screenScale: CGFloat
    let screenSize: CGSize
}

struct AnalyticsSummary {
    let userId: String
    let sessionId: String
    let eventCounts: [String: Int]
    let totalEvents: Int
}

enum CrashType: String, Codable {
    case exception = "exception"
    case signal = "signal"
    case error = "error"
}

enum JobInteraction: String, CaseIterable {
    case viewed = "viewed"
    case favorited = "favorited"
    case unfavorited = "unfavorited"
    case applied = "applied"
    case shared = "shared"
    case opened_external = "opened_external"
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else {
            value = try container.decode(String.self)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else {
            try container.encode(String(describing: value))
        }
    }
}