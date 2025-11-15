//
//  FavoriteJobRowView.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import SwiftUI

struct FavoriteJobRowView: View {
    let job: Job
    let onRemove: () -> Void
    let onViewDetails: () -> Void
    
    @State private var showingJobDetail = false
    
    // Services for job detail view
    private let apiService: USAJobsAPIServiceProtocol
    private let persistenceService: DataPersistenceServiceProtocol
    
    init(
        job: Job,
        onRemove: @escaping () -> Void,
        onViewDetails: @escaping () -> Void = {},
        apiService: USAJobsAPIServiceProtocol? = nil,
        persistenceService: DataPersistenceServiceProtocol? = nil
    ) {
        self.job = job
        self.onRemove = onRemove
        self.onViewDetails = onViewDetails
        self.apiService = apiService ?? USAJobsAPIService(apiKey: AppConfiguration.API.key)
        self.persistenceService = persistenceService ?? DataPersistenceService(coreDataStack: CoreDataStack.shared)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Job Header with Status Indicator
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Favorite job: \(job.title ?? "Unknown title")")
        .sheet(isPresented: $showingJobDetail) {
            if let jobId = job.jobId {
                NavigationStack {
                    JobDetailView(
                        jobId: jobId,
                        apiService: apiService,
                        persistenceService: persistenceService
                    )
                }
            }
        }
    }
    
    // MARK: - Job Header
    
    private var jobHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(job.title ?? "Unknown Title")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .accessibilityAddTraits(.isHeader)
                    
                    Spacer()
                    
