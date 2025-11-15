//
//  JobDetailViewModel.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation
import SwiftUI
import CoreData
import Combine

/// Salary range structure for job details
struct SalaryRange {
    let min: Int?
    let max: Int?
    
    init(min: Int?, max: Int?) {
        self.min = min
        self.max = max
    }
}

/// ViewModel for managing job detail functionality
@MainActor
class JobDetailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The detailed job information
    @Published var jobDetail: JobDescriptor?
    
    /// Whether the job is currently favorited
    @Published var isFavorited = false
    
    /// Loading state for job detail fetch
    @Published var isLoading = false
    
    /// Loading state for favorite toggle
    @Published var isTogglingFavorite = false
    
    /// Error message to display to user
    @Published var errorMessage: String?
    
    /// Application tracking information for this job
    @Published var applicationTracking: ApplicationTracking?
    
    /// Whether the application tracking is being updated
    @Published var isUpdatingApplication = false
    
    // MARK: - Private Properties
    
    private let apiService: USAJobsAPIServiceProtocol
    private let persistenceService: DataPersistenceServiceProtocol
    private let offlineManager: OfflineDataManager
    private let networkMonitor: NetworkMonitor
    private let loadingStateManager: LoadingStateManager
    private let errorHandler: ErrorHandlerProtocol
    private var currentJobId: String?
    
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
    
    /// Load detailed job information for the specified job ID
    func loadJobDetails(jobId: String) async {
        guard jobId != currentJobId || jobDetail == nil else {
            return // Already loaded this job
        }
        
        currentJobId = jobId
        isLoading = true
        errorMessage = nil
        
        print("🔍 Loading job details for ID: \(jobId)")
        
        do {
            // Check if this is a sample job
            if jobId.hasPrefix("SAMPLE") {
                print("📝 Loading sample job details for: \(jobId)")
                // Create sample job details directly
                let sampleDetails = createSampleJobDetails(for: jobId)
                jobDetail = sampleDetails
                
                // Load favorite status and application tracking
                await loadFavoriteStatus(jobId: jobId)
                await loadApplicationTracking(jobId: jobId)
                
                isLoading = false
                return
            }
            
            // Try to load from cache first
            if let cachedJob = try await persistenceService.getCachedJob(jobId: jobId) {
                print("📦 Found cached job for ID: \(jobId)")
                // Convert cached Job entity to JobDescriptor for display
                let cachedDetails = convertJobToDescriptor(cachedJob)
                jobDetail = cachedDetails
                
                // Load favorite status and application tracking from cache
                await loadFavoriteStatus(jobId: jobId)
                await loadApplicationTracking(jobId: jobId)
                
                isLoading = false
                return
            }
            
            print("❌ No cached job found for ID: \(jobId)")
            
            // If not cached and we're online, fetch from API
            if networkMonitor.isConnected {
                print("🌐 Fetching job details from API for ID: \(jobId)")
                let details = try await apiService.getJobDetails(jobId: jobId)
                jobDetail = details
                
                // Cache the fresh job details
                try? await persistenceService.cacheJobDetails(details)
                
                // Load favorite status and application tracking
                await loadFavoriteStatus(jobId: jobId)
                await loadApplicationTracking(jobId: jobId)
                
                isLoading = false
            } else {
                // Offline and no cache available
                errorMessage = "Job details not available offline. Please connect to the internet to view this job."
                isLoading = false
            }
            
        } catch {
            errorMessage = "Failed to load job details: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Load job details with offline fallback
    func loadJobDetailsWithOfflineFallback(jobId: String) async {
        if networkMonitor.isConnected {
            await loadJobDetails(jobId: jobId)
        } else {
            await loadCachedJobDetails(jobId: jobId)
        }
    }
    
    /// Load job details from cache only
    func loadCachedJobDetails(jobId: String) async {
        currentJobId = jobId
        isLoading = true
        errorMessage = nil
        
        do {
            if let cachedJob = try await persistenceService.getCachedJob(jobId: jobId) {
                let cachedDetails = convertJobToDescriptor(cachedJob)
                jobDetail = cachedDetails
                
                await loadFavoriteStatus(jobId: jobId)
                await loadApplicationTracking(jobId: jobId)
            } else {
                errorMessage = "Job details not available offline."
            }
        } catch {
            errorMessage = "Failed to load cached job details: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Toggle the favorite status of the current job
    func toggleFavorite() async {
        guard let jobDetail = jobDetail else { return }
        
        let result = await loadingStateManager.executeOperation(.toggleFavorite) {
            let newFavoriteStatus = try await self.persistenceService.toggleFavoriteStatus(jobId: jobDetail.positionId)
            
            // If favoriting, cache the job details
            if newFavoriteStatus {
                try await self.cacheJobDetails(jobDetail)
            }
            
            return newFavoriteStatus
        }
        
        switch result {
        case .success(let newFavoriteStatus):
            isFavorited = newFavoriteStatus
            
        case .failure(let appError):
            errorMessage = appError.localizedDescription
        }
        
        // Update legacy loading state for UI compatibility
        isTogglingFavorite = loadingStateManager.isLoading(.toggleFavorite)
    }
    
    /// Mark the job as applied and create application tracking
    func markAsApplied() async {
        guard let jobDetail = jobDetail else { return }
        
        let result = await loadingStateManager.executeOperation(.updateApplicationStatus) {
            // Check if application tracking already exists
            if let existingTracking = try await self.persistenceService.getApplicationTracking(for: jobDetail.positionId) {
                // Update existing tracking
                try await self.persistenceService.updateApplicationStatus(
                    jobId: jobDetail.positionId,
                    status: .applied
                )
            } else {
                // Create new application tracking
                let tracking = self.createApplicationTracking(for: jobDetail)
                try await self.persistenceService.saveApplicationTracking(tracking)
            }
        }
        
        switch result {
        case .success:
            // Reload application tracking to update UI
            await loadApplicationTracking(jobId: jobDetail.positionId)
            
        case .failure(let appError):
            errorMessage = appError.localizedDescription
        }
        
        // Update legacy loading state for UI compatibility
        isUpdatingApplication = loadingStateManager.isLoading(.updateApplicationStatus)
    }
    
    /// Update application status
    func updateApplicationStatus(to status: ApplicationTracking.Status) async {
        guard let jobDetail = jobDetail else { return }
        
        isUpdatingApplication = true
        errorMessage = nil
        
        do {
            try await persistenceService.updateApplicationStatus(
                jobId: jobDetail.positionId,
                status: status
            )
            
            // Reload application tracking to update UI
            await loadApplicationTracking(jobId: jobDetail.positionId)
            
        } catch {
            errorMessage = "Failed to update application status: \(error.localizedDescription)"
        }
        
        isUpdatingApplication = false
    }
    
    /// Open the USAJobs application page in Safari
    func openApplicationPage() {
        print("🔗 openApplicationPage called")

        guard let jobDetail = jobDetail else {
            print("❌ No job detail available")
            errorMessage = "Unable to open application page - no job details loaded"
            return
        }

        print("📋 Job ID: \(jobDetail.positionId)")
        print("📋 Application URI: \(jobDetail.applicationUri)")

        let urlString: String

        // Check if this is a sample job (starts with "SAMPLE")
        if jobDetail.positionId.hasPrefix("SAMPLE") {
            print("📝 Sample job detected, using main USAJobs website")
            // For sample jobs, open the main USAJobs website
            urlString = "https://www.usajobs.gov"
        } else {
            print("🌐 Real job detected, using application URI")
            // For real jobs, use the actual application URI
            urlString = jobDetail.applicationUri
        }

        print("🔗 Final URL: \(urlString)")

        // Check if URL string is empty
        guard !urlString.isEmpty else {
            print("❌ Empty URL string")
            errorMessage = "Unable to open application page - no URL available"
            return
        }

        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            errorMessage = "Unable to open application page - invalid URL"
            return
        }

        print("✅ Attempting to open URL in Safari: \(url)")

        #if canImport(UIKit)
        UIApplication.shared.open(url, options: [:]) { success in
            if success {
                print("✅ Successfully opened URL: \(url)")
            } else {
                print("❌ Failed to open URL: \(url)")
                Task { @MainActor in
                    self.errorMessage = "Unable to open application page in browser"
                }
            }
        }
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }
    
    /// Share job information
    func shareJob() -> [Any] {
        guard let jobDetail = jobDetail else { return [] }
        
        let shareText = """
        \(jobDetail.positionTitle)
        \(jobDetail.departmentName)
        Location: \(jobDetail.primaryLocation)
        Salary: \(jobDetail.salaryDisplay)
        
        Apply at: \(jobDetail.applicationUri)
        """
        
        return [shareText]
    }
    
    /// Clear current job details (useful when navigating away)
    func clearJobDetails() {
        jobDetail = nil
        isFavorited = false
        applicationTracking = nil
        errorMessage = nil
        currentJobId = nil
        loadingStateManager.clearAllErrors()
    }
    
    /// Retry failed operations
    func retryFailedOperation() async {
        if loadingStateManager.hasFailed(.loadJobDetails), let jobId = currentJobId {
            await loadJobDetails(jobId: jobId)
        } else if loadingStateManager.hasFailed(.toggleFavorite) {
            await toggleFavorite()
        } else if loadingStateManager.hasFailed(.updateApplicationStatus) {
            await markAsApplied()
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
    
    /// Load favorite status for the job
    private func loadFavoriteStatus(jobId: String) async {
        do {
            let favoriteJobs = try await persistenceService.getFavoriteJobs()
            isFavorited = favoriteJobs.contains { $0.jobId == jobId }
        } catch {
            // Don't show error for favorite status loading failure
            isFavorited = false
        }
    }
    
    /// Load application tracking information
    private func loadApplicationTracking(jobId: String) async {
        do {
            applicationTracking = try await persistenceService.getApplicationTracking(for: jobId)
        } catch {
            // Don't show error for application tracking loading failure
            applicationTracking = nil
        }
    }
    
    /// Cache job details in Core Data
    private func cacheJobDetails(_ details: JobDescriptor) async throws {
        // Check if job already exists in cache
        if let existingJob = try await persistenceService.getCachedJob(jobId: details.positionId) {
            // Update existing job with new details
            updateJobEntity(existingJob, with: details)
            try await persistenceService.cacheJob(existingJob)
        } else {
            // Create new job entity
            let job = createJobEntity(from: details)
            try await persistenceService.cacheJob(job)
        }
    }
    
    /// Create a new Job entity from JobDescriptor
    private func createJobEntity(from details: JobDescriptor) -> Job {
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
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
    
    /// Update existing Job entity with JobDescriptor data
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
    
    /// Create application tracking entity
    private func createApplicationTracking(for details: JobDescriptor) -> ApplicationTracking {
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
        let tracking = ApplicationTracking(context: context)
        tracking.jobId = details.positionId
        tracking.applicationDate = Date()
        tracking.status = ApplicationTracking.Status.applied.rawValue
        tracking.notes = nil
        
        // Set reminder date to 3 days before application deadline
        if let deadline = details.applicationDeadline {
            tracking.reminderDate = Calendar.current.date(byAdding: .day, value: -3, to: deadline)
        }
        
        return tracking
    }
    
    /// Fetch fresh job details from API
    private func fetchFreshJobDetails(jobId: String) async {
        do {
            let details = try await apiService.getJobDetails(jobId: jobId)
            jobDetail = details
            
            // Cache the fresh job details
            try await offlineManager.cacheJobForOffline(details)
            
            // Load favorite status and application tracking
            await loadFavoriteStatus(jobId: jobId)
            await loadApplicationTracking(jobId: jobId)
            
        } catch {
            // If we already have cached data, don't overwrite it with error
            if jobDetail == nil {
                handleError(error)
            }
        }
    }
    
    /// Convert Job entity to JobDescriptor for display
    private func convertJobToDescriptor(_ job: Job) -> JobDescriptor {
        // Create a minimal JobDescriptor from cached Job data
        // Note: This is a simplified version for offline display
        return JobDescriptor(
            positionId: job.jobId ?? "",
            positionTitle: job.title ?? "Unknown Position",
            positionUri: "https://www.usajobs.gov/job/\(job.jobId ?? "")",
            applicationCloseDate: job.applicationDeadline?.ISO8601Format() ?? "",
            positionStartDate: "",
            positionEndDate: "",
            publicationStartDate: job.datePosted?.ISO8601Format() ?? "",
            applicationUri: job.applicationUri ?? "https://www.usajobs.gov/job/\(job.jobId ?? "")",
            positionLocationDisplay: job.location ?? "Unknown Location",
            positionLocation: [],
            organizationName: job.department ?? "Unknown Department",
            departmentName: job.department ?? "Unknown Department",
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
    }
    
    /// Handle errors and set appropriate error messages
    private func handleError(_ error: Error) {
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
            case .noData:
                errorMessage = "Job details not found. This position may no longer be available."
            default:
                errorMessage = apiError.localizedDescription
            }
        } else {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    /// Create sample job details for demonstration jobs
    private func createSampleJobDetails(for jobId: String) -> JobDescriptor {
        // This method creates detailed sample job data that matches what we show in search
        // These are the same sample jobs created in JobSearchViewModel
        
        switch jobId {
        case "SAMPLE001":
            return JobDescriptor(
                positionId: "SAMPLE001",
                positionTitle: "Software Developer",
                positionUri: "https://www.usajobs.gov/job/SAMPLE001",
                applicationCloseDate: Calendar.current.date(byAdding: .day, value: 30, to: Date())?.ISO8601Format() ?? "",
                positionStartDate: Date().ISO8601Format(),
                positionEndDate: Calendar.current.date(byAdding: .year, value: 1, to: Date())?.ISO8601Format() ?? "",
                publicationStartDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())?.ISO8601Format() ?? "",
                applicationUri: "https://www.usajobs.gov",
                positionLocationDisplay: "Washington, DC",
                positionLocation: [],
                organizationName: "Department of Veterans Affairs",
                departmentName: "Department of Veterans Affairs",
                jobCategory: [JobCategory(name: "Professional", code: "0300")],
                jobGrade: [JobGrade(code: "GS-12/13")],
                positionRemuneration: [
                    PositionRemuneration(
                        minimumRange: "75000",
                        maximumRange: "120000",
                        rateIntervalCode: "PA",
                        description: "Per Year"
                    )
                ],
                positionSummary: "Develop and maintain software applications that serve millions of veterans nationwide. Work with modern technologies including React, Node.js, and cloud platforms to build user-friendly digital services.",
                positionFormattedDescription: [
                    PositionFormattedDescription(label: "Major Duties", labelDescription: "• Design and develop web applications for veteran services\n• Collaborate with UX designers and product managers\n• Write clean, maintainable code following best practices\n• Participate in code reviews and testing\n• Support production systems and troubleshoot issues"),
                    PositionFormattedDescription(label: "Requirements", labelDescription: "Bachelor's degree in Computer Science or related field. 3+ years of experience with web development. Knowledge of JavaScript, Python, and database systems required.")
                ],
                userArea: UserArea(details: UserAreaDetails(
                    jobSummary: "Develop and maintain software applications that serve millions of veterans nationwide.",
                    whoMayApply: WhoMayApply(name: "United States Citizens", code: "15317"),
                    lowGrade: "12",
                    highGrade: "13",
                    promotionPotential: "13",
                    organizationCodes: "Department of Veterans Affairs",
                    relocation: "No",
                    hiringPath: ["public"],
                    totalOpenings: "Few",
                    agencyMarketingStatement: "Join the federal workforce and make a difference in the lives of Americans.",
                    travelCode: "25",
                    detailStatusUrl: nil,
                    majorDuties: ["Design and develop web applications for veteran services", "Collaborate with UX designers and product managers", "Write clean, maintainable code following best practices", "Participate in code reviews and testing", "Support production systems and troubleshoot issues"],
                    education: "See requirements section",
                    requirements: "Bachelor's degree in Computer Science or related field. 3+ years of experience with web development. Knowledge of JavaScript, Python, and database systems required.",
                    evaluations: "You will be evaluated on the basis of your level of competency in the following areas: Technical Knowledge, Problem Solving, Communication, and Teamwork.",
                    howToApply: "Submit your application through USAJOBS. Ensure all required documents are included.",
                    whatToExpectNext: "After the closing date, your application will be reviewed and you will be contacted if selected for an interview.",
                    requiredDocuments: "Resume, Cover Letter, Transcripts (if applicable)",
                    benefits: "Federal employees enjoy comprehensive benefits including health insurance, retirement plans, paid time off, and professional development opportunities.",
                    benefitsUrl: "https://www.opm.gov/healthcare-insurance/",
                    benefitsDisplayDefaultText: true,
                    otherInformation: "This position may require a background investigation.",
                    keyRequirements: ["Bachelor's degree in Computer Science or related field. 3+ years of experience with web development. Knowledge of JavaScript, Python, and database systems required."],
                    withinArea: "No",
                    commuterLocation: "No",
                    serviceType: "Competitive",
                    announcementClosingType: "Cut-off",
                    agencyContactEmail: "hr@va.gov",
                    agencyContactPhone: "1-800-555-0199",
                    securityClearance: "Public Trust",
                    drugTest: "No",
                    adjudicationType: ["Suitability/Fitness"],
                    teleworkEligible: false,
                    remoteIndicator: false
                )),
                qualificationSummary: "Bachelor's degree in Computer Science or related field. 3+ years of experience with web development. Knowledge of JavaScript, Python, and database systems required."
            )
            
        default:
            // For other sample jobs, return a generic sample
            return JobDescriptor(
                positionId: jobId,
                positionTitle: "Sample Federal Position",
                positionUri: "https://www.usajobs.gov/job/\(jobId)",
                applicationCloseDate: Calendar.current.date(byAdding: .day, value: 30, to: Date())?.ISO8601Format() ?? "",
                positionStartDate: Date().ISO8601Format(),
                positionEndDate: Calendar.current.date(byAdding: .year, value: 1, to: Date())?.ISO8601Format() ?? "",
                publicationStartDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())?.ISO8601Format() ?? "",
                applicationUri: "https://www.usajobs.gov",
                positionLocationDisplay: "Washington, DC",
                positionLocation: [],
                organizationName: "Federal Agency",
                departmentName: "Federal Agency",
                jobCategory: [JobCategory(name: "Professional", code: "0300")],
                jobGrade: [JobGrade(code: "GS-12")],
                positionRemuneration: [
                    PositionRemuneration(
                        minimumRange: "70000",
                        maximumRange: "100000",
                        rateIntervalCode: "PA",
                        description: "Per Year"
                    )
                ],
                positionSummary: "This is a sample federal job position for demonstration purposes.",
                positionFormattedDescription: [
                    PositionFormattedDescription(label: "Major Duties", labelDescription: "• Perform professional duties\n• Support agency mission\n• Collaborate with team members"),
                    PositionFormattedDescription(label: "Requirements", labelDescription: "Bachelor's degree required. Experience preferred.")
                ],
                userArea: UserArea(details: UserAreaDetails(
                    jobSummary: "This is a sample federal job position for demonstration purposes.",
                    whoMayApply: WhoMayApply(name: "United States Citizens", code: "15317"),
                    lowGrade: "12",
                    highGrade: "12",
                    promotionPotential: "12",
                    organizationCodes: "Federal Agency",
                    relocation: "No",
                    hiringPath: ["public"],
                    totalOpenings: "Few",
                    agencyMarketingStatement: "Join the federal workforce and make a difference.",
                    travelCode: "25",
                    detailStatusUrl: nil,
                    majorDuties: ["Perform professional duties", "Support agency mission", "Collaborate with team members"],
                    education: "See requirements section",
                    requirements: "Bachelor's degree required. Experience preferred.",
                    evaluations: "You will be evaluated on the basis of your qualifications.",
                    howToApply: "Submit your application through USAJOBS.",
                    whatToExpectNext: "After the closing date, your application will be reviewed.",
                    requiredDocuments: "Resume, Cover Letter",
                    benefits: "Federal employees enjoy comprehensive benefits.",
                    benefitsUrl: "https://www.opm.gov/healthcare-insurance/",
                    benefitsDisplayDefaultText: true,
                    otherInformation: "This position may require a background investigation.",
                    keyRequirements: ["Bachelor's degree required. Experience preferred."],
                    withinArea: "No",
                    commuterLocation: "No",
                    serviceType: "Competitive",
                    announcementClosingType: "Cut-off",
                    agencyContactEmail: "hr@agency.gov",
                    agencyContactPhone: "1-800-555-0199",
                    securityClearance: "Public Trust",
                    drugTest: "No",
                    adjudicationType: ["Suitability/Fitness"],
                    teleworkEligible: false,
                    remoteIndicator: false
                )),
                qualificationSummary: "Bachelor's degree required. Experience preferred."
            )
        }
    }
}

// MARK: - Computed Properties

extension JobDetailViewModel {
    
    /// Whether the job detail is currently loaded
    var hasJobDetail: Bool {
        return jobDetail != nil
    }
    
    /// Whether the job has an application deadline
    var hasApplicationDeadline: Bool {
        return jobDetail?.applicationDeadline != nil
    }
    
    /// Whether the application deadline is approaching (within 7 days)
    var isDeadlineApproaching: Bool {
        guard let deadline = jobDetail?.applicationDeadline else { return false }
        
        let daysUntilDeadline = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
        return daysUntilDeadline <= 7 && daysUntilDeadline >= 0
    }
    
    /// Number of days until application deadline
    var daysUntilDeadline: Int? {
        guard let deadline = jobDetail?.applicationDeadline else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: deadline).day
    }
    
    /// Whether the job allows remote work
    var isRemoteEligible: Bool {
        return jobDetail?.isRemoteEligible ?? false
    }
    
    /// Whether the user has applied for this job
    var hasApplied: Bool {
        return applicationTracking != nil
    }
    
    /// Current application status display text
    var applicationStatusText: String? {
        guard let tracking = applicationTracking else { return nil }
        
        switch ApplicationTracking.Status(rawValue: tracking.status ?? "") {
        case .applied:
            return "Applied"
        case .interviewed:
            return "Interview Scheduled"
        case .offered:
            return "Offer Received"
        case .rejected:
            return "Not Selected"
        default:
            return "Unknown Status"
        }
    }
    
    /// Whether to show the apply button
    var shouldShowApplyButton: Bool {
        return !hasApplied && hasJobDetail
    }
    
    /// Whether to show the application status section
    var shouldShowApplicationStatus: Bool {
        return hasApplied
    }
}

// MARK: - Formatting Helpers

extension JobDetailViewModel {
    
    /// Get formatted application deadline text
    var applicationDeadlineText: String {
        guard let deadline = jobDetail?.applicationDeadline else {
            return "No deadline specified"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return "Application deadline: \(formatter.string(from: deadline))"
    }
    
    /// Get formatted publication date text
    var publicationDateText: String {
        guard let publicationDate = jobDetail?.publicationDate else {
            return "Publication date not available"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Posted: \(formatter.string(from: publicationDate))"
    }
    
    /// Get formatted salary range text
    var salaryText: String {
        return jobDetail?.salaryDisplay ?? "Salary not specified"
    }
    
    /// Get formatted job grade text
    var jobGradeText: String? {
        return jobDetail?.gradeDisplay
    }
    
    /// Get formatted major duties text
    var majorDutiesText: String? {
        return jobDetail?.majorDutiesText
    }
    
    /// Get formatted key requirements text
    var keyRequirementsText: String? {
        return jobDetail?.keyRequirementsText
    }
}