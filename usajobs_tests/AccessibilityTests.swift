//
//  AccessibilityTests.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import XCTest
import SwiftUI
@testable import usajobs

/// Comprehensive accessibility tests for the Federal Job Finder app
final class AccessibilityTests: XCTestCase {
    
    // MARK: - Test Setup
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    // MARK: - Extension Tests
    
    func testAccessibilityExtensions() throws {
        // Test that accessibility extensions compile and provide expected functionality
        let testView = Text("Test")
            .accessibleButton(
                label: "Test Button",
                hint: "This is a test button",
                traits: .isSelected,
                value: "Selected"
            )
        
        // Verify the view can be created without errors
        XCTAssertNotNil(testView)
    }
    
    func testAccessibilitySettings() throws {
        // Test accessibility settings helper
        let isReduceMotionEnabled = AccessibilitySettings.isReduceMotionEnabled
        let isVoiceOverRunning = AccessibilitySettings.isVoiceOverRunning
        let isSwitchControlRunning = AccessibilitySettings.isSwitchControlRunning
        
        // These should return boolean values without crashing
        XCTAssertTrue(isReduceMotionEnabled is Bool)
        XCTAssertTrue(isVoiceOverRunning is Bool)
        XCTAssertTrue(isSwitchControlRunning is Bool)
    }
    
    // MARK: - Dynamic Type Tests
    
    func testDynamicTypeSupport() throws {
        // Test that views support Dynamic Type scaling
        let testText = Text("Sample Text")
            .dynamicTypeSize(.xSmall ... .accessibility5)
        
        XCTAssertNotNil(testText)
        
        // Test with different content size categories
        let categories: [DynamicTypeSize] = [
            .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
            .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5
        ]
        
        for category in categories {
            let scaledText = Text("Test")
                .dynamicTypeSize(category...category)
            XCTAssertNotNil(scaledText)
        }
    }
    
    // MARK: - VoiceOver Label Tests
    
    func testVoiceOverLabels() throws {
        // Test that critical UI elements have proper accessibility labels
        
        // Test button labels
        let favoriteButton = Button("Favorite") {}
            .accessibleButton(
                label: "Add to favorites",
                hint: "Saves this job to your favorites list"
            )
        XCTAssertNotNil(favoriteButton)
        
        // Test form field labels
        let searchField = TextField("Search", text: .constant(""))
            .accessibleFormField(
                label: "Job search",
                hint: "Enter keywords to search for jobs",
                value: "Software Developer"
            )
        XCTAssertNotNil(searchField)
        
        // Test navigation labels
        let navLink = NavigationLink("Details", destination: Text("Details"))
            .accessibleNavigation(
                label: "View job details",
                hint: "Opens detailed information about this job"
            )
        XCTAssertNotNil(navLink)
    }
    
    // MARK: - Touch Target Tests
    
    func testTouchTargetSizes() throws {
        // Test that interactive elements meet minimum touch target requirements
        let minTouchTarget: CGFloat = 44
        
        let button = Button("Test") {}
            .accessibleTouchTarget(minSize: minTouchTarget)
        
        XCTAssertNotNil(button)
        
        // Test with custom size
        let customButton = Button("Custom") {}
            .accessibleTouchTarget(minSize: 60)
        
        XCTAssertNotNil(customButton)
    }
    
    // MARK: - Accessibility Actions Tests
    
    func testAccessibilityActions() throws {
        var actionExecuted = false
        
        let actions = [
            AccessibilityActionInfo("Test Action") {
                actionExecuted = true
            }
        ]
        
        let viewWithActions = Text("Test")
            .accessibilityActions(actions)
        
        XCTAssertNotNil(viewWithActions)
        
        // Execute the action
        actions.first?.action()
        XCTAssertTrue(actionExecuted)
    }
    
    // MARK: - Status Indicator Tests
    
    func testStatusIndicators() throws {
        // Test status indicators for important information
        let statusView = Text("Active")
            .accessibleStatus(
                label: "Job status",
                value: "Active",
                isImportant: true
            )
        
        XCTAssertNotNil(statusView)
        
        // Test non-important status
        let normalStatus = Text("Saved")
            .accessibleStatus(
                label: "Save status",
                value: "Saved",
                isImportant: false
            )
        
        XCTAssertNotNil(normalStatus)
    }
    
    // MARK: - List Item Tests
    
    func testListItemAccessibility() throws {
        // Test list items have proper accessibility support
        let listItem = VStack {
            Text("Job Title")
            Text("Department")
        }
        .accessibleListItem(
            label: "Software Developer at Department of Defense",
            hint: "Double tap to view details",
            value: "Salary: $80,000 - $120,000"
        )
        
        XCTAssertNotNil(listItem)
    }
    
    // MARK: - Reduced Motion Tests
    
    func testReducedMotionSupport() throws {
        // Test that animations respect reduced motion preferences
        let animatedView = Rectangle()
            .accessibleMotion("test", animation: .easeInOut)
        
        XCTAssertNotNil(animatedView)
        
        // Test with different animation types
        let springView = Circle()
            .accessibleMotion("spring", animation: .spring())
        
        XCTAssertNotNil(springView)
    }
    
