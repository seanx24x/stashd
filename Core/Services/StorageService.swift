//
//  StorageService.swift
//  stashd
//
//  Created by Sean Lynch on 10/11/25.
//

// File: Core/Services/StorageService.swift

import Foundation
import FirebaseStorage
import UIKit

@MainActor
final class StorageService {
    static let shared = StorageService()
    
    private let storage: Storage
    private let avatarsRef: StorageReference
    private let collectionsRef: StorageReference
    private let itemsRef: StorageReference
    
    private init() {
        self.storage = FirebaseService.shared.storage
        self.avatarsRef = storage.reference().child("avatars")
        self.collectionsRef = storage.reference().child("collections")
        self.itemsRef = storage.reference().child("items")
    }
    
    // MARK: - Avatar Upload
    
    func uploadAvatar(_ image: UIImage, userID: String) async throws -> URL {
        // Compress image in background thread
        let imageData = await Task.detached(priority: .userInitiated) {
            image.jpegData(compressionQuality: 0.6)
        }.value
        
        guard let imageData else {
            throw StorageError.invalidImage
        }
        
        let filename = "\(userID)_\(UUID().uuidString).jpg"
        let ref = avatarsRef.child(filename)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "public, max-age=31536000"
        
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        
        return downloadURL
    }
    
    // MARK: - Collection Cover Upload
    
    func uploadCollectionCover(_ image: UIImage, collectionID: String) async throws -> URL {
        // Compress image in background thread
        let imageData = await Task.detached(priority: .userInitiated) {
            image.jpegData(compressionQuality: 0.7)
        }.value
        
        guard let imageData else {
            throw StorageError.invalidImage
        }
        
        let filename = "\(collectionID)_cover_\(UUID().uuidString).jpg"
        let ref = collectionsRef.child(filename)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "public, max-age=31536000"
        
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        
        return downloadURL
    }
    
    // MARK: - Item Image Upload
    
    func uploadItemImage(_ image: UIImage, itemID: String) async throws -> URL {
        // Compress image in background thread
        let imageData = await Task.detached(priority: .userInitiated) {
            image.jpegData(compressionQuality: 0.7)
        }.value
        
        guard let imageData else {
            throw StorageError.invalidImage
        }
        
        let filename = "\(itemID)_\(UUID().uuidString).jpg"
        let ref = itemsRef.child(filename)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "public, max-age=31536000"
        
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        
        return downloadURL
    }
    
    // MARK: - Batch Upload (for multiple images)
    
    func uploadMultipleItemImages(_ images: [UIImage], itemID: String) async throws -> [URL] {
        var urls: [URL] = []
        
        for (index, image) in images.enumerated() {
            let url = try await uploadItemImage(image, itemID: "\(itemID)_\(index)")
            urls.append(url)
        }
        
        return urls
    }
    
    // MARK: - Delete Image
    
    func deleteImage(at url: URL) async throws {
        let ref = storage.reference(forURL: url.absoluteString)
        try await ref.delete()
    }
    
    // MARK: - Delete Multiple Images
    
    func deleteMultipleImages(at urls: [URL]) async throws {
        for url in urls {
            try await deleteImage(at: url)
        }
    }
}

enum StorageError: LocalizedError {
    case invalidImage
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .uploadFailed:
            return "Failed to upload image"
        }
    }
}