                    // Status Indicator
                    statusIndicator
                }
                
                Text(job.department ?? "Unknown Department")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIndicatorImage)
                .font(.caption)
                .foregroundColor(statusIndicatorColor)
            
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusIndicatorColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusIndicatorColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Job Details
    
    private var jobDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Location
            HStack {
                Image(systemName: "location")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(job.location ?? "Location not specified")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Salary
            HStack {
                Image(systemName: "dollarsign.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(salaryDisplay)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Job Metadata
    
    private var jobMetadata: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Application Deadline
            if let deadline = job.applicationDeadline {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(job.isExpired ? .red : (isDeadlineApproaching ? .orange : .secondary))
                    
                    Text(applicationDeadlineText)
                        .font(.caption)
                        .foregroundColor(job.isExpired ? .red : (isDeadlineApproaching ? .orange : .secondary))
                        .fontWeight((job.isExpired || isDeadlineApproaching) ? .medium : .regular)
                    
                    if isDeadlineApproaching && !job.isExpired {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Date Added to Favorites
            if let cachedAt = job.cachedAt {
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(dateAddedText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("View Details") {
                showingJobDetail = true
                onViewDetails()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("View job details")
            
            if !job.isExpired {
                Button("Apply on USAJobs") {
                    openUSAJobsApplication()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Apply for job on USAJobs website")
            }
            
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    
    private var isDeadlineApproaching: Bool {
        guard let daysUntil = job.daysUntilDeadline else { return false }
        return daysUntil <= 7 && daysUntil >= 0
    }
    
    private var statusIndicatorColor: Color {
        if job.isExpired {
            return .red
        } else if isDeadlineApproaching {
            return .orange
        } else {
            return .green
        }
    }
    
    private var statusIndicatorImage: String {
        if job.isExpired {
            return "clock.badge.xmark"
        } else if isDeadlineApproaching {
            return "clock.badge.exclamationmark"
        } else {
            return "clock.badge.checkmark"
        }
    }
    
    private var statusText: String {
        if job.isExpired {
            return "Expired"
        } else if isDeadlineApproaching {
            return "Closing Soon"
        } else {
            return "Active"
        }
    }
    
    private var salaryDisplay: String {
        let min = job.salaryMin
        let max = job.salaryMax
        
        switch (min, max) {
        case (let minVal, let maxVal) where minVal > 0 && maxVal > 0:
            return "$\(Int(minVal).formatted()) - $\(Int(maxVal).formatted())"
        case (let minVal, _) where minVal > 0:
            return "$\(Int(minVal).formatted())+"
        case (_, let maxVal) where maxVal > 0:
            return "Up to $\(Int(maxVal).formatted())"
        default:
            return "Salary not specified"
        }
    }
    
    private var applicationDeadlineText: String {
        guard let deadline = job.applicationDeadline else {
            return "No deadline specified"
        }
        
        if job.isExpired {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Expired \(formatter.string(from: deadline))"
        } else {
            let daysUntil = job.daysUntilDeadline ?? 0
            if daysUntil <= 0 {
                return "Deadline today"
            } else if daysUntil == 1 {
                return "1 day remaining"
            } else if daysUntil <= 7 {
                return "\(daysUntil) days remaining"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "Apply by \(formatter.string(from: deadline))"
            }
        }
    }
    
    private var dateAddedText: String {
        guard let cachedAt = job.cachedAt else {
            return "Date unknown"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return "Added \(formatter.localizedString(for: cachedAt, relativeTo: Date()))"
    }
    
    // MARK: - Helper Methods
    
    private func openUSAJobsApplication() {
        print("🔗 openUSAJobsApplication called for favorite job: \(job.jobId ?? "unknown")")

        guard let jobId = job.jobId else {
            print("❌ No job ID available")
            return
        }

        // Try to use the stored application URI first, fallback to constructing URL
        let urlString: String
        if let applicationUri = job.applicationUri, !applicationUri.isEmpty {
            print("📋 Using stored application URI: \(applicationUri)")
            urlString = applicationUri
        } else {
            print("📋 Constructing URL from job ID")
            urlString = "https://www.usajobs.gov/job/\(jobId)"
        }

        print("🔗 Final URL: \(urlString)")

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
        FavoriteJobRowView(
            job: SampleJobFactory.createSampleFavoriteJob(),
            onRemove: {},
            apiService: FavoriteJobRowPreviewMockUSAJobsAPIService(),
            persistenceService: FavoriteJobRowPreviewMockDataPersistenceService()
        )
        
        FavoriteJobRowView(
            job: SampleJobFactory.createSampleExpiredFavoriteJob(),
            onRemove: {},
            apiService: FavoriteJobRowPreviewMockUSAJobsAPIService(),
            persistenceService: FavoriteJobRowPreviewMockDataPersistenceService()
        )
        
        FavoriteJobRowView(
            job: SampleJobFactory.createSampleClosingSoonFavoriteJob(),
            onRemove: {},
            apiService: FavoriteJobRowPreviewMockUSAJobsAPIService(),
            persistenceService: FavoriteJobRowPreviewMockDataPersistenceService()
        )
    }
    .listStyle(PlainListStyle())
}

// MARK: - Preview Mock Services

private class FavoriteJobRowPreviewMockUSAJobsAPIService: USAJobsAPIServiceProtocol {
    func searchJobs(criteria: SearchCriteria) async throws -> JobSearchResponse {
        return JobSearchResponse(searchResult: SearchResult(
            searchResultItems: [],
            searchResultCount: 0,
            searchResultCountAll: 0
        ))
    }
    
    func getJobDetails(jobId: String) async throws -> JobDescriptor {
        return JobDescriptor(
            positionId: jobId,
            positionTitle: "Sample Job",
            positionUri: "https://example.com",
            applicationCloseDate: "2024-12-31T23:59:59.000Z",
            positionStartDate: "2024-01-01T00:00:00.000Z",
            positionEndDate: "2024-12-31T23:59:59.000Z",
            publicationStartDate: "2024-01-01T00:00:00.000Z",
            applicationUri: "https://usajobs.gov/apply",
            positionLocationDisplay: "Washington, DC",
            positionLocation: [],
            organizationName: "Sample Agency",
            departmentName: "Sample Department",
            jobCategory: [],
            jobGrade: [],
            positionRemuneration: [],
            positionSummary: "Sample job summary",
            positionFormattedDescription: [],
            userArea: nil,
            qualificationSummary: nil
        )
    }
    
    func validateAPIConnection() async throws -> Bool {
        return true
    }
}

private class FavoriteJobRowPreviewMockDataPersistenceService: DataPersistenceServiceProtocol {
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

// MARK: - Sample Data Factory

private struct SampleJobFactory {
    static func createSampleFavoriteJob() -> Job {
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
        return Job.sampleJob(
            context: context,
            jobId: "12345",
            title: "Software Developer",
            department: "General Services Administration",
            location: "Washington, DC",
            isExpired: false,
            isFavorited: true
        )
    }
    
    static func createSampleExpiredFavoriteJob() -> Job {
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
        return Job.sampleJob(
            context: context,
            jobId: "67890",
            title: "Data Analyst",
            department: "Department of Health and Human Services",
            location: "Remote",
            isExpired: true,
            isFavorited: true
        )
    }
    
    static func createSampleClosingSoonFavoriteJob() -> Job {
        let coreDataStack = CoreDataStack.shared
        let context = coreDataStack.context
        
        let job = Job.sampleJob(
            context: context,
            jobId: "11111",
            title: "Program Manager",
            department: "Department of Defense",
            location: "Arlington, VA",
            isExpired: false,
            isFavorited: true
        )
        
        // Set closing soon deadline (3 days)
        job.applicationDeadline = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        
        return job
    }
}