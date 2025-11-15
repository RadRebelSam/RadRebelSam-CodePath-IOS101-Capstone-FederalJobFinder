//
//  Extensions.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import SwiftUI
import UIKit

// MARK: - View Extensions

extension View {
    /// Adds accessibility support for buttons with comprehensive labeling
    func accessibleButton(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = .isButton,
        value: String? = nil
    ) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityValue(value ?? "")
    }
    
    /// Adds accessibility support for text elements
    func accessibleText(
        label: String? = nil,
        traits: AccessibilityTraits = .isStaticText
    ) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label ?? "")
            .accessibilityAddTraits(traits)
    }
    
    /// Adds accessibility support for form fields
    func accessibleFormField(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        isRequired: Bool = false
    ) -> some View {
        let accessibilityLabel = isRequired ? "\(label), required" : label
        
        return self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(.isSearchField)
    }
    
    /// Adds accessibility support for navigation elements
    func accessibleNavigation(
        label: String,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isLink)
    }
    
    /// Adds accessibility support for status indicators
    func accessibleStatus(
        label: String,
        value: String,
        isImportant: Bool = false
    ) -> some View {
        var traits: AccessibilityTraits = .isStaticText
        if isImportant {
            traits.insert(.updatesFrequently)
        }
        
        return self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityAddTraits(traits)
    }
    
    /// Adds accessibility support for list items
    func accessibleListItem(
        label: String,
        hint: String? = nil,
        value: String? = nil
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(.isButton)
    }
    
    /// Ensures minimum touch target size for accessibility
    func accessibleTouchTarget(minSize: CGFloat = 44) -> some View {
        self
            .frame(minWidth: minSize, minHeight: minSize)
    }
    
    /// Adds motion-sensitive animation support
    func accessibleMotion<V: Equatable>(
        _ value: V,
        animation: Animation? = .default
    ) -> some View {
        self
            .animation(AccessibilitySettings.isReduceMotionEnabled ? nil : animation, value: value)
    }
    
    /// Adds high contrast support
    func accessibleContrast() -> some View {
        self
            .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}

// MARK: - Accessibility Actions Extension

extension View {
    func accessibilityActions(_ actions: [AccessibilityActionInfo]) -> some View {
        var view = AnyView(self)
        
        for action in actions {
            view = AnyView(
                view.accessibilityAction(named: action.name, action.action)
            )
        }
        
        return view
    }
}

// MARK: - Accessibility Action Info

struct AccessibilityActionInfo {
    let name: String
    let action: () -> Void
    
    init(_ name: String, action: @escaping () -> Void) {
        self.name = name
        self.action = action
    }
}

// MARK: - Accessibility Settings Helper

struct AccessibilitySettings {
    static var isReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
    
    static var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }
    
    static var isSwitchControlRunning: Bool {
        UIAccessibility.isSwitchControlRunning
    }
    
    static var isAssistiveTouchRunning: Bool {
        UIAccessibility.isAssistiveTouchRunning
    }
    
    static var prefersCrossFadeTransitions: Bool {
        UIAccessibility.prefersCrossFadeTransitions
    }
    
    static var isVideoAutoplayEnabled: Bool {
        UIAccessibility.isVideoAutoplayEnabled
    }
}

// MARK: - String Extensions

extension String {
    /// Formats string for accessibility reading
    var accessibilityFormatted: String {
        // Replace common abbreviations with full words for better VoiceOver reading
        return self
            .replacingOccurrences(of: "GS-", with: "Grade ")
            .replacingOccurrences(of: "IT", with: "Information Technology")
            .replacingOccurrences(of: "HR", with: "Human Resources")
            .replacingOccurrences(of: "DOD", with: "Department of Defense")
            .replacingOccurrences(of: "DOJ", with: "Department of Justice")
            .replacingOccurrences(of: "HHS", with: "Department of Health and Human Services")
    }
    
    /// Removes HTML tags for accessibility
    var strippedHTML: String {
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Formats date for accessibility reading
    var accessibilityDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    /// Formats relative date for accessibility
    var accessibilityRelativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Checks if date is within the next week (useful for deadline warnings)
    var isWithinNextWeek: Bool {
        let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
        return self <= nextWeek && self >= Date()
    }
    
    /// Checks if date is in the past
    var isPast: Bool {
        return self < Date()
    }
}

// MARK: - Int Extensions

extension Int {
    /// Formats salary for display
    var salaryFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "$\(self)"
    }
    
    /// Formats number with thousands separator
    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - Color Extensions

extension Color {
    /// High contrast colors for accessibility
    static var accessiblePrimary: Color {
        Color.primary
    }
    
    static var accessibleSecondary: Color {
        Color.secondary
    }
    
    static var accessibleAccent: Color {
        Color.accentColor
    }
    
    /// Creates color with high contrast support
    static func accessible(light: Color, dark: Color) -> Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// MARK: - Array Extensions

extension Array where Element == JobSearchItem {
    /// Filters jobs by accessibility-friendly criteria
    func accessibilityFiltered() -> [JobSearchItem] {
        return self.filter { job in
            // Filter out jobs with very short titles that might be unclear
            job.matchedObjectDescriptor.positionTitle.count > 5
        }
    }
}

// MARK: - Tab Enum

enum Tab: String, CaseIterable {
    case search = "search"
    case favorites = "favorites"
    case saved = "saved"
    case applications = "applications"

    var title: String {
        switch self {
        case .search:
            return "Search"
        case .favorites:
            return "Favorites"
        case .saved:
            return "Saved Searches"
        case .applications:
            return "Applications"
        }
    }

    var icon: String {
        switch self {
        case .search:
            return "magnifyingglass"
        case .favorites:
            return "heart"
        case .saved:
            return "bookmark"
        case .applications:
            return "doc.text"
        }
    }

    var accessibilityLabel: String {
        return "\(title) tab"
    }

    var accessibilityHint: String {
        switch self {
        case .search:
            return "Search for federal job opportunities"
        case .favorites:
            return "View your saved favorite jobs"
        case .saved:
            return "Manage your saved job searches"
        case .applications:
            return "Track your job applications"
        }
    }
}

// MARK: - Service Container
// ServiceContainer is defined in usajobsApp.swift

// MARK: - Error Extensions

extension Error {
    /// User-friendly error message for accessibility
    var accessibilityDescription: String {
        if let apiError = self as? APIError {
            switch apiError {
            case .invalidURL:
                return "Invalid URL configuration. Please contact support."
            case .noData:
                return "No data received. Please try again."
            case .invalidResponse:
                return "Invalid response from server. Please try again later."
            case .decodingError:
                return "Data format error. Please try again later."
            case .networkError:
                return "Network connection error. Please check your internet connection and try again."
            case .rateLimitExceeded:
                return "Too many requests. Please wait a moment and try again."
            case .unauthorized:
                return "Authentication error. Please check your credentials."
            case .serverError:
                return "Server error. Please try again later."
            case .timeout:
                return "Request timed out. Please check your connection and try again."
            case .noInternetConnection:
                return "No internet connection. Please check your network settings."
            }
        }

        return localizedDescription
    }
}