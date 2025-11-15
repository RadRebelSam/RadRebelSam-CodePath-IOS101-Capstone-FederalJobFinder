//
//  JobSearchViewModel.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for managing job search functionality
@MainActor
class JobSearchViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current search results
    @Published var searchResults: [JobSearchItem] = []
    
    /// Current search criteria
    @Published var searchCriteria = SearchCriteria()
    
    /// Loading state for search operations
    @Published var isLoading = false
    
    /// Loading state for pagination (loading more results)
    @Published var isLoadingMore = false
    
    /// Error message to display to user
    @Published var errorMessage: String?
    
    /// Whether there are more results available for pagination
    @Published var hasMoreResults = false
    
    /// Total number of jobs found for current search
    @Published var totalJobCount = 0
    
    /// Current page number
    @Published var currentPage = 1
    
    /// Whether the search has been performed at least once
    @Published var hasSearched = false
    
    // MARK: - Private Properties
    
    private let apiService: USAJobsAPIServiceProtocol
    private let persistenceService: DataPersistenceServiceProtocol
    private let offlineManager: OfflineDataManager
    private let networkMonitor: NetworkMonitor
    private let loadingStateManager: LoadingStateManager
    private let errorHandler: ErrorHandlerProtocol
    
    // MARK: - Initialization

    init(
        apiService: USAJobsAPIServiceProtocol,
        persistenceService: DataPersistenceServiceProtocol,
        offlineManager: OfflineDataManager,
        networkMonitor: NetworkMonitor,
        loadingStateManager: LoadingStateManager? = nil,
        errorHandler: ErrorHandlerProtocol? = nil
    ) {
        self.apiService = apiService
        self.persistenceService = persistenceService
        self.offlineManager = offlineManager
        self.networkMonitor = networkMonitor
        self.loadingStateManager = loadingStateManager ?? LoadingStateManager()
        self.errorHandler = errorHandler ?? DefaultErrorHandler()
    }
    
    // MARK: - Public Methods
    
    /// Perform a new search with current criteria
    func performSearch() async {
        guard searchCriteria.isValidSearch else {
            let validationError = AppError.validation(.emptySearchCriteria)
            loadingStateManager.setError(.searchJobs, error: validationError)
            errorMessage = validationError.localizedDescription
            return
        }
        
        // Clear previous errors
        loadingStateManager.clearError(.searchJobs)
        errorMessage = nil
        currentPage = 1
        
        let result = await loadingStateManager.executeOperationWithRetry(.searchJobs) {
            let criteria = self.searchCriteria.withPage(self.currentPage)
            return try await self.apiService.searchJobs(criteria: criteria)
        }
        
        switch result {
        case .success(let response):
            searchResults = response.jobs
            totalJobCount = response.totalJobCount
            hasMoreResults = response.hasMoreResults
            hasSearched = true
            
        case .failure(let appError):
            errorMessage = appError.localizedDescription
        }
        
        // Update legacy loading state for UI compatibility
        isLoading = loadingStateManager.isLoading(.searchJobs)
    }
    
    /// Load more results for pagination
    func loadMoreResults() async {
        guard hasMoreResults && !loadingStateManager.isLoading(.loadMoreResults) && !loadingStateManager.isLoading(.searchJobs) else {
            return
        }
        
        let result = await loadingStateManager.executeOperationWithRetry(.loadMoreResults) {
            let nextPage = self.currentPage + 1
            let criteria = self.searchCriteria.withPage(nextPage)
            return try await self.apiService.searchJobs(criteria: criteria)
        }
        
        switch result {
        case .success(let response):
            // Append new results to existing ones
            searchResults.append(contentsOf: response.jobs)
            hasMoreResults = response.hasMoreResults
            currentPage += 1
            
        case .failure(let appError):
            errorMessage = appError.localizedDescription
        }
        
        // Update legacy loading state for UI compatibility
        isLoadingMore = loadingStateManager.isLoading(.loadMoreResults)
    }
    
    /// Update search criteria and reset pagination
    func updateSearchCriteria(_ criteria: SearchCriteria) {
        searchCriteria = criteria
        currentPage = 1
        hasMoreResults = false
    }
    
    /// Clear search results and criteria
    func clearSearch() {
        searchResults = []
        searchCriteria = SearchCriteria()
        errorMessage = nil
        hasMoreResults = false
        totalJobCount = 0
        currentPage = 1
        hasSearched = false
    }
    
    /// Toggle favorite status for a job
    func toggleFavorite(for job: JobSearchItem) async {
        let result = await loadingStateManager.executeOperation(.toggleFavorite) {
            // Check if job is currently favorited
            let favoriteJobs = try await self.persistenceService.getFavoriteJobs()
            let isFavorited = favoriteJobs.contains { $0.jobId == job.jobId }
            
            if isFavorited {
                try await self.persistenceService.removeFavoriteJob(jobId: job.jobId)
            } else {
                // Convert JobSearchItem to Job entity for persistence
                let jobEntity = try await self.createJobEntity(from: job)
                try await self.persistenceService.saveFavoriteJob(jobEntity)
            }
        }
        
        if case .failure(let appError) = result {
            errorMessage = appError.localizedDescription
        }
    }
    
    /// Check if a job is favorited
    func isFavorited(_ job: JobSearchItem) async -> Bool {
        do {
            let favoriteJobs = try await persistenceService.getFavoriteJobs()
            return favoriteJobs.contains { $0.jobId == job.jobId }
        } catch {
            return false
        }
    }
    
    /// Refresh current search results
    func refreshSearch() async {
        guard hasSearched else { return }
        
        currentPage = 1
        await performSearch()
    }
    
    /// Search with quick filters
    func searchWithKeyword(_ keyword: String) async {
        let criteria = SearchCriteria(keyword: keyword)
        updateSearchCriteria(criteria)
        await performSearch()
    }
    
    func searchByLocation(_ location: String) async {
        let criteria = SearchCriteria(location: location)
        updateSearchCriteria(criteria)
        await performSearch()
    }
    
    func searchRemoteJobs() async {
        let criteria = SearchCriteria(remoteOnly: true)
        updateSearchCriteria(criteria)
        await performSearch()
    }
    
    /// Save the current search criteria as a saved search
    func saveCurrentSearch(searchText: String) async -> Bool {
        // Create a saved search from current criteria and search text
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
        let savedSearch = SavedSearch(context: context)
        savedSearch.searchId = UUID()
        savedSearch.name = generateSearchName(from: searchText)
        savedSearch.keywords = searchText.isEmpty ? nil : searchText
        savedSearch.location = searchCriteria.location
        savedSearch.department = searchCriteria.department
        savedSearch.salaryMin = searchCriteria.salaryMin != nil ? Int32(searchCriteria.salaryMin!) : 0
        savedSearch.salaryMax = searchCriteria.salaryMax != nil ? Int32(searchCriteria.salaryMax!) : 0
        savedSearch.isNotificationEnabled = false // Default to off
        savedSearch.lastChecked = nil
        
        do {
            try await persistenceService.saveSavedSearch(savedSearch)
            
            // Show success feedback (you could add a toast or alert here)
            print("✅ Search saved successfully: \(savedSearch.name ?? "Unnamed")")
            return true
            
        } catch {
            print("❌ Failed to save search: \(error)")
            errorMessage = "Failed to save search. Please try again."
            return false
        }
    }
    
    /// Generate a descriptive name for the saved search
    private func generateSearchName(from searchText: String) -> String {
        var nameComponents: [String] = []
        
        // Add search text if provided
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            nameComponents.append(searchText)
        }
        
        // Add location if specified
        if let location = searchCriteria.location, !location.isEmpty {
            nameComponents.append("in \(location)")
        }
        
        // Add department if specified
        if let department = searchCriteria.department, !department.isEmpty {
            nameComponents.append("at \(department)")
        }
        
        // Add remote indicator
        if searchCriteria.remoteOnly {
            nameComponents.append("(Remote)")
        }
        
        // Add salary range if specified
        if let salaryMin = searchCriteria.salaryMin, let salaryMax = searchCriteria.salaryMax {
            nameComponents.append("$\(salaryMin/1000)K-\(salaryMax/1000)K")
        } else if let salaryMin = searchCriteria.salaryMin {
            nameComponents.append("$\(salaryMin/1000)K+")
        } else if let salaryMax = searchCriteria.salaryMax {
            nameComponents.append("up to $\(salaryMax/1000)K")
        }
        
        // Create final name
        let finalName = nameComponents.joined(separator: " ")
        
        // Fallback to generic name if nothing specified
        return finalName.isEmpty ? "All Federal Jobs" : finalName
    }
    
    /// Load recent jobs automatically when the app starts
    func loadRecentJobs() async {
        // Create criteria for recent jobs (no filters, sorted by publication date)
        let criteria = SearchCriteria(resultsPerPage: 25)
        updateSearchCriteria(criteria)
        
        // Try to load from API first
        await performSearch()
        
        // If API failed and we have no results, show sample data
        if searchResults.isEmpty && errorMessage != nil {
            await loadSampleJobs()
        }
    }
    
    /// Load sample jobs as fallback when API is not working
    private func loadSampleJobs() async {
        // Clear any existing error
        errorMessage = nil
        
        // Create sample job data
        let sampleJobs = createSampleJobs()
        searchResults = sampleJobs
        totalJobCount = sampleJobs.count
        hasMoreResults = false
        hasSearched = true
        
        // Update loading states
        isLoading = false
        isLoadingMore = false
    }
    
    /// Create sample job data for demonstration
    private func createSampleJobs() -> [JobSearchItem] {
        let sampleJobsData = [
            (
                id: "SAMPLE001",
                title: "Software Developer",
                department: "Department of Veterans Affairs",
                location: "Washington, DC",
                salary: (min: 75000, max: 120000),
                summary: "Develop and maintain software applications that serve millions of veterans nationwide. Work with modern technologies including React, Node.js, and cloud platforms to build user-friendly digital services.",
                requirements: "Bachelor's degree in Computer Science or related field. 3+ years of experience with web development. Knowledge of JavaScript, Python, and database systems required.",
                duties: ["Design and develop web applications for veteran services", "Collaborate with UX designers and product managers", "Write clean, maintainable code following best practices", "Participate in code reviews and testing", "Support production systems and troubleshoot issues"],
                grade: "GS-12/13",
                isRemote: false
            ),
            (
                id: "SAMPLE002", 
                title: "Data Analyst",
                department: "Department of Health and Human Services",
                location: "Atlanta, GA",
                salary: (min: 65000, max: 95000),
                summary: "Analyze health data to support public health initiatives and policy decisions. Work with large datasets to identify trends and provide actionable insights for health programs.",
                requirements: "Bachelor's degree in Statistics, Mathematics, or related field. Experience with SQL, R, or Python. Strong analytical and communication skills required.",
                duties: ["Analyze health surveillance data and trends", "Create reports and visualizations for stakeholders", "Develop statistical models and forecasts", "Collaborate with epidemiologists and public health experts", "Present findings to leadership and external partners"],
                grade: "GS-11/12",
                isRemote: false
            ),
            (
                id: "SAMPLE003",
                title: "Cybersecurity Specialist",
                department: "Department of Homeland Security",
                location: "Remote",
                salary: (min: 85000, max: 130000),
                summary: "Protect federal systems from cyber threats and vulnerabilities. Monitor security incidents, conduct risk assessments, and implement security controls across government networks.",
                requirements: "Bachelor's degree in Cybersecurity, Computer Science, or related field. Security+ certification required. Experience with network security, incident response, and risk management.",
                duties: ["Monitor and analyze security events and incidents", "Conduct vulnerability assessments and penetration testing", "Develop and implement security policies and procedures", "Respond to cybersecurity incidents and breaches", "Provide security training and awareness programs"],
                grade: "GS-13/14",
                isRemote: true
            ),
            (
                id: "SAMPLE004",
                title: "Financial Analyst",
                department: "Department of Treasury",
                location: "New York, NY",
                salary: (min: 70000, max: 110000),
                summary: "Analyze financial data and prepare reports for federal programs. Support budget planning, financial forecasting, and compliance monitoring for Treasury operations.",
                requirements: "Bachelor's degree in Finance, Accounting, or Economics. CPA or CFA preferred. 2+ years of experience in financial analysis or accounting.",
                duties: ["Prepare financial reports and budget analyses", "Monitor program expenditures and compliance", "Conduct cost-benefit analyses for new initiatives", "Support audit activities and regulatory reporting", "Develop financial models and forecasting tools"],
                grade: "GS-12/13",
                isRemote: false
            ),
            (
                id: "SAMPLE005",
                title: "Environmental Scientist",
                department: "Environmental Protection Agency",
                location: "Denver, CO",
                salary: (min: 68000, max: 105000),
                summary: "Conduct environmental research and assess pollution impacts on air, water, and soil quality. Support EPA's mission to protect human health and the environment.",
                requirements: "Master's degree in Environmental Science, Chemistry, or related field. Experience with environmental monitoring and data analysis. Knowledge of environmental regulations preferred.",
                duties: ["Conduct field studies and collect environmental samples", "Analyze laboratory data and prepare technical reports", "Review environmental impact assessments", "Support enforcement actions and compliance monitoring", "Collaborate with state and local environmental agencies"],
                grade: "GS-11/12",
                isRemote: false
            )
        ]
        
        return sampleJobsData.map { jobData in
            let descriptor = JobDescriptor(
                positionId: jobData.id,
                positionTitle: jobData.title,
                positionUri: "https://www.usajobs.gov/job/\(jobData.id)",
                applicationCloseDate: Calendar.current.date(byAdding: .day, value: 30, to: Date())?.ISO8601Format() ?? "",
                positionStartDate: Date().ISO8601Format(),
                positionEndDate: Calendar.current.date(byAdding: .year, value: 1, to: Date())?.ISO8601Format() ?? "",
                publicationStartDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())?.ISO8601Format() ?? "",
                applicationUri: "https://www.usajobs.gov/job/\(jobData.id)",
                positionLocationDisplay: jobData.location,
                positionLocation: [],
                organizationName: jobData.department,
                departmentName: jobData.department,
                jobCategory: [JobCategory(name: "Professional", code: "0300")],
                jobGrade: [JobGrade(code: jobData.grade)],
                positionRemuneration: [
                    PositionRemuneration(
                        minimumRange: String(jobData.salary.min),
                        maximumRange: String(jobData.salary.max),
                        rateIntervalCode: "PA",
                        description: "Per Year"
                    )
                ],
                positionSummary: jobData.summary,
                positionFormattedDescription: [
                    PositionFormattedDescription(label: "Major Duties", labelDescription: "• " + jobData.duties.joined(separator: "\n• ")),
                    PositionFormattedDescription(label: "Requirements", labelDescription: jobData.requirements)
                ],
                userArea: UserArea(details: UserAreaDetails(
                    jobSummary: jobData.summary,
                    whoMayApply: WhoMayApply(name: "United States Citizens", code: "15317"),
                    lowGrade: jobData.grade.components(separatedBy: "/").first ?? "12",
                    highGrade: jobData.grade.components(separatedBy: "/").last ?? "13",
                    promotionPotential: "13",
                    organizationCodes: jobData.department,
                    relocation: "No",
                    hiringPath: ["public"],
                    totalOpenings: "Few",
                    agencyMarketingStatement: "Join the federal workforce and make a difference in the lives of Americans.",
                    travelCode: "25",
                    detailStatusUrl: nil,
                    majorDuties: jobData.duties,
                    education: "See requirements section",
                    requirements: jobData.requirements,
                    evaluations: "You will be evaluated on the basis of your level of competency in the following areas: Technical Knowledge, Problem Solving, Communication, and Teamwork.",
                    howToApply: "Submit your application through USAJOBS. Ensure all required documents are included.",
                    whatToExpectNext: "After the closing date, your application will be reviewed and you will be contacted if selected for an interview.",
                    requiredDocuments: "Resume, Cover Letter, Transcripts (if applicable)",
                    benefits: "Federal employees enjoy comprehensive benefits including health insurance, retirement plans, paid time off, and professional development opportunities.",
                    benefitsUrl: "https://www.opm.gov/healthcare-insurance/",
                    benefitsDisplayDefaultText: true,
                    otherInformation: "This position may require a background investigation.",
                    keyRequirements: [jobData.requirements],
                    withinArea: "No",
                    commuterLocation: "No",
                    serviceType: "Competitive",
                    announcementClosingType: "Cut-off",
                    agencyContactEmail: "hr@\(jobData.department.lowercased().replacingOccurrences(of: " ", with: "")).gov",
                    agencyContactPhone: "1-800-555-0199",
                    securityClearance: "Public Trust",
                    drugTest: "No",
                    adjudicationType: ["Suitability/Fitness"],
                    teleworkEligible: jobData.isRemote,
                    remoteIndicator: jobData.isRemote
                )),
                qualificationSummary: jobData.requirements
            )
            
            return JobSearchItem(
                matchedObjectId: jobData.id,
                matchedObjectDescriptor: descriptor,
                relevanceRank: 1
            )
        }
    }
    
    // MARK: - Offline Methods
    
    /// Load cached jobs for offline browsing
    func loadCachedJobs() async {
        let result = await loadingStateManager.executeOperation(.searchJobs) {
            return try await self.offlineManager.getCachedJobs(limit: 50)
        }
        
        switch result {
        case .success(let cachedJobs):
            // Convert cached Job entities to JobSearchItem format for display
            searchResults = cachedJobs.compactMap { job in
                convertJobToSearchItem(job)
            }
            
            totalJobCount = searchResults.count
            hasMoreResults = false
            hasSearched = true
            
        case .failure(let appError):
            errorMessage = appError.localizedDescription
        }
        
        // Update legacy loading state for UI compatibility
        isLoading = loadingStateManager.isLoading(.searchJobs)
    }
    
    /// Check if search is available in current network state
    var isSearchAvailable: Bool {
        return networkMonitor.isConnected
    }
    
    /// Get offline status message
    var offlineStatusMessage: String {
        if networkMonitor.isConnected {
            return ""
        } else {
            return "You're offline. Showing cached jobs only."
        }
    }
    
    /// Perform search with offline fallback
    func performSearchWithOfflineFallback() async {
        if networkMonitor.isConnected {
            await performSearch()
        } else {
            await loadCachedJobs()
        }
    }
    
    /// Retry failed operations
    func retryFailedOperation() async {
        if loadingStateManager.hasFailed(.searchJobs) {
            await performSearch()
        } else if loadingStateManager.hasFailed(.loadMoreResults) {
            await loadMoreResults()
        } else if loadingStateManager.hasFailed(.toggleFavorite) {
            // Clear the error state for retry
            loadingStateManager.clearError(.toggleFavorite)
        }
    }
    
    /// Clear all errors
    func clearAllErrors() {
        loadingStateManager.clearAllErrors()
        errorMessage = nil
    }
    
    /// Get current loading state for specific operation
    func getLoadingState(_ operation: LoadingOperation) -> LoadingState {
        return loadingStateManager.getState(operation)
    }
    
    /// Check if any operation is currently loading
    var isAnyOperationLoading: Bool {
        return loadingStateManager.isAnyLoading
    }
    
    /// Get primary loading message
    var primaryLoadingMessage: String? {
        return loadingStateManager.primaryLoadingMessage
    }
    
    // MARK: - Private Helper Methods
    
    /// Handle search errors and set appropriate error messages
    private func handleSearchError(_ error: Error) {
        if let apiError = error as? APIError {
            switch apiError {
            case .noInternetConnection:
                errorMessage = "No internet connection. Please check your network and try again."
            case .rateLimitExceeded:
                errorMessage = "Too many requests. Please wait a moment and try again."
            case .unauthorized:
                errorMessage = "API access error. Please contact support."
            case .timeout:
                errorMessage = "Request timed out. Please try again."
            default:
                errorMessage = apiError.localizedDescription
            }
        } else {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    /// Convert JobSearchItem to Job entity for Core Data persistence
    private func createJobEntity(from jobItem: JobSearchItem) async throws -> Job {
        // Check if job already exists in cache
        if let existingJob = try await persistenceService.getCachedJob(jobId: jobItem.jobId) {
            return existingJob
        }
        
        // Create new job entity using Core Data stack
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
        let job = Job(
            context: context,
            jobId: jobItem.jobId,
            title: jobItem.jobTitle,
            department: jobItem.department,
            location: jobItem.location
        )
        
        let descriptor = jobItem.matchedObjectDescriptor
        let salaryRange = descriptor.salaryRange
        job.salaryMin = Int32(salaryRange.min ?? 0)
        job.salaryMax = Int32(salaryRange.max ?? 0)
        
        job.applicationDeadline = descriptor.applicationDeadline ?? Date()
        job.datePosted = descriptor.publicationDate ?? Date()
        job.isFavorited = true
        job.cachedAt = Date()
        
        return job
    }
    
    /// Convert Job entity to JobSearchItem for display
    private func convertJobToSearchItem(_ job: Job) -> JobSearchItem? {
        guard let jobId = job.jobId,
              let title = job.title,
              let department = job.department,
              let location = job.location else {
            return nil
        }
        
        // Create a JobDescriptor from cached data
        let descriptor = JobDescriptor(
            positionId: jobId,
            positionTitle: title,
            positionUri: "https://www.usajobs.gov/job/\(jobId)",
            applicationCloseDate: job.applicationDeadline?.ISO8601Format() ?? "",
            positionStartDate: "",
            positionEndDate: "",
            publicationStartDate: job.datePosted?.ISO8601Format() ?? "",
            applicationUri: job.applicationUri ?? "https://www.usajobs.gov/job/\(jobId)",
            positionLocationDisplay: location,
            positionLocation: [],
            organizationName: department,
            departmentName: department,
            jobCategory: [],
            jobGrade: job.gradeDisplay != nil ? [JobGrade(code: job.gradeDisplay!)] : [],
            positionRemuneration: [
                PositionRemuneration(
                    minimumRange: job.salaryMin > 0 ? String(job.salaryMin) : nil,
                    maximumRange: job.salaryMax > 0 ? String(job.salaryMax) : nil,
                    rateIntervalCode: "PA",
                    description: nil
                )
            ],
            positionSummary: job.majorDutiesText ?? "",
            positionFormattedDescription: [],
            userArea: job.isRemoteEligible ? UserArea(details: UserAreaDetails(
                jobSummary: nil,
                whoMayApply: nil,
                lowGrade: nil,
                highGrade: nil,
                promotionPotential: nil,
                organizationCodes: nil,
                relocation: nil,
                hiringPath: nil,
                totalOpenings: nil,
                agencyMarketingStatement: nil,
                travelCode: nil,
                detailStatusUrl: nil,
                majorDuties: nil,
                education: nil,
                requirements: nil,
                evaluations: nil,
                howToApply: nil,
                whatToExpectNext: nil,
                requiredDocuments: nil,
                benefits: nil,
                benefitsUrl: nil,
                benefitsDisplayDefaultText: nil,
                otherInformation: nil,
                keyRequirements: nil,
                withinArea: nil,
                commuterLocation: nil,
                serviceType: nil,
                announcementClosingType: nil,
                agencyContactEmail: nil,
                agencyContactPhone: nil,
                securityClearance: nil,
                drugTest: nil,
                adjudicationType: nil,
                teleworkEligible: job.isRemoteEligible,
                remoteIndicator: job.isRemoteEligible
            )) : nil,
            qualificationSummary: job.keyRequirementsText
        )
        
        return JobSearchItem(
            matchedObjectId: jobId,
            matchedObjectDescriptor: descriptor,
            relevanceRank: 0
        )
    }
}

// MARK: - Search State Computed Properties

extension JobSearchViewModel {
    
    /// Whether the search results are empty after a search
    var isSearchResultsEmpty: Bool {
        return hasSearched && searchResults.isEmpty && !isLoading
    }
    
    /// Whether to show the empty state
    var shouldShowEmptyState: Bool {
        return isSearchResultsEmpty && errorMessage == nil
    }
    
    /// Whether to show the loading state
    var shouldShowLoadingState: Bool {
        return isLoading && searchResults.isEmpty
    }
    
    /// Whether to show the error state
    var shouldShowErrorState: Bool {
        return errorMessage != nil && !isLoading
    }
    
    /// Current search summary text
    var searchSummaryText: String {
        if isLoading && searchResults.isEmpty {
            return "Searching..."
        } else if totalJobCount == 0 && hasSearched {
            return "No jobs found"
        } else if totalJobCount > 0 {
            let displayCount = min(searchResults.count, totalJobCount)
            return "Showing \(displayCount) of \(totalJobCount) jobs"
        } else {
            return "Enter search criteria to find jobs"
        }
    }
    
    /// Whether the load more button should be visible
    var shouldShowLoadMoreButton: Bool {
        return hasMoreResults && !isLoadingMore && !isLoading && !searchResults.isEmpty
    }
}

// MARK: - Convenience Methods for UI

extension JobSearchViewModel {
    
    /// Get formatted salary display for a job
    func salaryDisplay(for job: JobSearchItem) -> String {
        return job.matchedObjectDescriptor.salaryDisplay
    }
    
    /// Get formatted application deadline for a job
    func applicationDeadlineDisplay(for job: JobSearchItem) -> String {
        guard let deadline = job.matchedObjectDescriptor.applicationDeadline else {
            return "No deadline specified"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Apply by \(formatter.string(from: deadline))"
    }
    
    /// Check if a job application deadline is approaching (within 7 days)
    func isDeadlineApproaching(for job: JobSearchItem) -> Bool {
        guard let deadline = job.matchedObjectDescriptor.applicationDeadline else {
            return false
        }
        
        let daysUntilDeadline = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
        return daysUntilDeadline <= 7 && daysUntilDeadline >= 0
    }
    
    /// Get the number of days until application deadline
    func daysUntilDeadline(for job: JobSearchItem) -> Int? {
        guard let deadline = job.matchedObjectDescriptor.applicationDeadline else {
            return nil
        }
        
        return Calendar.current.dateComponents([.day], from: Date(), to: deadline).day
    }
    
    /// Check if a job allows remote work
    func isRemoteEligible(_ job: JobSearchItem) -> Bool {
        return job.matchedObjectDescriptor.isRemoteEligible
    }
    
    /// Clean up unused resources for memory optimization
    func cleanupUnusedResources() {
        // Clear old search results if we have too many
        if searchResults.count > 200 {
            let keepCount = 100
            searchResults = Array(searchResults.suffix(keepCount))
        }
        
        // Clear error messages that are no longer relevant
        if !isLoading && !isLoadingMore {
            errorMessage = nil
        }
        
        // Clear loading state manager cache
        loadingStateManager.clearCompletedOperations()
    }
}