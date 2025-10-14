//
//  Like.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import SwiftData

@Model
final class Like {
    var id: UUID
    var createdAt: Date
    
    // Relationships
    var user: UserProfile
    var collection: CollectionModel
    
    init(
        user: UserProfile,
        collection: CollectionModel
    ) {
        self.id = UUID()
        self.user = user
        self.collection = collection
        self.createdAt = Date()
    }
}
