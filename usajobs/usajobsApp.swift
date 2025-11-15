//
//  usajobsApp.swift
//  Federal Job Finder
//
//  Created by Federal Job Finder Team on 11/13/25.
//

import SwiftUI
import BackgroundTasks
import UserNotifications
import UIKit
import OSLog

@main
@available(iOS 16.0, *)
struct FederalJobFinderApp: App {
    let coreDataStack = CoreDataStack.shared

    // Initialize services
    private let persistenceService: DataPersistenceServiceProtocol
    private let apiService: USAJobsAPIServiceProtocol
    private let notificationService: NotificationServiceProtocol

    // App management
    @StateObject private var lifecycleManager = AppLifecycleManager()
    private let analyticsManager = AnalyticsManager.shared
    private let logger = Logger(subsystem: "com.federaljobfinder.usajobs", category: "App")
    
    // App state
    @State private var isAppActive = true
    private let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    
    init() {
        // Initialize services in correct order
        let persistenceService = DataPersistenceService(coreDataStack: CoreDataStack.shared)
        let apiService = USAJobsAPIService(apiKey: AppConfiguration.API.key)
        let notificationService = NotificationService(
            persistenceService: persistenceService,
            apiService: apiService
        )
        
        // Assign to instance properties
        self.persistenceService = persistenceService
        self.apiService = apiService
        self.notificationService = notificationService
        
        // Configure app appearance
        configureAppAppearance()
        
        // Setup notification categories (doesn't use self)
        setupNotificationCategories()
        
        // Initialize analytics (doesn't use self)
        initializeAnalytics()
        
        // Register background tasks (uses self, so do it last)
        registerBackgroundTasks()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataStack.context)
                .environmentObject(ServiceContainer(
                    persistenceService: persistenceService,
                    apiService: apiService,
                    notificationService: notificationService
                ))
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    handleAppDidEnterBackground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    handleAppWillEnterForeground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    handleAppDidBecomeActive()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    handleAppWillResignActive()
                }
                .task {
                    await performAppLaunchTasks()
                }
        }
    }
    
    // MARK: - App Configuration
    
    private func configureAppAppearance() {
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor.systemBackground
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Set accent color
        UIView.appearance().tintColor = UIColor.systemBlue
    }
    
    private func setupNotificationCategories() {
        let newJobsAction = UNNotificationAction(
            identifier: "VIEW_NEW_JOBS",
            title: "View Jobs",
            options: [.foreground]
        )
        
        let deadlineAction = UNNotificationAction(
            identifier: "VIEW_APPLICATION",
            title: "View Application",
            options: [.foreground]
        )
        
        let newJobsCategory = UNNotificationCategory(
            identifier: AppConfiguration.Notifications.newJobsIdentifier,
            actions: [newJobsAction],
            intentIdentifiers: [],
            options: []
        )
        
        let deadlineCategory = UNNotificationCategory(
            identifier: AppConfiguration.Notifications.deadlineReminderIdentifier,
            actions: [deadlineAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([newJobsCategory, deadlineCategory])
    }
    
    // MARK: - App Lifecycle Handlers
    
    private func handleAppDidEnterBackground() {
        isAppActive = false
        scheduleBackgroundAppRefresh()

        // Save any pending data
        Task {
            do {
                try await coreDataStack.save()
                logger.info("Core Data saved successfully on background")
            } catch {
                logger.error("Failed to save Core Data on background: \(error.localizedDescription)")
            }
        }

        // Clear sensitive data from memory if needed
        if AppConfiguration.FeatureFlags.enableDebugLogging {
            logger.debug("App entered background")
        }
    }
    
    private func handleAppWillEnterForeground() {
        // Refresh data when app comes to foreground
        Task {
            await refreshAppData()
        }

        if AppConfiguration.FeatureFlags.enableDebugLogging {
            logger.debug("App will enter foreground")
        }
    }
    
    private func handleAppDidBecomeActive() {
        isAppActive = true

        // Clear badge count
        UIApplication.shared.applicationIconBadgeNumber = 0

        if AppConfiguration.FeatureFlags.enableDebugLogging {
            logger.debug("App became active")
        }
    }
    
    private func handleAppWillResignActive() {
        // Save any pending changes
        Task {
            do {
                try await coreDataStack.save()
                logger.info("Core Data saved successfully on resign active")
            } catch {
                logger.error("Failed to save Core Data on resign active: \(error.localizedDescription)")
            }
        }

        if AppConfiguration.FeatureFlags.enableDebugLogging {
            logger.debug("App will resign active")
        }
    }
    
    private func performAppLaunchTasks() async {
        // Request notification permissions on first launch
        if !hasLaunchedBefore {
            await requestNotificationPermissions()
        }

        // Clean up expired cache
        do {
            try await persistenceService.clearExpiredCache()
            logger.info("Expired cache cleared successfully")
        } catch {
            logger.error("Failed to clear expired cache: \(error.localizedDescription)")
        }

        // Check for app updates or important announcements
        await checkForAppUpdates()

        if AppConfiguration.FeatureFlags.enableDebugLogging {
            logger.debug("App launch tasks completed")
        }
    }
    
    private func refreshAppData() async {
        // Refresh saved searches for new jobs
        // This will be handled by individual view models when they appear

        // Update application deadlines
        // This will be handled by the notification service

        if AppConfiguration.FeatureFlags.enableDebugLogging {
            logger.debug("App data refreshed")
        }
    }
    
    private func requestNotificationPermissions() async {
        do {
            let granted = try await notificationService.requestNotificationPermissions()
            if AppConfiguration.FeatureFlags.enableDebugLogging {
                logger.debug("Notification permissions granted: \(granted)")
            }
        } catch {
            logger.error("Failed to request notification permissions: \(error.localizedDescription)")
        }
    }
    
    private func checkForAppUpdates() async {
        // In a real app, this would check for updates from the App Store
        // For now, we'll just log the current version
        if AppConfiguration.FeatureFlags.enableDebugLogging {
            logger.debug("Current app version: \(AppConfiguration.appVersion) (\(AppConfiguration.buildNumber))")
        }
    }
    
    private func initializeAnalytics() {
        // Set user properties
        analyticsManager.setUserProperty("app_version", value: AppConfiguration.appVersion)
        analyticsManager.setUserProperty("build_number", value: AppConfiguration.buildNumber)
        analyticsManager.setUserProperty("is_first_launch", value: !hasLaunchedBefore)
        analyticsManager.setUserProperty("device_model", value: UIDevice.current.model)
        analyticsManager.setUserProperty("system_version", value: UIDevice.current.systemVersion)
        
        // Track app launch
        analyticsManager.trackEvent("app_launched", parameters: [
            "is_first_launch": !hasLaunchedBefore,
            "app_version": AppConfiguration.appVersion,
            "build_number": AppConfiguration.buildNumber
        ])
        
        if AppConfiguration.FeatureFlags.enableDebugLogging {
            logger.debug("Analytics initialized")
        }
    }
    
    // MARK: - Background Tasks
    
    private func registerBackgroundTasks() {
        // Register background app refresh task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.federaljobfinder.background-job-check",
            using: nil
        ) { task in
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                logger.error("Background task is not BGAppRefreshTask")
                task.setTaskCompleted(success: false)
                return
            }
            handleBackgroundJobCheck(task: appRefreshTask)
        }
    }
    
    private func scheduleBackgroundAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.federaljobfinder.background-job-check")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background app refresh scheduled successfully")
        } catch {
            logger.error("Could not schedule background app refresh: \(error.localizedDescription)")
        }
    }
    
    private func handleBackgroundJobCheck(task: BGAppRefreshTask) {
        // Schedule the next background refresh
        scheduleBackgroundAppRefresh()
        
        // Set expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Perform background job check
        Task {
            let success = await notificationService.handleBackgroundAppRefresh()
            task.setTaskCompleted(success: success)
        }
    }
}

// MARK: - Service Container

/// Container for dependency injection of services
@MainActor
class ServiceContainer: ObservableObject {
    let persistenceService: DataPersistenceServiceProtocol
    let apiService: USAJobsAPIServiceProtocol
    let notificationService: NotificationServiceProtocol
    let networkMonitor: NetworkMonitor
    let offlineManager: OfflineDataManager

    init(
        persistenceService: DataPersistenceServiceProtocol,
        apiService: USAJobsAPIServiceProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.persistenceService = persistenceService
        self.apiService = apiService
        self.notificationService = notificationService
        self.networkMonitor = NetworkMonitor.shared
        self.offlineManager = OfflineDataManager(
            networkMonitor: NetworkMonitor.shared,
            persistenceService: persistenceService,
            apiService: apiService
        )
    }
}
