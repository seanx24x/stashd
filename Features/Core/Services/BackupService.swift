//
//  BackupService.swift
//  stashd
//
//  Created by Sean Lynch on 10/16/25.
//


// File: Core/Services/BackupService.swift

import Foundation
import SwiftData
import FirebaseFirestore

@Observable
final class BackupService {
    static let shared = BackupService()
    
    private let db = Firestore.firestore()
    private let encryption = EncryptionService.shared
    
    var isBackingUp = false
    var lastBackupDate: Date?
    
    private init() {
        loadLastBackupDate()
    }
    
    // MARK: - Backup
    
    func backupUserData(for user: UserProfile, modelContext: ModelContext) async throws {
        isBackingUp = true
        defer { isBackingUp = false }
        
        print("🔄 Starting encrypted backup for user: \(user.username)")
        
        // Backup collections
        let descriptor = FetchDescriptor<CollectionModel>()
        let allCollections = try modelContext.fetch(descriptor)

        // Filter manually since SwiftData predicates with optional relationships can be tricky
        let userCollections = allCollections.filter { $0.owner?.id == user.id }
        
        for collection in userCollections {
            try await backupCollection(collection, userID: user.firebaseUID)
        }
        
        // Update last backup date
        lastBackupDate = Date()
        saveLastBackupDate()
        
        print("✅ Encrypted backup completed: \(userCollections.count) collections")
    }
    
    private func backupCollection(_ collection: CollectionModel, userID: String) async throws {
        let collectionRef = db.collection("users").document(userID)
            .collection("backups").document(collection.id.uuidString)
        
        // Encrypt sensitive data
        var encryptedDescription: String?
        if let description = collection.collectionDescription {
            let encryptedData = try encryption.encrypt(description)
            encryptedDescription = encryptedData.base64EncodedString()
        }
        
        let backupData: [String: Any] = [
            "id": collection.id.uuidString,
            "title": collection.title,
            "description": encryptedDescription as Any,
            "category": collection.category,
            "isPublic": collection.isPublic,
            "createdAt": Timestamp(date: collection.createdAt),
            "updatedAt": Timestamp(date: collection.updatedAt),
            "itemCount": collection.items?.count ?? 0,
            "backupVersion": 1,
            "encrypted": true
        ]
        
        try await collectionRef.setData(backupData, merge: true)
    }
    
    // MARK: - Restore
    
    func restoreUserData(for user: UserProfile, modelContext: ModelContext) async throws {
        print("🔄 Starting restore for user: \(user.username)")
        
        let backupsRef = db.collection("users").document(user.firebaseUID)
            .collection("backups")
        
        let snapshot = try await backupsRef.getDocuments()
        
        for document in snapshot.documents {
            try await restoreCollection(from: document, owner: user, modelContext: modelContext)
        }
        
        print("✅ Restore completed: \(snapshot.documents.count) collections")
    }
    
    private func restoreCollection(from document: DocumentSnapshot, owner: UserProfile, modelContext: ModelContext) async throws {
        guard let data = document.data() else { return }
        
        // Check if collection already exists
        let collectionID = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        let descriptor = FetchDescriptor<CollectionModel>()
        let allCollections = try modelContext.fetch(descriptor)
        let existing = allCollections.filter { $0.id == collectionID }
        
        if !existing.isEmpty {
            print("⚠️ Collection already exists, skipping: \(data["title"] as? String ?? "Unknown")")
            return
        }
        
        // Decrypt sensitive data
        var description: String?
        if let encryptedBase64 = data["description"] as? String,
           let encryptedData = Data(base64Encoded: encryptedBase64) {
            description = try? encryption.decryptToString(encryptedData)
        }
        
        // Get category from string
        let categoryString = data["category"] as? String ?? "other"
        let category = CollectionCategory(rawValue: categoryString) ?? .other
        
        // Create new collection
        let collection = CollectionModel(
            title: data["title"] as? String ?? "Untitled",
            category: category,
            owner: owner
        )
        
        collection.id = collectionID
        collection.collectionDescription = description
        collection.isPublic = data["isPublic"] as? Bool ?? true
        
        if let timestamp = data["createdAt"] as? Timestamp {
            collection.createdAt = timestamp.dateValue()
        }
        
        modelContext.insert(collection)
        try modelContext.save()
    }
    
    // MARK: - Auto Backup
    
    func scheduleAutoBackup(for user: UserProfile, modelContext: ModelContext) {
        Task {
            // Check if backup is needed (once per day)
            if shouldPerformBackup() {
                try? await backupUserData(for: user, modelContext: modelContext)
            }
        }
    }
    
    private func shouldPerformBackup() -> Bool {
        guard let lastBackup = lastBackupDate else { return true }
        let daysSinceBackup = Calendar.current.dateComponents([.day], from: lastBackup, to: Date()).day ?? 0
        return daysSinceBackup >= 1
    }
    
    // MARK: - Manual Backup Trigger
    
    func triggerManualBackup(for user: UserProfile, modelContext: ModelContext) async throws {
        try await backupUserData(for: user, modelContext: modelContext)
    }
    
    // MARK: - UserDefaults
    
    private func loadLastBackupDate() {
        if let timestamp = UserDefaults.standard.object(forKey: "lastBackupDate") as? Date {
            lastBackupDate = timestamp
        }
    }
    
    private func saveLastBackupDate() {
        UserDefaults.standard.set(lastBackupDate, forKey: "lastBackupDate")
    }
    
    // MARK: - Delete All Backups
    
    func deleteAllBackups(for userID: String) async throws {
        let backupsRef = db.collection("users").document(userID).collection("backups")
        let snapshot = try await backupsRef.getDocuments()
        
        for document in snapshot.documents {
            try await document.reference.delete()
        }
        
        lastBackupDate = nil
        UserDefaults.standard.removeObject(forKey: "lastBackupDate")
        
        print("🗑️ Deleted all backups for user")
    }
}
