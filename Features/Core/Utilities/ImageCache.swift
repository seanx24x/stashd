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

// MARK: - CachedAsyncImage

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let content: (AsyncImagePhase) -> Content
    
    @State private var phase: AsyncImagePhase = .empty
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.content = content
    }
    
    var body: some View {
        content(phase)
            .task(id: url) {
                await loadImage()
            }
    }
    
    private func loadImage() async {
        guard let url else {
            phase = .empty
            return
        }
        
        let cacheKey = url.absoluteString
        
        // Check cache first
        if let cachedImage = await ImageCache.shared.image(for: cacheKey) {
            phase = .success(Image(uiImage: cachedImage))
            return
        }
        
        // Download image
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloadedImage = UIImage(data: data) {
                await ImageCache.shared.setImage(downloadedImage, for: cacheKey)
                phase = .success(Image(uiImage: downloadedImage))
            } else {
                phase = .failure(ImageLoadError.invalidData)
            }
        } catch {
            phase = .failure(error)
        }
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage {
    /// Simple initializer that shows image with default loading/error states
    init(url: URL?) where Content == AnyView {
        self.init(url: url) { phase in
            AnyView(
                Group {
                    switch phase {
                    case .success(let image):
                        image.resizable()
                    case .empty:
                        ProgressView()
                    case .failure(_):
                        Color.gray.opacity(0.2)
                    @unknown default:
                        Color.gray.opacity(0.2)
                    }
                }
            )
        }
    }
    
    /// Initializer with separate content and placeholder closures
    init<ImageContent: View, PlaceholderContent: View>(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> ImageContent,
        @ViewBuilder placeholder: @escaping () -> PlaceholderContent
    ) where Content == AnyView {
        self.init(url: url) { phase in
            AnyView(
                Group {
                    switch phase {
                    case .success(let image):
                        content(image)
                    case .empty, .failure:
                        placeholder()
                    @unknown default:
                        placeholder()
                    }
                }
            )
        }
    }
}

// MARK: - Error Type

enum ImageLoadError: LocalizedError {
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Failed to decode image data"
        }
    }
}

// MARK: - AsyncImagePhase Extension for Convenience

extension AsyncImagePhase {
    var image: Image? {
        if case .success(let image) = self {
            return image
        }
        return nil
    }
    
    var error: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}