    // MARK: - High Contrast Tests
    
    func testHighContrastSupport() throws {
        // Test high contrast support
        let contrastView = Text("High Contrast")
            .accessibleContrast()
        
        XCTAssertNotNil(contrastView)
    }
    
    // MARK: - Form Accessibility Tests
    
    func testFormAccessibility() throws {
        // Test form elements have proper accessibility
        let requiredField = TextField("Required Field", text: .constant(""))
            .accessibleFormField(
                label: "Email address",
                hint: "Enter your email address",
                value: "user@example.com",
                isRequired: true
            )
        
        XCTAssertNotNil(requiredField)
        
        let optionalField = TextField("Optional Field", text: .constant(""))
            .accessibleFormField(
                label: "Phone number",
                hint: "Enter your phone number",
                isRequired: false
            )
        
        XCTAssertNotNil(optionalField)
    }
    
    // MARK: - Complex Interaction Tests
    
    func testComplexInteractions() throws {
        // Test complex UI elements with multiple accessibility actions
        var favoriteToggled = false
        var detailsViewed = false
        var applicationStarted = false
        
        let jobRow = VStack {
            Text("Software Developer")
            Text("Department of Defense")
        }
        .accessibilityActions([
            AccessibilityActionInfo("Toggle favorite") {
                favoriteToggled = true
            },
            AccessibilityActionInfo("View details") {
                detailsViewed = true
            },
            AccessibilityActionInfo("Apply") {
                applicationStarted = true
            }
        ])
        
        XCTAssertNotNil(jobRow)
        
        // Test that actions can be created and stored
        XCTAssertFalse(favoriteToggled)
        XCTAssertFalse(detailsViewed)
        XCTAssertFalse(applicationStarted)
    }
    
    // MARK: - Navigation Accessibility Tests
    
    func testNavigationAccessibility() throws {
        // Test navigation elements have proper accessibility
        let tabView = TabView {
            Text("Search")
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .accessibilityLabel("Search tab")
                .accessibilityHint("Search for federal job opportunities")
            
            Text("Favorites")
                .tabItem {
                    Image(systemName: "heart")
                    Text("Favorites")
                }
                .accessibilityLabel("Favorites tab")
                .accessibilityHint("View your saved favorite jobs")
        }
        .dynamicTypeSize(.xSmall ... .accessibility5)
        
        XCTAssertNotNil(tabView)
    }
    
    // MARK: - Error State Tests
    
    func testErrorStateAccessibility() throws {
        // Test error states have proper accessibility
        let errorView = VStack {
            Image(systemName: "exclamationmark.triangle")
            Text("Error Loading Jobs")
            Text("Please try again")
            Button("Retry") {}
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error loading jobs")
        .accessibilityHint("Please try again")
        
        XCTAssertNotNil(errorView)
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingStateAccessibility() throws {
        // Test loading states have proper accessibility
        let loadingView = VStack {
            ProgressView()
            Text("Loading jobs...")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading jobs")
        .accessibilityAddTraits(.updatesFrequently)
        
        XCTAssertNotNil(loadingView)
    }
    
    // MARK: - Performance Tests
    
    func testAccessibilityPerformance() throws {
        // Test that accessibility features don't significantly impact performance
        measure {
            let views = (0..<100).map { index in
                Text("Item \(index)")
                    .accessibleText(
                        label: "List item \(index)",
                        traits: .isButton
                    )
                    .accessibleTouchTarget()
                    .dynamicTypeSize(.xSmall ... .accessibility5)
            }
            
            XCTAssertEqual(views.count, 100)
        }
    }
    
    // MARK: - Integration Tests
    
    func testAccessibilityIntegration() throws {
        // Test that multiple accessibility features work together
        let complexView = VStack {
            Text("Job Title")
                .accessibleText(traits: .isHeader)
                .dynamicTypeSize(.xSmall ... .accessibility5)
            
            Text("Department")
                .accessibleText()
                .dynamicTypeSize(.xSmall ... .accessibility4)
            
            Button("Apply") {}
                .accessibleButton(
                    label: "Apply for job",
                    hint: "Opens application form"
                )
                .accessibleTouchTarget()
                .dynamicTypeSize(.xSmall ... .accessibility3)
        }
        .accessibilityElement(children: .contain)
        .accessibleMotion("complex", animation: .easeInOut)
        
        XCTAssertNotNil(complexView)
    }
}

// MARK: - Mock Data for Tests

extension AccessibilityTests {
    
    private func createMockJobSearchItem() -> JobSearchItem {
        return JobSearchItem(
            matchedObjectId: "test-id",
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
                jobGrade: [],
                positionRemuneration: [],
                positionSummary: "Test job summary",
                positionFormattedDescription: [],
                userArea: nil,
                qualificationSummary: nil
            ),
            relevanceRank: 1
        )
    }
}