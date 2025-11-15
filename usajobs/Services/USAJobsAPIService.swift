//
//  USAJobsAPIService.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation

// MARK: - API Service Protocol

/// Protocol defining USAJobs API service interface
protocol USAJobsAPIServiceProtocol {
    func searchJobs(criteria: SearchCriteria) async throws -> JobSearchResponse
    func getJobDetails(jobId: String) async throws -> JobDescriptor
    func validateAPIConnection() async throws -> Bool
}

// MARK: - API Errors

/// Errors that can occur during API operations
enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case invalidResponse
    case decodingError(Error)
    case networkError(Error)
    case rateLimitExceeded
    case unauthorized
    case serverError(Int)
    case timeout
    case noInternetConnection
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration"
        case .noData:
            return "No data received from server"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later."
        case .unauthorized:
            return "Unauthorized access. Please check API credentials."
        case .serverError(let code):
            return "Server error (HTTP \(code))"
        case .timeout:
            return "Request timed out. Please check your connection."
        case .noInternetConnection:
            return "No internet connection available"
        }
    }
}

// MARK: - USAJobs API Service Implementation

/// Service class for interacting with the USAJobs API
class USAJobsAPIService: USAJobsAPIServiceProtocol {
    
    // MARK: - Properties
    
    private let session: URLSession
    private let baseURL: String
    private let apiKey: String
    private let userAgent: String
    private let maxRetryAttempts: Int
    private let retryDelay: TimeInterval
    
    // MARK: - Initialization
    
    init(
        apiKey: String,
        baseURL: String = AppConfiguration.API.baseURL,
        userAgent: String = NetworkConfiguration.userAgent,
        maxRetryAttempts: Int = AppConfiguration.API.maxRetries,
        retryDelay: TimeInterval = AppConfiguration.API.rateLimitDelay
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.userAgent = userAgent
        self.maxRetryAttempts = maxRetryAttempts
        self.retryDelay = retryDelay
        
        // Configure URLSession with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfiguration.API.timeout
        config.timeoutIntervalForResource = AppConfiguration.API.timeout * 2
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public API Methods
    
    /// Search for jobs using the provided criteria
    func searchJobs(criteria: SearchCriteria) async throws -> JobSearchResponse {
        let url = try buildSearchURL(criteria: criteria)
        let request = try buildRequest(url: url)
        
        return try await performRequestWithRetry(request: request) { data in
            // Try to decode with flexible parsing
            try self.decodeJobSearchResponse(from: data)
        }
    }
    
    /// Flexible decoder that can handle different USAJobs API response formats
    private func decodeJobSearchResponse(from data: Data) throws -> JobSearchResponse {
        // First, try the standard decoding
        do {
            return try JSONDecoder().decode(JobSearchResponse.self, from: data)
        } catch {
            print("Standard decoding failed: \(error)")
            
            // Try to parse as raw JSON to understand the structure
            guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw APIError.decodingError(error)
            }
            
            // Print the structure for debugging
            print("API Response structure: \(jsonObject.keys)")
            
            // Try alternative parsing approaches
            return try parseAlternativeFormat(jsonObject: jsonObject)
        }
    }
    
    /// Parse alternative API response formats
    private func parseAlternativeFormat(jsonObject: [String: Any]) throws -> JobSearchResponse {
        // Check if the response has a different structure
        if let searchResult = jsonObject["SearchResult"] as? [String: Any] {
            return try parseSearchResult(searchResult)
        } else if let results = jsonObject["results"] as? [String: Any] {
            return try parseSearchResult(results)
        } else if let data = jsonObject["data"] as? [String: Any] {
            return try parseSearchResult(data)
        } else {
            // If no recognizable structure, create empty response
            print("Unknown API response format, creating empty response")
            return JobSearchResponse(searchResult: SearchResult(
                searchResultItems: [],
                searchResultCount: 0,
                searchResultCountAll: 0
            ))
        }
    }
    
