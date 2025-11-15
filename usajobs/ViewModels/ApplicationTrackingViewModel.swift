//
//  ApplicationTrackingViewModel.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation
import CoreData
import Combine

/// ViewModel for managing application tracking functionality
@MainActor
class ApplicationTrackingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var applications: [ApplicationTracking] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingError = false
    
    // MARK: - Private Properties
    
    private let persistenceService: DataPersistenceServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        persistenceService: DataPersistenceServiceProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.persistenceService = persistenceService
        self.notificationService = notificationService
        
        // Load applications on initialization
        Task {
            await loadApplications()
        }
    }
    
    // MARK: - Public Methods
    
    /// Load all application tracking records
    func loadApplications() async {
        isLoading = true
        errorMessage = nil
        
        do {
            applications = try await persistenceService.getApplicationTrackings()
        } catch {
            await handleError(error)
        }
        
        isLoading = false
    }
    
    /// Create a new application tracking record
    func createApplication(for jobId: String) async {
        do {
            let context = CoreDataStack.shared.context
            let application = ApplicationTracking(context: context, jobId: jobId)
            
            try await persistenceService.saveApplicationTracking(application)
            await loadApplications()
            
            // Schedule default reminder (3 days from now)
            application.setReminder(daysFromNow: AppConfiguration.Notifications.defaultReminderDays)
            try await persistenceService.saveApplicationTracking(application)
            try await notificationService.scheduleDeadlineReminder(for: application)
            
        } catch {
            await handleError(error)
        }
    }
    
    /// Update application status
    func updateApplicationStatus(_ application: ApplicationTracking, to status: ApplicationTracking.Status) async {
        guard let jobId = application.jobId else { return }
        
        do {
            try await persistenceService.updateApplicationStatus(jobId: jobId, status: status)
            await loadApplications()
        } catch {
            await handleError(error)
        }
    }
    
    /// Delete an application tracking record
    func deleteApplication(_ application: ApplicationTracking) async {
        guard let jobId = application.jobId else { return }
        
        do {
            // Cancel any pending notifications
            await notificationService.cancelDeadlineReminder(for: jobId)
            
            // Delete from persistence
            try await persistenceService.deleteApplicationTracking(jobId: jobId)
            await loadApplications()
        } catch {
            await handleError(error)
        }
    }
    
    /// Set reminder for application
    func setReminder(for application: ApplicationTracking, daysFromNow: Int) async {
        do {
            application.setReminder(daysFromNow: daysFromNow)
            try await persistenceService.saveApplicationTracking(application)
            
            // Schedule notification
            try await notificationService.scheduleDeadlineReminder(for: application)
            
            await loadApplications()
        } catch {
            await handleError(error)
        }
    }
    
    /// Clear reminder for application
    func clearReminder(for application: ApplicationTracking) async {
        guard let jobId = application.jobId else { return }
        
        do {
            application.clearReminder()
            try await persistenceService.saveApplicationTracking(application)
            
            // Cancel notification
            await notificationService.cancelDeadlineReminder(for: jobId)
            
            await loadApplications()
        } catch {
            await handleError(error)
        }
    }
    
    /// Update notes for application
    func updateNotes(for application: ApplicationTracking, notes: String) async {
        do {
            application.notes = notes.isEmpty ? nil : notes
            try await persistenceService.saveApplicationTracking(application)
            await loadApplications()
        } catch {
            await handleError(error)
        }
    }
    
    /// Get application for specific job ID
    func getApplication(for jobId: String) async -> ApplicationTracking? {
        do {
            return try await persistenceService.getApplicationTracking(for: jobId)
        } catch {
            await handleError(error)
            return nil
        }
    }
    
    /// Check if job is being tracked
    func isJobTracked(_ jobId: String) -> Bool {
        return applications.contains { $0.jobId == jobId }
    }
    
    /// Get applications by status
    func applications(with status: ApplicationTracking.Status) -> [ApplicationTracking] {
        return applications.filter { $0.applicationStatus == status }
    }
    
    /// Get applications with upcoming deadlines (within 7 days)
    func applicationsWithUpcomingDeadlines() -> [ApplicationTracking] {
        let sevenDaysFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        
        return applications.filter { application in
            guard let reminderDate = application.reminderDate else { return false }
            return reminderDate <= sevenDaysFromNow && reminderDate > Date()
        }
    }
    
    /// Refresh applications data
    func refresh() async {
        await loadApplications()
    }
    
    // MARK: - Private Methods
    
    /// Handle errors and update UI state
    private func handleError(_ error: Error) async {
        errorMessage = error.localizedDescription
        showingError = true
        
        // Log error for debugging
        print("ApplicationTrackingViewModel error: \(error)")
    }
    
    /// Clear error state
    func clearError() {
        errorMessage = nil
        showingError = false
    }
}

// MARK: - Computed Properties

extension ApplicationTrackingViewModel {
    
    /// Total number of applications
    var totalApplications: Int {
        applications.count
    }
    
    /// Number of active applications (applied or interviewed status)
    var activeApplications: Int {
        applications.filter { 
            $0.applicationStatus == .applied || $0.applicationStatus == .interviewed 
        }.count
    }
    
    /// Number of applications with offers
    var offersReceived: Int {
        applications(with: .offered).count
    }
    
    /// Applications grouped by status for display
    var applicationsByStatus: [ApplicationTracking.Status: [ApplicationTracking]] {
        Dictionary(grouping: applications) { $0.applicationStatus }
    }
}