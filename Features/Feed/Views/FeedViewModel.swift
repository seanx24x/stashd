// File: Features/Feed/ViewModels/FeedViewModel.swift

import Foundation
import SwiftData

@Observable
@MainActor
final class FeedViewModel {
    var feedItems: [CollectionModel] = []
    var isLoading = false
    var errorMessage: String?
    
    private let modelContext: ModelContext
    private let currentUser: UserProfile
    private let pageSize = 20
    private var currentPage = 0
    
    init(modelContext: ModelContext, currentUser: UserProfile) {
        self.modelContext = modelContext
        self.currentUser = currentUser
    }
    
    func loadFeed() async {
        isLoading = true
        errorMessage = nil
        currentPage = 0
        
        do {
            // Get following user IDs + INCLUDE SELF
            var followingIDs = currentUser.following.map { $0.id }
            followingIDs.append(currentUser.id)  // ← FIXED: Show your own collections!
            
            // Fetch ALL public collections
            var descriptor = FetchDescriptor<CollectionModel>(
                predicate: #Predicate { collection in
                    collection.isPublic == true
                },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            descriptor.fetchLimit = pageSize
            
            let allCollections = try modelContext.fetch(descriptor)
            
            // Filter by following (including self)
            feedItems = allCollections.filter { collection in
                guard let ownerID = collection.owner?.id else { return false }
                return followingIDs.contains(ownerID)
            }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load feed: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func loadMore() async {
        guard !isLoading else { return }
        
        isLoading = true
        currentPage += 1
        
        do {
            var followingIDs = currentUser.following.map { $0.id }
            followingIDs.append(currentUser.id)  // ← FIXED: Include self here too
            
            var descriptor = FetchDescriptor<CollectionModel>(
                predicate: #Predicate { collection in
                    collection.isPublic == true
                },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            descriptor.fetchLimit = pageSize
            descriptor.fetchOffset = currentPage * pageSize
            
            let allCollections = try modelContext.fetch(descriptor)
            
            let moreItems = allCollections.filter { collection in
                guard let ownerID = collection.owner?.id else { return false }
                return followingIDs.contains(ownerID)
            }
            
            feedItems.append(contentsOf: moreItems)
            isLoading = false
        } catch {
            isLoading = false
        }
    }
    
    func isLiked(_ collection: CollectionModel) -> Bool {
        collection.likes.contains { $0.user.id == currentUser.id }
    }
    
    func toggleLike(for collection: CollectionModel) {
        if let existingLike = collection.likes.first(where: { $0.user.id == currentUser.id }) {
            modelContext.delete(existingLike)
        } else {
            let newLike = Like(user: currentUser, collection: collection)
            modelContext.insert(newLike)
        }
        
        try? modelContext.save()
    }
}
