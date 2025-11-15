//
//  DeepLinkManager.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation

/// Manager for handling deep link URL generation and parsing
struct DeepLinkManager {
    
    // MARK: - Constants
    
    static let scheme = "federaljobfinder"
    
    enum Host: String, CaseIterable {
        case job = "job"
        case search = "search"
        case favorites = "favorites"
        case saved = "saved"
        case applications = "applications"
    }
    
    // MARK: - URL Generation
    
    /// Generate a deep link URL for a specific job
    /// - Parameter jobId: The job ID to link to
    /// - Returns: Deep link URL for the job
    static func jobURL(jobId: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = Host.job.rawValue
        components.path = "/\(jobId)"
        return components.url
    }
    
    /// Generate a deep link URL for a specific tab
    /// - Parameter tab: The tab to link to
    /// - Returns: Deep link URL for the tab
    static func tabURL(tab: Tab) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        
        switch tab {
        case .search:
            components.host = Host.search.rawValue
        case .favorites:
            components.host = Host.favorites.rawValue
        case .saved:
            components.host = Host.saved.rawValue
        case .applications:
            components.host = Host.applications.rawValue
        }
        
        return components.url
    }
    
    // MARK: - URL Parsing
    
    /// Parse a deep link URL to extract the target
    /// - Parameter url: The URL to parse
    /// - Returns: Deep link target information
    static func parseURL(_ url: URL) -> DeepLinkTarget? {
        guard url.scheme == scheme else { return nil }
        
        switch url.host {
        case Host.job.rawValue:
            if let jobId = url.pathComponents.dropFirst().first {
                return .job(jobId: jobId)
            }
        case Host.search.rawValue:
            return .tab(.search)
        case Host.favorites.rawValue:
            return .tab(.favorites)
        case Host.saved.rawValue:
            return .tab(.saved)
        case Host.applications.rawValue:
            return .tab(.applications)
        default:
            break
        }
        
        return nil
    }
    
    // MARK: - Share URL Generation
    
    /// Generate a shareable URL for a job (external USAJobs link)
    /// - Parameter jobId: The job ID
    /// - Returns: USAJobs URL for sharing
    static func shareableJobURL(jobId: String) -> URL? {
        return URL(string: "https://www.usajobs.gov/job/\(jobId)")
    }
}

// MARK: - Deep Link Target

enum DeepLinkTarget {
    case job(jobId: String)
    case tab(Tab)
}

// MARK: - Deep Link Job Item

struct DeepLinkJobItem: Identifiable {
    let id = UUID()
    let jobId: String
}

// MARK: - Extensions

extension Tab {
    /// Convert tab to deep link host
    var deepLinkHost: DeepLinkManager.Host {
        switch self {
        case .search: return .search
        case .favorites: return .favorites
        case .saved: return .saved
        case .applications: return .applications
        }
    }
}