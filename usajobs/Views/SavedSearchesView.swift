//
//  SavedSearchesView.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import SwiftUI

struct SavedSearchesView: View {
    @StateObject private var viewModel: SavedSearchViewModel
    @State private var searchText = ""
    
    private let apiService: USAJobsAPIServiceProtocol
    private let persistenceService: DataPersistenceServiceProtocol
    
    init(
        viewModel: SavedSearchViewModel,
        apiService: USAJobsAPIServiceProtocol,
        persistenceService: DataPersistenceServiceProtocol
    ) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.apiService = apiService
        self.persistenceService = persistenceService
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Header
            if !viewModel.isEmpty {
                searchHeader
            }
            
            // Content
            savedSearchesContent
        }
        .navigationTitle("Saved Searches")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Add") {
                    viewModel.showCreateSearchSheet()
                }
                .accessibilityLabel("Create new saved search")
            }
        }
        .onAppear {
            Task {
                await viewModel.loadSavedSearches()
            }
        }
        .refreshable {
            await viewModel.loadSavedSearches()
        }
        .sheet(isPresented: $viewModel.showingCreateEditSheet) {
            SavedSearchEditSheet(
                viewModel: viewModel,
                savedSearch: viewModel.selectedSearch
            )
        }
        .alert("Delete Saved Search", isPresented: $viewModel.showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelDelete()
            }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.confirmDelete()
                }
            }
        } message: {
            if let search = viewModel.searchToDelete {
                Text("Are you sure you want to delete \"\(search.name ?? "this search")\"? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Search Header
    
    private var searchHeader: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search saved searches...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: searchText) { newValue in
                        viewModel.searchSavedSearches(with: newValue)
                    }
                    .accessibilityLabel("Search saved searches")
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                        viewModel.searchSavedSearches(with: "")
                    }
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Clear search text")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Summary
            HStack {
                Text(viewModel.summaryText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if viewModel.isExecutingSearch {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Executing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Saved Searches Content
    
    private var savedSearchesContent: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            } else if viewModel.shouldShowEmptyState {
                emptyStateView
            } else if viewModel.shouldShowNoResultsState {
                noResultsView
            } else {
                savedSearchesList
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading saved searches...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading saved searches")
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Error Loading Saved Searches")
                .font(.headline)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                Task {
                    viewModel.clearError()
                    await viewModel.loadSavedSearches()
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Retry loading saved searches")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bookmark")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Saved Searches")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Save your search criteria to quickly find jobs that match your preferences. You can also enable notifications to be alerted when new matching jobs are posted.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Create Saved Search") {
                viewModel.showCreateSearchSheet()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Create your first saved search")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Results Found")
                .font(.headline)
            
            Text("No saved searches match your current search criteria.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Clear Search") {
                searchText = ""
                viewModel.searchSavedSearches(with: "")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Clear search text")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var savedSearchesList: some View {
        List {
            ForEach(viewModel.filteredSavedSearches, id: \.objectID) { savedSearch in
                SavedSearchRowView(
                    savedSearch: savedSearch,
                    newJobCount: viewModel.newJobCount(for: savedSearch),
                    onExecute: {
                        Task {
                            let _ = await viewModel.executeSavedSearch(savedSearch)
                            // TODO: Navigate to search results
                        }
                    },
                    onEdit: {
                        viewModel.showEditSearchSheet(for: savedSearch)
                    },
                    onToggleNotifications: {
                        Task {
                            await viewModel.toggleNotifications(for: savedSearch)
                        }
                    },
                    onDelete: {
                        viewModel.showDeleteConfirmation(for: savedSearch)
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete") {
                        viewModel.showDeleteConfirmation(for: savedSearch)
                    }
                    .tint(.red)
                    .accessibilityLabel("Delete saved search")
                    
                    Button("Edit") {
                        viewModel.showEditSearchSheet(for: savedSearch)
                    }
                    .tint(.blue)
                    .accessibilityLabel("Edit saved search")
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button("Execute") {
                        Task {
                            let _ = await viewModel.executeSavedSearch(savedSearch)
                            // TODO: Navigate to search results
                        }
                    }
                    .tint(.green)
                    .accessibilityLabel("Execute saved search")
                }
            }
        }
        .listStyle(PlainListStyle())
        .accessibilityLabel("Saved searches list")
    }
}

// MARK: - Saved Search Row View

struct SavedSearchRowView: View {
    let savedSearch: SavedSearch
    let newJobCount: Int
    let onExecute: () -> Void
    let onEdit: () -> Void
    let onToggleNotifications: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with name and new job count
            HStack {
                Text(savedSearch.name ?? "Unnamed Search")
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                if newJobCount > 0 {
                    Text("\(newJobCount) new")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            
            // Search criteria
            Text(searchCriteriaDisplay)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // Status row
            HStack {
                // Last checked
                Text(lastCheckedDisplay)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Notification status
                HStack(spacing: 4) {
                    Image(systemName: notificationStatusImage)
                        .font(.caption)
                        .foregroundColor(notificationStatusColor)
                    
                    Text(savedSearch.isNotificationEnabled ? "On" : "Off")
                        .font(.caption)
                        .foregroundColor(notificationStatusColor)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Execute") {
                    onExecute()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Execute this saved search")
                
                Button("Edit") {
                    onEdit()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Edit this saved search")
                
                Button(savedSearch.isNotificationEnabled ? "Notifications On" : "Notifications Off") {
                    onToggleNotifications()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(notificationStatusColor)
                .accessibilityLabel("Toggle notifications for this saved search")
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Saved search: \(savedSearch.name ?? "Unnamed"), \(searchCriteriaDisplay)")
        .accessibilityHint("Double tap to execute search")
        .onTapGesture {
            onExecute()
        }
    }
    
    // MARK: - Helper Properties
    
    private var searchCriteriaDisplay: String {
        var components: [String] = []
        
        if let keywords = savedSearch.keywords, !keywords.isEmpty {
            components.append("Keywords: \(keywords)")
        }
        
        if let location = savedSearch.location, !location.isEmpty {
            components.append("Location: \(location)")
        }
        
        if let department = savedSearch.department, !department.isEmpty {
            components.append("Department: \(department)")
        }
        
        if savedSearch.salaryMin > 0 || savedSearch.salaryMax > 0 {
            let min = savedSearch.salaryMin
            let max = savedSearch.salaryMax
            
            if min > 0 && max > 0 {
                components.append("Salary: $\(Int(min).formatted()) - $\(Int(max).formatted())")
            } else if min > 0 {
                components.append("Salary: $\(Int(min).formatted())+")
            } else if max > 0 {
                components.append("Salary: Up to $\(Int(max).formatted())")
            }
        }
        
        return components.isEmpty ? "All jobs" : components.joined(separator: ", ")
    }
    
    private var lastCheckedDisplay: String {
        guard let lastChecked = savedSearch.lastChecked else {
            return "Never checked"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return "Last checked \(formatter.localizedString(for: lastChecked, relativeTo: Date()))"
    }
    
    private var notificationStatusColor: Color {
        return savedSearch.isNotificationEnabled ? .green : .secondary
    }
    
    private var notificationStatusImage: String {
        return savedSearch.isNotificationEnabled ? "bell.fill" : "bell.slash"
    }
}

// MARK: - Preview

#Preview {
    let mockAPIService = SavedSearchesPreviewMockUSAJobsAPIService()
    let mockPersistenceService = SavedSearchesPreviewMockDataPersistenceService()
    let mockNotificationService = SavedSearchesPreviewMockNotificationService()

    SavedSearchesView(
        viewModel: SavedSearchViewModel(
            persistenceService: mockPersistenceService,
            apiService: mockAPIService,
            notificationService: mockNotificationService
        ),
        apiService: mockAPIService,
        persistenceService: mockPersistenceService
    )
}

// MARK: - Mock Services for Preview

private class SavedSearchesPreviewMockUSAJobsAPIService: USAJobsAPIServiceProtocol {
    func searchJobs(criteria: SearchCriteria) async throws -> JobSearchResponse {
        return JobSearchResponse(searchResult: SearchResult(
            searchResultItems: [],
            searchResultCount: 0,
            searchResultCountAll: 0
        ))
    }
    
    func getJobDetails(jobId: String) async throws -> JobDescriptor {
        return JobDescriptor(
            positionId: jobId,
            positionTitle: "Sample Job",
            positionUri: "https://example.com",
            applicationCloseDate: "2024-12-31T23:59:59.000Z",
            positionStartDate: "2024-01-01T00:00:00.000Z",
            positionEndDate: "2024-12-31T23:59:59.000Z",
            publicationStartDate: "2024-01-01T00:00:00.000Z",
            applicationUri: "https://usajobs.gov/apply",
            positionLocationDisplay: "Washington, DC",
            positionLocation: [],
            organizationName: "Sample Agency",
            departmentName: "Sample Department",
            jobCategory: [],
            jobGrade: [],
            positionRemuneration: [],
            positionSummary: "Sample job summary",
            positionFormattedDescription: [],
            userArea: nil,
            qualificationSummary: nil
        )
    }
    
    func validateAPIConnection() async throws -> Bool {
        return true
    }
}

private class SavedSearchesPreviewMockDataPersistenceService: DataPersistenceServiceProtocol {
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
            location: jobDetails.positionLocationDisplay
        )
    }
    func getCacheSize() async throws -> Int { return 0 }
    func clearAllCache() async throws {}
}

private class SavedSearchesPreviewMockNotificationService: NotificationServiceProtocol {
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