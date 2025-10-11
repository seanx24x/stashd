//
//  FeedViewModel.swift
//  stashd
//
//  Created by Sean Lynch on 10/10/25.
//


// File: Features/Feed/ViewModels/FeedViewModel.swift

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class FeedViewModel {
    var feedItems: [CollectionModel] = []
    var isLoading = false
    var errorMessage: String?
    
    private let modelContext: ModelContext
    private let currentUser: UserProfile
    
    init(modelContext: ModelContext, currentUser: UserProfile) {
        self.modelContext = modelContext
        self.currentUser = currentUser
    }
    
    func loadFeed() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get collections from users you follow + your own
            let followingIDs = currentUser.following.map { $0.id }
            var allIDs = followingIDs
            allIDs.append(currentUser.id)
            
            let descriptor = FetchDescriptor<CollectionModel>(
                predicate: #Predicate { collection in
                    collection.isPublic == true
                },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            
            let allCollections = try modelContext.fetch(descriptor)
            
            // Filter to only show collections from followed users + yourself
            feedItems = allCollections.filter { collection in
                guard let ownerID = collection.owner?.id else { return false }
                return allIDs.contains(ownerID)
            }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load feed: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func toggleLike(for collection: CollectionModel) {
        // Check if already liked
        if let existingLike = collection.likes.first(where: { $0.user?.id == currentUser.id }) {
            // Unlike
            modelContext.delete(existingLike)
        } else {
            // Like
            let newLike = Like(user: currentUser, collection: collection)
            modelContext.insert(newLike)
        }
        
        try? modelContext.save()
    }
    
    func isLiked(_ collection: CollectionModel) -> Bool {
        collection.likes.contains { $0.user?.id == currentUser.id }
    }
}