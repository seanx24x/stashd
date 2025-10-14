//
//  CollectionItem.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import SwiftData

@Model
final class CollectionItem {
    var id: UUID
    var name: String
    var notes: String?
    var estimatedValue: Decimal
    var condition: ItemCondition?
    var purchaseDate: Date?
    
    // ✅ REMOVE transformable - SwiftData handles these natively
    var imageURLs: [URL] = []
    
    var isFavorite: Bool
    var displayOrder: Int
    var createdAt: Date
    var updatedAt: Date
    
    // ✅ REMOVE transformable - SwiftData handles these natively
    var tags: [String] = []
    
    // Relationship
    var collection: CollectionModel
    
    init(
        name: String,
        collection: CollectionModel,
        notes: String? = nil,
        estimatedValue: Decimal = 0,
        condition: ItemCondition? = nil,
        purchaseDate: Date? = nil,
        imageURLs: [URL] = [],
        tags: [String] = []
    ) {
        self.id = UUID()
        self.name = name
        self.collection = collection
        self.notes = notes
        self.estimatedValue = estimatedValue
        self.condition = condition
        self.purchaseDate = purchaseDate
        self.imageURLs = imageURLs
        self.isFavorite = false
        self.displayOrder = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = tags
    }
}

enum ItemCondition: String, Codable, CaseIterable {
    case mint = "Mint"
    case nearMint = "Near Mint"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
}
