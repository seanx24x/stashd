// File: Features/Explore/ViewModels/ExploreViewModel.swift

import Foundation
import SwiftData

@Observable
@MainActor
final class ExploreViewModel {
    var allCollections: [CollectionModel] = []
    var filteredCollections: [CollectionModel] = []
    var trendingCollections: [CollectionModel] = []
    var recentCollections: [CollectionModel] = []
    var selectedCategory: CollectionCategory?
    var searchText = "" {
        didSet {
            applyFilters()
        }
    }
    var isLoading = false
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func loadAllCollections() async {
        isLoading = true
        
        do {
            let descriptor = FetchDescriptor<CollectionModel>(
                predicate: #Predicate { collection in
                    collection.isPublic == true
                },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            
            allCollections = try modelContext.fetch(descriptor)
            
            // Calculate trending (most likes)
            trendingCollections = allCollections
                .sorted { $0.likes.count > $1.likes.count }
                .prefix(10)
                .map { $0 }
            
            // Recent collections (already sorted by updatedAt)
            recentCollections = Array(allCollections.prefix(10))
            
            applyFilters()
            isLoading = false
        } catch {
            print("Failed to load collections: \(error)")
            isLoading = false
        }
    }
    
    func applyFilters() {
        var results = allCollections
        
        // ✅ FIX: Filter by category - compare String to String
        if let category = selectedCategory {
            results = results.filter { $0.category == category.rawValue }  // ← CHANGED
        }
        
        // Filter by search text (including tags)
        if !searchText.isEmpty {
            results = results.filter { collection in
                // Search in collection title
                if collection.title.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                // Search in collection description
                if collection.collectionDescription?.localizedCaseInsensitiveContains(searchText) ?? false {
                    return true
                }
                
                // Search in item tags
                if let items = collection.items {  // ← SAFELY UNWRAP
                    let hasMatchingTag = items.contains { item in
                        item.tags.contains { tag in
                            tag.localizedCaseInsensitiveContains(searchText)
                        }
                    }
                    return hasMatchingTag
                }
                
                return false
            }
        }
        
        filteredCollections = results
    }
    
    func selectCategory(_ category: CollectionCategory?) {
        selectedCategory = category
        applyFilters()
    }
    
    func collectionsForCategory(_ category: CollectionCategory) -> [CollectionModel] {
        // ✅ FIX: Compare String to String
        allCollections.filter { $0.category == category.rawValue }  // ← CHANGED
    }
    
    // Search by specific tag
    func searchByTag(_ tag: String) {
        searchText = tag
    }
}
