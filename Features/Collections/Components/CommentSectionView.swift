//
//  CommentSectionView.swift
//  stashd
//
//  Created by Sean Lynch on 10/10/25.
//


// File: Features/Collections/Components/CommentSectionView.swift

import SwiftUI

struct CommentSectionView: View {
    let collection: CollectionModel
    @Bindable var viewModel: CollectionDetailViewModel
    let currentUserID: UUID?
    let onProfileTap: (UUID) -> Void
    
    @FocusState private var isCommentFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Text("Comments")
                    .font(.headlineSmall)
                    .foregroundStyle(.textPrimary)
                
                Spacer()
                
                Text("\(collection.comments.count)")
                    .font(.labelMedium)
                    .foregroundStyle(.textSecondary)
            }
            .padding(.horizontal, Spacing.large)
            
            VStack(spacing: Spacing.small) {
                HStack(alignment: .top, spacing: Spacing.small) {
                    TextField("Add a comment...", text: $viewModel.commentText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...6)
                        .focused($isCommentFocused)
                    
                    if !viewModel.commentText.isEmpty {
                        Button {
                            Task {
                                await viewModel.postComment(for: collection)
                                isCommentFocused = false
                            }
                        } label: {
                            if viewModel.isSubmittingComment {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.stashdPrimary)  // ← Changed this line
                            }
                        }
                        .disabled(viewModel.isSubmittingComment)
                    }
                }
                .padding(Spacing.medium)
                .background(.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .strokeBorder(
                            isCommentFocused ? Color.stashdPrimary : Color.separator,
                            lineWidth: isCommentFocused ? 2 : 1
                        )
                }
                .animation(.smooth(duration: 0.2), value: isCommentFocused)
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.labelSmall)
                        .foregroundStyle(.error)
                }
            }
            .padding(.horizontal, Spacing.large)
            
            if viewModel.sortedComments(for: collection).isEmpty {
                VStack(spacing: Spacing.small) {
                    Image(systemName: "bubble.left")
                        .font(.title)
                        .foregroundStyle(.textTertiary)
                    
                    Text("No comments yet")
                        .font(.bodyMedium)
                        .foregroundStyle(.textSecondary)
                    
                    Text("Be the first to comment")
                        .font(.labelMedium)
                        .foregroundStyle(.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xLarge)
            } else {
                LazyVStack(alignment: .leading, spacing: Spacing.medium) {
                    ForEach(viewModel.sortedComments(for: collection)) { comment in
                        CommentRowView(
                            comment: comment,
                            currentUserID: currentUserID,
                            onDelete: {
                                viewModel.deleteComment(comment)
                            },
                            onProfileTap: {
                                onProfileTap(comment.author.id)
                            }
                        )
                        .padding(.horizontal, Spacing.large)
                        
                        if comment.id != viewModel.sortedComments(for: collection).last?.id {
                            Divider()
                                .padding(.horizontal, Spacing.large)
                        }
                    }
                }
            }
        }
    }
}
