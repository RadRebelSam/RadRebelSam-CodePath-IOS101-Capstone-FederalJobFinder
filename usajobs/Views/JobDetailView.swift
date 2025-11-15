//
//  JobDetailView.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import SwiftUI

/// View for displaying detailed job information
struct JobDetailView: View {
    
    // MARK: - Properties
    
    let jobId: String
    @StateObject private var viewModel: JobDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    
    // MARK: - Initialization
    
    init(
        jobId: String,
        apiService: USAJobsAPIServiceProtocol,
        persistenceService: DataPersistenceServiceProtocol
    ) {
        self.jobId = jobId
        self._viewModel = StateObject(wrappedValue: JobDetailViewModel(
            apiService: apiService,
            persistenceService: persistenceService,
            offlineManager: OfflineDataManager(
                networkMonitor: NetworkMonitor.shared,
                persistenceService: persistenceService,
                apiService: apiService
            ),
            networkMonitor: NetworkMonitor.shared,
            loadingStateManager: LoadingStateManager(),
            errorHandler: DefaultErrorHandler()
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(errorMessage)
            } else if viewModel.hasJobDetail {
                jobDetailContent
            } else {
                emptyView
            }
        }
        .navigationTitle(viewModel.jobDetail?.positionTitle ?? "Job Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Close")
                .accessibilityHint("Close job details and return to main view")
            }

            if viewModel.hasJobDetail {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        favoriteButton
                        shareButton
                    }
                }
            }
        }
        .task {
            await viewModel.loadJobDetails(jobId: jobId)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: viewModel.shareJob())
        }
    }
    
    // MARK: - Content Views
    
    private var jobDetailContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                jobHeaderSection
                jobInfoSection
                
                if viewModel.shouldShowApplicationStatus {
                    applicationStatusSection
                }
                
                jobDescriptionSection
                requirementsSection
                locationSection
                compensationSection
                applicationSection
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadJobDetails(jobId: jobId)
        }
    }
    
    private var jobHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.jobDetail?.positionTitle ?? "")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
            
            Text(viewModel.jobDetail?.departmentName ?? "")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack {
                Label(viewModel.jobDetail?.primaryLocation ?? "", systemImage: "location")
                
                if viewModel.isRemoteEligible {
                    Label("Remote Eligible", systemImage: "wifi")
                        .foregroundColor(.blue)
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            Text(viewModel.publicationDateText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var jobInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let gradeText = viewModel.jobGradeText {
                InfoRow(title: "Grade", value: gradeText)
            }
            
            InfoRow(title: "Salary", value: viewModel.salaryText)
            
            if viewModel.hasApplicationDeadline {
                HStack {
                    InfoRow(title: "Deadline", value: viewModel.applicationDeadlineText)
                    
                    if viewModel.isDeadlineApproaching {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var applicationStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Application Status")
                .font(.headline)
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                Text(viewModel.applicationStatusText ?? "")
                    .font(.subheadline)
                
                Spacer()
                
                Menu("Update Status") {
                    Button("Applied") {
                        Task {
                            await viewModel.updateApplicationStatus(to: .applied)
                        }
                    }
                    
                    Button("Interview Scheduled") {
                        Task {
                            await viewModel.updateApplicationStatus(to: .interviewed)
                        }
                    }
                    
                    Button("Offer Received") {
                        Task {
                            await viewModel.updateApplicationStatus(to: .offered)
                        }
                    }
                    
                    Button("Not Selected") {
                        Task {
                            await viewModel.updateApplicationStatus(to: .rejected)
                        }
                    }
                }
                .disabled(viewModel.isUpdatingApplication)
            }
            .padding()
            .background(Color(.systemGreen).opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var jobDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Job Summary")
                .font(.headline)
            
            Text(viewModel.jobDetail?.positionSummary ?? "No summary available")
                .font(.body)
                .multilineTextAlignment(.leading)
            
            if let majorDuties = viewModel.majorDutiesText {
                Text("Major Duties")
                    .font(.headline)
                    .padding(.top)
                
                Text("• \(majorDuties)")
                    .font(.body)
                    .multilineTextAlignment(.leading)
            }
        }
    }
    
    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Requirements")
                .font(.headline)
            
            if let qualificationSummary = viewModel.jobDetail?.qualificationSummary {
                Text(qualificationSummary)
                    .font(.body)
                    .multilineTextAlignment(.leading)
            }
            
            if let keyRequirements = viewModel.keyRequirementsText {
                Text("Key Requirements")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.top, 8)
                
                Text("• \(keyRequirements)")
                    .font(.body)
                    .multilineTextAlignment(.leading)
            }
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location Details")
                .font(.headline)
            
            ForEach(viewModel.jobDetail?.positionLocation ?? [], id: \.locationName) { location in
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.locationName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let cityName = location.cityName {
                        Text(cityName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var compensationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compensation & Benefits")
                .font(.headline)
            
            Text(viewModel.salaryText)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if let remuneration = viewModel.jobDetail?.positionRemuneration.first,
               let description = remuneration.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var applicationSection: some View {
        VStack(spacing: 16) {
            if viewModel.shouldShowApplyButton {
                Button(action: {
                    Task {
                        await viewModel.markAsApplied()
                    }
                }) {
                    HStack {
                        if viewModel.isUpdatingApplication {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "doc.text")
                        }
                        Text("Mark as Applied")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isUpdatingApplication)
            }
            
            Button(action: {
                viewModel.openApplicationPage()
            }) {
                HStack {
                    Image(systemName: "safari")
                    Text("Apply on USAJobs.gov")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - State Views
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading job details...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Error Loading Job")
                .font(.headline)
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Try Again") {
                Task {
                    await viewModel.loadJobDetails(jobId: jobId)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Job Details")
                .font(.headline)
            
            Text("Unable to load job information")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Toolbar Buttons
    
    private var favoriteButton: some View {
        Button(action: {
            Task {
                await viewModel.toggleFavorite()
            }
        }) {
            Image(systemName: viewModel.isFavorited ? "heart.fill" : "heart")
                .foregroundColor(viewModel.isFavorited ? .red : .primary)
        }
        .disabled(viewModel.isTogglingFavorite)
    }
    
    private var shareButton: some View {
        Button(action: {
            showingShareSheet = true
        }) {
            Image(systemName: "square.and.arrow.up")
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#if DEBUG
struct JobDetailView_Previews: PreviewProvider {
    static var previews: some View {
        JobDetailView(
            jobId: "sample-job-id",
            apiService: MockUSAJobsAPIService(),
            persistenceService: MockDataPersistenceService()
        )
    }
}

// Mock services for preview
private class MockUSAJobsAPIService: USAJobsAPIServiceProtocol {
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

private class MockDataPersistenceService: DataPersistenceServiceProtocol {
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
#endif