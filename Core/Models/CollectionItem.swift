//
//  CollectionItem.swift
//  stashd
//
//  Created by Sean Lynch on 10/9/25.
//


// File: Core/Models/CollectionItem.swift

import SwiftData
import Foundation

@Model
final class CollectionItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var itemDescription: String?
    var imageURLs: [URL]
    
    @Relationship(deleteRule: .nullify)
    var collection: CollectionModel?
    
    var metadata: [String: String]
    var externalID: String?
    var externalURL: URL?
    
    var acquiredDate: Date?
    var purchasePrice: Decimal?
    var estimatedValue: Decimal?
    var condition: ItemCondition?
    
    var displayOrder: Int
    var isFavorite: Bool
    
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        collection: CollectionModel,
        displayOrder: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.collection = collection
        self.imageURLs = []
        self.metadata = [:]
        self.displayOrder = displayOrder
        self.isFavorite = false
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

enum ItemCondition: String, Codable, CaseIterable {
    case mint = "Mint"
    case nearMint = "Near Mint"
    case excellent = "Excellent"
    case veryGood = "Very Good"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
}