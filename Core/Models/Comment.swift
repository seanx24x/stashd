//
//  Comment.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import SwiftData

@Model
final class Comment {
    var id: UUID
    var content: String
    var createdAt: Date
    
    // Relationships
    var author: UserProfile
    var collection: CollectionModel
    
    init(
        content: String,
        author: UserProfile,
        collection: CollectionModel
    ) {
        self.id = UUID()
        self.content = content
        self.author = author
        self.collection = collection
        self.createdAt = Date()
    }
}
