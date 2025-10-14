//
//  CollectionFeedCard.swift
//  stashd
//
//  Created by Sean Lynch on 10/10/25.
//

// File: Features/Feed/Views/CollectionFeedCard.swift

import SwiftUI
import SwiftData

struct CollectionFeedCard: View {
    let collection: CollectionModel
    let isLiked: Bool
    let onLikeTapped: () -> Void
    let onCommentTapped: () -> Void
    let onProfileTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            // Header with user info
            if let owner = collection.owner {
                Button(action: onProfileTapped) {
                    HStack(spacing: Spacing.small) {
                        Circle()
                            .fill(Color.surfaceElevated)
                            .frame(width: 40, height: 40)
                            .overlay {
                                if let avatarURL = owner.avatarURL {
                                    CachedAsyncImage(url: avatarURL) { image in  // ← CHANGED TO CachedAsyncImage
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Image(systemName: "person.fill")
                                            .font(.caption)
                                            .foregroundStyle(.textTertiary)
                                    }
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.caption)
                                        .foregroundStyle(.textTertiary)
                                }
                            }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(owner.displayName)
                                .font(.labelLarge)
                                .foregroundStyle(.textPrimary)
                            
                            Text("@\(owner.username)")
                                .font(.labelSmall)
                                .foregroundStyle(.textSecondary)
                        }
                        
                        Spacer()
                        
                        Text(collection.createdAt.formatted(.relative(presentation: .named)))
                            .font(.labelSmall)
                            .foregroundStyle(.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            
            // Collection content
            VStack(alignment: .leading, spacing: Spacing.small) {
                // Cover image
                if let coverURL = collection.coverImageURL {
                    CachedAsyncImage(url: coverURL) { image in  // ← CHANGED TO CachedAsyncImage
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
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                } else {
                    // Placeholder with category icon
                    Rectangle()
                        .fill(Color.surfaceElevated)
                        .frame(height: 300)
                        .overlay {
                            VStack(spacing: Spacing.small) {
                                Image(systemName: collection.category.iconName)
                                    .font(.system(size: 48))
                                    .foregroundStyle(.textTertiary)
                                
                                Text(collection.category.rawValue)
                                    .font(.labelMedium)
                                    .foregroundStyle(.textSecondary)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }
                
                // Title and description
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text(collection.title)
                        .font(.headlineSmall)
                        .foregroundStyle(.textPrimary)
                    
                    if let description = collection.collectionDescription, !description.isEmpty {
                        Text(description)
                            .font(.bodyMedium)
                            .foregroundStyle(.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: Spacing.large) {
                // Like button
                Button {
                    HapticManager.shared.medium()
                    onLikeTapped()
                } label: {
                    HStack(spacing: Spacing.xSmall) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundStyle(isLiked ? .error : .textSecondary)
                            .symbolEffect(.bounce, value: isLiked)
                        
                        if collection.likes.count > 0 {
                            Text("\(collection.likes.count)")
                                .font(.labelMedium)
                                .foregroundStyle(.textSecondary)
                                .contentTransition(.numericText())
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // Comment button
                Button {
                    HapticManager.shared.light()
                    onCommentTapped()
                } label: {
                    HStack(spacing: Spacing.xSmall) {
                        Image(systemName: "bubble.left")
                            .foregroundStyle(.textSecondary)
                        
                        if collection.comments.count > 0 {
                            Text("\(collection.comments.count)")
                                .font(.labelMedium)
                                .foregroundStyle(.textSecondary)
                                .contentTransition(.numericText())
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // Item count
                HStack(spacing: Spacing.xSmall) {
                    Image(systemName: "square.stack.3d.up")
                        .foregroundStyle(.textSecondary)
                    
                    Text("\(collection.items.count)")
                        .font(.labelMedium)
                        .foregroundStyle(.textSecondary)
                }
                
                Spacer()
            }
        }
        .padding(Spacing.medium)
        .background(.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .id(collection.id)  // ← ADD STABLE ID FOR PERFORMANCE
    }
}
