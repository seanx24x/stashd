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
                    AsyncImage(url: coverURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.surfaceElevated)
                            .overlay {
                                ProgressView()
                            }
                    }
                } else {
                    Rectangle()
                        .fill(Color.surfaceElevated)
                        .overlay {
                            Image(systemName: collection.category.iconName)
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
                    Label("\(collection.likes.count)", systemImage: "heart")
                    Label("\(collection.comments.count)", systemImage: "bubble.left")
                    Label("\(collection.items.count)", systemImage: "square.stack.3d.up")
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

#Preview {
    NavigationStack {
        CategoryBrowseView(
            category: .vinyl,
            collections: []
        )
        .environment(AppCoordinator())
    }
}