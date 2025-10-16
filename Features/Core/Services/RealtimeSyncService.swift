//
//  RealtimeSyncService.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import SwiftData
import FirebaseFirestore
import Observation

@MainActor
@Observable
final class RealtimeSyncService {
    static let shared = RealtimeSyncService()
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    // Sync status
    var isSyncing = false
    var lastSyncTime: Date?
    var syncError: Error?
    
    private init() {
        // Enable offline persistence
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        db.settings = settings
        
        ErrorLoggingService.shared.logInfo(
            "Real-time sync service initialized",
            context: "Sync"
        )
    }
    
    // MARK: - Start/Stop Sync
    
    /// Start syncing for a user
    func startSync(for userID: String, modelContext: ModelContext) {
        stopSync() // Clear any existing listeners
        
        ErrorLoggingService.shared.logInfo(
            "Starting real-time sync for user: \(userID)",
            context: "Sync"
        )
        
        // Listen to collections
        listenToCollections(userID: userID, modelContext: modelContext)
        
        // Listen to activity feed
        listenToActivity(userID: userID, modelContext: modelContext)
        
        lastSyncTime = Date()
    }
    
    /// Stop all sync listeners
    func stopSync() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        
        ErrorLoggingService.shared.logInfo(
            "Stopped real-time sync",
            context: "Sync"
        )
    }
    
    // MARK: - Collection Sync
    
    private func listenToCollections(userID: String, modelContext: ModelContext) {
        isSyncing = true
        
        let listener = db.collection("users")
            .document(userID)
            .collection("collections")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        self.handleSyncError(error)
                        return
                    }
                    
                    guard let snapshot = snapshot else { return }
                    
                    // Process document changes
                    for change in snapshot.documentChanges {
                        switch change.type {
                        case .added:
                            await self.handleCollectionAdded(change.document, modelContext: modelContext)
                        case .modified:
                            await self.handleCollectionModified(change.document, modelContext: modelContext)
                        case .removed:
                            await self.handleCollectionRemoved(change.document, modelContext: modelContext)
                        }
                    }
                    
                    self.isSyncing = false
                    self.lastSyncTime = Date()
                    
                    ErrorLoggingService.shared.logInfo(
                        "Collections synced: \(snapshot.documents.count) collections",
                        context: "Sync"
                    )
                }
            }
        
        listeners.append(listener)
    }
    
    private func handleCollectionAdded(_ document: DocumentSnapshot, modelContext: ModelContext) async {
        guard let data = document.data() else { return }
        
        // Check if collection already exists locally
        let collectionID = document.documentID
        let descriptor = FetchDescriptor<CollectionModel>(
            predicate: #Predicate { $0.id.uuidString == collectionID }
        )
        
        let existing = try? modelContext.fetch(descriptor)
        if existing?.isEmpty == false {
            return // Already exists
        }
        
        // Create new collection from Firestore data
        do {
            let collection = try CollectionModel.fromFirestore(data, id: collectionID)
            modelContext.insert(collection)
            try modelContext.save()
            
            ErrorLoggingService.shared.logInfo(
                "Added collection from sync: \(collection.title)",
                context: "Sync"
            )
            
            // Listen to items in this collection
            listenToItems(
                userID: data["userID"] as? String ?? "",
                collectionID: collectionID,
                modelContext: modelContext
            )
        } catch {
            ErrorLoggingService.shared.logError(
                error,
                context: "Sync - Add collection"
            )
        }
    }
    
    private func handleCollectionModified(_ document: DocumentSnapshot, modelContext: ModelContext) async {
        guard let data = document.data() else { return }
        
        let collectionID = document.documentID
        let descriptor = FetchDescriptor<CollectionModel>(
            predicate: #Predicate { $0.id.uuidString == collectionID }
        )
        
        guard let collections = try? modelContext.fetch(descriptor),
              let collection = collections.first else {
            return
        }
        
        // Update collection from Firestore data
        collection.updateFromFirestore(data)
        try? modelContext.save()
        
        ErrorLoggingService.shared.logInfo(
            "Updated collection from sync: \(collection.title)",
            context: "Sync"
        )
    }
    
    private func handleCollectionRemoved(_ document: DocumentSnapshot, modelContext: ModelContext) async {
        let collectionID = document.documentID
        let descriptor = FetchDescriptor<CollectionModel>(
            predicate: #Predicate { $0.id.uuidString == collectionID }
        )
        
        guard let collections = try? modelContext.fetch(descriptor),
              let collection = collections.first else {
            return
        }
        
        modelContext.delete(collection)
        try? modelContext.save()
        
        ErrorLoggingService.shared.logInfo(
            "Deleted collection from sync: \(collectionID)",
            context: "Sync"
        )
    }
    
    // MARK: - Item Sync
    
    private func listenToItems(userID: String, collectionID: String, modelContext: ModelContext) {
        let listener = db.collection("users")
            .document(userID)
            .collection("collections")
            .document(collectionID)
            .collection("items")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        self.handleSyncError(error)
                        return
                    }
                    
                    guard let snapshot = snapshot else { return }
                    
                    // Process item changes
                    for change in snapshot.documentChanges {
                        switch change.type {
                        case .added:
                            await self.handleItemAdded(
                                change.document,
                                collectionID: collectionID,
                                modelContext: modelContext
                            )
                        case .modified:
                            await self.handleItemModified(
                                change.document,
                                modelContext: modelContext
                            )
                        case .removed:
                            await self.handleItemRemoved(
                                change.document,
                                modelContext: modelContext
                            )
                        }
                    }
                    
                    ErrorLoggingService.shared.logInfo(
                        "Items synced for collection: \(collectionID)",
                        context: "Sync"
                    )
                }
            }
        
        listeners.append(listener)
    }
    
    private func handleItemAdded(_ document: DocumentSnapshot, collectionID: String, modelContext: ModelContext) async {
        guard let data = document.data() else { return }
        
        let itemID = document.documentID
        let descriptor = FetchDescriptor<CollectionItem>(
            predicate: #Predicate { $0.id.uuidString == itemID }
        )
        
        let existing = try? modelContext.fetch(descriptor)
        if existing?.isEmpty == false {
            return // Already exists
        }
        
        // Find the collection
        let collectionDescriptor = FetchDescriptor<CollectionModel>(
            predicate: #Predicate { $0.id.uuidString == collectionID }
        )
        
        guard let collections = try? modelContext.fetch(collectionDescriptor),
              let collection = collections.first else {
            return
        }
        
        // Create new item
        do {
            let item = try CollectionItem.fromFirestore(data, id: itemID, collection: collection)
            collection.items?.append(item)
            modelContext.insert(item)
            try modelContext.save()
            
            ErrorLoggingService.shared.logInfo(
                "Added item from sync: \(item.name)",
                context: "Sync"
            )
        } catch {
            ErrorLoggingService.shared.logError(
                error,
                context: "Sync - Add item"
            )
        }
    }
    
    private func handleItemModified(_ document: DocumentSnapshot, modelContext: ModelContext) async {
        guard let data = document.data() else { return }
        
        let itemID = document.documentID
        let descriptor = FetchDescriptor<CollectionItem>(
            predicate: #Predicate { $0.id.uuidString == itemID }
        )
        
        guard let items = try? modelContext.fetch(descriptor),
              let item = items.first else {
            return
        }
        
        item.updateFromFirestore(data)
        try? modelContext.save()
        
        ErrorLoggingService.shared.logInfo(
            "Updated item from sync: \(item.name)",
            context: "Sync"
        )
    }
    
    private func handleItemRemoved(_ document: DocumentSnapshot, modelContext: ModelContext) async {
        let itemID = document.documentID
        let descriptor = FetchDescriptor<CollectionItem>(
            predicate: #Predicate { $0.id.uuidString == itemID }
        )
        
        guard let items = try? modelContext.fetch(descriptor),
              let item = items.first else {
            return
        }
        
        modelContext.delete(item)
        try? modelContext.save()
        
        ErrorLoggingService.shared.logInfo(
            "Deleted item from sync: \(itemID)",
            context: "Sync"
        )
    }
    
    // MARK: - Activity Feed Sync
    
    private func listenToActivity(userID: String, modelContext: ModelContext) {
        let listener = db.collection("users")
            .document(userID)
            .collection("activity")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        self.handleSyncError(error)
                        return
                    }
                    
                    guard let snapshot = snapshot else { return }
                    
                    for change in snapshot.documentChanges {
                        if change.type == .added {
                            await self.handleActivityAdded(
                                change.document,
                                modelContext: modelContext
                            )
                        }
                    }
                    
                    ErrorLoggingService.shared.logInfo(
                        "Activity feed synced: \(snapshot.documents.count) items",
                        context: "Sync"
                    )
                }
            }
        
        listeners.append(listener)
    }
    
    private func handleActivityAdded(_ document: DocumentSnapshot, modelContext: ModelContext) async {
        guard let data = document.data() else { return }
        
        let activityID = document.documentID
        let descriptor = FetchDescriptor<ActivityItem>(
            predicate: #Predicate { $0.id.uuidString == activityID }
        )
        
        let existing = try? modelContext.fetch(descriptor)
        if existing?.isEmpty == false {
            return
        }
        
        do {
            let activity = try ActivityItem.fromFirestore(data, id: activityID)
            modelContext.insert(activity)
            try modelContext.save()
            
            ErrorLoggingService.shared.logInfo(
                "Added activity from sync",
                context: "Sync"
            )
        } catch {
            ErrorLoggingService.shared.logError(
                error,
                context: "Sync - Add activity"
            )
        }
    }
    
    // MARK: - Error Handling
    
    private func handleSyncError(_ error: Error) {
        syncError = error
        isSyncing = false
        
        ErrorLoggingService.shared.logError(
            error,
            context: "Real-time Sync"
        )
    }
    
    // MARK: - Manual Sync
    
    /// Force a manual sync
    func forceSync(for userID: String, modelContext: ModelContext) async {
        ErrorLoggingService.shared.logInfo(
            "Force sync requested",
            context: "Sync"
        )
        
        // Stop and restart listeners
        stopSync()
        startSync(for: userID, modelContext: modelContext)
    }
}

// MARK: - Sync Status

enum SyncStatus {
    case synced
    case syncing
    case offline
    case error(Error)
    
    var description: String {
        switch self {
        case .synced:
            return "All changes synced"
        case .syncing:
            return "Syncing..."
        case .offline:
            return "Offline - changes will sync when online"
        case .error:
            return "Sync error - tap to retry"
        }
    }
    
    var icon: String {
        switch self {
        case .synced:
            return "checkmark.icloud"
        case .syncing:
            return "arrow.triangle.2.circlepath.icloud"
        case .offline:
            return "icloud.slash"
        case .error:
            return "exclamationmark.icloud"
        }
    }
}
