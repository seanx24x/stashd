//
//  ItemGridView.swift
//  stashd
//
//  Created by Sean Lynch on 10/10/25.
//


// File: Features/Collections/Components/ItemGridView.swift

import SwiftUI

struct ItemGridView: View {
    let items: [CollectionItem]
    
    let columns = [
        GridItem(.flexible(), spacing: Spacing.small),
        GridItem(.flexible(), spacing: Spacing.small)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.small) {
            ForEach(items.sorted(by: { $0.displayOrder < $1.displayOrder })) { item in
                NavigationLink(value: item) {
                    ItemThumbnailView(item: item)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.large)
    }
}

struct ItemThumbnailView: View {
    let item: CollectionItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            // Thumbnail Image
            Group {
                if let firstImageURL = item.imageURLs.first {
                    AsyncImage(url: firstImageURL) { image in
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
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundStyle(.textTertiary)
                        }
                }
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            
            // Item Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.name)
                        .font(.labelLarge)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                    
                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.error)
                    }
                }
                
                if let condition = item.condition {
                    Text(condition.rawValue)
                        .font(.labelSmall)
                        .foregroundStyle(.textSecondary)
                }
            }
        }
    }
}

#Preview {
    let item = CollectionItem(
        name: "Blue Note Classics",
        collection: CollectionModel(
            title: "Preview",
            category: .vinyl,
            owner: UserProfile(
                firebaseUID: "preview",
                username: "preview",
                displayName: "Preview"
            )
        )
    )
    item.condition = .excellent
    
    return ItemGridView(items: [item, item, item])
}