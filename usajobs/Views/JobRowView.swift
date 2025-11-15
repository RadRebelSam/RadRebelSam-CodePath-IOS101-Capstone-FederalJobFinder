//
//  JobRowView.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import SwiftUI

struct JobRowView: View {
    let job: JobSearchItem
    let onFavoriteToggle: () -> Void
    
    @State private var isFavorited = false
    @State private var showingJobDetail = false
    @State private var isAnimating = false
    
    // Services for job detail view
    private let apiService: USAJobsAPIServiceProtocol
    private let persistenceService: DataPersistenceServiceProtocol
    
    init(
        job: JobSearchItem,
        onFavoriteToggle: @escaping () -> Void,
        apiService: USAJobsAPIServiceProtocol? = nil,
        persistenceService: DataPersistenceServiceProtocol? = nil
    ) {
        self.job = job
        self.onFavoriteToggle = onFavoriteToggle
        self.apiService = apiService ?? USAJobsAPIService(apiKey: AppConfiguration.API.key)
        self.persistenceService = persistenceService ?? DataPersistenceService(coreDataStack: CoreDataStack.shared)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Job Header
            jobHeader
            
            // Job Details
            jobDetails
            
            // Job Metadata
            jobMetadata
            
            // Action Buttons
            actionButtons
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .accessibleListItem(
            label: jobAccessibilityLabel,
            hint: "Double tap to view job details",
            value: jobAccessibilityValue
        )
        .accessibilityActions([
            AccessibilityActionInfo("Add to favorites") {
                onFavoriteToggle()
            },
            AccessibilityActionInfo("View details") {
                // This would be handled by navigation
            },
            AccessibilityActionInfo("Apply on USAJobs") {
                openUSAJobsApplication()
            }
        ])
        .dynamicTypeSize(.xSmall ... .accessibility5)
        .onAppear {
            // Check favorite status when view appears
            Task {
                await checkFavoriteStatus()
            }
        }
        .sheet(isPresented: $showingJobDetail) {
            NavigationStack {
                JobDetailView(
                    jobId: job.jobId,
                    apiService: apiService,
                    persistenceService: persistenceService
                )
            }
        }
    }
    
    // MARK: - Accessibility Helpers
    
    private var jobAccessibilityLabel: String {
        var components = [job.jobTitle, job.department, job.location]
        
        if job.matchedObjectDescriptor.isRemoteEligible {
            components.append("Remote eligible")
        }
        
        return components.joined(separator: ", ")
    }
    
    private var jobAccessibilityValue: String {
        var components = [job.matchedObjectDescriptor.salaryDisplay]
        
        if let grade = job.matchedObjectDescriptor.gradeDisplay {
            components.append("Grade GS-\(grade)")
        }
        
        if let deadline = job.matchedObjectDescriptor.applicationDeadline {
            components.append(applicationDeadlineText)
        }
        
        return components.joined(separator: ", ")
    }
    
    // MARK: - Job Header
    
    private var jobHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(job.jobTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .accessibleText(traits: .isHeader)
                    .dynamicTypeSize(.xSmall ... .accessibility5)
                
                Text(job.department)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .accessibleText()
                    .dynamicTypeSize(.xSmall ... .accessibility4)
            }
            
            Spacer()
            
