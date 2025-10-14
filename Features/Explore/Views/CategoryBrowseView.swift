//
//  CategoryBrowseView.swift
//  stashd
//
//  Created by Sean Lynch on 10/11/25.
//

// File: Features/Explore/Views/CategoryBrowseView.swift

import SwiftUI

struct CategoryBrowseView: View {
    let category: CollectionCategory
    let collections: [CollectionModel]
    
    @Environment(AppCoordinator.self) private var coordinator
    
    var body: some View {
        ScrollView {
            if collections.isEmpty {
                EmptyCategoryView(category: category)
            } else {
                LazyVStack(spacing: Spacing.medium) {
                    ForEach(collections) { collection in
                        Button {
                            coordinator.navigate(to: .collectionDetail(collection.id))
                        } label: {
                            CategoryCollectionCard(collection: collection)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.large)
                .padding(.vertical, Spacing.medium)
            }
        }
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct CategoryCollectionCard: View {
    let collection: CollectionModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            // Cover Image
            Group {
                if let coverURL = collection.coverImageURL {
                    CustomAsyncImageView(url: coverURL)
                } else {
                    Rectangle()
                        .fill(.surfaceElevated)
                        .overlay {
                            Image(systemName: getCategoryIcon(collection.category))
                                .font(.system(size: 48))
                                .foregroundStyle(.textTertiary)
                        }
                }
            }
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            
            // Info
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(collection.title)
                    .font(.headlineSmall)
                    .foregroundStyle(.textPrimary)
                
                if let owner = collection.owner {
                    Text("by @\(owner.username)")
                        .font(.labelMedium)
                        .foregroundStyle(.textSecondary)
                }
                
                if let description = collection.collectionDescription {
                    Text(description)
                        .font(.bodyMedium)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: Spacing.medium) {
                    Label("\(collection.likeCount)", systemImage: "heart")
                    Label("\(collection.commentCount)", systemImage: "bubble.left")
                    Label("\(collection.itemCount)", systemImage: "square.stack.3d.up")
                }
                .font(.labelMedium)
                .foregroundStyle(.textTertiary)
            }
        }
        .padding(Spacing.medium)
        .background(.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

struct EmptyCategoryView: View {
    let category: CollectionCategory
    
    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: category.iconName)
                .font(.system(size: 64))
                .foregroundStyle(.textTertiary)
            
            VStack(spacing: Spacing.small) {
                Text("No \(category.rawValue) collections yet")
                    .font(.headlineSmall)
                    .foregroundStyle(.textPrimary)
                
                Text("Be the first to create one")
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxLarge)
    }
}

// Helper view to avoid conflicts with AsyncImage
struct CustomAsyncImageView: View {
    let url: URL
    
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure(_):
                Rectangle()
                    .fill(.surfaceElevated)
                    .overlay {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 24))
                            .foregroundStyle(.textTertiary)
                    }
            case .empty:
                Rectangle()
                    .fill(.surfaceElevated)
                    .overlay {
                        ProgressView()
                    }
            @unknown default:
                Rectangle()
                    .fill(.surfaceElevated)
            }
        }
    }
}

// MARK: - Helper Functions (File-level)

// Helper function to get icon for category string
private func getCategoryIcon(_ category: String) -> String {
    switch category.lowercased() {
    case "vinyl", "vinyl records":
        return "opticaldisc"
    case "sneakers", "shoes":
        return "shoe"
    case "books":
        return "book"
    case "art":
        return "paintpalette"
    case "toys", "toys & action figures":
        return "teddybear"
    case "fashion":
        return "tshirt"
    case "tech", "tech & gadgets":
        return "laptopcomputer"
    case "movies":
        return "film"
    case "video games":
        return "gamecontroller"
    case "comics":
        return "book.pages"
    case "watches":
        return "watch"
    case "trading cards", "sports cards", "pokemon cards":
        return "rectangle.stack"
    case "lego":
        return "square.stack.3d.up"
    case "tabletop gaming", "board games":
        return "dice"
    case "knives":
        return "triangle"
    case "pens":
        return "pencil"
    case "cameras":
        return "camera"
    case "coins":
        return "dollarsign.circle"
    case "stamps":
        return "envelope"
    default:
        return "square.stack.3d.up"
    }
}

#Preview {
    NavigationStack {
        CategoryBrowseView(
            category: .vinyl,
            collections: []
        )
        .environment(AppCoordinator())
    }
}
