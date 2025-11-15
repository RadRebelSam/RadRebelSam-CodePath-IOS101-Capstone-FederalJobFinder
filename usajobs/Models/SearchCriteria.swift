//
//  SearchCriteria.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation

/// Search criteria model for job searches
struct SearchCriteria: Equatable {
    let keyword: String?
    let location: String?
    let department: String?
    let salaryMin: Int?
    let salaryMax: Int?
    let page: Int
    let resultsPerPage: Int
    let remoteOnly: Bool
    
    init(
        keyword: String? = nil,
        location: String? = nil,
        department: String? = nil,
        salaryMin: Int? = nil,
        salaryMax: Int? = nil,
        page: Int = 1,
        resultsPerPage: Int = 25,
        remoteOnly: Bool = false
    ) {
        self.keyword = keyword
        self.location = location
        self.department = department
        self.salaryMin = salaryMin
        self.salaryMax = salaryMax
        self.page = page
        self.resultsPerPage = resultsPerPage
        self.remoteOnly = remoteOnly
    }
}

// MARK: - SearchCriteria Extensions

extension SearchCriteria {
    /// Create a new SearchCriteria with updated page number
    func withPage(_ page: Int) -> SearchCriteria {
        return SearchCriteria(
            keyword: keyword,
            location: location,
            department: department,
            salaryMin: salaryMin,
            salaryMax: salaryMax,
            page: page,
            resultsPerPage: resultsPerPage,
            remoteOnly: remoteOnly
        )
    }
    
    /// Create a new SearchCriteria with updated results per page
    func withResultsPerPage(_ resultsPerPage: Int) -> SearchCriteria {
        return SearchCriteria(
            keyword: keyword,
            location: location,
            department: department,
            salaryMin: salaryMin,
            salaryMax: salaryMax,
            page: page,
            resultsPerPage: resultsPerPage,
            remoteOnly: remoteOnly
        )
    }
    
    /// Check if the search criteria has any filters applied
    var hasFilters: Bool {
        return keyword != nil || 
               location != nil || 
               department != nil || 
               salaryMin != nil || 
               salaryMax != nil || 
               remoteOnly
    }
    
    /// Check if the search criteria is completely empty (no filters and no keyword)
    /// Note: USAJobs API allows searches with no criteria (returns all jobs)
    var isEmpty: Bool {
        return keyword?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false &&
               location?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false &&
               department?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false &&
               salaryMin == nil &&
               salaryMax == nil &&
               !remoteOnly
    }
    
    /// Check if this is a valid search (always true for USAJobs API)
    var isValidSearch: Bool {
        return true // USAJobs API accepts empty searches
    }
    
    /// Get a display string for the current search criteria
    var displayString: String {
        var components: [String] = []
        
        if let keyword = keyword, !keyword.isEmpty {
            components.append("Keyword: \(keyword)")
        }
        
        if let location = location, !location.isEmpty {
            components.append("Location: \(location)")
        }
        
        if let department = department, !department.isEmpty {
            components.append("Department: \(department)")
        }
        
        if let salaryMin = salaryMin {
            if let salaryMax = salaryMax {
                components.append("Salary: $\(salaryMin.formatted()) - $\(salaryMax.formatted())")
            } else {
                components.append("Salary: $\(salaryMin.formatted())+")
            }
        } else if let salaryMax = salaryMax {
            components.append("Salary: Up to $\(salaryMax.formatted())")
        }
        
        if remoteOnly {
            components.append("Remote only")
        }
        
        return components.isEmpty ? "All jobs" : components.joined(separator: ", ")
    }
}