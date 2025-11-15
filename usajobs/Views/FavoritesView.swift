//
//  FavoritesView.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel: FavoritesViewModel
    @State private var searchText = ""
    @State private var selectedFilter: FavoriteFilter = .all
    @State private var showingFilterSheet = false
    
    private let apiService: USAJobsAPIServiceProtocol
    private let persistenceService: DataPersistenceServiceProtocol
    
    init(
        viewModel: FavoritesViewModel,
        apiService: USAJobsAPIServiceProtocol,
        persistenceService: DataPersistenceServiceProtocol
    ) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.apiService = apiService
        self.persistenceService = persistenceService
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filter Header
            searchAndFilterHeader
            
            // Content
            favoritesContent
        }
        .navigationTitle("Favorite Jobs")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if !viewModel.isEmpty {
                    Button("Refresh") {
                        Task {
                            await viewModel.refreshJobStatuses()
                        }
                    }
                    .disabled(viewModel.isRefreshingStatuses)
                    .accessibilityLabel("Refresh job statuses")
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadFavorites()
            }
        }
        .refreshable {
            await viewModel.loadFavorites()
        }
    }
    
    // MARK: - Search and Filter Header
    
    private var searchAndFilterHeader: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search favorites...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: searchText) { newValue in
                        viewModel.searchFavorites(with: newValue)
                    }
                    .accessibilityLabel("Search favorite jobs")
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                        viewModel.searchFavorites(with: "")
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
            
            // Filter Buttons and Summary
            if !viewModel.isEmpty {
                filterAndSummarySection
            }
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
    }
    
    private var filterAndSummarySection: some View {
        VStack(spacing: 8) {
            // Filter Buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FavoriteFilter.allCases, id: \.self) { filter in
                        FilterButton(
                            filter: filter,
                            isSelected: selectedFilter == filter,
                            count: countForFilter(filter)
                        ) {
                            selectedFilter = filter
                            viewModel.applyFilter(filter)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Summary
            HStack {
                Text(viewModel.summaryText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if viewModel.isRefreshingStatuses {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Refreshing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Favorites Content
    
    private var favoritesContent: some View {
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
                favoritesList
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading favorites...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading favorite jobs")
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Error Loading Favorites")
                .font(.headline)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                Task {
                    viewModel.clearError()
                    await viewModel.loadFavorites()
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Retry loading favorites")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Favorite Jobs")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Jobs you favorite will appear here. Start by searching for federal jobs and tap the heart icon to save them.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Search Jobs") {
                // TODO: Navigate to search tab
                // This would typically be handled by the parent TabView
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Go to job search")
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
            
            Text("No favorite jobs match your current search or filter criteria.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Clear Filters") {
                searchText = ""
                selectedFilter = .all
                viewModel.searchFavorites(with: "")
                viewModel.applyFilter(.all)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Clear search and filters")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var favoritesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredFavoriteJobs, id: \.objectID) { job in
                    FavoriteJobRowView(
                        job: job,
                        onRemove: {
                            Task {
                                await viewModel.removeFavorite(job: job)
                            }
                        },
                        apiService: apiService,
                        persistenceService: persistenceService
                    )
                    .padding(.horizontal)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .contextMenu {
                        Button("Remove from Favorites", systemImage: "heart.slash") {
                            Task {
                                await viewModel.removeFavorite(job: job)
                            }
                        }
                        .foregroundColor(.red)
                    }
                    .onAppear {
                        // Preload job details for better performance
                        preloadJobDetailsIfNeeded(for: job)
                    }
                    .onDisappear {
                        // Cleanup resources when view disappears
                        cleanupResourcesIfNeeded(for: job)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityLabel("Favorite jobs list")
        .onReceive(NotificationCenter.default.publisher(for: .memoryCleanupRequested)) { _ in
            // Handle memory cleanup notification
            handleMemoryCleanup()
        }
    }
    
    // MARK: - Helper Methods
    
    private func countForFilter(_ filter: FavoriteFilter) -> Int {
        switch filter {
        case .all:
            return viewModel.favoriteJobs.count
        case .active:
            return viewModel.activeJobsCount
        case .expired:
            return viewModel.expiredJobsCount
        case .recentlyAdded:
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return viewModel.favoriteJobs.filter { job in
                guard let cachedAt = job.cachedAt else { return false }
                return cachedAt >= sevenDaysAgo
            }.count
        }
    }
    
    // MARK: - Performance Optimization Methods
    
    private func preloadJobDetailsIfNeeded(for job: Job) {
        // Preload job details for better performance when user taps on job
        // This could involve caching additional job information
        
        // Example: Preload job images if available
        // if let logoURL = job.agencyLogoURL {
        //     Task {
        //         await ImageCacheService.shared.loadImage(from: logoURL)
        //     }
        // }
    }
    
    private func cleanupResourcesIfNeeded(for job: Job) {
        // Cleanup resources when job row disappears from view
        // This helps manage memory usage for large lists
        
        // Check if memory usage is high and cleanup if needed
        MemoryManager.shared.performMemoryCleanupIfNeeded()
    }
    
    private func handleMemoryCleanup() {
        // Handle memory cleanup notification
        // This could involve clearing cached view models or other resources
        print("Handling memory cleanup in FavoritesView")
        
        // Force garbage collection of unused resources
        viewModel.cleanupUnusedResources()
    }
}

// MARK: - Filter Button

struct FilterButton: View {
    let filter: FavoriteFilter
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.systemImage)
                    .font(.caption)
                
                Text(filter.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("(\(count))")
                        .font(.caption2)
                        .opacity(0.8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .accessibilityLabel("\(filter.displayName) filter, \(count) jobs")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview {
    let mockAPIService = FavoritesPreviewMockUSAJobsAPIService()
    let mockPersistenceService = FavoritesPreviewMockDataPersistenceService()
    
    FavoritesView(
        viewModel: FavoritesViewModel(
            persistenceService: mockPersistenceService,
            apiService: mockAPIService
        ),
        apiService: mockAPIService,
        persistenceService: mockPersistenceService
    )
}

// MARK: - Mock Services for Preview

private class FavoritesPreviewMockUSAJobsAPIService: USAJobsAPIServiceProtocol {
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

private class FavoritesPreviewMockDataPersistenceService: DataPersistenceServiceProtocol {
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