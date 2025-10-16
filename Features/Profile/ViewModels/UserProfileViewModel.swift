//
//  UserProfileViewModel.swift
//  stashd
//
//  Created by Sean Lynch on 10/11/25.
//


// File: Features/Profile/ViewModels/UserProfileViewModel.swift

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class UserProfileViewModel {
    var user: UserProfile?
    var collections: [CollectionModel] = []
    var isFollowing = false
    var isLoading = false
    var errorMessage: String?
    
    private let modelContext: ModelContext
    private let currentUser: UserProfile
    private let userID: UUID
    
    init(userID: UUID, modelContext: ModelContext, currentUser: UserProfile) {
        self.userID = userID
        self.modelContext = modelContext
        self.currentUser = currentUser
    }
    
    func loadUser() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch the user
            let userDescriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate { $0.id == userID }
            )
            
            guard let fetchedUser = try modelContext.fetch(userDescriptor).first else {
                errorMessage = "User not found"
                isLoading = false
                return
            }
            
            user = fetchedUser
            
            // Check if following
            isFollowing = currentUser.following.contains { $0.id == userID }
            
            // Fetch user's collections
            let collectionsDescriptor = FetchDescriptor<CollectionModel>(
                predicate: #Predicate { collection in
                    collection.owner?.id == userID && collection.isPublic == true
                },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            
            collections = try modelContext.fetch(collectionsDescriptor)
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func toggleFollow() {
        guard let user else { return }
        
        if isFollowing {
            // Unfollow
            if let index = currentUser.following.firstIndex(where: { $0.id == user.id }) {
                currentUser.following.remove(at: index)
            }
            if let index = user.followers.firstIndex(where: { $0.id == currentUser.id }) {
                user.followers.remove(at: index)
            }
            isFollowing = false
        } else {
            // Follow
            currentUser.following.append(user)
            user.followers.append(currentUser)
            isFollowing = true
            
            // Create activity for the user being followed
            let activity = ActivityItem(
                type: .follow,
                actor: currentUser,
                recipient: user
            )
            modelContext.insert(activity)
            
            // Sync activity to Firestore
            Task {
                try? await FirestoreService.shared.saveActivity(activity)
                
                // ✅ NEW: Send push notification
                await PushNotificationService.shared.sendNotification(
                    to: user.firebaseUID,
                    type: .follow,
                    actorName: currentUser.displayName
                )
            }
        }
        
        try? modelContext.save()
        
        // Sync both user profiles to Firestore
        Task {
            try? await FirestoreService.shared.saveUserProfile(currentUser)
            try? await FirestoreService.shared.saveUserProfile(user)
        }
    }
    
    var followerCount: Int {
        user?.followers.count ?? 0
    }
    
    var followingCount: Int {
        user?.following.count ?? 0
    }
    
    var collectionCount: Int {
        collections.count
    }
}
