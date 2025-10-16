//
//  ActivityItem.swift
//  stashd
//
//  Created by Sean Lynch on 10/11/25.
//


// File: Core/Models/ActivityItem.swift

import SwiftData
import Foundation
import FirebaseFirestore

@Model
final class ActivityItem {
    @Attribute(.unique) var id: UUID
    var type: ActivityType
    var createdAt: Date
    var isRead: Bool
    
    // Relationships
    @Relationship(deleteRule: .nullify)
    var actor: UserProfile? // Person who performed the action
    
    @Relationship(deleteRule: .nullify)
    var recipient: UserProfile? // Person receiving the notification
    
    @Relationship(deleteRule: .nullify)
    var collection: CollectionModel? // Related collection
    
    @Relationship(deleteRule: .nullify)
    var comment: Comment? // Related comment
    
    init(
        id: UUID = UUID(),
        type: ActivityType,
        actor: UserProfile,
        recipient: UserProfile,
        collection: CollectionModel? = nil,
        comment: Comment? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.type = type
        self.actor = actor
        self.recipient = recipient
        self.collection = collection
        self.comment = comment
        self.createdAt = createdAt
        self.isRead = false
    }
    
    // ✅ NEW: Convenience initializer for Firestore sync (allows nil actor/recipient)
    convenience init(
        id: UUID = UUID(),
        type: ActivityType,
        actorOptional: UserProfile? = nil,
        recipientOptional: UserProfile? = nil,
        collection: CollectionModel? = nil,
        comment: Comment? = nil,
        createdAt: Date = .now
    ) {
        // Use placeholder profiles if nil (will be updated by sync service)
        let placeholderActor = actorOptional ?? UserProfile(
            firebaseUID: "placeholder",
            username: "unknown",
            displayName: "Unknown User"
        )
        let placeholderRecipient = recipientOptional ?? UserProfile(
            firebaseUID: "placeholder",
            username: "unknown",
            displayName: "Unknown User"
        )
        
        self.init(
            id: id,
            type: type,
            actor: placeholderActor,
            recipient: placeholderRecipient,
            collection: collection,
            comment: comment,
            createdAt: createdAt
        )
        
        // If using placeholders, set to nil after init
        if actorOptional == nil {
            self.actor = nil
        }
        if recipientOptional == nil {
            self.recipient = nil
        }
    }
}

enum ActivityType: String, Codable {
    case follow = "follow"
    case like = "like"
    case comment = "comment"
    case mention = "mention"
    
    var icon: String {
        switch self {
        case .follow: return "person.badge.plus"
        case .like: return "heart.fill"
        case .comment: return "bubble.left.fill"
        case .mention: return "at"
        }
    }
    
    var color: String {
        switch self {
        case .follow: return "stashdPrimary"
        case .like: return "error"
        case .comment: return "stashdAccent"
        case .mention: return "stashdPrimary"
        }
    }
}

// MARK: - Firestore Sync Helpers

extension ActivityItem {
    static func fromFirestore(_ data: [String: Any], id: String) throws -> ActivityItem {
        guard let typeString = data["type"] as? String,
              let type = ActivityType(rawValue: typeString) else {
            throw FirestoreError.invalidData
        }
        
        // Create activity with optional convenience initializer
        let activity = ActivityItem(
            id: UUID(uuidString: id) ?? UUID(),
            type: type,
            actorOptional: nil,  // ✅ Will be populated later by sync service
            recipientOptional: nil,  // ✅ Will be populated later by sync service
            createdAt: data["createdAt"] as? Date ?? Date()
        )
        
        activity.isRead = data["isRead"] as? Bool ?? false
        
        if let timestamp = data["createdAt"] as? Timestamp {
            activity.createdAt = timestamp.dateValue()
        }
        
        return activity
    }
}
