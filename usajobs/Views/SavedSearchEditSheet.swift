//
//  SavedSearchEditSheet.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import SwiftUI

struct SavedSearchEditSheet: View {
    @ObservedObject var viewModel: SavedSearchViewModel
    let savedSearch: SavedSearch?
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchName = ""
    @State private var keywords = ""
    @State private var location = ""
    @State private var department = ""
    @State private var salaryMin = ""
    @State private var salaryMax = ""
    @State private var enableNotifications = false
    
    @State private var showingValidationError = false
    @State private var validationErrorMessage = ""
    
    private var isEditing: Bool {
        return savedSearch != nil
    }
    
    private var title: String {
        return isEditing ? "Edit Saved Search" : "Create Saved Search"
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Search Name Section
                Section {
                    TextField("Search Name", text: $searchName)
                        .accessibilityLabel("Search name")
                        .accessibilityHint("Enter a name for this saved search")
                } header: {
                    Text("Search Name")
                } footer: {
                    Text("Give your search a memorable name")
                }
                
                // Search Criteria Section
                Section {
                    TextField("Keywords (optional)", text: $keywords)
                        .accessibilityLabel("Keywords")
                        .accessibilityHint("Enter job keywords to search for")
                    
                    TextField("Location (optional)", text: $location)
                        .accessibilityLabel("Location")
                        .accessibilityHint("Enter a city, state, or 'remote'")
                    
                    TextField("Department (optional)", text: $department)
                        .accessibilityLabel("Department")
                        .accessibilityHint("Enter a specific government department")
                } header: {
                    Text("Search Criteria")
                } footer: {
                    Text("All fields are optional. Leave blank to search all jobs.")
                }
                
                // Salary Range Section
                Section {
                    HStack {
                        TextField("Min", text: $salaryMin)
                            .keyboardType(.numberPad)
                            .accessibilityLabel("Minimum salary")
                        
                        Text("to")
                            .foregroundColor(.secondary)
                        
                        TextField("Max", text: $salaryMax)
                            .keyboardType(.numberPad)
                            .accessibilityLabel("Maximum salary")
                    }
                } header: {
                    Text("Salary Range (optional)")
                } footer: {
                    Text("Enter annual salary amounts in dollars")
                }
                
                // Notification Settings Section
                Section {
                    Toggle("Enable Notifications", isOn: $enableNotifications)
                        .accessibilityLabel("Enable notifications")
                        .accessibilityHint("Get notified when new jobs match this search")
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Receive push notifications when new jobs match your search criteria")
                }
                
                // Preview Section
                if hasSearchCriteria {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Search Preview")
                                .font(.headline)
                            
                            Text(searchCriteriaPreview)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Preview")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel editing")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveSearch()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(searchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Save search")
                }
            }
            .onAppear {
                loadExistingData()
            }
            .alert("Validation Error", isPresented: $showingValidationError) {
                Button("OK") {
                    showingValidationError = false
                }
            } message: {
                Text(validationErrorMessage)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadExistingData() {
        guard let savedSearch = savedSearch else { return }
        
        searchName = savedSearch.name ?? ""
        keywords = savedSearch.keywords ?? ""
        location = savedSearch.location ?? ""
        department = savedSearch.department ?? ""
        
        if savedSearch.salaryMin > 0 {
            salaryMin = String(savedSearch.salaryMin)
        }
        
        if savedSearch.salaryMax > 0 {
            salaryMax = String(savedSearch.salaryMax)
        }
        
        enableNotifications = savedSearch.isNotificationEnabled
    }
    
    private func saveSearch() async {
        // Validate input
        guard validateInput() else { return }
        
        // Create search criteria
        let criteria = SearchCriteria(
            keyword: keywords.isEmpty ? nil : keywords,
            location: location.isEmpty ? nil : location,
            department: department.isEmpty ? nil : department,
            salaryMin: parseSalary(salaryMin),
            salaryMax: parseSalary(salaryMax)
        )
        
        // Save or update the search
        if let existingSearch = savedSearch {
            await viewModel.updateSavedSearch(existingSearch, name: searchName, criteria: criteria)
            
            // Update notification setting separately
            if existingSearch.isNotificationEnabled != enableNotifications {
                existingSearch.isNotificationEnabled = enableNotifications
                await viewModel.toggleNotifications(for: existingSearch)
            }
        } else {
            await viewModel.createSavedSearch(name: searchName, criteria: criteria)
        }
        
        // Check for errors
        if viewModel.errorMessage == nil {
            dismiss()
        } else {
            validationErrorMessage = viewModel.errorMessage ?? "An error occurred"
            showingValidationError = true
        }
    }
    
    private func validateInput() -> Bool {
        let trimmedName = searchName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            validationErrorMessage = "Search name cannot be empty"
            showingValidationError = true
            return false
        }
        
        // Validate salary inputs
        if !salaryMin.isEmpty {
            guard let _ = Int(salaryMin), Int(salaryMin) ?? 0 >= 0 else {
                validationErrorMessage = "Minimum salary must be a valid number"
                showingValidationError = true
                return false
            }
        }
        
        if !salaryMax.isEmpty {
            guard let _ = Int(salaryMax), Int(salaryMax) ?? 0 >= 0 else {
                validationErrorMessage = "Maximum salary must be a valid number"
                showingValidationError = true
                return false
            }
        }
        
        // Validate salary range
        if let minSalary = parseSalary(salaryMin),
           let maxSalary = parseSalary(salaryMax),
           minSalary > maxSalary {
            validationErrorMessage = "Minimum salary cannot be greater than maximum salary"
            showingValidationError = true
            return false
        }
        
        return true
    }
    
