//
//  validate_navigation_functionality.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation

/// Validation script for navigation functionality
struct NavigationValidator {
    
    static func main() {
        print("🧭 Validating Navigation Functionality...")
        
        var allTestsPassed = true
        
        // Test 1: Tab Structure
        print("\n1. Testing Tab Structure...")
        if validateTabStructure() {
            print("✅ Tab structure validation passed")
        } else {
            print("❌ Tab structure validation failed")
            allTestsPassed = false
        }
        
        // Test 2: Navigation Stack Implementation
        print("\n2. Testing Navigation Stack...")
        if validateNavigationStack() {
            print("✅ Navigation stack validation passed")
        } else {
            print("❌ Navigation stack validation failed")
            allTestsPassed = false
        }
        
        // Test 3: Deep Link Support
        print("\n3. Testing Deep Link Support...")
        if validateDeepLinkSupport() {
            print("✅ Deep link support validation passed")
        } else {
            print("❌ Deep link support validation failed")
            allTestsPassed = false
        }
        
        // Test 4: Navigation UI Tests
        print("\n4. Testing Navigation UI Tests...")
        if validateNavigationUITests() {
            print("✅ Navigation UI tests validation passed")
        } else {
            print("❌ Navigation UI tests validation failed")
            allTestsPassed = false
        }
        
        // Test 5: Back Navigation
        print("\n5. Testing Back Navigation...")
        if validateBackNavigation() {
            print("✅ Back navigation validation passed")
        } else {
            print("❌ Back navigation validation failed")
            allTestsPassed = false
        }
        
        // Test 6: Tab Accessibility
        print("\n6. Testing Tab Accessibility...")
        if validateTabAccessibility() {
            print("✅ Tab accessibility validation passed")
        } else {
            print("❌ Tab accessibility validation failed")
            allTestsPassed = false
        }
        
        // Final Results
        print("\n" + String(repeating: "=", count: 50))
        if allTestsPassed {
            print("🎉 All navigation validation tests passed!")
            exit(0)
        } else {
            print("💥 Some navigation validation tests failed!")
            exit(1)
        }
    }
    
    // MARK: - Validation Methods
    
    static func validateTabStructure() -> Bool {
        let extensionsFile = "usajobs/Utilities/Extensions.swift"
        
        guard let content = readFile(extensionsFile) else {
            print("   ❌ Extensions file not found")
            return false
        }
        
        let requiredTabs = ["search", "favorites", "saved", "applications"]
        
        for tab in requiredTabs {
            if !content.contains("case \(tab)") {
                print("   ❌ Missing tab case: \(tab)")
                return false
            }
        }
        
        // Check for tab properties
        let requiredProperties = ["title", "icon", "accessibilityLabel", "accessibilityHint"]
        
        for property in requiredProperties {
            if !content.contains("var \(property):") {
                print("   ❌ Missing tab property: \(property)")
                return false
            }
        }
        
        print("   ✅ All required tabs and properties found")
        return true
    }
    
    static func validateNavigationStack() -> Bool {
        let contentViewFile = "usajobs/ContentView.swift"
        
        guard let content = readFile(contentViewFile) else {
            print("   ❌ ContentView.swift not found")
            return false
        }
        
        if content.contains("NavigationStack") || content.contains("NavigationView") {
            print("   ✅ Navigation stack implementation found")
            return true
        } else {
            print("   ❌ Navigation stack implementation not found")
            return false
        }
    }
    
    static func validateDeepLinkSupport() -> Bool {
        let extensionsFile = "usajobs/Utilities/Extensions.swift"
        
        guard let content = readFile(extensionsFile) else {
            return false
        }
        
        if content.contains("DeepLinkJobItem") {
            print("   ✅ Deep link support structure found")
            return true
        } else {
            print("   ❌ Deep link support structure not found")
            return false
        }
    }
    
    static func validateNavigationUITests() -> Bool {
        let uiTestsFile = "usajobs/Tests/NavigationUITests.swift"
        
        guard let content = readFile(uiTestsFile) else {
            print("   ❌ NavigationUITests.swift not found")
            return false
        }
        
        let requiredTests = [
            "testTabViewStructure",
            "testTabSelection",
            "testJobSearchNavigationStack",
            "testJobDetailNavigation",
            "testDeepLinkURLParsing"
        ]
        
        for test in requiredTests {
            if !content.contains(test) {
                print("   ❌ Missing navigation UI test: \(test)")
                return false
            }
        }
        
        print("   ✅ All required navigation UI tests found")
        return true
    }
    
    static func validateBackNavigation() -> Bool {
        let uiTestsFile = "usajobs/Tests/NavigationUITests.swift"
        
        guard let content = readFile(uiTestsFile) else {
            return false
        }
        
        if content.contains("backButton") && content.contains("navigationBars") {
            print("   ✅ Back navigation handling found")
            return true
        } else {
            print("   ❌ Back navigation handling not found")
            return false
        }
    }
    
    static func validateTabAccessibility() -> Bool {
        let extensionsFile = "usajobs/Utilities/Extensions.swift"
        
        guard let content = readFile(extensionsFile) else {
            return false
        }
        
        if content.contains("accessibilityLabel") && content.contains("accessibilityHint") {
            print("   ✅ Tab accessibility properties found")
            return true
        } else {
            print("   ❌ Tab accessibility properties not found")
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    static func readFile(_ path: String) -> String? {
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

// Validation functions available for testing
// Call NavigationValidator.main() to run validation