    /// Parse search result from JSON object
    private func parseSearchResult(_ searchResultJson: [String: Any]) throws -> JobSearchResponse {
        let searchResultCount = searchResultJson["SearchResultCount"] as? Int ?? 0
        let searchResultCountAll = searchResultJson["SearchResultCountAll"] as? Int ?? 0
        
        var searchResultItems: [JobSearchItem] = []
        
        if let items = searchResultJson["SearchResultItems"] as? [[String: Any]] {
            searchResultItems = items.compactMap { itemJson in
                return parseJobSearchItem(itemJson)
            }
        }
        
        let searchResult = SearchResult(
            searchResultItems: searchResultItems,
            searchResultCount: searchResultCount,
            searchResultCountAll: searchResultCountAll
        )
        
        return JobSearchResponse(searchResult: searchResult)
    }
    
    /// Parse individual job search item from JSON
    private func parseJobSearchItem(_ itemJson: [String: Any]) -> JobSearchItem? {
        guard let matchedObjectId = itemJson["MatchedObjectId"] as? String,
              let descriptorJson = itemJson["MatchedObjectDescriptor"] as? [String: Any] else {
            return nil
        }
        
        guard let descriptor = parseJobDescriptor(descriptorJson) else {
            return nil
        }
        
        let relevanceRank = itemJson["RelevanceRank"] as? Int ?? 0
        
        return JobSearchItem(
            matchedObjectId: matchedObjectId,
            matchedObjectDescriptor: descriptor,
            relevanceRank: relevanceRank
        )
    }
    
