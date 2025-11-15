//
//  MemoryManager.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation
import UIKit

/// Memory management utility for optimizing performance with large datasets
class MemoryManager {
    static let shared = MemoryManager()
    
    private let maxCachedItems = 500
    private let memoryWarningThreshold = 0.8 // 80% of available memory
    private var memoryObserver: NSObjectProtocol?
    
    // Cache for view models and heavy objects
    private var viewModelCache = NSCache<NSString, AnyObject>()
    private var imagePreloadQueue = DispatchQueue(label: "image.preload", qos: .utility)
    
    private init() {
        setupMemoryManagement()
        setupMemoryWarningObserver()
    }
    
    deinit {
        if let observer = memoryObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public Methods
    
    /// Configure cache limits based on device capabilities
    func setupMemoryManagement() {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryInMB = Int(physicalMemory / (1024 * 1024))
        
        // Adjust cache limits based on available memory
        if memoryInMB > 4000 { // > 4GB
            viewModelCache.countLimit = 100
            viewModelCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        } else if memoryInMB > 2000 { // > 2GB
            viewModelCache.countLimit = 75
            viewModelCache.totalCostLimit = 30 * 1024 * 1024 // 30MB
        } else { // <= 2GB
            viewModelCache.countLimit = 50
            viewModelCache.totalCostLimit = 20 * 1024 * 1024 // 20MB
        }
    }
    
    /// Cache a view model or heavy object
    func cacheObject<T: AnyObject>(_ object: T, forKey key: String, cost: Int = 0) {
        viewModelCache.setObject(object, forKey: key as NSString, cost: cost)
    }
    
    /// Retrieve cached object
    func getCachedObject<T: AnyObject>(forKey key: String, type: T.Type) -> T? {
        return viewModelCache.object(forKey: key as NSString) as? T
    }
    
    /// Remove cached object
    func removeCachedObject(forKey key: String) {
        viewModelCache.removeObject(forKey: key as NSString)
    }
    
    /// Clear all cached objects
    func clearCache() {
        viewModelCache.removeAllObjects()
    }
    
    /// Get current memory usage
    func getCurrentMemoryUsage() -> (used: Int64, available: Int64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let used = Int64(info.resident_size)
            let available = Int64(ProcessInfo.processInfo.physicalMemory)
            return (used: used, available: available)
        }
        
        return (used: 0, available: Int64(ProcessInfo.processInfo.physicalMemory))
    }
    
    /// Check if memory usage is high
    func isMemoryUsageHigh() -> Bool {
        let (used, available) = getCurrentMemoryUsage()
        let usageRatio = Double(used) / Double(available)
        return usageRatio > memoryWarningThreshold
    }
    
    /// Perform memory cleanup when needed
    func performMemoryCleanupIfNeeded() {
        if isMemoryUsageHigh() {
            Task { @MainActor in
                performMemoryCleanup()
            }
        }
    }

    /// Force memory cleanup
    @MainActor
    func performMemoryCleanup() {
        // Clear view model cache
        viewModelCache.removeAllObjects()

        // Clear image cache
        ImageCacheService.shared.clearCache()

        // Notify other components to clean up
        NotificationCenter.default.post(name: .memoryCleanupRequested, object: nil)

        print("Memory cleanup performed")
    }
    
    // MARK: - Batch Processing
    
    /// Process large arrays in batches to avoid memory spikes
    func processBatch<T, R>(
        items: [T],
        batchSize: Int = 50,
        processor: @escaping ([T]) async throws -> [R]
    ) async throws -> [R] {
        var results: [R] = []
        
        for i in stride(from: 0, to: items.count, by: batchSize) {
            let endIndex = min(i + batchSize, items.count)
            let batch = Array(items[i..<endIndex])
            
            let batchResults = try await processor(batch)
            results.append(contentsOf: batchResults)
            
            // Check memory usage between batches
            if isMemoryUsageHigh() {
                // Give system time to clean up
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        
        return results
    }
    
    // MARK: - Private Methods
    
    private func setupMemoryWarningObserver() {
        memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    nonisolated private func handleMemoryWarning() {
        print("Memory warning received - performing cleanup")
        Task { @MainActor in
            MemoryManager.shared.performMemoryCleanup()
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let memoryCleanupRequested = Notification.Name("memoryCleanupRequested")
}

// MARK: - Memory-Efficient Collection Extensions

extension Array {
    /// Process array in memory-efficient batches
    func processInBatches<R>(
        batchSize: Int = 50,
        processor: @escaping ([Element]) async throws -> [R]
    ) async throws -> [R] {
        return try await MemoryManager.shared.processBatch(
            items: self,
            batchSize: batchSize,
            processor: processor
        )
    }
    
    /// Chunked processing for large arrays
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Memory-Efficient View Model Protocol

protocol MemoryEfficientViewModel: AnyObject {
    var cacheKey: String { get }
    func cleanup()
    func estimatedMemoryUsage() -> Int
}

extension MemoryEfficientViewModel {
    func cacheIfNeeded() {
        MemoryManager.shared.cacheObject(
            self,
            forKey: cacheKey,
            cost: estimatedMemoryUsage()
        )
    }
    
    func removeFromCache() {
        MemoryManager.shared.removeCachedObject(forKey: cacheKey)
    }
}