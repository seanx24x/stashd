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
    
    // ✅ FIXED: Proper transformable attributes for arrays
    @Attribute(.transformable(by: "NSSecureUnarchiveFromDataTransformerName"))
    var imageURLs: [URL] = []
    
    var isFavorite: Bool
    var displayOrder: Int
    var createdAt: Date
    var updatedAt: Date
    
    @Attribute(.transformable(by: "NSSecureUnarchiveFromDataTransformerName"))
    var tags: [String] = []
    
    // Relationship - make it non-optional with default
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
