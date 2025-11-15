//
//  JobSearchView.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import SwiftUI

struct JobSearchView: View {
    @StateObject private var viewModel: JobSearchViewModel
    @State private var showingFilters = false
    @State private var searchText = ""
    @State private var showingSaveSuccess = false
    
    private let apiService: USAJobsAPIServiceProtocol
    private let persistenceService: DataPersistenceServiceProtocol
    
    init(
        viewModel: JobSearchViewModel,
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
            searchHeader
            
            // Search Results Content
            searchContent
        }
        .navigationTitle("Federal Jobs")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Filters") {
                    showingFilters = true
                }
                .accessibilityLabel("Open search filters")
            }
        }
        .sheet(isPresented: $showingFilters) {
            FilterView(
                searchCriteria: $viewModel.searchCriteria,
                onApplyFilters: {
                    Task {
                        await viewModel.performSearch()
                    }
                }
            )
        }
        .onAppear {
            // Load recent jobs when the view first appears
            if !viewModel.hasSearched && viewModel.searchResults.isEmpty {
                Task {
                    await viewModel.loadRecentJobs()
                }
            }
        }
        .overlay(alignment: .top) {
            // Success toast for saved search
            if showingSaveSuccess {
                VStack {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Search saved successfully!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 4)
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                }
                .zIndex(1)
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
                    .accessibilityHidden(true)
                
                TextField("Search federal jobs...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        performKeywordSearch()
                    }
                    .accessibleFormField(
                        label: "Job search",
                        hint: "Enter keywords, job titles, or skills to search for federal jobs",
                        value: searchText.isEmpty ? nil : searchText
                    )
                    .dynamicTypeSize(.xSmall ... .accessibility3)
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .foregroundColor(.secondary)
                    .accessibleButton(
                        label: "Clear search",
                        hint: "Removes all text from the search field"
                    )
                    .accessibleTouchTarget()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Quick Filter Buttons
            quickFilterButtons
            
            // Search Summary
            if viewModel.hasSearched {
                searchSummary
            }
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .contain)
    }
    
    private var quickFilterButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                QuickFilterButton(
                    title: "Remote Jobs",
                    icon: "house.fill",
                    isSelected: viewModel.searchCriteria.remoteOnly
                ) {
                    Task {
                        await viewModel.searchRemoteJobs()
                    }
                }
                
                QuickFilterButton(
                    title: "Save Search",
                    icon: "bookmark.fill",
                    isSelected: false
                ) {
                    saveCurrentSearch()
                }
            }
            .padding(.horizontal)
        }
        .accessibilityLabel("Quick actions")
        .accessibilityHint("Remote jobs filter and save current search")
    }
    
    private var searchSummary: some View {
        HStack {
            Text(viewModel.searchSummaryText)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if viewModel.searchCriteria.hasFilters {
                Button("Clear Filters") {
                    Task {
                        await viewModel.clearSearch()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
                .accessibilityLabel("Clear all search filters")
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Search Content
    
    private var searchContent: some View {
        Group {
            if viewModel.shouldShowLoadingState {
                loadingView
            } else if viewModel.shouldShowErrorState {
                errorView
            } else if viewModel.shouldShowEmptyState {
                emptyStateView
            } else if !viewModel.searchResults.isEmpty {
                jobResultsList
            } else {
                welcomeView
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching federal jobs...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading search results")
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Search Error")
                .font(.headline)
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Try Again") {
                Task {
                    await viewModel.performSearch()
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Retry search")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Jobs Found")
                .font(.headline)
            
            Text("Try adjusting your search criteria or filters to find more opportunities.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Clear Filters") {
                Task {
                    await viewModel.clearSearch()
                }
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Clear search filters")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var welcomeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("Federal Job Finder")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Loading recent federal job opportunities...")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            ProgressView()
                .scaleEffect(1.2)
                .padding()
            
            VStack(spacing: 12) {
                Button("Search All Jobs") {
                    Task {
                        await viewModel.loadRecentJobs()
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Load all recent federal jobs")
                
                Button("Browse Remote Jobs") {
                    Task {
                        await viewModel.searchRemoteJobs()
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Browse remote federal jobs")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var jobResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.searchResults, id: \.jobId) { job in
                    JobRowView(
                        job: job,
                        onFavoriteToggle: {
                            // Just a simple callback - JobRowView handles the actual favorite logic
                            // This could be used for analytics or other side effects
                        },
                        apiService: apiService,
                        persistenceService: persistenceService
                    )
                    .padding(.horizontal)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .onAppear {
                        // Load more results when approaching end of list
                        if job.jobId == viewModel.searchResults.last?.jobId {
                            Task {
                                await viewModel.loadMoreResults()
                            }
                        }
                        
                        // Preload images for better performance
                        preloadImagesIfNeeded(for: job)
                    }
                    .onDisappear {
                        // Cleanup resources when view disappears
                        cleanupResourcesIfNeeded(for: job)
                    }
                }
                
                // Load More Button
                if viewModel.shouldShowLoadMoreButton {
                    loadMoreButton
                        .padding(.horizontal)
                }
                
                // Loading More Indicator
                if viewModel.isLoadingMore {
                    loadingMoreView
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await viewModel.refreshSearch()
        }
        .accessibilityLabel("Job search results")
        .onReceive(NotificationCenter.default.publisher(for: .memoryCleanupRequested)) { _ in
            // Handle memory cleanup notification
            handleMemoryCleanup()
        }
    }
    
    private var loadMoreButton: some View {
        Button("Load More Jobs") {
            Task {
                await viewModel.loadMoreResults()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .accessibilityLabel("Load more job results")
    }
    
    private var loadingMoreView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("Loading more jobs...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading more job results")
    }
    
    // MARK: - Helper Methods
    
    private func performKeywordSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        Task {
            await viewModel.searchWithKeyword(searchText)
        }
    }
    
    private func saveCurrentSearch() {
        Task {
            let success = await viewModel.saveCurrentSearch(searchText: searchText)
            
            if success {
                // Show success toast
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showingSaveSuccess = true
                }
                
                // Hide toast after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showingSaveSuccess = false
                    }
                }
            }
        }
    }
    
    // MARK: - Performance Optimization Methods
    
    private func preloadImagesIfNeeded(for job: JobSearchItem) {
        // Preload agency logos or job-related images if available
        // This would be implemented when we have image URLs from the API
        // For now, we'll prepare the infrastructure
        
        // Example: If job has logo URL
        // if let logoURL = job.agencyLogoURL {
        //     Task {
        //         await ImageCacheService.shared.loadImage(from: logoURL)
        //     }
        // }
    }
    
    private func cleanupResourcesIfNeeded(for job: JobSearchItem) {
        // Cleanup resources when job row disappears from view
        // This helps manage memory usage for large lists
        
        // Check if memory usage is high and cleanup if needed
        MemoryManager.shared.performMemoryCleanupIfNeeded()
    }
    
    private func handleMemoryCleanup() {
        // Handle memory cleanup notification
        // This could involve clearing cached view models or other resources
        print("Handling memory cleanup in JobSearchView")
        
        // Force garbage collection of unused resources
        viewModel.cleanupUnusedResources()
    }
}

// MARK: - Quick Filter Button

struct QuickFilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .accessibilityHidden(true)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .dynamicTypeSize(.xSmall ... .accessibility2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .accessibleButton(
            label: "\(title) filter",
            hint: isSelected ? "Currently selected. Tap to deselect" : "Tap to apply this filter",
            traits: isSelected ? .isSelected : []
        )
        .accessibleTouchTarget()
    }
}

// MARK: - Preview

#Preview {
    let mockAPIService = PreviewMockUSAJobsAPIService()
    let mockPersistenceService = PreviewMockDataPersistenceService()
    let mockOfflineManager = OfflineDataManager(
        networkMonitor: NetworkMonitor.shared,
        persistenceService: mockPersistenceService,
        apiService: mockAPIService
    )

    JobSearchView(
        viewModel: JobSearchViewModel(
            apiService: mockAPIService,
            persistenceService: mockPersistenceService,
            offlineManager: mockOfflineManager,
            networkMonitor: NetworkMonitor.shared
        ),
        apiService: mockAPIService,
        persistenceService: mockPersistenceService
    )
}

// MARK: - Mock Services for Preview

private class PreviewMockUSAJobsAPIService: USAJobsAPIServiceProtocol {
    func searchJobs(criteria: SearchCriteria) async throws -> JobSearchResponse {
        // Mock implementation for preview
        return JobSearchResponse(searchResult: SearchResult(
            searchResultItems: [],
            searchResultCount: 0,
            searchResultCountAll: 0
        ))
    }
    
    func getJobDetails(jobId: String) async throws -> JobDescriptor {
        // Return a mock job descriptor
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

private class PreviewMockDataPersistenceService: DataPersistenceServiceProtocol {
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