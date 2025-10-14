import SwiftUI
import SwiftData

// MARK: - Collection Detail Loader

struct CollectionDetailViewLoader: View {
    let collectionID: UUID
    @Environment(\.modelContext) private var modelContext
    @Query private var allCollections: [CollectionModel]
    
    private var collection: CollectionModel? {
        allCollections.first { $0.id == collectionID }
    }
    
    var body: some View {
        if let collection {
            CollectionDetailView(collection: collection)
        } else {
            VStack(spacing: Spacing.large) {
                ProgressView()
                Text("Loading collection...")
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
            }
        }
    }
}

// MARK: - Item Detail Loader

struct ItemDetailViewLoader: View {
    let itemID: UUID
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [CollectionItem]
    
    private var item: CollectionItem? {
        allItems.first { $0.id == itemID }
    }
    
    var body: some View {
        if let item {
            ItemDetailView(item: item)
        } else {
            ContentUnavailableView(
                "Item Not Found",
                systemImage: "exclamationmark.triangle",
                description: Text("This item could not be found.")
            )
        }
    }
}
