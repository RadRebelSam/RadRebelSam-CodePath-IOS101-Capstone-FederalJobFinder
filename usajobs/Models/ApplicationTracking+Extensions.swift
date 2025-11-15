//
//  ApplicationTracking+Extensions.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/14/25.
//

import Foundation
import CoreData

// MARK: - ApplicationTracking Extensions

extension ApplicationTracking {
    
    /// Application status enumeration
    enum Status: String, CaseIterable {
        case applied = "applied"
        case underReview = "under_review"
        case interviewed = "interviewed"
        case offered = "offered"
        case rejected = "rejected"
        case withdrawn = "withdrawn"
        
        var displayName: String {
            switch self {
            case .applied:
                return "Applied"
            case .underReview:
                return "Under Review"
            case .interviewed:
                return "Interviewed"
            case .offered:
                return "Offered"
            case .rejected:
                return "Rejected"
            case .withdrawn:
                return "Withdrawn"
            }
        }
        
        var systemImage: String {
            switch self {
            case .applied:
                return "paperplane.fill"
            case .underReview:
                return "clock.fill"
            case .interviewed:
                return "person.2.fill"
            case .offered:
                return "checkmark.circle.fill"
            case .rejected:
                return "xmark.circle.fill"
            case .withdrawn:
                return "arrow.uturn.left.circle.fill"
            }
        }
        
        var color: String {
            switch self {
            case .applied:
                return "blue"
            case .underReview:
                return "orange"
            case .interviewed:
                return "purple"
            case .offered:
                return "green"
            case .rejected:
                return "red"
            case .withdrawn:
                return "gray"
            }
        }
    }
    
    /// Computed property for application status
    var applicationStatus: Status {
        get {
            return Status(rawValue: status ?? "") ?? .applied
        }
        set {
            status = newValue.rawValue
        }
    }
    
    /// Check if application is active (not rejected or withdrawn)
    var isActive: Bool {
        return ![.rejected, .withdrawn].contains(applicationStatus)
    }
    
    /// Check if application needs follow-up
    var needsFollowUp: Bool {
        guard let applicationDate = applicationDate else { return false }
        
        switch applicationStatus {
        case .applied, .underReview:
            // Follow up after 2 weeks
            let followUpDate = Calendar.current.date(byAdding: .day, value: 14, to: applicationDate)
            return Date() >= (followUpDate ?? Date())
        case .interviewed:
            // Follow up after 1 week
            let followUpDate = Calendar.current.date(byAdding: .day, value: 7, to: applicationDate)
            return Date() >= (followUpDate ?? Date())
        default:
            return false
        }
    }
    
    /// Days since application was submitted
    var daysSinceApplication: Int? {
        guard let applicationDate = applicationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: applicationDate, to: Date()).day
    }
    
    /// Formatted application date string
    var formattedApplicationDate: String {
        guard let applicationDate = applicationDate else { return "Unknown" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: applicationDate)
    }
    
    /// Formatted reminder date string
    var formattedReminderDate: String? {
        guard let reminderDate = reminderDate else { return nil }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: reminderDate)
    }

    /// Update application status
    func updateStatus(to newStatus: Status) {
        self.status = newStatus.rawValue
    }
    
    /// Set reminder for application deadline
    func setReminder(daysFromNow: Int) {
        let calendar = Calendar.current
        self.reminderDate = calendar.date(byAdding: .day, value: daysFromNow, to: Date())
    }
    
    /// Clear reminder for application
    func clearReminder() {
        self.reminderDate = nil
    }
    
    /// Check if application has an active reminder
    var hasActiveReminder: Bool {
        guard let reminderDate = reminderDate else { return false }
        return reminderDate > Date()
    }
}

// MARK: - Core Data Convenience Initializer

extension ApplicationTracking {
    
    /// Convenience initializer for ApplicationTracking
    convenience init(
        context: NSManagedObjectContext,
        jobId: String,
        status: Status = .applied,
        applicationDate: Date = Date(),
        notes: String? = nil,
        reminderDate: Date? = nil
    ) {
        self.init(context: context)
        self.jobId = jobId
        self.status = status.rawValue
        self.applicationDate = applicationDate
        self.notes = notes
        self.reminderDate = reminderDate
    }
}