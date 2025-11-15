//
//  DataPersistenceService.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation
import CoreData

/// Protocol defining data persistence operations
protocol DataPersistenceServiceProtocol {
    // Favorites management
    func saveFavoriteJob(_ job: Job) async throws
    func removeFavoriteJob(jobId: String) async throws
    func getFavoriteJobs() async throws -> [Job]
    func toggleFavoriteStatus(jobId: String) async throws -> Bool
    
    // Saved searches persistence
    func saveSavedSearch(_ search: SavedSearch) async throws
    func getSavedSearches() async throws -> [SavedSearch]
    func deleteSavedSearch(searchId: UUID) async throws
    func updateSavedSearch(_ search: SavedSearch) async throws
    
    // Application tracking data management
    func saveApplicationTracking(_ application: ApplicationTracking) async throws
    func getApplicationTrackings() async throws -> [ApplicationTracking]
    func updateApplicationStatus(jobId: String, status: ApplicationTracking.Status) async throws
    func deleteApplicationTracking(jobId: String) async throws
    func getApplicationTracking(for jobId: String) async throws -> ApplicationTracking?
    
    // Cache management
    func cacheJob(_ job: Job) async throws
    func getCachedJob(jobId: String) async throws -> Job?
    func clearExpiredCache() async throws
    func getCachedJobs(limit: Int?) async throws -> [Job]
    func cacheJobDetails(_ jobDetails: JobDescriptor) async throws -> Job
    func getCacheSize() async throws -> Int
    func clearAllCache() async throws
}

/// Service class for managing Core Data persistence operations
@MainActor
class DataPersistenceService: DataPersistenceServiceProtocol {
    private let coreDataStack: CoreDataStack
    private let context: NSManagedObjectContext
    
    init(coreDataStack: CoreDataStack = CoreDataStack.shared) {
        self.coreDataStack = coreDataStack
        self.context = coreDataStack.context
    }
    
    // MARK: - Private Helper Methods
    
    private func saveContext() throws {
        if context.hasChanges {
            try context.save()
        }
    }
    
    private func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            coreDataStack.persistentContainer.performBackgroundTask { backgroundContext in
                do {
                    let result = try block(backgroundContext)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Favorites Management
    
    func saveFavoriteJob(_ job: Job) async throws {
        job.isFavorited = true
        job.updateCacheTimestamp()
        try saveContext()
    }
    
    func removeFavoriteJob(jobId: String) async throws {
        let request: NSFetchRequest<Job> = Job.fetchRequest()
        request.predicate = NSPredicate(format: "jobId == %@", jobId)
        
        let jobs = try context.fetch(request)
        for job in jobs {
            job.isFavorited = false
        }
        
        try saveContext()
    }
    
    func getFavoriteJobs() async throws -> [Job] {
        let request: NSFetchRequest<Job> = Job.fetchRequest()
        request.predicate = NSPredicate(format: "isFavorited == YES")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Job.cachedAt, ascending: false)
        ]
        
        return try context.fetch(request)
    }
    
    func toggleFavoriteStatus(jobId: String) async throws -> Bool {
        let request: NSFetchRequest<Job> = Job.fetchRequest()
        request.predicate = NSPredicate(format: "jobId == %@", jobId)
        
        let jobs = try context.fetch(request)
        guard let job = jobs.first else {
            throw DataPersistenceError.jobNotFound
        }
        
        job.toggleFavorite()
        job.updateCacheTimestamp()
        try saveContext()
        
        return job.isFavorited
    } 
   
    // MARK: - Saved Searches Persistence
    
    func saveSavedSearch(_ search: SavedSearch) async throws {
        try saveContext()
    }
    
