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

// MARK: - Firestore Conversion

extension ActivityItem {
    static func fromFirestore(_ data: [String: Any], id: String) throws -> ActivityItem {
        guard let typeString = data["type"] as? String,
              let type = ActivityType(rawValue: typeString) else {
            throw SyncError.missingRequiredField("type")
        }
        
        // Note: actor and recipient will need to be set separately
        // after fetching from database, as they're relationships
        // This creates a temporary activity that will be updated with relationships later
        let tempActor = UserProfile(
            firebaseUID: data["actorID"] as? String ?? "unknown",
            username: "temp",
            displayName: "Loading..."
        )
        
        let tempRecipient = UserProfile(
            firebaseUID: data["recipientID"] as? String ?? "unknown",
            username: "temp",
            displayName: "Loading..."
        )
        
        let activity = ActivityItem(
            id: UUID(uuidString: id) ?? UUID(),
            type: type,
            actor: tempActor,
            recipient: tempRecipient
        )
        
        activity.isRead = data["isRead"] as? Bool ?? false
        
        if let createdTimestamp = data["createdAt"] as? Timestamp {
            activity.createdAt = createdTimestamp.dateValue()
        }
        
        return activity
    }
}
