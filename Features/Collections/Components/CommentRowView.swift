//
//  CommentRowView.swift
//  stashd
//
//  Created by Sean Lynch on 10/10/25.
//


// File: Features/Collections/Components/CommentRowView.swift

import SwiftUI

struct CommentRowView: View {
    let comment: Comment
    let currentUserID: UUID?
    let onDelete: () -> Void
    let onProfileTap: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.small) {
            Button(action: onProfileTap) {
                Circle()
                    .fill(Color.surfaceElevated)
                    .frame(width: 32, height: 32)
                    .overlay {
                        let author = comment.author
                        if let avatarURL = author.avatarURL {
                            AsyncImage(url: avatarURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.textTertiary)
                            }
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                                .foregroundStyle(.textTertiary)
                        }
                    }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                HStack(spacing: Spacing.xSmall) {
                    let author = comment.author
                    Button(action: onProfileTap) {
                        Text(author.displayName)
                            .font(.labelMedium.weight(.semibold))
                            .foregroundStyle(.textPrimary)
                    }
                    .buttonStyle(.plain)
                    
                    Text("@\(author.username)")
                        .font(.labelSmall)
                        .foregroundStyle(.textSecondary)
                    
                    Text("·")
                        .foregroundStyle(.textTertiary)
                    
                    Text(comment.createdAt.formatted(.relative(presentation: .named)))
                        .font(.labelSmall)
                        .foregroundStyle(.textTertiary)
                    
                    Spacer()
                    
                    if comment.author.id == currentUserID {
                        Menu {
                            Button("Delete", role: .destructive, action: onDelete)
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption)
                                .foregroundStyle(.textTertiary)
                        }
                    }
                }
                
                Text(comment.content)
                    .font(.bodyMedium)
                    .foregroundStyle(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Spacing.small)
    }
}