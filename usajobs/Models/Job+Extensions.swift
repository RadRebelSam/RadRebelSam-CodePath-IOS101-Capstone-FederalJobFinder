//
//  Job+Extensions.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/14/25.
//

import Foundation
import CoreData

// MARK: - Job Extensions

extension Job {
    
    /// Convenience initializer for Job
    convenience init(
        context: NSManagedObjectContext,
        jobId: String,
        title: String,
        department: String,
        location: String
    ) {
        self.init(context: context)
        self.jobId = jobId
        self.title = title
        self.department = department
        self.location = location
        self.datePosted = Date()
        self.cachedAt = Date()
        self.isFavorited = false
        self.isRemoteEligible = false
    }
    
    /// Check if job application deadline has passed
    var isExpired: Bool {
        guard let deadline = applicationDeadline else { return false }
        return Date() > deadline
    }
    
    /// Days until application deadline
    var daysUntilDeadline: Int? {
        guard let deadline = applicationDeadline else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: deadline)
        return components.day
    }
    
    /// Formatted salary range string
    var salaryRangeDisplay: String {
        let min = Int(salaryMin)
        let max = Int(salaryMax)
        
        switch (min, max) {
        case (let minVal, let maxVal) where minVal > 0 && maxVal > 0:
            return "$\(minVal.formatted()) - $\(maxVal.formatted())"
        case (let minVal, _) where minVal > 0:
            return "$\(minVal.formatted())+"
        case (_, let maxVal) where maxVal > 0:
            return "Up to $\(maxVal.formatted())"
        default:
            return "Salary not specified"
        }
    }
    
    /// Formatted application deadline string
    var deadlineDisplay: String {
        guard let deadline = applicationDeadline else {
            return "No deadline specified"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if isExpired {
            return "Expired \(formatter.string(from: deadline))"
        } else {
            return "Apply by \(formatter.string(from: deadline))"
        }
    }
    
    /// Formatted date posted string
    var datePostedDisplay: String {
        guard let posted = datePosted else {
            return "Date unknown"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return "Posted \(formatter.localizedString(for: posted, relativeTo: Date()))"
    }
    
    /// Check if job is recently posted (within last 7 days)
    var isRecentlyPosted: Bool {
        guard let posted = datePosted else { return false }
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return posted >= sevenDaysAgo
    }
    
    /// Generate USAJobs application URL
    var applicationURL: URL? {
        guard let jobId = jobId else { return nil }
        return URL(string: "https://www.usajobs.gov/job/\(jobId)")
    }

    /// Update cache timestamp
    func updateCacheTimestamp() {
        self.cachedAt = Date()
    }

    /// Toggle favorite status
    func toggleFavorite() {
        self.isFavorited.toggle()
    }
}

// MARK: - Sample Data Factory

extension Job {
    
    /// Create sample job for previews and testing
    static func sampleJob(
        context: NSManagedObjectContext,
        jobId: String = "sample-\(UUID().uuidString.prefix(8))",
        title: String = "Sample Job Title",
        department: String = "Sample Department",
        location: String = "Washington, DC",
        isExpired: Bool = false,
        isFavorited: Bool = false
    ) -> Job {
        let job = Job(
            context: context,
            jobId: jobId,
            title: title,
            department: department,
            location: location
        )
        
        job.salaryMin = Int32.random(in: 50000...80000)
        job.salaryMax = Int32.random(in: 80000...120000)
        job.gradeDisplay = "GS-\(Int.random(in: 11...14))"
        job.isFavorited = isFavorited
        job.isRemoteEligible = Bool.random()
        
        // Set application deadline
        let daysFromNow = isExpired ? -Int.random(in: 1...30) : Int.random(in: 1...60)
        job.applicationDeadline = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())
        
        // Set posted date
        let postedDaysAgo = -Int.random(in: 1...30)
        job.datePosted = Calendar.current.date(byAdding: .day, value: postedDaysAgo, to: Date())
        
        // Set cached date for favorites
        if isFavorited {
            let cachedDaysAgo = -Int.random(in: 1...14)
            job.cachedAt = Calendar.current.date(byAdding: .day, value: cachedDaysAgo, to: Date())
        }
        
        return job
    }
}