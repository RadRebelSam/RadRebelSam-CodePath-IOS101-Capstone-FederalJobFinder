//
//  FilterView.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import SwiftUI

struct FilterView: View {
    @Binding var searchCriteria: SearchCriteria
    let onApplyFilters: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // Local state for form inputs
    @State private var keyword: String = ""
    @State private var location: String = ""
    @State private var selectedDepartment: String = ""
    @State private var salaryMin: String = ""
    @State private var salaryMax: String = ""
    @State private var remoteOnly: Bool = false
    
    // Department options
    private let departments = [
        "",
        "Department of Agriculture",
        "Department of Commerce", 
        "Department of Defense",
        "Department of Education",
        "Department of Energy",
        "Department of Health and Human Services",
        "Department of Homeland Security",
        "Department of Housing and Urban Development",
        "Department of Justice",
        "Department of Labor",
        "Department of State",
        "Department of Transportation",
        "Department of Treasury",
        "Department of Veterans Affairs",
        "Environmental Protection Agency",
        "General Services Administration",
        "National Aeronautics and Space Administration",
        "Social Security Administration"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                keywordSection
                locationSection
                departmentSection
                salarySection
                workArrangementSection
            }
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .dynamicTypeSize(.xSmall ... .accessibility5)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibleButton(
                        label: "Cancel",
                        hint: "Discards filter changes and closes the filter screen"
                    )
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyFilters()
                    }
                    .fontWeight(.semibold)
                    .accessibleButton(
                        label: "Apply filters",
                        hint: "Saves the filter settings and performs a new search"
                    )
                }
            }
            .onAppear {
                loadCurrentCriteria()
            }
        }
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Form Sections
    
    private var keywordSection: some View {
        Section {
            TextField("Enter keywords, job title, or skills", text: $keyword)
                .accessibleFormField(
                    label: "Job keywords",
                    hint: "Enter specific job titles, skills, or keywords to search for in job descriptions",
                    value: keyword.isEmpty ? nil : keyword
                )
                .dynamicTypeSize(.xSmall ... .accessibility3)
        } header: {
            Text("Keywords")
                .accessibleText(traits: .isHeader)
        } footer: {
            Text("Search for specific job titles, skills, or keywords in job descriptions.")
                .font(.caption)
                .accessibleText()
                .dynamicTypeSize(.xSmall ... .accessibility2)
        }
    }
    
    private var locationSection: some View {
        Section {
            TextField("City, State, or ZIP code", text: $location)
                .accessibleFormField(
                    label: "Location",
                    hint: "Enter a city, state, or ZIP code. Leave blank to search all locations",
                    value: location.isEmpty ? nil : location
                )
                .dynamicTypeSize(.xSmall ... .accessibility3)
        } header: {
            Text("Location")
                .accessibleText(traits: .isHeader)
        } footer: {
            Text("Enter a city, state, or ZIP code. Leave blank to search all locations.")
                .font(.caption)
                .accessibleText()
                .dynamicTypeSize(.xSmall ... .accessibility2)
        }
    }
    
    private var departmentSection: some View {
        Section {
            Picker("Department", selection: $selectedDepartment) {
                ForEach(departments, id: \.self) { department in
                    Text(department.isEmpty ? "All Departments" : department)
                        .tag(department)
                        .dynamicTypeSize(.xSmall ... .accessibility3)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Department selection")
            .accessibilityHint("Choose a specific government department or agency to filter jobs")
            .accessibilityValue(selectedDepartment.isEmpty ? "All Departments" : selectedDepartment)
        } header: {
            Text("Department")
                .accessibleText(traits: .isHeader)
        } footer: {
            Text("Filter jobs by specific government department or agency.")
                .font(.caption)
                .accessibleText()
                .dynamicTypeSize(.xSmall ... .accessibility2)
        }
    }
    
    private var salarySection: some View {
        Section {
            HStack {
                TextField("Min", text: $salaryMin)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibleFormField(
                        label: "Minimum salary",
                        hint: "Enter the minimum annual salary in dollars",
                        value: salaryMin.isEmpty ? nil : salaryMin
                    )
                    .dynamicTypeSize(.xSmall ... .accessibility3)
                
                Text("to")
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                
                TextField("Max", text: $salaryMax)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibleFormField(
                        label: "Maximum salary",
                        hint: "Enter the maximum annual salary in dollars",
                        value: salaryMax.isEmpty ? nil : salaryMax
                    )
                    .dynamicTypeSize(.xSmall ... .accessibility3)
            }
            
            // Salary Range Presets
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Salary Ranges")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibleText(traits: .isHeader)
                    .dynamicTypeSize(.xSmall ... .accessibility2)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    SalaryPresetButton(title: "$40K - $60K", min: 40000, max: 60000) {
                        setSalaryRange(min: 40000, max: 60000)
                    }
                    
                    SalaryPresetButton(title: "$60K - $80K", min: 60000, max: 80000) {
                        setSalaryRange(min: 60000, max: 80000)
                    }
                    
                    SalaryPresetButton(title: "$80K - $100K", min: 80000, max: 100000) {
                        setSalaryRange(min: 80000, max: 100000)
                    }
                    
                    SalaryPresetButton(title: "$100K+", min: 100000, max: nil) {
                        setSalaryRange(min: 100000, max: nil)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Quick salary range selection buttons")
            }
        } header: {
            Text("Salary Range")
                .accessibleText(traits: .isHeader)
        } footer: {
            Text("Enter annual salary range in dollars. Leave blank for any salary.")
                .font(.caption)
                .accessibleText()
                .dynamicTypeSize(.xSmall ... .accessibility2)
        }
    }
    
    private var workArrangementSection: some View {
        Section {
            Toggle("Remote work eligible", isOn: $remoteOnly)
                .accessibilityLabel("Remote work filter")
                .accessibilityHint("When enabled, shows only jobs that offer remote work or telework options")
                .accessibilityValue(remoteOnly ? "Enabled" : "Disabled")
                .dynamicTypeSize(.xSmall ... .accessibility3)
        } header: {
            Text("Work Arrangement")
                .accessibleText(traits: .isHeader)
        } footer: {
            Text("Show only positions that offer remote work or telework options.")
                .font(.caption)
                .accessibleText()
                .dynamicTypeSize(.xSmall ... .accessibility2)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentCriteria() {
        keyword = searchCriteria.keyword ?? ""
        location = searchCriteria.location ?? ""
        selectedDepartment = searchCriteria.department ?? ""
        salaryMin = searchCriteria.salaryMin?.description ?? ""
        salaryMax = searchCriteria.salaryMax?.description ?? ""
        remoteOnly = searchCriteria.remoteOnly
    }
    
    private func applyFilters() {
        let newCriteria = SearchCriteria(
            keyword: keyword.isEmpty ? nil : keyword,
            location: location.isEmpty ? nil : location,
            department: selectedDepartment.isEmpty ? nil : selectedDepartment,
            salaryMin: Int(salaryMin),
            salaryMax: Int(salaryMax),
            page: 1,
            resultsPerPage: searchCriteria.resultsPerPage,
            remoteOnly: remoteOnly
        )
        
        searchCriteria = newCriteria
        onApplyFilters()
        dismiss()
    }
    
    private func setSalaryRange(min: Int, max: Int?) {
        salaryMin = String(min)
        salaryMax = max?.description ?? ""
    }
}

// MARK: - Salary Preset Button

struct SalaryPresetButton: View {
    let title: String
    let min: Int
    let max: Int?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
                .dynamicTypeSize(.xSmall ... .accessibility2)
        }
        .accessibleButton(
            label: "Set salary range to \(title)",
            hint: "Automatically fills in the salary range fields with this preset"
        )
        .accessibleTouchTarget()
    }
}

// MARK: - Preview

#Preview {
    FilterView(
        searchCriteria: .constant(SearchCriteria()),
        onApplyFilters: {}
    )
}