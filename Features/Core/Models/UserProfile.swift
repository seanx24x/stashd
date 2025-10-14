//
//  UserProfile.swift
//  stashd
//
//  Created by Sean Lynch on 10/9/25.
//


// File: Core/Models/UserProfile.swift

import SwiftData
import Foundation

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var firebaseUID: String
    @Attribute(.unique) var username: String
    
    var displayName: String
    var bio: String?
    var avatarURL: URL?
    var bannerURL: URL?
    
    var instagramHandle: String?
    var twitterHandle: String?
    var websiteURL: URL?
    
    @Relationship(deleteRule: .cascade, inverse: \CollectionModel.owner)
    var collections: [CollectionModel]
    
    @Relationship(deleteRule: .nullify)
    var following: [UserProfile]
    
    @Relationship(deleteRule: .nullify)
    var followers: [UserProfile]
    
    var createdAt: Date
    var lastActiveAt: Date
    
    var isPrivate: Bool
    var allowsComments: Bool
    var notificationsEnabled: Bool
    
    init(
        id: UUID = UUID(),
        firebaseUID: String,
        username: String,
        displayName: String,
        bio: String? = nil,
        avatarURL: URL? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.firebaseUID = firebaseUID
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.avatarURL = avatarURL
        self.collections = []
        self.following = []
        self.followers = []
        self.createdAt = createdAt
        self.lastActiveAt = .now
        self.isPrivate = false
        self.allowsComments = true
        self.notificationsEnabled = true
    }
}