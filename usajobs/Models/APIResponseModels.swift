import Foundation

// MARK: - Main API Response Models

/// Root response structure from USAJobs API search endpoint
struct JobSearchResponse: Codable {
    let searchResult: SearchResult
    
    enum CodingKeys: String, CodingKey {
        case searchResult = "SearchResult"
    }
}

/// Search result container with items and metadata
struct SearchResult: Codable {
    let searchResultItems: [JobSearchItem]?
    let searchResultCount: Int
    let searchResultCountAll: Int
    
    enum CodingKeys: String, CodingKey {
        case searchResultItems = "SearchResultItems"
        case searchResultCount = "SearchResultCount"
        case searchResultCountAll = "SearchResultCountAll"
    }
}

/// Individual job search result item
struct JobSearchItem: Codable {
    let matchedObjectId: String
    let matchedObjectDescriptor: JobDescriptor
    let relevanceRank: Int
    
    enum CodingKeys: String, CodingKey {
        case matchedObjectId = "MatchedObjectId"
        case matchedObjectDescriptor = "MatchedObjectDescriptor"
        case relevanceRank = "RelevanceRank"
    }
}

/// Detailed job information descriptor
struct JobDescriptor: Codable {
    let positionId: String
    let positionTitle: String
    let positionUri: String
    let applicationCloseDate: String
    let positionStartDate: String
    let positionEndDate: String
    let publicationStartDate: String
    let applicationUri: String
    let positionLocationDisplay: String
    let positionLocation: [PositionLocation]
    let organizationName: String
    let departmentName: String
    let jobCategory: [JobCategory]
    let jobGrade: [JobGrade]
    let positionRemuneration: [PositionRemuneration]
    let positionSummary: String
    let positionFormattedDescription: [PositionFormattedDescription]
    let userArea: UserArea?
    let qualificationSummary: String?
    
    enum CodingKeys: String, CodingKey {
        case positionId = "PositionID"
        case positionTitle = "PositionTitle"
        case positionUri = "PositionURI"
        case applicationCloseDate = "ApplicationCloseDate"
        case positionStartDate = "PositionStartDate"
        case positionEndDate = "PositionEndDate"
        case publicationStartDate = "PublicationStartDate"
        case applicationUri = "ApplicationURI"
        case positionLocationDisplay = "PositionLocationDisplay"
        case positionLocation = "PositionLocation"
        case organizationName = "OrganizationName"
        case departmentName = "DepartmentName"
        case jobCategory = "JobCategory"
        case jobGrade = "JobGrade"
        case positionRemuneration = "PositionRemuneration"
        case positionSummary = "PositionSummary"
        case positionFormattedDescription = "PositionFormattedDescription"
        case userArea = "UserArea"
        case qualificationSummary = "QualificationSummary"
    }
}

// MARK: - Supporting Models

/// Position location information
struct PositionLocation: Codable {
    let locationName: String
    let countryCode: String
    let countrySubDivisionCode: String?
    let cityName: String?
    let longitude: Double?
    let latitude: Double?
    
    enum CodingKeys: String, CodingKey {
        case locationName = "LocationName"
        case countryCode = "CountryCode"
        case countrySubDivisionCode = "CountrySubDivisionCode"
        case cityName = "CityName"
        case longitude = "Longitude"
        case latitude = "Latitude"
    }
}

/// Job category classification
struct JobCategory: Codable {
    let name: String
    let code: String
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case code = "Code"
    }
}

/// Job grade information (GS level, etc.)
struct JobGrade: Codable {
    let code: String
    
    enum CodingKeys: String, CodingKey {
        case code = "Code"
    }
}

/// Salary and compensation information
struct PositionRemuneration: Codable {
    let minimumRange: String?
    let maximumRange: String?
    let rateIntervalCode: String?
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case minimumRange = "MinimumRange"
        case maximumRange = "MaximumRange"
        case rateIntervalCode = "RateIntervalCode"
        case description = "Description"
    }
}

/// Formatted job description content
struct PositionFormattedDescription: Codable {
    let label: String
    let labelDescription: String
    
    enum CodingKeys: String, CodingKey {
        case label = "Label"
        case labelDescription = "LabelDescription"
    }
}

/// Additional user area information
struct UserArea: Codable {
    let details: UserAreaDetails?
    
    enum CodingKeys: String, CodingKey {
        case details = "Details"
    }
}

/// User area details containing additional job metadata
struct UserAreaDetails: Codable {
    let jobSummary: String?
    let whoMayApply: WhoMayApply?
    let lowGrade: String?
    let highGrade: String?
    let promotionPotential: String?
    let organizationCodes: String?
    let relocation: String?
    let hiringPath: [String]?
    let totalOpenings: String?
    let agencyMarketingStatement: String?
    let travelCode: String?
    let detailStatusUrl: String?
    let majorDuties: [String]?
    let education: String?
    let requirements: String?
    let evaluations: String?
    let howToApply: String?
    let whatToExpectNext: String?
    let requiredDocuments: String?
    let benefits: String?
    let benefitsUrl: String?
    let benefitsDisplayDefaultText: Bool?
    let otherInformation: String?
    let keyRequirements: [String]?
    let withinArea: String?
    let commuterLocation: String?
    let serviceType: String?
    let announcementClosingType: String?
    let agencyContactEmail: String?
    let agencyContactPhone: String?
    let securityClearance: String?
    let drugTest: String?
    let adjudicationType: [String]?
    let teleworkEligible: Bool?
    let remoteIndicator: Bool?
    
