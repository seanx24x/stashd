//
//  DataSyncService.swift
//  stashd
//
//  Created by Sean Lynch on 10/11/25.
//


// File: Core/Services/DataSyncService.swift

import Foundation
import SwiftData

@MainActor
final class DataSyncService {
    static let shared = DataSyncService()
    
    private init() {}
    
    // MARK: - Load User Data from Firestore
    
    func loadUserData(for userProfile: UserProfile, modelContext: ModelContext) async throws {
        // Load user's collections from Firestore
        let collections = try await FirestoreService.shared.fetchPublicCollections(limit: 100)
        
        // For now, we're keeping data local
        // In a full implementation, you'd sync Firestore data to SwiftData here
        print("✅ Loaded \(collections.count) collections from Firestore")
        
        // Load activities
        let activities = try await FirestoreService.shared.fetchActivities(
            for: userProfile.firebaseUID,
            limit: 100
        )
        print("✅ Loaded \(activities.count) activities from Firestore")
    }
    
    // MARK: - Sync Local Changes to Firestore
    
    func syncLocalChanges(modelContext: ModelContext) async throws {
        // Get all collections
        let collectionsDescriptor = FetchDescriptor<CollectionModel>()
        let collections = try modelContext.fetch(collectionsDescriptor)
        
        // Sync each collection to Firestore
        for collection in collections {
            try await FirestoreService.shared.saveCollection(collection)
        }
        
        print("✅ Synced \(collections.count) collections to Firestore")
        
        // Get all activities
        let activitiesDescriptor = FetchDescriptor<ActivityItem>()
        let activities = try modelContext.fetch(activitiesDescriptor)
        
        // Sync each activity to Firestore
        for activity in activities {
            try await FirestoreService.shared.saveActivity(activity)
        }
        
        print("✅ Synced \(activities.count) activities to Firestore")
    }
}