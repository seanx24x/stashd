//
//  ImageCache.swift
//  stashd
//
//  Created by Sean Lynch on 10/12/25.
//


// File: Core/Utilities/ImageCache.swift

import UIKit
import SwiftUI

actor ImageCache {
    static let shared = ImageCache()
    
    private var cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100 // Cache up to 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        return cache
    }()
    
    private init() {}
    
    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }
    
    func setImage(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func removeImage(for key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

// Cached AsyncImage wrapper
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url else { return }
        
        isLoading = true
        let cacheKey = url.absoluteString
        
        // Check cache first
        if let cachedImage = await ImageCache.shared.image(for: cacheKey) {
            self.image = cachedImage
            isLoading = false
            return
        }
        
        // Download image
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloadedImage = UIImage(data: data) {
                await ImageCache.shared.setImage(downloadedImage, for: cacheKey)
                self.image = downloadedImage
            }
        } catch {
            print("Failed to load image: \(error)")
        }
        
        isLoading = false
    }
}
