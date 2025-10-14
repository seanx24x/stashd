//
//  UserProfileView.swift
//  stashd
//
//  Created by Sean Lynch on 10/11/25.
//

// File: Features/Profile/Views/UserProfileView.swift

import SwiftUI
import SwiftData

struct UserProfileView: View {
    let userID: UUID
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthenticationService.self) private var authService
    @Environment(AppCoordinator.self) private var coordinator
    
    @State private var viewModel: UserProfileViewModel?
    
    var isOwnProfile: Bool {
        userID == authService.currentUser?.id
    }
    
    var body: some View {
        Group {
            if let viewModel {
                ScrollView {
                    VStack(spacing: Spacing.large) {
                        // Profile Header
                        if let user = viewModel.user {
                            VStack(spacing: Spacing.medium) {
                                // Avatar
                                Circle()
                                    .fill(Color.surfaceElevated)
                                    .frame(width: 100, height: 100)
                                    .overlay {
                                        if let avatarURL = user.avatarURL {
                                            // ✅ FIXED: Use CachedAsyncImage
                                            CachedAsyncImage(url: avatarURL) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            } placeholder: {
                                                Image(systemName: "person.fill")
                                                    .font(.largeTitle)
                                                    .foregroundStyle(.textTertiary)
                                            }
                                            .clipShape(Circle())
                                        } else {
                                            Image(systemName: "person.fill")
                                                .font(.largeTitle)
                                                .foregroundStyle(.textTertiary)
                                        }
                                    }
                                    .overlay {
                                        Circle()
                                            .strokeBorder(Color.separator, lineWidth: 1)
                                    }
                                
                                // Name and Username
                                VStack(spacing: Spacing.xSmall) {
                                    Text(user.displayName)
                                        .font(.headlineLarge)
                                        .foregroundStyle(.textPrimary)
                                    
                                    Text("@\(user.username)")
                                        .font(.bodyLarge)
                                        .foregroundStyle(.textSecondary)
                                }
                                
                                // Bio
                                if let bio = user.bio, !bio.isEmpty {
                                    Text(bio)
                                        .font(.bodyMedium)
                                        .foregroundStyle(.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, Spacing.large)
                                }
                                
                                // Stats
                                HStack(spacing: Spacing.xLarge) {
                                    StatButton(
                                        value: viewModel.collectionCount,
                                        label: "Collections"
                                    ) {
                                        HapticManager.shared.selection()
                                    }
                                    
                                    StatButton(
                                        value: viewModel.followerCount,
                                        label: "Followers"
                                    ) {
                                        HapticManager.shared.selection()
                                    }
                                    
                                    StatButton(
                                        value: viewModel.followingCount,
                                        label: "Following"
                                    ) {
                                        HapticManager.shared.selection()
                                    }
                                }
                                .padding(.top, Spacing.small)
                                
                                // Follow Button (if not own profile)
                                if !isOwnProfile {
                                    Button {
                                        HapticManager.shared.light()
                                        withAnimation(.spring(response: 0.3)) {
                                            viewModel.toggleFollow()
                                        }
                                    } label: {
                                        Text(viewModel.isFollowing ? "Following" : "Follow")
                                            .font(.bodyLarge.weight(.semibold))
                                            .foregroundStyle(viewModel.isFollowing ? .textPrimary : .white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 48)
                                            .background(viewModel.isFollowing ? Color.surfaceElevated : Color.stashdPrimary)
                                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                                            .overlay {
                                                if viewModel.isFollowing {
                                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                                        .strokeBorder(Color.separator, lineWidth: 1)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, Spacing.large)
                                }
                            }
                            .padding(.top, Spacing.medium)
                            
                            Divider()
                                .padding(.horizontal, Spacing.large)
                            
                            // Collections Section
                            VStack(alignment: .leading, spacing: Spacing.medium) {
                                Text("Collections")
                                    .font(.headlineSmall)
                                    .foregroundStyle(.textPrimary)
                                    .padding(.horizontal, Spacing.large)
                                
                                if viewModel.collections.isEmpty {
                                    EmptyCollectionsStateView(isOwnProfile: isOwnProfile)
                                } else {
                                    UserCollectionsGrid(
                                        collections: viewModel.collections,
                                        onCollectionTap: { collection in
                                            HapticManager.shared.light()
                                            coordinator.navigate(to: .collectionDetail(collection.id))
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.bottom, Spacing.xxLarge)
                }
                .refreshable {
                    HapticManager.shared.light()
                    await viewModel.loadUser()
                }
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isOwnProfile {
                    Button {
                        HapticManager.shared.selection()
                        // Navigate to settings/edit profile
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.textPrimary)
                    }
                }
            }
        }
        .task {
            if viewModel == nil, let currentUser = authService.currentUser {
                viewModel = UserProfileViewModel(
                    userID: userID,
                    modelContext: modelContext,
                    currentUser: currentUser
                )
                await viewModel?.loadUser()
            }
        }
    }
}

// MARK: - Supporting Views

struct StatButton: View {
    let value: Int
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xSmall) {
                Text("\(value)")
                    .font(.headlineMedium)
                    .foregroundStyle(.textPrimary)
                    .contentTransition(.numericText())
                
                Text(label)
                    .font(.labelMedium)
                    .foregroundStyle(.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct EmptyCollectionsStateView: View {
    let isOwnProfile: Bool
    
    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundStyle(.textTertiary)
                .symbolEffect(.pulse)
            
            VStack(spacing: Spacing.small) {
                Text("No collections yet")
                    .font(.headlineSmall)
                    .foregroundStyle(.textPrimary)
                
                Text(isOwnProfile ? "Start creating collections" : "This user hasn't created any collections yet")
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxLarge)
        .padding(.horizontal, Spacing.large)
    }
}

struct UserCollectionsGrid: View {
    let collections: [CollectionModel]
    let onCollectionTap: (CollectionModel) -> Void
    
    let columns = [
        GridItem(.flexible(), spacing: Spacing.small),
        GridItem(.flexible(), spacing: Spacing.small)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.small) {
            ForEach(collections) { collection in
                Button {
                    onCollectionTap(collection)
                } label: {
                    UserCollectionThumbnail(collection: collection)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.large)
    }
}

struct UserCollectionThumbnail: View {
    let collection: CollectionModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            // ✅ FIXED: Use CachedAsyncImage
            if let coverURL = collection.coverImageURL {
                CachedAsyncImage(url: coverURL)
                    .scaledToFill()
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            } else {
                Rectangle()
                    .fill(Color.surfaceElevated)
                    .frame(height: 160)
                    .overlay {
                        // ✅ FIXED: Use categoryEnum instead of category
                        Image(systemName: collection.categoryEnum.iconName)
                            .font(.title)
                            .foregroundStyle(.textTertiary)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            
            Text(collection.title)
                .font(.labelLarge)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            
            // ✅ FIXED: Safely unwrap optional items array
            Text("\(collection.items?.count ?? 0) items")
                .font(.labelSmall)
                .foregroundStyle(.textSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: UserProfile.self, configurations: config)
        
        let user = UserProfile(
            firebaseUID: "preview",
            username: "janedoe",
            displayName: "Jane Doe",
            bio: "Sneaker collector & vinyl enthusiast"
        )
        container.mainContext.insert(user)
        
        return UserProfileView(userID: user.id)
            .environment(AuthenticationService())
            .environment(AppCoordinator())
            .modelContainer(container)
    }
}
