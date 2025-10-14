//
//  ActivityRowView.swift
//  stashd
//
//  Created by Sean Lynch on 10/11/25.
//


// File: Features/Notifications/Views/ActivityRowView.swift

import SwiftUI

struct ActivityRowView: View {
    let activity: ActivityItem
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.medium) {
                // Icon
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: activity.type.icon)
                            .font(.title3)
                            .foregroundStyle(iconColor)
                    }
                
                // Content
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text(activityText)
                        .font(.bodyMedium)
                        .foregroundStyle(.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Text(activity.createdAt.formatted(.relative(presentation: .named)))
                        .font(.labelSmall)
                        .foregroundStyle(.textSecondary)
                }
                
                Spacer()
                
                // Unread indicator
                if !activity.isRead {
                    Circle()
                        .fill(Color.stashdPrimary)
                        .frame(width: 8, height: 8)
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.textTertiary)
            }
            .padding(Spacing.medium)
            .background(activity.isRead ? Color.clear : Color.stashdPrimary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private var activityText: AttributedString {
        guard let actor = activity.actor else {
            return AttributedString("Someone interacted with your content")
        }
        
        var text = AttributedString()
        
        // Actor name (bold)
        var actorName = AttributedString("@\(actor.username)")
        actorName.font = .labelLarge.weight(.semibold)
        text.append(actorName)
        
        // Action
        switch activity.type {
        case .follow:
            text.append(AttributedString(" started following you"))
            
        case .like:
            if let collection = activity.collection {
                text.append(AttributedString(" liked your collection "))
                var collectionName = AttributedString("\"\(collection.title)\"")
                collectionName.font = .labelLarge.weight(.semibold)
                text.append(collectionName)
            } else {
                text.append(AttributedString(" liked your collection"))
            }
            
        case .comment:
            if let collection = activity.collection {
                text.append(AttributedString(" commented on "))
                var collectionName = AttributedString("\"\(collection.title)\"")
                collectionName.font = .labelLarge.weight(.semibold)
                text.append(collectionName)
            } else {
                text.append(AttributedString(" commented on your collection"))
            }
            
        case .mention:
            text.append(AttributedString(" mentioned you in a comment"))
        }
        
        return text
    }
    
    private var iconColor: Color {
        switch activity.type {
        case .follow:
            return .stashdPrimary
        case .like:
            return .error
        case .comment:
            return .stashdAccent
        case .mention:
            return .stashdPrimary
        }
    }
}