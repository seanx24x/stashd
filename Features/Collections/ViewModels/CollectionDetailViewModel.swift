//
//  CollectionDetailViewModel.swift
//  stashd
//
//  Created by Sean Lynch on 10/10/25.
//


// File: Features/Collections/ViewModels/CollectionDetailViewModel.swift

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class CollectionDetailViewModel {
    var commentText = ""
    var isSubmittingComment = false
    var errorMessage: String?
    
    private var modelContext: ModelContext?
    private var currentUser: UserProfile?
    
    func configure(modelContext: ModelContext, currentUser: UserProfile?) {
        self.modelContext = modelContext
        self.currentUser = currentUser
    }
    
    func toggleLike(for collection: CollectionModel) {
        guard let modelContext, let currentUser else { return }
        
        if let existingLike = collection.likes.first(where: { $0.user?.id == currentUser.id }) {
            modelContext.delete(existingLike)
        } else {
            let newLike = Like(user: currentUser, collection: collection)
            modelContext.insert(newLike)
        }
        
        try? modelContext.save()
    }
    
    func isLiked(_ collection: CollectionModel) -> Bool {
        guard let currentUser else { return false }
        return collection.likes.contains { $0.user?.id == currentUser.id }
    }
    
    func postComment(for collection: CollectionModel) async {
        guard let modelContext, let currentUser else { return }
        guard !commentText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isSubmittingComment = true
        errorMessage = nil
        
        do {
            try await Task.sleep(for: .milliseconds(300))
            
            let comment = Comment(
                text: commentText.trimmingCharacters(in: .whitespaces),
                author: currentUser,
                collection: collection
            )
            
            modelContext.insert(comment)
            try modelContext.save()
            
            commentText = ""
            isSubmittingComment = false
        } catch {
            errorMessage = "Failed to post comment"
            isSubmittingComment = false
        }
    }
    
    func deleteComment(_ comment: Comment) {
        guard let modelContext, let currentUser else { return }
        guard comment.author?.id == currentUser.id else { return }
        
        modelContext.delete(comment)
        try? modelContext.save()
    }
    
    func sortedComments(for collection: CollectionModel) -> [Comment] {
        collection.comments.sorted { $0.createdAt > $1.createdAt }
    }
}