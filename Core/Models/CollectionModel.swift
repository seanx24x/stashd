//
//  CollectionModel.swift
//  stashd
//
//  Created by Sean Lynch
//

// File: Core/Models/CollectionModel.swift

import Foundation
import SwiftData

@Model
final class CollectionModel {
    var id: UUID
    var title: String
    var collectionDescription: String?
    var category: String
    var coverImageURL: URL?
    
    // Encrypted estimated value storage
    @Attribute(.externalStorage) private var _encryptedValue: Data?
    
    var createdAt: Date
    var updatedAt: Date
    var isPublic: Bool
    var itemCount: Int
    var totalValue: Decimal
    var viewCount: Int
    var likeCount: Int
    var commentCount: Int
    
    @Relationship(deleteRule: .cascade, inverse: \CollectionItem.collection)
    var items: [CollectionItem]?
    
    @Relationship(deleteRule: .nullify)
    var owner: UserProfile?
    
    // MARK: - Computed Property for Estimated Value (Encrypted)
    
    var estimatedValue: Decimal {
        get {
            guard let encryptedData = _encryptedValue else {
                return 0
            }
            
            do {
                return try EncryptionService.shared.decryptToDecimal(encryptedData)
            } catch {
                print("⚠️ Failed to decrypt estimated value: \(error)")
                return 0
            }
        }
        set {
            do {
                _encryptedValue = try EncryptionService.shared.encryptDecimal(newValue)
            } catch {
                print("⚠️ Failed to encrypt estimated value: \(error)")
                _encryptedValue = nil
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        category: CollectionCategory,
        coverImageURL: URL? = nil,
        owner: UserProfile?,
        isPublic: Bool = true,
        estimatedValue: Decimal = 0
    ) {
        self.id = id
        self.title = title
        self.collectionDescription = description
        self.category = category.rawValue
        self.coverImageURL = coverImageURL
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPublic = isPublic
        self.itemCount = 0
        self.totalValue = 0
        self.viewCount = 0
        self.likeCount = 0
        self.commentCount = 0
        self.items = []
        self.owner = owner
        
        // Encrypt the estimated value on init
        do {
            self._encryptedValue = try EncryptionService.shared.encryptDecimal(estimatedValue)
        } catch {
            print("⚠️ Failed to encrypt initial estimated value: \(error)")
            self._encryptedValue = nil
        }
    }
}

// MARK: - Computed Properties

extension CollectionModel {
    var categoryEnum: CollectionCategory {
        CollectionCategory(rawValue: category) ?? .other
    }
    
    var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: estimatedValue)) ?? "$0.00"
    }
}

// MARK: - Sample Data

extension CollectionModel {
    static func sample(owner: UserProfile) -> CollectionModel {
        CollectionModel(
            title: "Sneaker Collection",
            description: "My rare sneaker collection",
            category: .sneakers,
            owner: owner,
            estimatedValue: 5000
        )
    }
}
