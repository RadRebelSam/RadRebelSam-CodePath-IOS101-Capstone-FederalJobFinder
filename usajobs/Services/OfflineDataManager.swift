//
//  OfflineDataManager.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation
import Combine

/// Manager for handling offline functionality and data synchronization
@MainActor
class OfflineDataManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether the app is currently in offline mode
    @Published var isOfflineMode = false
    
    /// Whether data synchronization is in progress
    @Published var isSyncing = false
    
    /// Last successful sync timestamp
    @Published var lastSyncDate: Date?
    
    /// Number of cached jobs available offline
    @Published var cachedJobsCount = 0
    
    /// Whether there are pending changes to sync
    @Published var hasPendingChanges = false
    
    // MARK: - Private Properties
    
    private let networkMonitor: NetworkMonitor
    private let persistenceService: DataPersistenceServiceProtocol
    private let apiService: USAJobsAPIServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // UserDefaults keys for persistence
    private let lastSyncDateKey = "OfflineDataManager.lastSyncDate"
    private let pendingChangesKey = "OfflineDataManager.pendingChanges"
    
    // MARK: - Initialization
    
    init(
        networkMonitor: NetworkMonitor,
        persistenceService: DataPersistenceServiceProtocol,
        apiService: USAJobsAPIServiceProtocol
    ) {
        self.networkMonitor = networkMonitor
        self.persistenceService = persistenceService
        self.apiService = apiService
        
        setupNetworkMonitoring()
        loadPersistedState()
        
        Task {
            await updateCachedJobsCount()
        }
    }
    
    // MARK: - Public Methods
    
    /// Manually trigger data synchronization
    func syncData() async {
        guard networkMonitor.isConnected && !isSyncing else {
            return
        }
        
        isSyncing = true
        
        do {
            // Sync favorite jobs with latest data
            try await syncFavoriteJobs()
            
            // Clean up expired cache
            try await persistenceService.clearExpiredCache()
            
            // Update cache count
            await updateCachedJobsCount()
            
            // Update sync timestamp
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: lastSyncDateKey)
            
            hasPendingChanges = false
            UserDefaults.standard.set(false, forKey: pendingChangesKey)
            
        } catch {
            print("Sync failed: \(error)")
        }
        
        isSyncing = false
    }
    
    /// Get cached job details for offline viewing
    func getCachedJobDetails(jobId: String) async throws -> Job? {
        return try await persistenceService.getCachedJob(jobId: jobId)
    }
    
    /// Get all cached jobs for offline browsing
    func getCachedJobs(limit: Int? = nil) async throws -> [Job] {
        return try await persistenceService.getCachedJobs(limit: limit)
    }
    
    /// Cache job details for offline access
    func cacheJobForOffline(_ jobDetails: JobDescriptor) async throws {
        _ = try await persistenceService.cacheJobDetails(jobDetails)
        await updateCachedJobsCount()
    }
    
    /// Mark that there are pending changes to sync
    func markPendingChanges() {
        hasPendingChanges = true
        UserDefaults.standard.set(true, forKey: pendingChangesKey)
    }
    
    /// Clear all cached data (except favorites)
    func clearCache() async throws {
        try await persistenceService.clearAllCache()
        await updateCachedJobsCount()
    }
    
    /// Get cache statistics
    func getCacheStatistics() async throws -> CacheStatistics {
        let totalJobs = try await persistenceService.getCacheSize()
        let favoriteJobs = try await persistenceService.getFavoriteJobs()
        let cachedJobs = try await persistenceService.getCachedJobs(limit: nil)
        
        let cacheSize = totalJobs
        let favoritesCount = favoriteJobs.count
        let nonFavoritesCount = cacheSize - favoritesCount
        
        // Calculate oldest and newest cache entries
        let sortedJobs = cachedJobs.sorted { ($0.cachedAt ?? Date.distantPast) < ($1.cachedAt ?? Date.distantPast) }
        let oldestCacheDate = sortedJobs.first?.cachedAt
        let newestCacheDate = sortedJobs.last?.cachedAt
        
        return CacheStatistics(
            totalCachedJobs: cacheSize,
            favoritedJobs: favoritesCount,
            nonFavoritedJobs: nonFavoritesCount,
            oldestCacheDate: oldestCacheDate,
            newestCacheDate: newestCacheDate,
            lastSyncDate: lastSyncDate
        )
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOfflineMode = !isConnected
                
                // Auto-sync when connection is restored
                if isConnected && self?.hasPendingChanges == true {
                    Task {
                        await self?.syncData()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadPersistedState() {
        lastSyncDate = UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date
        hasPendingChanges = UserDefaults.standard.bool(forKey: pendingChangesKey)
    }
    
    private func syncFavoriteJobs() async throws {
        let favoriteJobs = try await persistenceService.getFavoriteJobs()
        
        for job in favoriteJobs {
            guard let jobId = job.jobId else { continue }
            
            do {
                // Fetch latest job details from API
                let latestDetails = try await apiService.getJobDetails(jobId: jobId)
                
                // Update cached job with latest information
                _ = try await persistenceService.cacheJobDetails(latestDetails)
                
            } catch {
                // If individual job sync fails, continue with others
                print("Failed to sync job \(jobId): \(error)")
                continue
            }
        }
    }
    
    private func updateCachedJobsCount() async {
        do {
            cachedJobsCount = try await persistenceService.getCacheSize()
        } catch {
            cachedJobsCount = 0
        }
    }
}

// MARK: - Cache Statistics

struct CacheStatistics {
    let totalCachedJobs: Int
    let favoritedJobs: Int
    let nonFavoritedJobs: Int
    let oldestCacheDate: Date?
    let newestCacheDate: Date?
    let lastSyncDate: Date?
    
    var cacheAgeDescription: String {
        guard let oldestDate = oldestCacheDate else {
            return "No cached data"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Oldest: \(formatter.localizedString(for: oldestDate, relativeTo: Date()))"
    }
    
    var lastSyncDescription: String {
        guard let syncDate = lastSyncDate else {
            return "Never synced"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Last sync: \(formatter.localizedString(for: syncDate, relativeTo: Date()))"
    }
}

// MARK: - Offline Mode Extensions

extension OfflineDataManager {
    
    /// Check if a specific feature is available offline
    func isFeatureAvailableOffline(_ feature: OfflineFeature) -> Bool {
        switch feature {
        case .viewFavorites:
            return true
        case .viewCachedJobs:
            return cachedJobsCount > 0
        case .viewApplicationTracking:
            return true
        case .viewSavedSearches:
            return true
        case .searchJobs:
            return false // Requires network
        case .applyToJobs:
            return false // Requires network
        }
    }
    
    /// Get offline availability message for a feature
    func getOfflineMessage(for feature: OfflineFeature) -> String {
        if isFeatureAvailableOffline(feature) {
            return "Available offline"
        } else {
            return "Requires internet connection"
        }
    }
}

enum OfflineFeature {
    case viewFavorites
    case viewCachedJobs
    case viewApplicationTracking
    case viewSavedSearches
    case searchJobs
    case applyToJobs
}