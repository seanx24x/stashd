//
//  Like.swift
//  stashd
//
//  Created by Sean Lynch on 10/9/25.
//


// File: Core/Models/Like.swift

import SwiftData
import Foundation

@Model
final class Like {
    @Attribute(.unique) var id: UUID
    
    @Relationship(deleteRule: .nullify)
    var user: UserProfile?
    
    @Relationship(deleteRule: .nullify)
    var collection: CollectionModel?
    
    var createdAt: Date
    
    init(id: UUID = UUID(), user: UserProfile, collection: CollectionModel) {
        self.id = id
        self.user = user
        self.collection = collection
        self.createdAt = .now
    }
}