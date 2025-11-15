//
//  AppLifecycleManager.swift
//  Federal Job Finder
//
//  Created by Federal Job Finder Team on 11/13/25.
//

import Foundation
import UIKit
import Combine

/// Manages app lifecycle events and state transitions
@MainActor
class AppLifecycleManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var appState: AppState = .active
    @Published var isFirstLaunch: Bool
    @Published var sessionStartTime: Date
    
    /// Computed property to check if app is currently active
    var isAppActive: Bool {
        return appState == .active
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    
    // MARK: - App State
    
    enum AppState {
        case launching
        case active
        case inactive
        case background
        case terminated
    }
    
    // MARK: - Initialization
    
    init() {
        self.isFirstLaunch = !userDefaults.bool(forKey: "hasLaunchedBefore")
        self.sessionStartTime = Date()
        
        setupLifecycleObservers()
        
        if isFirstLaunch {
            handleFirstLaunch()
        }
        
        recordLaunch()
    }
    
    // MARK: - Lifecycle Observers
    
    private func setupLifecycleObservers() {
        // App became active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppBecameActive()
            }
            .store(in: &cancellables)
        
        // App will resign active
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppWillResignActive()
            }
            .store(in: &cancellables)
        
        // App entered background
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppEnteredBackground()
            }
            .store(in: &cancellables)
        
        // App will enter foreground
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
        
        // App will terminate
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.handleAppWillTerminate()
            }
            .store(in: &cancellables)
        
        // Memory warning
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Lifecycle Handlers
    
    private func handleAppBecameActive() {
        appState = .active
        sessionStartTime = Date()
        
        // Clear badge count
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        // Log analytics event
        logEvent("app_became_active")
        
        if AppConfiguration.FeatureFlags.enableDebugLogging {
            print("📱 App became active")
        }
    }
    
    private func handleAppWillResignActive() {
        appState = .inactive
        
        // Save session duration
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        recordSessionDuration(sessionDuration)
        
        logEvent("app_will_resign_active", parameters: ["session_duration": sessionDuration])
        
        if AppConfiguration.FeatureFlags.enableDebugLogging {
            print("📱 App will resign active (session: \(Int(sessionDuration))s)")
        }
    }
    
    private func handleAppEnteredBackground() {
        appState = .background
        
        // Record background timestamp
        userDefaults.set(Date(), forKey: "lastBackgroundTime")
        
        logEvent("app_entered_background")
        
        if AppConfiguration.FeatureFlags.enableDebugLogging {
            print("📱 App entered background")
        }
    }
    
    private func handleAppWillEnterForeground() {
        appState = .active
        
        // Check how long app was in background
        if let backgroundTime = userDefaults.object(forKey: "lastBackgroundTime") as? Date {
            let backgroundDuration = Date().timeIntervalSince(backgroundTime)
            
            // If app was in background for more than 30 minutes, treat as new session
            if backgroundDuration > 30 * 60 {
                sessionStartTime = Date()
                logEvent("app_new_session_after_background", parameters: ["background_duration": backgroundDuration])
            }
        }
        
        logEvent("app_will_enter_foreground")
        
        if AppConfiguration.FeatureFlags.enableDebugLogging {
            print("📱 App will enter foreground")
        }
    }
    
    private func handleAppWillTerminate() {
        appState = .terminated
        
        // Record final session duration
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        recordSessionDuration(sessionDuration)
        
        logEvent("app_will_terminate", parameters: ["session_duration": sessionDuration])
        
        if AppConfiguration.FeatureFlags.enableDebugLogging {
            print("📱 App will terminate")
        }
    }
    
    private func handleMemoryWarning() {
        logEvent("memory_warning")
        
        // Notify other parts of the app to free up memory
        NotificationCenter.default.post(name: .memoryWarning, object: nil)
        
        if AppConfiguration.FeatureFlags.enableDebugLogging {
            print("⚠️ Memory warning received")
        }
    }
    
    private func handleFirstLaunch() {
        userDefaults.set(true, forKey: "hasLaunchedBefore")
        userDefaults.set(Date(), forKey: "firstLaunchDate")
        userDefaults.set(AppConfiguration.appVersion, forKey: "firstLaunchVersion")
        
        logEvent("first_launch", parameters: ["app_version": AppConfiguration.appVersion])
        
        if AppConfiguration.FeatureFlags.enableDebugLogging {
            print("🎉 First app launch")
        }
    }
    
    // MARK: - Data Recording
    
    private func recordLaunch() {
        let launchCount = userDefaults.integer(forKey: "launchCount") + 1
        userDefaults.set(launchCount, forKey: "launchCount")
        userDefaults.set(Date(), forKey: "lastLaunchDate")
        userDefaults.set(AppConfiguration.appVersion, forKey: "lastLaunchVersion")
        
        logEvent("app_launch", parameters: [
            "launch_count": launchCount,
            "app_version": AppConfiguration.appVersion,
            "is_first_launch": isFirstLaunch
        ])
    }
    
    private func recordSessionDuration(_ duration: TimeInterval) {
        let totalSessionTime = userDefaults.double(forKey: "totalSessionTime") + duration
        userDefaults.set(totalSessionTime, forKey: "totalSessionTime")
        
        let sessionCount = userDefaults.integer(forKey: "sessionCount") + 1
        userDefaults.set(sessionCount, forKey: "sessionCount")
    }
    
    // MARK: - Analytics
    
    private func logEvent(_ eventName: String, parameters: [String: Any] = [:]) {
        // In a real app, this would send events to your analytics service
        // For now, we'll just log to console in debug mode
        
        if AppConfiguration.FeatureFlags.enableDebugLogging {
            var logMessage = "📊 Analytics: \(eventName)"
            if !parameters.isEmpty {
                let paramString = parameters.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
                logMessage += " (\(paramString))"
            }
            print(logMessage)
        }
    }
    
    // MARK: - Public Methods
    
    /// Get app usage statistics
    func getUsageStatistics() -> AppUsageStatistics {
        return AppUsageStatistics(
            launchCount: userDefaults.integer(forKey: "launchCount"),
            totalSessionTime: userDefaults.double(forKey: "totalSessionTime"),
            sessionCount: userDefaults.integer(forKey: "sessionCount"),
            firstLaunchDate: userDefaults.object(forKey: "firstLaunchDate") as? Date,
            lastLaunchDate: userDefaults.object(forKey: "lastLaunchDate") as? Date,
            firstLaunchVersion: userDefaults.string(forKey: "firstLaunchVersion"),
            lastLaunchVersion: userDefaults.string(forKey: "lastLaunchVersion")
        )
    }
    
    /// Reset all usage statistics (for testing or privacy)
    func resetUsageStatistics() {
        let keys = ["launchCount", "totalSessionTime", "sessionCount", "firstLaunchDate", 
                   "lastLaunchDate", "firstLaunchVersion", "lastLaunchVersion", "hasLaunchedBefore"]
        
        keys.forEach { userDefaults.removeObject(forKey: $0) }
        
        logEvent("usage_statistics_reset")
    }
}

// MARK: - App Usage Statistics

struct AppUsageStatistics {
    let launchCount: Int
    let totalSessionTime: TimeInterval
    let sessionCount: Int
    let firstLaunchDate: Date?
    let lastLaunchDate: Date?
    let firstLaunchVersion: String?
    let lastLaunchVersion: String?
    
    var averageSessionDuration: TimeInterval {
        guard sessionCount > 0 else { return 0 }
        return totalSessionTime / Double(sessionCount)
    }
    
    var daysSinceFirstLaunch: Int? {
        guard let firstLaunch = firstLaunchDate else { return nil }
        return Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let memoryWarning = Notification.Name("AppMemoryWarning")
}