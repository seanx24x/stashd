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

// MARK: - Firestore Sync Helpers

extension CollectionItem {
    static func fromFirestore(_ data: [String: Any], id: String, collection: CollectionModel) throws -> CollectionItem {
        guard let name = data["name"] as? String else {
            throw FirestoreError.invalidData
        }
        
        let item = CollectionItem(
            name: name,
            collection: collection
        )
        
        item.id = UUID(uuidString: id) ?? UUID()
        item.notes = data["notes"] as? String
        
        if let valueString = data["estimatedValue"] as? String,
           let value = Decimal(string: valueString) {
            item.estimatedValue = value
        }
        
        if let conditionString = data["condition"] as? String {
            item.condition = ItemCondition(rawValue: conditionString)
        }
        
        if let timestamp = data["purchaseDate"] as? Timestamp {
            item.purchaseDate = timestamp.dateValue()
        }
        
        if let urlStrings = data["imageURLs"] as? [String] {
            item.imageURLs = urlStrings.compactMap { URL(string: $0) }
        }
        
        if let tags = data["tags"] as? [String] {
            item.tags = tags
        }
        
        item.isFavorite = data["isFavorite"] as? Bool ?? false
        
        if let timestamp = data["createdAt"] as? Timestamp {
            item.createdAt = timestamp.dateValue()
        }
        if let timestamp = data["updatedAt"] as? Timestamp {
            item.updatedAt = timestamp.dateValue()
        }
        
        return item
    }
    
    func updateFromFirestore(_ data: [String: Any]) {
        if let name = data["name"] as? String {
            self.name = name
        }
        if let notes = data["notes"] as? String {
            self.notes = notes
        }
        if let valueString = data["estimatedValue"] as? String,
           let value = Decimal(string: valueString) {
            self.estimatedValue = value
        }
        if let conditionString = data["condition"] as? String {
            self.condition = ItemCondition(rawValue: conditionString)
        }
        if let timestamp = data["purchaseDate"] as? Timestamp {
            self.purchaseDate = timestamp.dateValue()
        }
        if let urlStrings = data["imageURLs"] as? [String] {
            self.imageURLs = urlStrings.compactMap { URL(string: $0) }
        }
        if let tags = data["tags"] as? [String] {
            self.tags = tags
        }
        if let isFavorite = data["isFavorite"] as? Bool {
            self.isFavorite = isFavorite
        }
        if let timestamp = data["updatedAt"] as? Timestamp {
            self.updatedAt = timestamp.dateValue()
        }
    }
}
