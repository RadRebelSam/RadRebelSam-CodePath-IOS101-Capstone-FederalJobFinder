//
//  OfflineStatusView.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import SwiftUI

/// View component for displaying offline status and connectivity information
struct OfflineStatusView: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @ObservedObject private var offlineManager: OfflineDataManager
    
    let showDetails: Bool
    
    init(offlineManager: OfflineDataManager, showDetails: Bool = false) {
        self.offlineManager = offlineManager
        self.showDetails = showDetails
    }
    
    var body: some View {
        if !networkMonitor.isConnected {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.orange)
                    
                    Text("You're offline")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if offlineManager.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                if showDetails {
                    VStack(alignment: .leading, spacing: 4) {
                        if offlineManager.cachedJobsCount > 0 {
                            Text("\(offlineManager.cachedJobsCount) jobs available offline")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let lastSync = offlineManager.lastSyncDate {
                            Text("Last sync: \(RelativeDateTimeFormatter().localizedString(for: lastSync, relativeTo: Date()))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

/// Compact offline indicator for navigation bars
struct OfflineIndicator: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 4) {
                Image(systemName: "wifi.slash")
                    .font(.caption)
                Text("Offline")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(4)
        }
    }
}

/// Connection quality indicator
struct ConnectionQualityView: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
            
            Text(connectionText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var connectionColor: Color {
        if !networkMonitor.isConnected {
            return .red
        } else if networkMonitor.isExpensive {
            return .orange
        } else {
            return .green
        }
    }
    
    private var connectionText: String {
        if !networkMonitor.isConnected {
            return "No connection"
        } else if networkMonitor.isExpensive {
            return "Limited connection"
        } else {
            return "Connected"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // Create a mock offline manager for preview
        let mockOfflineManager = OfflineDataManager(
            networkMonitor: NetworkMonitor.shared,
            persistenceService: MockDataPersistenceService(),
            apiService: MockUSAJobsAPIService()
        )

        OfflineStatusView(offlineManager: mockOfflineManager, showDetails: true)
        OfflineIndicator()
        ConnectionQualityView()
    }
    .padding()
}

// MARK: - Mock Services for Preview

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

private class MockUSAJobsAPIService: USAJobsAPIServiceProtocol {
    func searchJobs(criteria: SearchCriteria) async throws -> JobSearchResponse {
        return JobSearchResponse(searchResult: SearchResult(searchResultItems: [], searchResultCount: 0, searchResultCountAll: 0))
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
    func validateAPIConnection() async throws -> Bool { return true }
}