//
//  SavedSearch+Extensions.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/14/25.
//

import Foundation
import CoreData

// MARK: - SavedSearch Extensions

extension SavedSearch {
    
    /// Convenience initializer for SavedSearch
    convenience init(
        context: NSManagedObjectContext,
        name: String,
        keywords: String? = nil,
        location: String? = nil,
        department: String? = nil,
        salaryMin: Int32 = 0,
        salaryMax: Int32 = 0
    ) {
        self.init(context: context)
        self.searchId = UUID()
        self.name = name
        self.keywords = keywords
        self.location = location
        self.department = department
        self.salaryMin = salaryMin
        self.salaryMax = salaryMax
        self.isNotificationEnabled = false
        self.lastChecked = Date()
    }
    
    /// Formatted last checked date string
    var formattedLastChecked: String {
        guard let lastChecked = lastChecked else {
            return "Never checked"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return "Last checked \(formatter.localizedString(for: lastChecked, relativeTo: Date()))"
    }
    
    /// Check if search needs to be refreshed (older than 1 hour)
    var needsRefresh: Bool {
        guard let lastChecked = lastChecked else { return true }
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
        return lastChecked < oneHourAgo
    }
    
    /// Generate search criteria from saved search
    var searchCriteria: SearchCriteria {
        return SearchCriteria(
            keyword: keywords,
            location: location,
            department: department,
            salaryMin: salaryMin > 0 ? Int(salaryMin) : nil,
            salaryMax: salaryMax > 0 ? Int(salaryMax) : nil
        )
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
            return "Any salary"
        }
    }
    
    /// Search summary for display
    var searchSummary: String {
        var components: [String] = []

        if let keywords = keywords, !keywords.isEmpty {
            components.append("Keywords: \(keywords)")
        }

        if let location = location, !location.isEmpty {
            components.append("Location: \(location)")
        }

        if let department = department, !department.isEmpty {
            components.append("Department: \(department)")
        }

        if salaryMin > 0 || salaryMax > 0 {
            components.append("Salary: \(salaryRangeDisplay)")
        }

        return components.isEmpty ? "No criteria specified" : components.joined(separator: " • ")
    }

    /// Update last checked timestamp
    func updateLastChecked() {
        self.lastChecked = Date()
    }
    
    /// Toggle notification status
    func toggleNotifications() {
        self.isNotificationEnabled.toggle()
    }
}

// MARK: - Sample Data Factory

extension SavedSearch {
    
    /// Create sample saved search for previews and testing
    static func sampleSavedSearch(
        context: NSManagedObjectContext,
        name: String = "Sample Search",
        keywords: String? = "developer",
        location: String? = "Washington, DC",
        department: String? = nil,
        isNotificationEnabled: Bool = false
    ) -> SavedSearch {
        let search = SavedSearch(
            context: context,
            name: name,
            keywords: keywords,
            location: location,
            department: department,
            salaryMin: Int32.random(in: 0...80000),
            salaryMax: Int32.random(in: 80000...150000)
        )
        
        search.isNotificationEnabled = isNotificationEnabled
        
        // Set last checked to a random recent date
        let daysAgo = -Int.random(in: 0...7)
        search.lastChecked = Calendar.current.date(byAdding: .day, value: daysAgo, to: Date())
        
        return search
    }
}