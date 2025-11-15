//
//  validate_offline_functionality.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation

/// Validation script for offline functionality
struct OfflineValidator {
    
    static func main() {
        print("📱 Validating Offline Functionality...")
        
        var allTestsPassed = true
        
        // Test 1: Offline Data Manager
        print("\n1. Testing Offline Data Manager...")
        if validateOfflineDataManager() {
            print("✅ Offline data manager validation passed")
        } else {
            print("❌ Offline data manager validation failed")
            allTestsPassed = false
        }
        
        // Test 2: Network Monitor
        print("\n2. Testing Network Monitor...")
        if validateNetworkMonitor() {
            print("✅ Network monitor validation passed")
        } else {
            print("❌ Network monitor validation failed")
            allTestsPassed = false
        }
        
        // Test 3: Offline Status View
        print("\n3. Testing Offline Status View...")
        if validateOfflineStatusView() {
            print("✅ Offline status view validation passed")
        } else {
            print("❌ Offline status view validation failed")
            allTestsPassed = false
        }
        
        // Test 4: Data Caching
        print("\n4. Testing Data Caching...")
        if validateDataCaching() {
            print("✅ Data caching validation passed")
        } else {
            print("❌ Data caching validation failed")
            allTestsPassed = false
        }
        
        // Test 5: Offline Tests
        print("\n5. Testing Offline Tests...")
        if validateOfflineTests() {
            print("✅ Offline tests validation passed")
        } else {
            print("❌ Offline tests validation failed")
            allTestsPassed = false
        }
        
        // Test 6: Sync Functionality
        print("\n6. Testing Sync Functionality...")
        if validateSyncFunctionality() {
            print("✅ Sync functionality validation passed")
        } else {
            print("❌ Sync functionality validation failed")
            allTestsPassed = false
        }
        
        // Final Results
        print("\n" + String(repeating: "=", count: 50))
        if allTestsPassed {
            print("🎉 All offline functionality validation tests passed!")
            exit(0)
        } else {
            print("💥 Some offline functionality validation tests failed!")
            exit(1)
        }
    }
    
    // MARK: - Validation Methods
    
    static func validateOfflineDataManager() -> Bool {
        let offlineManagerFile = "usajobs/Services/OfflineDataManager.swift"
        
        guard let content = readFile(offlineManagerFile) else {
            print("   ❌ OfflineDataManager.swift not found")
            return false
        }
        
        let requiredMethods = [
            "getCachedJobs",
            "cacheJobsForOfflineAccess",
            "syncWhenOnline",
            "clearExpiredCache"
        ]
        
        for method in requiredMethods {
            if !content.contains(method) {
                print("   ❌ Missing offline manager method: \(method)")
                return false
            }
        }
        
        print("   ✅ All required offline manager methods found")
        return true
    }
    
    static func validateNetworkMonitor() -> Bool {
        let networkMonitorFile = "usajobs/Services/NetworkMonitor.swift"
        
        guard let content = readFile(networkMonitorFile) else {
            print("   ❌ NetworkMonitor.swift not found")
            return false
        }
        
        let requiredProperties = [
            "isConnected",
            "connectionType"
        ]
        
        for property in requiredProperties {
            if !content.contains(property) {
                print("   ❌ Missing network monitor property: \(property)")
                return false
            }
        }
        
        if content.contains("NWPathMonitor") || content.contains("Reachability") {
            print("   ✅ Network monitoring implementation found")
            return true
        } else {
            print("   ❌ Network monitoring implementation not found")
            return false
        }
    }
    
    static func validateOfflineStatusView() -> Bool {
        let offlineStatusFile = "usajobs/Views/OfflineStatusView.swift"
        
        guard let content = readFile(offlineStatusFile) else {
            print("   ❌ OfflineStatusView.swift not found")
            return false
        }
        
        if content.contains("struct OfflineStatusView") && content.contains("View") {
            print("   ✅ Offline status view implementation found")
            return true
        } else {
            print("   ❌ Offline status view implementation not found")
            return false
        }
    }
    
    static func validateDataCaching() -> Bool {
        let persistenceServiceFile = "usajobs/Services/DataPersistenceService.swift"
        
        guard let content = readFile(persistenceServiceFile) else {
            print("   ❌ DataPersistenceService.swift not found")
            return false
        }
        
        let requiredMethods = [
            "cacheJob",
            "getCachedJob",
            "clearExpiredCache"
        ]
        
        for method in requiredMethods {
            if !content.contains(method) {
                print("   ❌ Missing caching method: \(method)")
                return false
            }
        }
        
        print("   ✅ All required caching methods found")
        return true
    }
    
    static func validateOfflineTests() -> Bool {
        let offlineTestsFile = "usajobs/Tests/OfflineDataManagerTests.swift"
        
        guard let content = readFile(offlineTestsFile) else {
            print("   ❌ OfflineDataManagerTests.swift not found")
            return false
        }
        
        let requiredTests = [
            "testCacheJobsForOfflineAccess",
            "testGetCachedJobs",
            "testSyncWhenOnline",
            "testClearExpiredCache"
        ]
        
        for test in requiredTests {
            if !content.contains(test) {
                print("   ❌ Missing offline test: \(test)")
                return false
            }
        }
        
        print("   ✅ All required offline tests found")
        return true
    }
    
    static func validateSyncFunctionality() -> Bool {
        let integrationTestsFile = "usajobs/Tests/IntegrationTests.swift"
        
        guard let content = readFile(integrationTestsFile) else {
            print("   ❌ IntegrationTests.swift not found")
            return false
        }
        
        if content.contains("testOfflineWorkflow") && content.contains("syncWhenOnline") {
            print("   ✅ Sync functionality validation found")
            return true
        } else {
            print("   ❌ Sync functionality validation not found")
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
// Call OfflineValidator.main() to run validation