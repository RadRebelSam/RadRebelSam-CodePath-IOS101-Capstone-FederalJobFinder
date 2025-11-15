//
//  ApplicationsView.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import SwiftUI
import UserNotifications

/// View for displaying and managing tracked job applications
struct ApplicationsView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel: ApplicationTrackingViewModel
    @State private var selectedApplication: ApplicationTracking?
    @State private var showingApplicationDetail = false
    @State private var showingStatusPicker = false
    @State private var showingReminderPicker = false
    @State private var showingNotesEditor = false
    
    // MARK: - Initialization
    
    init(
        persistenceService: DataPersistenceServiceProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self._viewModel = StateObject(wrappedValue: ApplicationTrackingViewModel(
            persistenceService: persistenceService,
            notificationService: notificationService
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading applications...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.applications.isEmpty {
                emptyStateView
            } else {
                applicationsList
            }
        }
        .navigationTitle("My Applications")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Refresh") {
                    Task {
                        await viewModel.refresh()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.refresh()
            }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .sheet(item: $selectedApplication) { application in
            ApplicationDetailSheet(
                application: application,
                viewModel: viewModel,
                showingStatusPicker: $showingStatusPicker,
                showingReminderPicker: $showingReminderPicker,
                showingNotesEditor: $showingNotesEditor
            )
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Applications Tracked")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start tracking your federal job applications to stay organized and never miss a deadline.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("To track an application, go to a job detail and tap 'Track Application'.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    // MARK: - Applications List
    
    private var applicationsList: some View {
        List {
            // Summary section
            summarySection
            
            // Applications by status
            ForEach(ApplicationTracking.Status.allCases, id: \.self) { status in
                let statusApplications = viewModel.applications(with: status)
                if !statusApplications.isEmpty {
                    Section(header: Text(status.displayName)) {
                        ForEach(statusApplications, id: \.objectID) { application in
                            ApplicationRowView(application: application) {
                                selectedApplication = application
                                showingApplicationDetail = true
                            }
                        }
                        .onDelete { indexSet in
                            deleteApplications(at: indexSet, from: statusApplications)
                        }
                    }
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        Section {
            VStack(spacing: 12) {
                HStack {
                    StatCard(
                        title: "Total",
                        value: "\(viewModel.totalApplications)",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Active",
                        value: "\(viewModel.activeApplications)",
                        color: .orange
                    )
                    
                    StatCard(
                        title: "Offers",
                        value: "\(viewModel.offersReceived)",
                        color: .green
                    )
                }
                
                // Upcoming deadlines
                let upcomingDeadlines = viewModel.applicationsWithUpcomingDeadlines()
                if !upcomingDeadlines.isEmpty {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundColor(.orange)
                        Text("\(upcomingDeadlines.count) upcoming deadline\(upcomingDeadlines.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Helper Methods
    
    private func deleteApplications(at offsets: IndexSet, from applications: [ApplicationTracking]) {
        for index in offsets {
            let application = applications[index]
            Task {
                await viewModel.deleteApplication(application)
            }
        }
    }
}

// MARK: - Application Row View

struct ApplicationRowView: View {
    let application: ApplicationTracking
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(application.jobId ?? "Unknown Job")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    StatusBadge(status: application.applicationStatus)
                }
                
                if let applicationDate = application.applicationDate {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text("Applied: \(applicationDate, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if application.hasActiveReminder {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                }
                
                if let notes = application.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: ApplicationTracking.Status
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(Capsule())
    }
    
    private var backgroundColor: Color {
        switch status {
        case .applied:
            return .blue.opacity(0.2)
        case .underReview:
            return .yellow.opacity(0.2)
        case .interviewed:
            return .orange.opacity(0.2)
        case .offered:
            return .green.opacity(0.2)
        case .rejected:
            return .red.opacity(0.2)
        case .withdrawn:
            return .gray.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch status {
        case .applied:
            return .blue
        case .underReview:
            return .yellow
        case .interviewed:
            return .orange
        case .offered:
            return .green
        case .rejected:
            return .red
        case .withdrawn:
            return .gray
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Application Detail Sheet

struct ApplicationDetailSheet: View {
    let application: ApplicationTracking
    let viewModel: ApplicationTrackingViewModel
    
    @Binding var showingStatusPicker: Bool
    @Binding var showingReminderPicker: Bool
    @Binding var showingNotesEditor: Bool
    
    @Environment(\.dismiss) private var dismiss
    @State private var notes: String = ""
    @State private var selectedReminderDays = 3
    
    var body: some View {
        NavigationView {
            List {
                // Job Information
                Section("Job Information") {
                    HStack {
                        Text("Job ID")
                        Spacer()
                        Text(application.jobId ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    if let applicationDate = application.applicationDate {
                        HStack {
                            Text("Application Date")
                            Spacer()
                            Text(applicationDate, style: .date)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Status Management
                Section("Status") {
                    HStack {
                        Text("Current Status")
                        Spacer()
                        StatusBadge(status: application.applicationStatus)
                    }
                    
                    Button("Update Status") {
                        showingStatusPicker = true
                    }
                }
                
                // Reminder Management
                Section("Reminders") {
                    if let reminderDate = application.reminderDate {
                        HStack {
                            Text("Reminder Set")
                            Spacer()
                            Text(reminderDate, style: .date)
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Clear Reminder", role: .destructive) {
                            Task {
                                await viewModel.clearReminder(for: application)
                            }
                        }
                    } else {
                        Text("No reminder set")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Set Reminder") {
                        showingReminderPicker = true
                    }
                }
                
                // Notes
                Section("Notes") {
                    if let existingNotes = application.notes, !existingNotes.isEmpty {
                        Text(existingNotes)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No notes")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Edit Notes") {
                        notes = application.notes ?? ""
                        showingNotesEditor = true
                    }
                }
                
                // Actions
                Section {
                    Button("Delete Application", role: .destructive) {
                        Task {
                            await viewModel.deleteApplication(application)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Application Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog("Update Status", isPresented: $showingStatusPicker) {
            ForEach(ApplicationTracking.Status.allCases, id: \.self) { status in
                Button(status.displayName) {
                    Task {
                        await viewModel.updateApplicationStatus(application, to: status)
                    }
                }
            }
        }
        .confirmationDialog("Set Reminder", isPresented: $showingReminderPicker) {
            Button("1 day") {
                Task {
                    await viewModel.setReminder(for: application, daysFromNow: 1)
                }
            }
            Button("3 days") {
                Task {
                    await viewModel.setReminder(for: application, daysFromNow: 3)
                }
            }
            Button("1 week") {
                Task {
                    await viewModel.setReminder(for: application, daysFromNow: 7)
                }
            }
            Button("2 weeks") {
                Task {
                    await viewModel.setReminder(for: application, daysFromNow: 14)
                }
            }
        }
        .alert("Edit Notes", isPresented: $showingNotesEditor) {
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3...6)
            
            Button("Save") {
                Task {
                    await viewModel.updateNotes(for: application, notes: notes)
                }
            }
            
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Preview

#Preview {
    ApplicationsView(
        persistenceService: ApplicationsPreviewMockDataPersistenceService(),
        notificationService: ApplicationsPreviewMockNotificationService()
    )
}

// MARK: - Mock Service for Preview

private class ApplicationsPreviewMockDataPersistenceService: DataPersistenceServiceProtocol {
    func saveFavoriteJob(_ job: Job) async throws {}
    func removeFavoriteJob(jobId: String) async throws {}
    func getFavoriteJobs() async throws -> [Job] { return [] }
    func toggleFavoriteStatus(jobId: String) async throws -> Bool { return false }
    func saveSavedSearch(_ search: SavedSearch) async throws {}
    func getSavedSearches() async throws -> [SavedSearch] { return [] }
    func deleteSavedSearch(searchId: UUID) async throws {}
    func updateSavedSearch(_ search: SavedSearch) async throws {}
    func saveApplicationTracking(_ application: ApplicationTracking) async throws {}
    func getApplicationTrackings() async throws -> [ApplicationTracking] { return [] }
    func updateApplicationStatus(jobId: String, status: ApplicationTracking.Status) async throws {}
    func deleteApplicationTracking(jobId: String) async throws {}
    func getApplicationTracking(for jobId: String) async throws -> ApplicationTracking? { return nil }
    func cacheJob(_ job: Job) async throws {}
    func getCachedJob(jobId: String) async throws -> Job? { return nil }
    func clearExpiredCache() async throws {}
    func getCachedJobs(limit: Int?) async throws -> [Job] { return [] }
    func cacheJobDetails(_ jobDetails: JobDescriptor) async throws -> Job {
        return Job(
            context: CoreDataStack.shared.context,
            jobId: jobDetails.positionId,
            title: jobDetails.positionTitle,
            department: jobDetails.departmentName,
            location: jobDetails.primaryLocation
        )
    }
    func getCacheSize() async throws -> Int { return 0 }
    func clearAllCache() async throws {}
}

private class ApplicationsPreviewMockNotificationService: NotificationServiceProtocol {
    func requestNotificationPermissions() async throws -> Bool { return true }
    func scheduleDeadlineReminder(for application: ApplicationTracking) async throws {}
    func scheduleNewJobsNotification(for search: SavedSearch, jobCount: Int) async throws {}
    func cancelDeadlineReminder(for jobId: String) async {}
    func cancelNewJobsNotification(for searchId: UUID) async {}
    func cancelAllNotifications() async {}
    func getNotificationSettings() async -> UNNotificationSettings {
        return await UNUserNotificationCenter.current().notificationSettings()
    }
    func handleNotificationResponse(_ response: UNNotificationResponse) async {}
    func handleBackgroundAppRefresh() async -> Bool { return true }
}