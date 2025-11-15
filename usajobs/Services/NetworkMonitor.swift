//
//  NetworkMonitor.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import Foundation
import Network
import Combine

/// Service for monitoring network connectivity status
@MainActor
class NetworkMonitor: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether the device is currently connected to the internet
    @Published var isConnected = false
    
    /// Whether the device is connected via cellular
    @Published var isExpensive = false
    
    /// Whether the device is connected via WiFi
    @Published var isWiFi = false
    
    /// Current connection type
    @Published var connectionType: ConnectionType = .unknown
    
    // MARK: - Types
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    // MARK: - Private Properties
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // MARK: - Singleton
    
    static let shared = NetworkMonitor()
    
    // MARK: - Initialization
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods

    /// Start monitoring network connectivity
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateConnectionStatus(path)
            }
        }
        monitor.start(queue: queue)
    }

    /// Stop monitoring network connectivity
    nonisolated func stopMonitoring() {
        monitor.cancel()
    }
    
    /// Check if network is available for API calls
    var isNetworkAvailable: Bool {
        return isConnected
    }
    
    /// Check if network is suitable for large downloads
    var isSuitableForLargeDownloads: Bool {
        return isConnected && !isExpensive
    }
    
    // MARK: - Private Methods
    
    private func updateConnectionStatus(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        
        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
            isWiFi = true
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
            isWiFi = false
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
            isWiFi = false
        } else {
            connectionType = .unknown
            isWiFi = false
        }
    }
}

// MARK: - Convenience Methods

extension NetworkMonitor {
    
    /// Get user-friendly connection status text
    var connectionStatusText: String {
        if !isConnected {
            return "No Internet Connection"
        }
        
        switch connectionType {
        case .wifi:
            return "Connected via WiFi"
        case .cellular:
            return "Connected via Cellular"
        case .ethernet:
            return "Connected via Ethernet"
        case .unknown:
            return "Connected"
        }
    }
    
    /// Get connection quality indicator
    var connectionQuality: ConnectionQuality {
        if !isConnected {
            return .none
        } else if isExpensive {
            return .limited
        } else {
            return .good
        }
    }
    
    enum ConnectionQuality {
        case none
        case limited
        case good
        
        var description: String {
            switch self {
            case .none:
                return "No connection"
            case .limited:
                return "Limited connection"
            case .good:
                return "Good connection"
            }
        }
    }
}