    /// Parse job descriptor from JSON with flexible field handling
    private func parseJobDescriptor(_ descriptorJson: [String: Any]) -> JobDescriptor? {
        // Extract required fields with fallbacks
        let positionId = descriptorJson["PositionID"] as? String ?? ""
        let positionTitle = descriptorJson["PositionTitle"] as? String ?? "Untitled Position"
        let positionUri = descriptorJson["PositionURI"] as? String ?? ""
        let applicationCloseDate = descriptorJson["ApplicationCloseDate"] as? String ?? ""
        let positionStartDate = descriptorJson["PositionStartDate"] as? String ?? ""
        let positionEndDate = descriptorJson["PositionEndDate"] as? String ?? ""
        let publicationStartDate = descriptorJson["PublicationStartDate"] as? String ?? ""

        // ApplyURI is an array - take the first element
        let applicationUri: String
        if let applyUriArray = descriptorJson["ApplyURI"] as? [String], let firstUri = applyUriArray.first {
            applicationUri = firstUri
        } else {
            // Fallback to constructing URL from PositionID if ApplyURI is not available
            applicationUri = "https://www.usajobs.gov/job/\(positionId)"
        }

        let positionLocationDisplay = descriptorJson["PositionLocationDisplay"] as? String ?? "Location not specified"
        let organizationName = descriptorJson["OrganizationName"] as? String ?? "Federal Agency"
        let departmentName = descriptorJson["DepartmentName"] as? String ?? organizationName
        let positionSummary = descriptorJson["PositionSummary"] as? String ?? ""
        let qualificationSummary = descriptorJson["QualificationSummary"] as? String

        // Parse job grades
        var jobGrade: [JobGrade] = []
        if let gradeArray = descriptorJson["JobGrade"] as? [[String: Any]] {
            jobGrade = gradeArray.compactMap { gradeJson in
                guard let code = gradeJson["Code"] as? String else { return nil }
                return JobGrade(code: code)
            }
        }

        // Parse salary/remuneration
        var positionRemuneration: [PositionRemuneration] = []
        if let remunerationArray = descriptorJson["PositionRemuneration"] as? [[String: Any]] {
            positionRemuneration = remunerationArray.compactMap { remJson in
                let minRange = remJson["MinimumRange"] as? String
                let maxRange = remJson["MaximumRange"] as? String
                let rateIntervalCode = remJson["RateIntervalCode"] as? String
                let description = remJson["Description"] as? String
                return PositionRemuneration(
                    minimumRange: minRange,
                    maximumRange: maxRange,
                    rateIntervalCode: rateIntervalCode,
                    description: description
                )
            }
        }

        // Parse job categories
        var jobCategory: [JobCategory] = []
        if let categoryArray = descriptorJson["JobCategory"] as? [[String: Any]] {
            jobCategory = categoryArray.compactMap { catJson in
                let name = catJson["Name"] as? String ?? ""
                let code = catJson["Code"] as? String ?? ""
                return JobCategory(name: name, code: code)
            }
        }

        // Parse position locations
        var positionLocation: [PositionLocation] = []
        if let locationArray = descriptorJson["PositionLocation"] as? [[String: Any]] {
            positionLocation = locationArray.compactMap { locJson in
                let locationName = locJson["LocationName"] as? String ?? ""
                let countryCode = locJson["CountryCode"] as? String ?? ""
                let countrySubDivisionCode = locJson["CountrySubDivisionCode"] as? String
                let cityName = locJson["CityName"] as? String
                let longitude = locJson["Longitude"] as? Double
                let latitude = locJson["Latitude"] as? Double
                return PositionLocation(
                    locationName: locationName,
                    countryCode: countryCode,
                    countrySubDivisionCode: countrySubDivisionCode,
                    cityName: cityName,
                    longitude: longitude,
                    latitude: latitude
                )
            }
        }

        // Parse UserArea for detailed information
        var userArea: UserArea? = nil
        if let userAreaJson = descriptorJson["UserArea"] as? [String: Any],
           let detailsJson = userAreaJson["Details"] as? [String: Any] {

            let jobSummary = detailsJson["JobSummary"] as? String
            let lowGrade = detailsJson["LowGrade"] as? String
            let highGrade = detailsJson["HighGrade"] as? String
            let promotionPotential = detailsJson["PromotionPotential"] as? String
            let organizationCodes = detailsJson["OrganizationCodes"] as? String
            let relocation = detailsJson["Relocation"] as? String
            let hiringPath = detailsJson["HiringPath"] as? [String]
            let totalOpenings = detailsJson["TotalOpenings"] as? String
            let agencyMarketingStatement = detailsJson["AgencyMarketingStatement"] as? String
            let travelCode = detailsJson["TravelCode"] as? String
            let detailStatusUrl = detailsJson["DetailStatusUrl"] as? String
            let majorDuties = detailsJson["MajorDuties"] as? [String]
            let education = detailsJson["Education"] as? String
            let requirements = detailsJson["Requirements"] as? String
            let evaluations = detailsJson["Evaluations"] as? String
            let howToApply = detailsJson["HowToApply"] as? String
            let whatToExpectNext = detailsJson["WhatToExpectNext"] as? String
            let requiredDocuments = detailsJson["RequiredDocuments"] as? String
            let benefits = detailsJson["Benefits"] as? String
            let benefitsUrl = detailsJson["BenefitsUrl"] as? String
            let benefitsDisplayDefaultText = detailsJson["BenefitsDisplayDefaultText"] as? Bool
            let otherInformation = detailsJson["OtherInformation"] as? String
            let keyRequirements = detailsJson["KeyRequirements"] as? [String]
            let withinArea = detailsJson["WithinArea"] as? String
            let commuterLocation = detailsJson["CommuterLocation"] as? String
            let serviceType = detailsJson["ServiceType"] as? String
            let announcementClosingType = detailsJson["AnnouncementClosingType"] as? String
            let agencyContactEmail = detailsJson["AgencyContactEmail"] as? String
            let agencyContactPhone = detailsJson["AgencyContactPhone"] as? String
            let securityClearance = detailsJson["SecurityClearance"] as? String
            let drugTest = detailsJson["DrugTest"] as? String
            let adjudicationType = detailsJson["AdjudicationType"] as? [String]
            let teleworkEligible = detailsJson["TeleworkEligible"] as? Bool
            let remoteIndicator = detailsJson["RemoteIndicator"] as? Bool

            // Parse WhoMayApply if present
            var whoMayApply: WhoMayApply? = nil
            if let whoMayApplyJson = detailsJson["WhoMayApply"] as? [String: Any] {
                let name = whoMayApplyJson["Name"] as? String
                let code = whoMayApplyJson["Code"] as? String
                whoMayApply = WhoMayApply(name: name, code: code)
            }

            userArea = UserArea(
                details: UserAreaDetails(
                    jobSummary: jobSummary,
                    whoMayApply: whoMayApply,
                    lowGrade: lowGrade,
                    highGrade: highGrade,
                    promotionPotential: promotionPotential,
                    organizationCodes: organizationCodes,
                    relocation: relocation,
                    hiringPath: hiringPath,
                    totalOpenings: totalOpenings,
                    agencyMarketingStatement: agencyMarketingStatement,
                    travelCode: travelCode,
                    detailStatusUrl: detailStatusUrl,
                    majorDuties: majorDuties,
                    education: education,
                    requirements: requirements,
                    evaluations: evaluations,
                    howToApply: howToApply,
                    whatToExpectNext: whatToExpectNext,
                    requiredDocuments: requiredDocuments,
                    benefits: benefits,
                    benefitsUrl: benefitsUrl,
                    benefitsDisplayDefaultText: benefitsDisplayDefaultText,
                    otherInformation: otherInformation,
                    keyRequirements: keyRequirements,
                    withinArea: withinArea,
                    commuterLocation: commuterLocation,
                    serviceType: serviceType,
                    announcementClosingType: announcementClosingType,
                    agencyContactEmail: agencyContactEmail,
                    agencyContactPhone: agencyContactPhone,
                    securityClearance: securityClearance,
                    drugTest: drugTest,
                    adjudicationType: adjudicationType,
                    teleworkEligible: teleworkEligible,
                    remoteIndicator: remoteIndicator
                )
            )
        }

        // Parse formatted descriptions (usually empty arrays in the API)
        let positionFormattedDescription: [PositionFormattedDescription] = []

        return JobDescriptor(
            positionId: positionId,
            positionTitle: positionTitle,
            positionUri: positionUri,
            applicationCloseDate: applicationCloseDate,
            positionStartDate: positionStartDate,
            positionEndDate: positionEndDate,
            publicationStartDate: publicationStartDate,
            applicationUri: applicationUri,
            positionLocationDisplay: positionLocationDisplay,
            positionLocation: positionLocation,
            organizationName: organizationName,
            departmentName: departmentName,
            jobCategory: jobCategory,
            jobGrade: jobGrade,
            positionRemuneration: positionRemuneration,
            positionSummary: positionSummary,
            positionFormattedDescription: positionFormattedDescription,
            userArea: userArea,
            qualificationSummary: qualificationSummary
        )
    }
    