    private func parseSalary(_ salaryString: String) -> Int? {
        guard !salaryString.isEmpty else { return nil }
        return Int(salaryString)
    }
    
    // MARK: - Computed Properties
    
    private var hasSearchCriteria: Bool {
        return !keywords.isEmpty ||
               !location.isEmpty ||
               !department.isEmpty ||
               !salaryMin.isEmpty ||
               !salaryMax.isEmpty
    }
    
    private var searchCriteriaPreview: String {
        var components: [String] = []
        
        if !keywords.isEmpty {
            components.append("Keywords: \(keywords)")
        }
        
        if !location.isEmpty {
            components.append("Location: \(location)")
        }
        
        if !department.isEmpty {
            components.append("Department: \(department)")
        }
        
        if !salaryMin.isEmpty || !salaryMax.isEmpty {
            let min = parseSalary(salaryMin)
            let max = parseSalary(salaryMax)
            
            switch (min, max) {
            case (let minVal?, let maxVal?):
                components.append("Salary: $\(minVal.formatted()) - $\(maxVal.formatted())")
            case (let minVal?, nil):
                components.append("Salary: $\(minVal.formatted())+")
            case (nil, let maxVal?):
                components.append("Salary: Up to $\(maxVal.formatted())")
            default:
                break
            }
        }
        
        return components.isEmpty ? "All jobs" : components.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview("Create New Search") {
    SavedSearchEditSheet(
        viewModel: SavedSearchViewModel(
            persistenceService: SavedSearchEditPreviewMockDataPersistenceService(),
            apiService: SavedSearchEditPreviewMockUSAJobsAPIService(),
            notificationService: SavedSearchEditPreviewMockNotificationService()
        ),
        savedSearch: nil
    )
}

#Preview("Edit Existing Search") {
    let mockSearch = SavedSearch(context: CoreDataStack.shared.context, name: "Software Developer Jobs")
    mockSearch.keywords = "software developer"
    mockSearch.location = "Washington, DC"
    mockSearch.salaryMin = 80000
    mockSearch.salaryMax = 120000
    mockSearch.isNotificationEnabled = true

    return SavedSearchEditSheet(
        viewModel: SavedSearchViewModel(
            persistenceService: SavedSearchEditPreviewMockDataPersistenceService(),
            apiService: SavedSearchEditPreviewMockUSAJobsAPIService(),
            notificationService: SavedSearchEditPreviewMockNotificationService()
        ),
        savedSearch: mockSearch
    )
}

// MARK: - Mock Services for Preview

private class SavedSearchEditPreviewMockUSAJobsAPIService: USAJobsAPIServiceProtocol {
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

private class SavedSearchEditPreviewMockDataPersistenceService: DataPersistenceServiceProtocol {
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

private class SavedSearchEditPreviewMockNotificationService: NotificationServiceProtocol {
    func requestNotificationPermissions() async throws -> Bool { return true }
    func scheduleDeadlineReminder(for application: ApplicationTracking) async throws {}
    func scheduleNewJobsNotification(for search: SavedSearch, jobCount: Int) async throws {}
    func cancelDeadlineReminder(for jobId: String) async {}
    func cancelNewJobsNotification(for searchId: UUID) async {}
    func cancelAllNotifications() async {}
    func getNotificationSettings() async -> UNNotificationSettings {
        return await UNUserNotificationCenter.current().notificationSettings()
    }
    func handleNotificationResponse(_ response: UNNotificationResponse) async {}
    func handleBackgroundAppRefresh() async -> Bool { return true }
}