// File: Features/Collections/ViewModels/CollectionViewModel.swift

import Foundation
import SwiftData
import UIKit
import Observation

@Observable
@MainActor
final class CollectionViewModel {
    var isLoading = false
    var errorMessage: String?
    
    private var modelContext: ModelContext?
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func createCollection(
        title: String,
        description: String?,
        category: CollectionCategory,
        coverImage: UIImage?,
        owner: UserProfile
    ) async throws {
        guard let modelContext else {
            throw CollectionError.noModelContext
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // ✅ NEW: Validate inputs
            try ValidationService.validateCollectionTitle(title)
            try ValidationService.validateCollectionDescription(description)
            
            // ✅ NEW: Sanitize inputs
            let sanitizedTitle = ValidationService.sanitizeInput(title)
            let sanitizedDescription = description.map { ValidationService.sanitizeInput($0) }
            
            // Simulate upload delay
            try await Task.sleep(for: .milliseconds(500))
            
            // Upload cover image to Firebase Storage (if provided)
            var coverURL: URL?
            if let image = coverImage {
                let collectionID = UUID()
                coverURL = try await StorageService.shared.uploadCollectionCover(image, collectionID: collectionID.uuidString)
            }
            
            // Create the collection with sanitized values
            let collection = CollectionModel(
                title: sanitizedTitle,
                category: category,
                owner: owner
            )
            collection.collectionDescription = sanitizedDescription
            collection.coverImageURL = coverURL
            collection.isPublic = true
            
            // Save locally
            modelContext.insert(collection)
            try modelContext.save()
            
            // Sync to Firestore
            try await FirestoreService.shared.saveCollection(collection)
            
            HapticManager.shared.success()
            
            isLoading = false
        } catch {
            HapticManager.shared.error()
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func deleteCollection(_ collection: CollectionModel) {
        guard let modelContext else { return }
        
        // Delete cover image from Firebase Storage if it exists
        if let coverURL = collection.coverImageURL {
            Task {
                try? await StorageService.shared.deleteImage(at: coverURL)
            }
        }
        
        // Delete item images from Firebase Storage
        if let items = collection.items {
            for item in items {
                for imageURL in item.imageURLs {
                    Task {
                        try? await StorageService.shared.deleteImage(at: imageURL)
                    }
                }
            }
        }
        
        modelContext.delete(collection)
        try? modelContext.save()
        
        HapticManager.shared.success()
    }
    
    func updateCollection(
        _ collection: CollectionModel,
        title: String,
        description: String?,
        category: CollectionCategory,
        coverImage: UIImage?
    ) async throws {
        guard let modelContext else {
            throw CollectionError.noModelContext
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // ✅ NEW: Validate inputs
            try ValidationService.validateCollectionTitle(title)
            try ValidationService.validateCollectionDescription(description)
            
            // ✅ NEW: Sanitize inputs
            let sanitizedTitle = ValidationService.sanitizeInput(title)
            let sanitizedDescription = description.map { ValidationService.sanitizeInput($0) }
            
            try await Task.sleep(for: .milliseconds(300))
            
            // Update cover image if new one provided
            if let image = coverImage {
                // Delete old cover image from Firebase Storage
                if let oldCoverURL = collection.coverImageURL {
                    try? await StorageService.shared.deleteImage(at: oldCoverURL)
                }
                
                // Upload new cover image to Firebase Storage
                let newCoverURL = try await StorageService.shared.uploadCollectionCover(
                    image,
                    collectionID: collection.id.uuidString
                )
                collection.coverImageURL = newCoverURL
            }
            
            // Update with sanitized values
            collection.title = sanitizedTitle
            collection.collectionDescription = sanitizedDescription
            collection.category = category.rawValue
            collection.updatedAt = .now
            
            try modelContext.save()
            
            // Sync to Firestore
            try await FirestoreService.shared.saveCollection(collection)
            
            HapticManager.shared.success()
            
            isLoading = false
        } catch {
            HapticManager.shared.error()
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

enum CollectionError: LocalizedError {
    case noModelContext
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .noModelContext:
            return "Database connection not available"
        case .saveFailed:
            return "Failed to save collection"
        }
    }
}
