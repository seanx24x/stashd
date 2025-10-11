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
            // Simulate upload delay
            try await Task.sleep(for: .milliseconds(500))
            
            // Save cover image to documents directory
            var coverURL: URL?
            if let image = coverImage,
               let imageData = image.jpegData(compressionQuality: 0.7) {
                let filename = "\(UUID().uuidString)_cover.jpg"
                if let documentsDirectory = FileManager.default.urls(
                    for: .documentDirectory,
                    in: .userDomainMask
                ).first {
                    let fileURL = documentsDirectory.appendingPathComponent(filename)
                    try? imageData.write(to: fileURL)
                    coverURL = fileURL
                }
            }
            
            // Create the collection
            let collection = CollectionModel(
                title: title,
                category: category,
                owner: owner
            )
            collection.collectionDescription = description
            collection.coverImageURL = coverURL
            collection.isPublic = true
            
            modelContext.insert(collection)
            try modelContext.save()
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func deleteCollection(_ collection: CollectionModel) {
        guard let modelContext else { return }
        
        // Delete cover image file if it exists
        if let coverURL = collection.coverImageURL {
            try? FileManager.default.removeItem(at: coverURL)
        }
        
        // Delete item images
        for item in collection.items {
            for imageURL in item.imageURLs {
                try? FileManager.default.removeItem(at: imageURL)
            }
        }
        
        modelContext.delete(collection)
        try? modelContext.save()
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
            try await Task.sleep(for: .milliseconds(300))
            
            // Update cover image if new one provided
            if let image = coverImage {
                // Delete old cover image
                if let oldCoverURL = collection.coverImageURL {
                    try? FileManager.default.removeItem(at: oldCoverURL)
                }
                
                // Save new cover image
                if let imageData = image.jpegData(compressionQuality: 0.7) {
                    let filename = "\(UUID().uuidString)_cover.jpg"
                    if let documentsDirectory = FileManager.default.urls(
                        for: .documentDirectory,
                        in: .userDomainMask
                    ).first {
                        let fileURL = documentsDirectory.appendingPathComponent(filename)
                        try? imageData.write(to: fileURL)
                        collection.coverImageURL = fileURL
                    }
                }
            }
            
            collection.title = title
            collection.collectionDescription = description
            collection.category = category
            collection.updatedAt = .now
            
            try modelContext.save()
            
            isLoading = false
        } catch {
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
