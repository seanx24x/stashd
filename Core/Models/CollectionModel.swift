//
//  CollectionModel.swift
//  stashd
//
//  Created by Sean Lynch on 10/9/25.
//


// File: Core/Models/CollectionModel.swift

import SwiftData
import Foundation

@Model
final class CollectionModel {
    @Attribute(.unique) var id: UUID
    var title: String
    var collectionDescription: String?
    var category: CollectionCategory
    var coverImageURL: URL?
    
    @Relationship(deleteRule: .cascade, inverse: \CollectionItem.collection)
    var items: [CollectionItem]
    
    @Relationship(deleteRule: .nullify)
    var owner: UserProfile?
    
    @Relationship(deleteRule: .cascade)
    var likes: [Like]
    
    @Relationship(deleteRule: .cascade, inverse: \Comment.collection)
    var comments: [Comment]
    
    var tags: [String]
    var isPublic: Bool
    var isFeatured: Bool
    
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
    
    var createdAt: Date
    var updatedAt: Date
    var viewCount: Int
    
    init(
        id: UUID = UUID(),
        title: String,
        category: CollectionCategory,
        owner: UserProfile,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.owner = owner
        self.items = []
        self.likes = []
        self.comments = []
        self.tags = []
        self.isPublic = true
        self.isFeatured = false
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.viewCount = 0
    }
}

enum CollectionCategory: String, Codable, CaseIterable {
    case vinyl = "Vinyl Records"
    case sneakers = "Sneakers"
    case books = "Books"
    case art = "Art"
    case toys = "Toys & Figures"
    case fashion = "Fashion"
    case watches = "Watches"
    case photography = "Photography"
    case plants = "Plants"
    case other = "Other"
    
    var iconName: String {
        switch self {
        case .vinyl: return "opticaldisc"
        case .sneakers: return "shoe.2"
        case .books: return "book"
        case .art: return "paintpalette"
        case .toys: return "teddybear"
        case .fashion: return "tshirt"
        case .watches: return "watchface.applewatch.case"
        case .photography: return "camera"
        case .plants: return "leaf"
        case .other: return "square.grid.2x2"
        }
    }
}