            Button(action: {
                handleFavoriteToggle()
            }) {
                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundColor(isFavorited ? .red : .secondary)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
                    .animation(.easeInOut(duration: 0.2), value: isFavorited)
            }
            .accessibleButton(
                label: isFavorited ? "Remove from favorites" : "Add to favorites",
                hint: isFavorited ? "Removes this job from your favorites list" : "Saves this job to your favorites list"
            )
            .accessibleTouchTarget()
        }
    }
    
    // MARK: - Job Details
    
    private var jobDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Location
            HStack {
                Image(systemName: "location")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                
                Text(job.location)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibleText(label: "Location: \(job.location)")
                    .dynamicTypeSize(.xSmall ... .accessibility3)
                
                if job.matchedObjectDescriptor.isRemoteEligible {
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "house.fill")
                            .font(.caption2)
                            .accessibilityHidden(true)
                        Text("Remote")
                            .font(.caption)
                            .fontWeight(.medium)
                            .dynamicTypeSize(.xSmall ... .accessibility2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(4)
                    .accessibilityLabel("Remote work eligible")
                }
            }
            
            // Salary
            HStack {
                Image(systemName: "dollarsign.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                
                Text(job.matchedObjectDescriptor.salaryDisplay)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibleText(label: "Salary: \(job.matchedObjectDescriptor.salaryDisplay)")
                    .dynamicTypeSize(.xSmall ... .accessibility3)
                
                if let grade = job.matchedObjectDescriptor.gradeDisplay {
                    Spacer()
                    
                    Text("GS-\(grade)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                        .accessibilityLabel("Government service grade \(grade)")
                        .dynamicTypeSize(.xSmall ... .accessibility2)
                }
            }
        }
    }
    
    // MARK: - Job Metadata
    
    private var jobMetadata: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Application Deadline
            if let deadline = job.matchedObjectDescriptor.applicationDeadline {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(isDeadlineApproaching ? .orange : .secondary)
                        .accessibilityHidden(true)
                    
                    Text(applicationDeadlineText)
                        .font(.caption)
                        .foregroundColor(isDeadlineApproaching ? .orange : .secondary)
                        .fontWeight(isDeadlineApproaching ? .medium : .regular)
                        .accessibleText(
                            label: "Application deadline: \(applicationDeadlineText)",
                            traits: isDeadlineApproaching ? .updatesFrequently : []
                        )
                        .dynamicTypeSize(.xSmall ... .accessibility3)
                    
                    if isDeadlineApproaching {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .accessibilityLabel("Urgent deadline")
                    }
                }
            }
            
            // Job Summary (first few lines)
            if !job.matchedObjectDescriptor.positionSummary.isEmpty {
                Text(job.matchedObjectDescriptor.positionSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .accessibleText(label: "Job summary: \(job.matchedObjectDescriptor.positionSummary)")
                    .dynamicTypeSize(.xSmall ... .accessibility3)
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("View Details") {
                // Cache the job data before showing details
                Task {
                    await cacheJobForDetails()
                }
                showingJobDetail = true
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .dynamicTypeSize(.xSmall ... .accessibility3)
            .buttonStyle(.bordered)
            .accessibleNavigation(
                label: "View job details",
                hint: "Opens detailed information about this job"
            )
            .accessibleTouchTarget()
            
            Button("Apply on USAJobs") {
                openUSAJobsApplication()
            }
            .buttonStyle(.borderedProminent)
            .accessibleButton(
                label: "Apply for job on USAJobs website",
                hint: "Opens the official USAJobs website to apply for this position"
            )
            .accessibleTouchTarget()
            .dynamicTypeSize(.xSmall ... .accessibility3)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isDeadlineApproaching: Bool {
        guard let deadline = job.matchedObjectDescriptor.applicationDeadline else {
            return false
        }
        
        let daysUntilDeadline = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
        return daysUntilDeadline <= 7 && daysUntilDeadline >= 0
    }
    
    private var applicationDeadlineText: String {
        guard let deadline = job.matchedObjectDescriptor.applicationDeadline else {
            return "No deadline specified"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        let daysUntilDeadline = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
        
        if daysUntilDeadline < 0 {
            return "Application closed"
        } else if daysUntilDeadline == 0 {
            return "Closes today"
        } else if daysUntilDeadline <= 7 {
            return "Closes in \(daysUntilDeadline) day\(daysUntilDeadline == 1 ? "" : "s")"
        } else {
            return "Closes \(formatter.string(from: deadline))"
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if this job is currently favorited
    private func checkFavoriteStatus() async {
        do {
            let favoriteJobs = try await persistenceService.getFavoriteJobs()
            let isCurrentlyFavorited = favoriteJobs.contains { $0.jobId == job.jobId }
            
            await MainActor.run {
                isFavorited = isCurrentlyFavorited
            }
        } catch {
            print("Error checking favorite status: \(error)")
        }
    }
    
    /// Handle favorite toggle with animation
    private func handleFavoriteToggle() {
        // Start animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isAnimating = true
        }
        
        // Toggle favorite status
        Task {
            do {
                let newFavoriteStatus: Bool
                
                if isFavorited {
                    // Remove from favorites
                    try await persistenceService.removeFavoriteJob(jobId: job.jobId)
                    newFavoriteStatus = false
                } else {
                    // Add to favorites - first create/get the job entity
                    let jobEntity = try await getOrCreateJobEntity()
                    try await persistenceService.saveFavoriteJob(jobEntity)
                    newFavoriteStatus = true
                }
                
                await MainActor.run {
                    // Update UI state
                    isFavorited = newFavoriteStatus
                    
                    // End animation after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isAnimating = false
                        }
                    }
                }
                
                // Call the original callback
                onFavoriteToggle()
                
            } catch {
                print("Error toggling favorite: \(error)")
                
                await MainActor.run {
                    // End animation even if there's an error
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isAnimating = false
                    }
                }
            }
        }
    }
    
    /// Get existing job entity or create a new one from the search item
    private func getOrCreateJobEntity() async throws -> Job {
        // Check if job already exists in cache
        if let existingJob = try await persistenceService.getCachedJob(jobId: job.jobId) {
            return existingJob
        }
        
        // Create new job entity from the search item
        return try await persistenceService.cacheJobDetails(job.matchedObjectDescriptor)
    }
    
    /// Cache the job data for the detail view
    private func cacheJobForDetails() async {
        do {
            // Cache the job details so the JobDetailView can access them
            _ = try await persistenceService.cacheJobDetails(job.matchedObjectDescriptor)
            print("✅ Cached job details for: \(job.jobId)")
        } catch {
            print("❌ Failed to cache job details: \(error)")
        }
    }
    
    private func openUSAJobsApplication() {
        print("🔗 openUSAJobsApplication called for job: \(job.jobId)")
        print("📋 Application URI: \(job.matchedObjectDescriptor.applicationUri)")

        let urlString: String

        // Check if this is a sample job (starts with "SAMPLE")
        if job.jobId.hasPrefix("SAMPLE") {
            print("📝 Sample job detected, using main USAJobs website")
            urlString = "https://www.usajobs.gov"
        } else {
            print("🌐 Real job detected, using application URI")
            urlString = job.matchedObjectDescriptor.applicationUri
        }

        print("🔗 Final URL: \(urlString)")

        // Check if URL string is empty
        guard !urlString.isEmpty else {
            print("❌ Empty URL string for job \(job.jobId)")
            return
        }

        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return
        }

        print("✅ Attempting to open URL: \(url)")

        #if canImport(UIKit)
        UIApplication.shared.open(url, options: [:]) { success in
            if success {
                print("✅ Successfully opened URL: \(url)")
            } else {
                print("❌ Failed to open URL: \(url)")
            }
        }
        #endif
    }
}

