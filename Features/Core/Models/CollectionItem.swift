//
//  CollectionItem.swift
//  stashd
//
//  Created by Sean Lynch
//

import Foundation
import SwiftData
import FirebaseFirestore

@Model
final class CollectionItem {
    var id: UUID
    var name: String
    var notes: String?
    var estimatedValue: Decimal
    var condition: ItemCondition?
    var purchaseDate: Date?
    var imageURLs: [URL]
    var isFavorite: Bool
    var displayOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
    
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

// MARK: - Firestore Conversion

extension CollectionItem {
    /// Create CollectionItem from Firestore data
    static func fromFirestore(_ data: [String: Any], id: String, collection: CollectionModel) throws -> CollectionItem {
        guard let name = data["name"] as? String else {
            throw SyncError.missingRequiredField("name")
        }
        
        let item = CollectionItem(
            name: name,
            collection: collection
        )
        
        item.id = UUID(uuidString: id) ?? UUID()
        item.notes = data["notes"] as? String
        
        if let valueDouble = data["estimatedValue"] as? Double {
            item.estimatedValue = Decimal(valueDouble)
        }
        
        if let conditionString = data["condition"] as? String {
            item.condition = ItemCondition(rawValue: conditionString)
        }
        
        if let purchaseTimestamp = data["purchaseDate"] as? Timestamp {
            item.purchaseDate = purchaseTimestamp.dateValue()
        }
        
        if let imageURLStrings = data["imageURLs"] as? [String] {
            item.imageURLs = imageURLStrings.compactMap { URL(string: $0) }
        }
        
        item.isFavorite = data["isFavorite"] as? Bool ?? false
        item.displayOrder = data["displayOrder"] as? Int ?? 0
        
        if let tagsArray = data["tags"] as? [String] {
            item.tags = tagsArray
        }
        
        if let createdTimestamp = data["createdAt"] as? Timestamp {
            item.createdAt = createdTimestamp.dateValue()
        }
        
        if let updatedTimestamp = data["updatedAt"] as? Timestamp {
            item.updatedAt = updatedTimestamp.dateValue()
        }
        
        return item
    }
    
    /// Update item from Firestore data
    func updateFromFirestore(_ data: [String: Any]) {
        if let name = data["name"] as? String {
            self.name = name
        }
        
        if let notes = data["notes"] as? String {
            self.notes = notes
        }
        
        if let valueDouble = data["estimatedValue"] as? Double {
            self.estimatedValue = Decimal(valueDouble)
        }
        
        if let conditionString = data["condition"] as? String {
            self.condition = ItemCondition(rawValue: conditionString)
        }
        
        if let imageURLStrings = data["imageURLs"] as? [String] {
            self.imageURLs = imageURLStrings.compactMap { URL(string: $0) }
        }
        
        if let tagsArray = data["tags"] as? [String] {
            self.tags = tagsArray
        }
        
        self.isFavorite = data["isFavorite"] as? Bool ?? self.isFavorite
        
        if let updatedTimestamp = data["updatedAt"] as? Timestamp {
            self.updatedAt = updatedTimestamp.dateValue()
        }
    }
}