    func getSavedSearches() async throws -> [SavedSearch] {
        let request: NSFetchRequest<SavedSearch> = SavedSearch.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \SavedSearch.name, ascending: true)
        ]
        
        return try context.fetch(request)
    }
    
    func deleteSavedSearch(searchId: UUID) async throws {
        let request: NSFetchRequest<SavedSearch> = SavedSearch.fetchRequest()
        request.predicate = NSPredicate(format: "searchId == %@", searchId as CVarArg)
        
        let searches = try context.fetch(request)
        for search in searches {
            context.delete(search)
        }
        
        try saveContext()
    }
    
    func updateSavedSearch(_ search: SavedSearch) async throws {
        search.updateLastChecked()
        try saveContext()
    }    
 
   // MARK: - Application Tracking Data Management
    
    func saveApplicationTracking(_ application: ApplicationTracking) async throws {
        try saveContext()
    }
    
    func getApplicationTrackings() async throws -> [ApplicationTracking] {
        let request: NSFetchRequest<ApplicationTracking> = ApplicationTracking.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ApplicationTracking.applicationDate, ascending: false)
        ]
        
        return try context.fetch(request)
    }
    
    func updateApplicationStatus(jobId: String, status: ApplicationTracking.Status) async throws {
        let request: NSFetchRequest<ApplicationTracking> = ApplicationTracking.fetchRequest()
        request.predicate = NSPredicate(format: "jobId == %@", jobId)
        
        let applications = try context.fetch(request)
        guard let application = applications.first else {
            throw DataPersistenceError.applicationNotFound
        }
        
        application.updateStatus(to: status)
        try saveContext()
    }
    
    func deleteApplicationTracking(jobId: String) async throws {
        let request: NSFetchRequest<ApplicationTracking> = ApplicationTracking.fetchRequest()
        request.predicate = NSPredicate(format: "jobId == %@", jobId)
        
        let applications = try context.fetch(request)
        for application in applications {
            context.delete(application)
        }
        
        try saveContext()
    }
    
    func getApplicationTracking(for jobId: String) async throws -> ApplicationTracking? {
        let request: NSFetchRequest<ApplicationTracking> = ApplicationTracking.fetchRequest()
        request.predicate = NSPredicate(format: "jobId == %@", jobId)
        request.fetchLimit = 1
        
        let applications = try context.fetch(request)
        return applications.first
    }   
 
    // MARK: - Cache Management
    
    func cacheJob(_ job: Job) async throws {
        job.updateCacheTimestamp()
        try saveContext()
    }
    
    func getCachedJob(jobId: String) async throws -> Job? {
        let request: NSFetchRequest<Job> = Job.fetchRequest()
        request.predicate = NSPredicate(format: "jobId == %@", jobId)
        request.fetchLimit = 1
        
        let jobs = try context.fetch(request)
        return jobs.first
    }
    
    func clearExpiredCache() async throws {
        // Remove cached jobs older than 7 days that are not favorited
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let request: NSFetchRequest<Job> = Job.fetchRequest()
        request.predicate = NSPredicate(format: "cachedAt < %@ AND isFavorited == NO", sevenDaysAgo as NSDate)
        
        let expiredJobs = try context.fetch(request)
        for job in expiredJobs {
            context.delete(job)
        }
        
        try saveContext()
    }
    
    func getCachedJobs(limit: Int? = nil) async throws -> [Job] {
        let request: NSFetchRequest<Job> = Job.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Job.cachedAt, ascending: false)
        ]
        
        if let limit = limit {
            request.fetchLimit = limit
        }
        
        return try context.fetch(request)
    }
    
    func cacheJobDetails(_ jobDetails: JobDescriptor) async throws -> Job {
        // Check if job already exists in cache
        if let existingJob = try await getCachedJob(jobId: jobDetails.positionId) {
            // Update existing job with new details
            updateJobEntity(existingJob, with: jobDetails)
            try await cacheJob(existingJob)
            return existingJob
        } else {
            // Create new job entity
            let job = createJobEntity(from: jobDetails)
            try await cacheJob(job)
            return job
        }
    }
    
    func getCacheSize() async throws -> Int {
        let request: NSFetchRequest<Job> = Job.fetchRequest()
        return try context.count(for: request)
    }
    
    func clearAllCache() async throws {
        // Only clear non-favorited jobs
        let request: NSFetchRequest<Job> = Job.fetchRequest()
        request.predicate = NSPredicate(format: "isFavorited == NO")
        
        let jobs = try context.fetch(request)
        for job in jobs {
            context.delete(job)
        }
        
        try saveContext()
    }
    
    // MARK: - Private Cache Helper Methods
    
    private func createJobEntity(from details: JobDescriptor) -> Job {
        let job = Job(
            context: context,
            jobId: details.positionId,
            title: details.positionTitle,
            department: details.departmentName,
            location: details.primaryLocation
        )
        
        updateJobEntity(job, with: details)
        return job
    }
    
    private func updateJobEntity(_ job: Job, with details: JobDescriptor) {
        let salaryRange = details.salaryRange
        job.salaryMin = Int32(salaryRange.min ?? 0)
        job.salaryMax = Int32(salaryRange.max ?? 0)
        job.applicationDeadline = details.applicationDeadline
        job.datePosted = details.publicationDate
        job.applicationUri = details.applicationUri
        job.gradeDisplay = details.gradeDisplay
        job.isRemoteEligible = details.isRemoteEligible
        job.keyRequirementsText = details.keyRequirementsText
        job.majorDutiesText = details.majorDutiesText
        job.cachedAt = Date()
    }
}

// MARK: - Error Types

enum DataPersistenceError: Error, LocalizedError {
    case jobNotFound
    case applicationNotFound
    case savedSearchNotFound
    case coreDataError(Error)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .jobNotFound:
            return "Job not found in local storage"
        case .applicationNotFound:
            return "Application tracking record not found"
        case .savedSearchNotFound:
            return "Saved search not found"
        case .coreDataError(let error):
            return "Core Data error: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid data provided"
        }
    }
}