//
//  ImageCacheService.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import SwiftUI
import Foundation
import OSLog

/// Service for caching images with memory and disk storage
@MainActor
class ImageCacheService: ObservableObject {
    static let shared = ImageCacheService()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL
    private let maxDiskCacheSize: Int = 100 * 1024 * 1024 // 100MB
    private let maxMemoryCacheSize: Int = 50 * 1024 * 1024 // 50MB
    private let logger = Logger(subsystem: "com.federaljobfinder.usajobs", category: "ImageCache")

    private init() {
        // Setup memory cache
        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = 100

        // Setup disk cache directory
        guard let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            logger.error("Failed to get cache directory")
            // Fallback to temporary directory
            diskCacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("ImageCache")
            return
        }
        diskCacheURL = cacheDirectory.appendingPathComponent("ImageCache")

        // Create cache directory if needed
        do {
            try FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create image cache directory: \(error.localizedDescription)")
        }
        
        // Setup memory warning observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Load image from cache or download if not cached
    func loadImage(from url: URL) async -> UIImage? {
        let cacheKey = url.absoluteString
        
        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }
        
        // Check disk cache
        if let diskImage = loadFromDisk(cacheKey: cacheKey) {
            // Store in memory cache for faster access
            let imageSize = diskImage.jpegData(compressionQuality: 0.8)?.count ?? 0
            memoryCache.setObject(diskImage, forKey: cacheKey as NSString, cost: imageSize)
            return diskImage
        }
        
        // Download image
        return await downloadAndCacheImage(from: url, cacheKey: cacheKey)
    }
    
    /// Preload images for better performance
    func preloadImages(urls: [URL]) {
        Task {
            for url in urls {
                _ = await loadImage(from: url)
            }
        }
    }
    
    /// Clear all cached images
    func clearCache() {
        memoryCache.removeAllObjects()
        do {
            try FileManager.default.removeItem(at: diskCacheURL)
            try FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
            logger.info("Cache cleared successfully")
        } catch {
            logger.error("Failed to clear cache: \(error.localizedDescription)")
        }
    }
    
    /// Clear expired cache entries
    func clearExpiredCache() {
        let expirationDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }
        
        for fileURL in files {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                  let modificationDate = attributes[.modificationDate] as? Date else {
                continue
            }
            
            if modificationDate < expirationDate {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                } catch {
                    logger.warning("Failed to remove expired cache file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Get current cache size
    func getCacheSize() -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        return files.reduce(0) { total, fileURL in
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                  let fileSize = attributes[.size] as? Int else {
                return total
            }
            return total + fileSize
        }
    }
    
    // MARK: - Private Methods
    
    private func loadFromDisk(cacheKey: String) -> UIImage? {
        let fileName = cacheKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? cacheKey
        let fileURL = diskCacheURL.appendingPathComponent(fileName)
        
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        
        return UIImage(data: data)
    }
    
    private func downloadAndCacheImage(from url: URL, cacheKey: String) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            guard let image = UIImage(data: data) else {
                return nil
            }
            
            // Cache to disk
            saveToDisk(image: image, cacheKey: cacheKey)
            
            // Cache to memory
            let imageSize = data.count
            memoryCache.setObject(image, forKey: cacheKey as NSString, cost: imageSize)
            
            return image
        } catch {
            logger.error("Failed to download image from \(url.absoluteString): \(error.localizedDescription)")
            return nil
        }
    }
    
    private func saveToDisk(image: UIImage, cacheKey: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        
        let fileName = cacheKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? cacheKey
        let fileURL = diskCacheURL.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
        } catch {
            logger.error("Failed to save image to disk: \(error.localizedDescription)")
        }
        
        // Check if we need to clean up old files to stay under size limit
        if getCacheSize() > maxDiskCacheSize {
            cleanupOldFiles()
        }
    }
    
    private func cleanupOldFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }
        
        // Sort files by modification date (oldest first)
        let sortedFiles = files.sorted { file1, file2 in
            let date1 = (try? file1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            let date2 = (try? file2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return date1 < date2
        }
        
        // Remove oldest files until we're under the size limit
        var currentSize = getCacheSize()
        for fileURL in sortedFiles {
            if currentSize <= maxDiskCacheSize * 3 / 4 { // Remove until 75% of limit
                break
            }
            
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? Int {
                currentSize -= fileSize
            }

            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                logger.warning("Failed to remove old cache file during cleanup: \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func handleMemoryWarning() {
        memoryCache.removeAllObjects()
    }
}

// MARK: - AsyncImage with Caching

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let content: (AsyncImagePhase) -> Content
    
    @StateObject private var imageCache = ImageCacheService.shared
    @State private var phase: AsyncImagePhase = .empty
    
    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }
    
    var body: some View {
        content(phase)
            .task {
                await loadImage()
            }
    }
    
    private func loadImage() async {
        guard let url = url else {
            phase = .empty
            return
        }
        
        phase = .empty
        
        if let image = await imageCache.loadImage(from: url) {
            phase = .success(Image(uiImage: image))
        } else {
            phase = .failure(URLError(.badURL))
        }
    }
}

// MARK: - Convenience Extensions

// Note: Convenience initializer removed to avoid return type issues
// Use the main initializer with a custom content closure instead