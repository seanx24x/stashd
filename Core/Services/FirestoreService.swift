//
//  FirestoreService.swift
//  stashd
//
//  Created by Sean Lynch on 10/11/25.
//


// File: Core/Services/FirestoreService.swift

import Foundation
import FirebaseFirestore
import SwiftData

@MainActor
final class FirestoreService {
    static let shared = FirestoreService()
    
    private let db: Firestore
    private let userProfilesCollection = "userProfiles"
    private let collectionsCollection = "collections"
    private let activitiesCollection = "activities"
    
    private init() {
        self.db = FirebaseService.shared.firestore
    }
    
    // MARK: - User Profile Sync
    
    func saveUserProfile(_ profile: UserProfile) async throws {
        let data: [String: Any] = [
            "id": profile.id.uuidString,
            "firebaseUID": profile.firebaseUID,
            "username": profile.username,
            "displayName": profile.displayName,
            "bio": profile.bio ?? "",
            "avatarURL": profile.avatarURL?.absoluteString ?? "",
            "createdAt": Timestamp(date: profile.createdAt),
            "lastActiveAt": Timestamp(date: profile.lastActiveAt),
            "isPrivate": profile.isPrivate,
            "followingIDs": profile.following.map { $0.id.uuidString },
            "followerIDs": profile.followers.map { $0.id.uuidString }
        ]
        
        try await db.collection(userProfilesCollection)
            .document(profile.firebaseUID)
            .setData(data, merge: true)
    }
    
    func fetchUserProfile(firebaseUID: String) async throws -> [String: Any]? {
        let snapshot = try await db.collection(userProfilesCollection)
            .document(firebaseUID)
            .getDocument()
        
        return snapshot.data()
    }
    
    func checkUsernameAvailable(_ username: String) async throws -> Bool {
        let snapshot = try await db.collection(userProfilesCollection)
            .whereField("username", isEqualTo: username)
            .getDocuments()
        
        return snapshot.documents.isEmpty
    }
    
    // MARK: - Collection Sync
    
    func saveCollection(_ collection: CollectionModel) async throws {
        guard let ownerUID = collection.owner?.firebaseUID else {
            throw FirestoreError.missingOwner
        }
        
        let data: [String: Any] = [
            "id": collection.id.uuidString,
            "title": collection.title,
            "description": collection.collectionDescription ?? "",
            "category": collection.category.rawValue,
            "coverImageURL": collection.coverImageURL?.absoluteString ?? "",
            "ownerUID": ownerUID,
            "isPublic": collection.isPublic,
            "tags": collection.tags,
            "createdAt": Timestamp(date: collection.createdAt),
            "updatedAt": Timestamp(date: collection.updatedAt),
            "viewCount": collection.viewCount,
            "likeCount": collection.likes.count,
            "commentCount": collection.comments.count,
            "itemCount": collection.items.count
        ]
        
        try await db.collection(collectionsCollection)
            .document(collection.id.uuidString)
            .setData(data, merge: true)
    }
    
    func fetchPublicCollections(limit: Int = 50) async throws -> [[String: Any]] {
        let snapshot = try await db.collection(collectionsCollection)
            .whereField("isPublic", isEqualTo: true)
            .order(by: "updatedAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.map { $0.data() }
    }
    
    // MARK: - Activity Sync
    
    func saveActivity(_ activity: ActivityItem) async throws {
        guard let actorUID = activity.actor?.firebaseUID,
              let recipientUID = activity.recipient?.firebaseUID else {
            throw FirestoreError.missingUser
        }
        
        let data: [String: Any] = [
            "id": activity.id.uuidString,
            "type": activity.type.rawValue,
            "actorUID": actorUID,
            "recipientUID": recipientUID,
            "collectionID": activity.collection?.id.uuidString ?? "",
            "commentID": activity.comment?.id.uuidString ?? "",
            "createdAt": Timestamp(date: activity.createdAt),
            "isRead": activity.isRead
        ]
        
        try await db.collection(activitiesCollection)
            .document(activity.id.uuidString)
            .setData(data, merge: true)
    }
    
    func fetchActivities(for userUID: String, limit: Int = 50) async throws -> [[String: Any]] {
        let snapshot = try await db.collection(activitiesCollection)
            .whereField("recipientUID", isEqualTo: userUID)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.map { $0.data() }
    }
}

enum FirestoreError: LocalizedError {
    case missingOwner
    case missingUser
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .missingOwner:
            return "Collection owner not found"
        case .missingUser:
            return "User not found"
        case .invalidData:
            return "Invalid data format"
        }
    }
}