//
//  OfflineManager.swift
//  stashd
//
//  Created by Sean Lynch on 10/16/25.
//


//
//  OfflineManager.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import Network
import Observation
import SwiftData

@MainActor
@Observable
final class OfflineManager {
    static let shared = OfflineManager()
    
    // Network status
    var isOnline = true
    var connectionType: ConnectionType = .wifi
    
    // Offline queue
    private var pendingOperations: [PendingOperation] = []
    private let maxQueueSize = 1000
    
    // Network monitor
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.stashd.networkMonitor")
    
    private init() {
        startMonitoring()
    }
    
    // MARK: - Network Monitoring
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }  // ← THIS IS THE FIX
                
                let wasOnline = self.isOnline
                self.isOnline = path.status == .satisfied
                
                // Determine connection type
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .ethernet
                } else {
                    self.connectionType = .none
                }
                
                ErrorLoggingService.shared.logInfo(
                    "Network status changed: \(self.isOnline ? "Online" : "Offline") (\(self.connectionType.rawValue))",
                    context: "Offline Manager"
                )
                
                // If we just came back online, process pending operations
                if !wasOnline && self.isOnline {
                    await self.processPendingOperations()
                }
            }
        }
        
        monitor.start(queue: monitorQueue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    // MARK: - Offline Queue Management
    
    /// Add operation to offline queue
    func queueOperation(_ operation: PendingOperation) {
        // Check if queue is full and remove oldest if needed
        if pendingOperations.count >= maxQueueSize {
            ErrorLoggingService.shared.logInfo(
                "Offline queue full - dropping oldest operation",
                context: "Offline Manager"
            )
            pendingOperations.removeFirst()
        }
        
        pendingOperations.append(operation)
        
        ErrorLoggingService.shared.logInfo(
            "Queued offline operation: \(operation.type.rawValue)",
            context: "Offline Manager"
        )
    }
    
    /// Process all pending operations when back online
    private func processPendingOperations() async {
        guard isOnline && !pendingOperations.isEmpty else { return }
        
        ErrorLoggingService.shared.logInfo(
            "Processing \(pendingOperations.count) pending operations",
            context: "Offline Manager"
        )
        
        let operations = pendingOperations
        pendingOperations.removeAll()
        
        for operation in operations {
            await executeOperation(operation)
        }
        
        ErrorLoggingService.shared.logInfo(
            "Completed processing pending operations",
            context: "Offline Manager"
        )
    }
    
    private func executeOperation(_ operation: PendingOperation) async {
        do {
            switch operation.type {
            case .createCollection:
                // Re-sync collection to Firestore
                if let collectionData = operation.data as? [String: Any] {
                    try await syncCollectionToFirestore(collectionData)
                }
                
            case .updateCollection:
                // Re-sync updated collection
                if let collectionData = operation.data as? [String: Any] {
                    try await syncCollectionToFirestore(collectionData)
                }
                
            case .deleteCollection:
                // Delete from Firestore
                if let collectionID = operation.data as? String {
                    try await deleteCollectionFromFirestore(collectionID)
                }
                
            case .createItem:
                // Re-sync item to Firestore
                if let itemData = operation.data as? [String: Any] {
                    try await syncItemToFirestore(itemData)
                }
                
            case .updateItem:
                // Re-sync updated item
                if let itemData = operation.data as? [String: Any] {
                    try await syncItemToFirestore(itemData)
                }
                
            case .deleteItem:
                // Delete from Firestore
                if let itemID = operation.data as? String {
                    try await deleteItemFromFirestore(itemID)
                }
            }
            
            ErrorLoggingService.shared.logInfo(
                "Executed pending operation: \(operation.type.rawValue)",
                context: "Offline Manager"
            )
            
        } catch {
            ErrorLoggingService.shared.logError(
                error,
                context: "Offline Manager - Execute operation"
            )
            
            // Re-queue if failed
            queueOperation(operation)
        }
    }
    
    // MARK: - Firestore Sync Helpers
    
    private func syncCollectionToFirestore(_ data: [String: Any]) async throws {
        // Implementation will use FirestoreService
        // For now, placeholder
    }
    
    private func deleteCollectionFromFirestore(_ collectionID: String) async throws {
        // Implementation will use FirestoreService
    }
    
    private func syncItemToFirestore(_ data: [String: Any]) async throws {
        // Implementation will use FirestoreService
    }
    
    private func deleteItemFromFirestore(_ itemID: String) async throws {
        // Implementation will use FirestoreService
    }
    
    // MARK: - Status
    
    var statusMessage: String {
        if isOnline {
            return "Connected"
        } else {
            return pendingOperations.isEmpty ? "Offline" : "Offline - \(pendingOperations.count) pending"
        }
    }
    
    var hasPendingOperations: Bool {
        !pendingOperations.isEmpty
    }
}

// MARK: - Models

struct PendingOperation: Codable {
    let id: UUID
    let type: OperationType
    let data: AnyEncodable?
    let timestamp: Date
    
    init(type: OperationType, data: Any? = nil) {
        self.id = UUID()
        self.type = type
        self.data = data.map { AnyEncodable($0) }
        self.timestamp = Date()
    }
}

enum OperationType: String, Codable {
    case createCollection
    case updateCollection
    case deleteCollection
    case createItem
    case updateItem
    case deleteItem
}

enum ConnectionType: String {
    case wifi = "Wi-Fi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case none = "No Connection"
}

// Helper to encode Any type
struct AnyEncodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let dict = value as? [String: Any] {
            let dictData = try JSONSerialization.data(withJSONObject: dict)
            let dictString = String(data: dictData, encoding: .utf8) ?? "{}"
            try container.encode(dictString)
        } else {
            try container.encode("")
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = ""
        }
    }
}