// MARK: - Preview

#Preview {
    List {
        JobRowView(
            job: sampleJobSearchItem,
            onFavoriteToggle: {},
            apiService: JobRowPreviewMockUSAJobsAPIService(),
            persistenceService: JobRowPreviewMockDataPersistenceService()
        )
        
        JobRowView(
            job: sampleJobSearchItemWithDeadline,
            onFavoriteToggle: {},
            apiService: JobRowPreviewMockUSAJobsAPIService(),
            persistenceService: JobRowPreviewMockDataPersistenceService()
        )
    }
    .listStyle(PlainListStyle())
}

// MARK: - Preview Mock Services

private class JobRowPreviewMockUSAJobsAPIService: USAJobsAPIServiceProtocol {
    func searchJobs(criteria: SearchCriteria) async throws -> JobSearchResponse {
        return JobSearchResponse(searchResult: SearchResult(
            searchResultItems: [],
            searchResultCount: 0,
            searchResultCountAll: 0
        ))
    }
    
    func getJobDetails(jobId: String) async throws -> JobDescriptor {
        return sampleJobSearchItem.matchedObjectDescriptor
    }
    
    func validateAPIConnection() async throws -> Bool {
        return true
    }
}

private class JobRowPreviewMockDataPersistenceService: DataPersistenceServiceProtocol {
    func saveFavoriteJob(_ job: Job) async throws {}
    func removeFavoriteJob(jobId: String) async throws {}
    func getFavoriteJobs() async throws -> [Job] { return [] }
    func toggleFavoriteStatus(jobId: String) async throws -> Bool { return false }
    func saveSavedSearch(_ search: SavedSearch) async throws {}
    func getSavedSearches() async throws -> [SavedSearch] { return [] }
    func deleteSavedSearch(searchId: UUID) async throws {}
    func updateSavedSearch(_ search: SavedSearch) async throws {}
    func saveApplicationTracking(_ application: ApplicationTracking) async throws {}
    func getApplicationTrackings() async throws -> [ApplicationTracking] { return [] }
    func updateApplicationStatus(jobId: String, status: ApplicationTracking.Status) async throws {}
    func deleteApplicationTracking(jobId: String) async throws {}
    func getApplicationTracking(for jobId: String) async throws -> ApplicationTracking? { return nil }
    func cacheJob(_ job: Job) async throws {}
    func getCachedJob(jobId: String) async throws -> Job? { return nil }
    func clearExpiredCache() async throws {}
    func getCachedJobs(limit: Int?) async throws -> [Job] { return [] }
    func cacheJobDetails(_ jobDetails: JobDescriptor) async throws -> Job {
        return Job(
            context: CoreDataStack.shared.context,
            jobId: jobDetails.positionId,
            title: jobDetails.positionTitle,
            department: jobDetails.departmentName,
            location: jobDetails.positionLocationDisplay
        )
    }
    func getCacheSize() async throws -> Int { return 0 }
    func clearAllCache() async throws {}
}

