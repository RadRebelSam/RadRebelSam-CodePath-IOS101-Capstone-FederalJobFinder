//
//  NotificationService.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation
import UserNotifications
import UIKit

// MARK: - Notification Service Protocol

/// Protocol defining notification service interface
protocol NotificationServiceProtocol {
    func requestNotificationPermissions() async throws -> Bool
    func scheduleDeadlineReminder(for application: ApplicationTracking) async throws
    func scheduleNewJobsNotification(for search: SavedSearch, jobCount: Int) async throws
    func cancelDeadlineReminder(for jobId: String) async
    func cancelNewJobsNotification(for searchId: UUID) async
    func cancelAllNotifications() async
    func getNotificationSettings() async -> UNNotificationSettings
    func handleNotificationResponse(_ response: UNNotificationResponse) async
    func handleBackgroundAppRefresh() async -> Bool
}

// MARK: - Notification Errors

/// Errors that can occur during notification operations
enum NotificationError: Error, LocalizedError {
    case permissionDenied
    case invalidApplicationData
    case invalidSearchData
    case schedulingFailed(Error)
    case notificationNotFound
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permissions are required to receive job alerts"
        case .invalidApplicationData:
            return "Invalid application data for reminder"
        case .invalidSearchData:
            return "Invalid search data for notification"
        case .schedulingFailed(let error):
            return "Failed to schedule notification: \(error.localizedDescription)"
        case .notificationNotFound:
            return "Notification not found"
        }
    }
}

// MARK: - Notification Service Implementation

/// Service class for managing local and push notifications
@MainActor
class NotificationService: NSObject, NotificationServiceProtocol {
    
    // MARK: - Properties
    
    private let notificationCenter: UNUserNotificationCenter
    private let persistenceService: DataPersistenceServiceProtocol
    private let apiService: USAJobsAPIServiceProtocol
    
    // MARK: - Initialization
    
    init(
        persistenceService: DataPersistenceServiceProtocol,
        apiService: USAJobsAPIServiceProtocol,
        notificationCenter: UNUserNotificationCenter = UNUserNotificationCenter.current()
    ) {
        self.persistenceService = persistenceService
        self.apiService = apiService
        self.notificationCenter = notificationCenter
        super.init()
        
        // Set delegate to handle notification responses
        notificationCenter.delegate = self
        
        // Configure notification categories
        configureNotificationCategories()
    }
    
    // MARK: - Permission Management
    