    enum CodingKeys: String, CodingKey {
        case jobSummary = "JobSummary"
        case whoMayApply = "WhoMayApply"
        case lowGrade = "LowGrade"
        case highGrade = "HighGrade"
        case promotionPotential = "PromotionPotential"
        case organizationCodes = "OrganizationCodes"
        case relocation = "Relocation"
        case hiringPath = "HiringPath"
        case totalOpenings = "TotalOpenings"
        case agencyMarketingStatement = "AgencyMarketingStatement"
        case travelCode = "TravelCode"
        case detailStatusUrl = "DetailStatusUrl"
        case majorDuties = "MajorDuties"
        case education = "Education"
        case requirements = "Requirements"
        case evaluations = "Evaluations"
        case howToApply = "HowToApply"
        case whatToExpectNext = "WhatToExpectNext"
        case requiredDocuments = "RequiredDocuments"
        case benefits = "Benefits"
        case benefitsUrl = "BenefitsUrl"
        case benefitsDisplayDefaultText = "BenefitsDisplayDefaultText"
        case otherInformation = "OtherInformation"
        case keyRequirements = "KeyRequirements"
        case withinArea = "WithinArea"
        case commuterLocation = "CommuterLocation"
        case serviceType = "ServiceType"
        case announcementClosingType = "AnnouncementClosingType"
        case agencyContactEmail = "AgencyContactEmail"
        case agencyContactPhone = "AgencyContactPhone"
        case securityClearance = "SecurityClearance"
        case drugTest = "DrugTest"
        case adjudicationType = "AdjudicationType"
        case teleworkEligible = "TeleworkEligible"
        case remoteIndicator = "RemoteIndicator"
    }
}

/// Who may apply information
struct WhoMayApply: Codable {
    let name: String?
    let code: String?
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case code = "Code"
    }
}

// MARK: - Model Extensions and Computed Properties

extension JobDescriptor {
    /// Computed property to get salary range as integers
    var salaryRange: (min: Int?, max: Int?) {
        guard let remuneration = positionRemuneration.first else {
            return (nil, nil)
        }
        
        let minSalary = remuneration.minimumRange?.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "$", with: "")
        let maxSalary = remuneration.maximumRange?.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "$", with: "")
        
        return (Int(minSalary ?? ""), Int(maxSalary ?? ""))
    }
    
    /// Computed property to get application deadline as Date
    var applicationDeadline: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter.date(from: applicationCloseDate)
    }
    
    /// Computed property to get publication date as Date
    var publicationDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter.date(from: publicationStartDate)
    }
    
    /// Computed property to get primary location display
    var primaryLocation: String {
        return positionLocationDisplay
    }
    
    /// Computed property to get job grade display
    var gradeDisplay: String? {
        return jobGrade.first?.code
    }
    
    /// Computed property to get formatted salary display
    var salaryDisplay: String {
        let range = salaryRange
        switch (range.min, range.max) {
        case (let min?, let max?):
            return "$\(min.formatted()) - $\(max.formatted())"
        case (let min?, nil):
            return "$\(min.formatted())+"
        case (nil, let max?):
            return "Up to $\(max.formatted())"
        default:
            return "Salary not specified"
        }
    }
    
    /// Computed property to check if position allows remote work
    var isRemoteEligible: Bool {
        return userArea?.details?.remoteIndicator == true || 
               userArea?.details?.teleworkEligible == true
    }
    
    /// Computed property to get major duties as formatted string
    var majorDutiesText: String? {
        return userArea?.details?.majorDuties?.joined(separator: "\n• ")
    }
    
    /// Computed property to get key requirements as formatted string
    var keyRequirementsText: String? {
        return userArea?.details?.keyRequirements?.joined(separator: "\n• ")
    }
}

extension JobSearchItem {
    /// Convenience property to access job title
    var jobTitle: String {
        return matchedObjectDescriptor.positionTitle
    }
    
    /// Convenience property to access job ID
    var jobId: String {
        return matchedObjectDescriptor.positionId
    }
    
    /// Convenience property to access department name
    var department: String {
        return matchedObjectDescriptor.departmentName
    }
    
    /// Convenience property to access location
    var location: String {
        return matchedObjectDescriptor.primaryLocation
    }
}

extension JobSearchResponse {
    /// Computed property to get total number of jobs found
    var totalJobCount: Int {
        return searchResult.searchResultCountAll
    }
    
    /// Computed property to get current page job count
    var currentPageJobCount: Int {
        return searchResult.searchResultCount
    }
    
    /// Computed property to get job items safely
    var jobs: [JobSearchItem] {
        return searchResult.searchResultItems ?? []
    }
    
    /// Check if there are more results available
    var hasMoreResults: Bool {
        return currentPageJobCount < totalJobCount
    }
}