    /// Get detailed information for a specific job
    func getJobDetails(jobId: String) async throws -> JobDescriptor {
        // Use the search endpoint with PositionID parameter to get specific job details
        guard var components = URLComponents(string: "\(baseURL)/search") else {
            throw APIError.invalidURL
        }

        // Set query parameters for specific job lookup
        components.queryItems = [
            URLQueryItem(name: "PositionID", value: jobId),
            URLQueryItem(name: "ResultsPerPage", value: "1"),
            URLQueryItem(name: "Fields", value: "Full")  // Request full details
        ]
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        print("🔍 Fetching job details from: \(url)")
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization-Key")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("📡 Job details API response status: \(httpResponse.statusCode)")
        
        switch httpResponse.statusCode {
        case 200:
            // Debug: Print raw response to understand structure
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Raw API response (first 500 chars): \(String(jsonString.prefix(500)))")
            }

            let searchResponse = try decodeJobSearchResponse(from: data)

            guard let job = searchResponse.jobs.first?.matchedObjectDescriptor else {
                print("❌ No job found with ID: \(jobId)")
                throw APIError.noData
            }

            print("✅ Successfully fetched job details for: \(jobId)")
            print("📋 Application URI: \(job.applicationUri)")
            print("📋 Position URI: \(job.positionUri)")
            print("📋 UserArea present: \(job.userArea != nil)")
            return job
            
        case 401:
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimitExceeded
        case 404:
            throw APIError.noData
        default:
            print("❌ Unexpected status code: \(httpResponse.statusCode)")
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Validate API connection and credentials
    func validateAPIConnection() async throws -> Bool {
        let testCriteria = SearchCriteria(keyword: "test", resultsPerPage: 1)
        
        do {
            _ = try await searchJobs(criteria: testCriteria)
            return true
        } catch APIError.unauthorized {
            return false
        } catch {
            // Other errors might be temporary, so we consider the connection valid
            // if we get a response (even if it's an error response)
            return true
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Build URL for job search with query parameters
    private func buildSearchURL(criteria: SearchCriteria) throws -> URL {
        guard var components = URLComponents(string: "\(baseURL)/search") else {
            throw APIError.invalidURL
        }
        
        var queryItems: [URLQueryItem] = []
        
        // Add search parameters
        if let keyword = criteria.keyword, !keyword.isEmpty {
            queryItems.append(URLQueryItem(name: "Keyword", value: keyword))
        }
        
        if let location = criteria.location, !location.isEmpty {
            queryItems.append(URLQueryItem(name: "LocationName", value: location))
        }
        
        if let department = criteria.department, !department.isEmpty {
            queryItems.append(URLQueryItem(name: "Organization", value: department))
        }
        
        if let salaryMin = criteria.salaryMin {
            queryItems.append(URLQueryItem(name: "SalaryBucket", value: "\(salaryMin)"))
        }
        
        if criteria.remoteOnly {
            queryItems.append(URLQueryItem(name: "RemoteIndicator", value: "true"))
        }
        
        // Pagination
        queryItems.append(URLQueryItem(name: "Page", value: "\(criteria.page)"))
        queryItems.append(URLQueryItem(name: "ResultsPerPage", value: "\(criteria.resultsPerPage)"))

        // Request full details for all jobs
        queryItems.append(URLQueryItem(name: "Fields", value: "Full"))

        // Sort by relevance
        queryItems.append(URLQueryItem(name: "SortField", value: "Relevance"))
        queryItems.append(URLQueryItem(name: "SortDirection", value: "Descending"))
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        return url
    }
    
    /// Build HTTP request with required headers
    private func buildRequest(url: URL) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Required headers for USAJobs API
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return request
    }
    
    /// Perform HTTP request with retry logic and error handling
    private func performRequestWithRetry<T>(
        request: URLRequest,
        decoder: @escaping (Data) throws -> T
    ) async throws -> T {
        let errorHandler = DefaultErrorHandler(maxRetryAttempts: maxRetryAttempts, baseRetryDelay: retryDelay)
        var lastError: Error?
        
        for attempt in 1...maxRetryAttempts {
            do {
                let (data, response) = try await session.data(for: request)
                
                // Check HTTP response status
                if let httpResponse = response as? HTTPURLResponse {
                    try validateHTTPResponse(httpResponse)
                }
                
                // Decode and return the response
                do {
                    return try decoder(data)
                } catch {
                    throw APIError.decodingError(error)
                }
                
            } catch let error as APIError {
                lastError = error
                let appError = error.toAppError()
                
                // Don't retry for certain errors
                if !errorHandler.shouldRetry(appError, attemptCount: attempt) {
                    throw error
                }
                
                if attempt < maxRetryAttempts {
                    let delay = errorHandler.getRetryDelay(appError, attemptCount: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                throw error
                
            } catch {
                lastError = error
                
                // Handle URLSession errors
                let apiError: APIError
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost:
                        apiError = .noInternetConnection
                    case .timedOut:
                        apiError = .timeout
                    default:
                        apiError = .networkError(error)
                    }
                } else {
                    apiError = .networkError(error)
                }
                
                let appError = apiError.toAppError()
                
                // Retry for retryable errors
                if attempt < maxRetryAttempts && errorHandler.shouldRetry(appError, attemptCount: attempt) {
                    let delay = errorHandler.getRetryDelay(appError, attemptCount: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                throw apiError
            }
        }
        
        // If we get here, all retries failed
        throw lastError as? APIError ?? APIError.networkError(NSError(domain: "USAJobsAPIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "All retry attempts failed"]))
    }
    
    /// Validate HTTP response status codes
    private func validateHTTPResponse(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299:
            return // Success
        case 401:
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimitExceeded
        case 500...599:
            throw APIError.serverError(response.statusCode)
        default:
            throw APIError.serverError(response.statusCode)
        }
    }
}

// MARK: - Convenience Extensions

extension USAJobsAPIService {
    /// Convenience method to search jobs with simple keyword
    func searchJobs(keyword: String, page: Int = 1) async throws -> JobSearchResponse {
        let criteria = SearchCriteria(keyword: keyword, page: page)
        return try await searchJobs(criteria: criteria)
    }
    
    /// Convenience method to search jobs by location
    func searchJobsByLocation(_ location: String, page: Int = 1) async throws -> JobSearchResponse {
        let criteria = SearchCriteria(location: location, page: page)
        return try await searchJobs(criteria: criteria)
    }
    
    /// Convenience method to search remote jobs
    func searchRemoteJobs(keyword: String? = nil, page: Int = 1) async throws -> JobSearchResponse {
        let criteria = SearchCriteria(keyword: keyword, page: page, remoteOnly: true)
        return try await searchJobs(criteria: criteria)
    }
}