    /// Request notification permissions from the user
    func requestNotificationPermissions() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        
        do {
            let granted = try await notificationCenter.requestAuthorization(options: options)
            
            if granted {
                // Register for remote notifications if available
                await UIApplication.shared.registerForRemoteNotifications()
            }
            
            return granted
        } catch {
            throw NotificationError.schedulingFailed(error)
        }
    }
    
    /// Get current notification settings
    func getNotificationSettings() async -> UNNotificationSettings {
        return await notificationCenter.notificationSettings()
    }
    
    // MARK: - Deadline Reminders
    
    /// Schedule a deadline reminder notification for an application
    func scheduleDeadlineReminder(for application: ApplicationTracking) async throws {
        guard let jobId = application.jobId,
              let reminderDate = application.reminderDate else {
            throw NotificationError.invalidApplicationData
        }
        
        // Check if we have permission
        let settings = await getNotificationSettings()
        guard settings.authorizationStatus == .authorized else {
            throw NotificationError.permissionDenied
        }
        
        // Get job details for the notification
        let job = try await persistenceService.getCachedJob(jobId: jobId)
        let jobTitle = job?.title ?? "Federal Job Application"
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Application Deadline Reminder"
        content.body = "Don't forget about your application for \(jobTitle)"
        content.sound = .default
        content.categoryIdentifier = AppConfiguration.Notifications.categoryIdentifier
        content.userInfo = [
            "type": "deadline_reminder",
            "jobId": jobId,
            "applicationDate": application.applicationDate?.timeIntervalSince1970 ?? 0
        ]
        
        // Create trigger for the reminder date
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        // Create and schedule the request
        let identifier = "deadline_\(jobId)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
        } catch {
            throw NotificationError.schedulingFailed(error)
        }
    }
    
    /// Cancel a deadline reminder notification
    func cancelDeadlineReminder(for jobId: String) async {
        let identifier = "deadline_\(jobId)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    // MARK: - New Job Notifications
    
    /// Schedule a notification for new jobs matching a saved search
    func scheduleNewJobsNotification(for search: SavedSearch, jobCount: Int) async throws {
        guard let searchId = search.searchId,
              let searchName = search.name,
              search.isNotificationEnabled,
              jobCount > 0 else {
            return // Don't schedule if notifications are disabled or no new jobs
        }
        
        // Check if we have permission
        let settings = await getNotificationSettings()
        guard settings.authorizationStatus == .authorized else {
            throw NotificationError.permissionDenied
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "New Federal Jobs Available"
        
        if jobCount == 1 {
            content.body = "1 new job matches your saved search '\(searchName)'"
        } else {
            content.body = "\(jobCount) new jobs match your saved search '\(searchName)'"
        }
        
        content.sound = .default
        content.badge = NSNumber(value: jobCount)
        content.categoryIdentifier = AppConfiguration.Notifications.categoryIdentifier
        content.userInfo = [
            "type": "new_jobs",
            "searchId": searchId.uuidString,
            "searchName": searchName,
            "jobCount": jobCount
        ]
        
        // Schedule immediately (for new jobs found during background check)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create and schedule the request
        let identifier = "new_jobs_\(searchId.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
        } catch {
            throw NotificationError.schedulingFailed(error)
        }
    }
    
    /// Cancel new jobs notification for a saved search
    func cancelNewJobsNotification(for searchId: UUID) async {
        let identifier = "new_jobs_\(searchId.uuidString)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    // MARK: - Background Job Checking
    
    /// Check for new jobs matching all saved searches with notifications enabled
    func checkForNewJobsInBackground() async {
        do {
            let savedSearches = try await persistenceService.getSavedSearches()
            let notificationEnabledSearches = savedSearches.filter { $0.isNotificationEnabled }
            
            for search in notificationEnabledSearches {
                await checkForNewJobs(in: search)
            }
        } catch {
            // Log error but don't throw - background operations should be silent
            print("Background job check failed: \(error)")
        }
    }
    
    /// Check for new jobs in a specific saved search
    private func checkForNewJobs(in search: SavedSearch) async {
        guard let searchId = search.searchId else { return }
        
        do {
            // Convert saved search to search criteria
            let criteria = SearchCriteria(
                keyword: search.keywords?.isEmpty == false ? search.keywords : nil,
                location: search.location?.isEmpty == false ? search.location : nil,
                department: search.department?.isEmpty == false ? search.department : nil,
                salaryMin: search.salaryMin > 0 ? Int(search.salaryMin) : nil,
                salaryMax: search.salaryMax > 0 ? Int(search.salaryMax) : nil,
                page: 1,
                resultsPerPage: 25,
                remoteOnly: false
            )
            
            // Search for jobs
            let response = try await apiService.searchJobs(criteria: criteria)
            
            // Calculate new jobs since last check
            let lastChecked = search.lastChecked ?? Date.distantPast
            let newJobs = response.jobs.filter { job in
                guard let postedDate = job.matchedObjectDescriptor.publicationDate else { return false }
                return postedDate > lastChecked
            }
            
            // Schedule notification if there are new jobs
            if !newJobs.isEmpty {
                try await scheduleNewJobsNotification(for: search, jobCount: newJobs.count)
            }
            
            // Update last checked timestamp
            search.updateLastChecked()
            try await persistenceService.updateSavedSearch(search)
            
        } catch {
            // Log error but continue with other searches
            print("Failed to check for new jobs in search \(searchId): \(error)")
        }
    }
    
    // MARK: - Notification Management
    
    /// Cancel all pending notifications
    func cancelAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    /// Handle notification response when user taps on a notification
    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        
        guard let type = userInfo["type"] as? String else { return }
        
        switch type {
        case "deadline_reminder":
            await handleDeadlineReminderResponse(userInfo)
        case "new_jobs":
            await handleNewJobsResponse(userInfo)
        default:
            break
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Configure notification categories and actions
    private func configureNotificationCategories() {
        // Define actions for job notifications
        let viewAction = UNNotificationAction(
            identifier: "VIEW_JOBS",
            title: "View Jobs",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: []
        )
        
        // Create category
        let category = UNNotificationCategory(
            identifier: AppConfiguration.Notifications.categoryIdentifier,
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Register category
        notificationCenter.setNotificationCategories([category])
    }
    
    /// Handle deadline reminder notification response
    private func handleDeadlineReminderResponse(_ userInfo: [AnyHashable: Any]) async {
        guard let jobId = userInfo["jobId"] as? String else { return }
        
        // Navigate to job detail or application tracking
        // This would typically post a notification to the app to handle navigation
        NotificationCenter.default.post(
            name: .navigateToJobDetail,
            object: nil,
            userInfo: ["jobId": jobId]
        )
    }
    
    /// Handle new jobs notification response
    private func handleNewJobsResponse(_ userInfo: [AnyHashable: Any]) async {
        guard let searchIdString = userInfo["searchId"] as? String,
              let searchId = UUID(uuidString: searchIdString) else { return }
        
        // Navigate to saved search results
        NotificationCenter.default.post(
            name: .navigateToSavedSearch,
            object: nil,
            userInfo: ["searchId": searchId]
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Handle notification response
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task {
            await handleNotificationResponse(response)
            completionHandler()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToJobDetail = Notification.Name("navigateToJobDetail")
    static let navigateToSavedSearch = Notification.Name("navigateToSavedSearch")
}

// MARK: - Background App Refresh Support

extension NotificationService {
    
    /// Configure background app refresh for job checking
    func configureBackgroundAppRefresh() {
        // This would be called from the app delegate to set up background refresh
        // The actual background refresh would be handled by the system
    }
    
    /// Handle background app refresh
    func handleBackgroundAppRefresh() async -> Bool {
        do {
            await checkForNewJobsInBackground()
            return true
        } catch {
            print("Background app refresh failed: \(error)")
            return false
        }
    }
}