// MARK: - Sample Data for Preview

private let sampleJobSearchItem = JobSearchItem(
    matchedObjectId: "1",
    matchedObjectDescriptor: JobDescriptor(
        positionId: "12345",
        positionTitle: "Software Developer",
        positionUri: "https://example.com",
        applicationCloseDate: "2025-12-31T23:59:59.000Z",
        positionStartDate: "2025-01-01T00:00:00.000Z",
        positionEndDate: "2025-12-31T23:59:59.000Z",
        publicationStartDate: "2024-11-01T00:00:00.000Z",
        applicationUri: "https://usajobs.gov/apply",
        positionLocationDisplay: "Washington, DC",
        positionLocation: [],
        organizationName: "General Services Administration",
        departmentName: "General Services Administration",
        jobCategory: [],
        jobGrade: [JobGrade(code: "13")],
        positionRemuneration: [PositionRemuneration(
            minimumRange: "80000",
            maximumRange: "120000",
            rateIntervalCode: "PA",
            description: "Per Year"
        )],
        positionSummary: "Develop and maintain software applications for federal agencies. Work with modern technologies and contribute to digital transformation initiatives.",
        positionFormattedDescription: [],
        userArea: UserArea(details: UserAreaDetails(
            jobSummary: nil,
            whoMayApply: nil,
            lowGrade: "13",
            highGrade: "13",
            promotionPotential: nil,
            organizationCodes: nil,
            relocation: nil,
            hiringPath: nil,
            totalOpenings: "5",
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
            teleworkEligible: true,
            remoteIndicator: true
        )),
        qualificationSummary: nil
    ),
    relevanceRank: 1
)

private let sampleJobSearchItemWithDeadline = JobSearchItem(
    matchedObjectId: "2",
    matchedObjectDescriptor: JobDescriptor(
        positionId: "67890",
        positionTitle: "Data Analyst",
        positionUri: "https://example.com",
        applicationCloseDate: "2025-11-20T23:59:59.000Z", // Soon deadline
        positionStartDate: "2025-01-01T00:00:00.000Z",
        positionEndDate: "2025-12-31T23:59:59.000Z",
        publicationStartDate: "2024-11-01T00:00:00.000Z",
        applicationUri: "https://usajobs.gov/apply",
        positionLocationDisplay: "Remote",
        positionLocation: [],
        organizationName: "Department of Health and Human Services",
        departmentName: "Department of Health and Human Services",
        jobCategory: [],
        jobGrade: [JobGrade(code: "12")],
        positionRemuneration: [PositionRemuneration(
            minimumRange: "65000",
            maximumRange: "95000",
            rateIntervalCode: "PA",
            description: "Per Year"
        )],
        positionSummary: "Analyze healthcare data to support policy decisions and program improvements. Remote work available.",
        positionFormattedDescription: [],
        userArea: UserArea(details: UserAreaDetails(
            jobSummary: nil,
            whoMayApply: nil,
            lowGrade: "12",
            highGrade: "12",
            promotionPotential: nil,
            organizationCodes: nil,
            relocation: nil,
            hiringPath: nil,
            totalOpenings: "3",
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
            teleworkEligible: true,
            remoteIndicator: true
        )),
        qualificationSummary: nil
    ),
    relevanceRank: 2
)