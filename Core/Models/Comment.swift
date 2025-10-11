//
//  Comment.swift
//  stashd
//
//  Created by Sean Lynch on 10/9/25.
//


// File: Core/Models/Comment.swift

import SwiftData
import Foundation

@Model
final class Comment {
    @Attribute(.unique) var id: UUID
    var text: String
    
    @Relationship(deleteRule: .nullify)
    var author: UserProfile?
    
    @Relationship(deleteRule: .nullify)
    var collection: CollectionModel?
    
    @Relationship(deleteRule: .nullify)
    var parentComment: Comment?
    
    @Relationship(deleteRule: .cascade)
    var replies: [Comment]
    
    var createdAt: Date
    var editedAt: Date?
    
    init(
        id: UUID = UUID(),
        text: String,
        author: UserProfile,
        collection: CollectionModel,
        createdAt: Date = .now
    ) {
        self.id = id
        self.text = text
        self.author = author
        self.collection = collection
        self.replies = []
        self.createdAt = createdAt
    }
}