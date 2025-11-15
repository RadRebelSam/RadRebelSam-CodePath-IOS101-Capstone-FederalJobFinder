//
//  ContentView.swift
//  usajobs
//
//  Created by Dexin Yang on 11/13/25.
//

import SwiftUI
import UserNotifications

@available(iOS 16.0, *)
struct ContentView: View {
    @EnvironmentObject var serviceContainer: ServiceContainer
    @State private var selectedTab: Tab = .search
    @State private var deepLinkJobId: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                JobSearchView(
                    viewModel: JobSearchViewModel(
                        apiService: serviceContainer.apiService,
                        persistenceService: serviceContainer.persistenceService,
                        offlineManager: serviceContainer.offlineManager,
                        networkMonitor: serviceContainer.networkMonitor
                    ),
                    apiService: serviceContainer.apiService,
                    persistenceService: serviceContainer.persistenceService
                )
            }
            .tabItem {
                Image(systemName: Tab.search.icon)
                Text(Tab.search.title)
            }
            .tag(Tab.search)
            .accessibilityLabel("Search tab")
            .accessibilityHint("Search for federal job opportunities")
            
            NavigationStack {
                FavoritesView(
                    viewModel: FavoritesViewModel(
                        persistenceService: serviceContainer.persistenceService,
                        apiService: serviceContainer.apiService
                    ),
                    apiService: serviceContainer.apiService,
                    persistenceService: serviceContainer.persistenceService
                )
            }
            .tabItem {
                Image(systemName: Tab.favorites.icon)
                Text(Tab.favorites.title)
            }
            .tag(Tab.favorites)
            .accessibilityLabel("Favorites tab")
            .accessibilityHint("View your saved favorite jobs")
            
            NavigationStack {
                SavedSearchesView(
                    viewModel: SavedSearchViewModel(
                        persistenceService: serviceContainer.persistenceService,
                        apiService: serviceContainer.apiService,
                        notificationService: serviceContainer.notificationService
                    ),
                    apiService: serviceContainer.apiService,
                    persistenceService: serviceContainer.persistenceService
                )
            }
            .tabItem {
                Image(systemName: Tab.saved.icon)
                Text(Tab.saved.title)
            }
            .tag(Tab.saved)
            .accessibilityLabel("Saved searches tab")
            .accessibilityHint("Manage your saved job searches and notifications")
            
            NavigationStack {
                ApplicationsView(
                    persistenceService: serviceContainer.persistenceService,
                    notificationService: serviceContainer.notificationService
                )
            }
            .tabItem {
                Image(systemName: Tab.applications.icon)
                Text(Tab.applications.title)
            }
            .tag(Tab.applications)
            .accessibilityLabel("Applications tab")
            .accessibilityHint("Track your job applications and deadlines")
        }
        .dynamicTypeSize(.xSmall ... .accessibility5)
        .accessibilityElement(children: .contain)
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .sheet(item: Binding<DeepLinkJobItem?>(
            get: { deepLinkJobId.map(DeepLinkJobItem.init) },
            set: { _ in deepLinkJobId = nil }
        )) { item in
            NavigationStack {
                JobDetailView(
                    jobId: item.jobId,
                    apiService: serviceContainer.apiService,
                    persistenceService: serviceContainer.persistenceService
                )
                .accessibilityLabel("Job details sheet")
            }
        }
    }
    
    // MARK: - Deep Linking
    
    private func handleDeepLink(_ url: URL) {
        guard let target = DeepLinkManager.parseURL(url) else { return }
        
        switch target {
        case .job(let jobId):
            deepLinkJobId = jobId
        case .tab(let tab):
            selectedTab = tab
        }
    }
}

@available(iOS 16.0, *)
#Preview {
    let mockPersistenceService = MockDataPersistenceService()
    let mockAPIService = USAJobsAPIService(apiKey: "preview-key")
    let mockNotificationService = MockNotificationService()

    ContentView()
        .environmentObject(ServiceContainer(
            persistenceService: mockPersistenceService,
            apiService: mockAPIService,
            notificationService: mockNotificationService
        ))
        .preferredColorScheme(.light)
}

// MARK: - Mock Service for Preview

private class MockDataPersistenceService: DataPersistenceServiceProtocol {
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
        // Return a dummy job for preview
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

private class MockNotificationService: NotificationServiceProtocol {
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
