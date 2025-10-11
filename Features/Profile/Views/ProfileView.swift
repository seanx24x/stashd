// File: Features/Profile/Views/ProfileView.swift

import SwiftUI
import SwiftData

struct ProfileView: View {
    let user: UserProfile
    
    @Environment(AuthenticationService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    
    @Query private var collections: [CollectionModel]
    
    init(user: UserProfile) {
        self.user = user
        
        let userID = user.id
        _collections = Query(
            filter: #Predicate<CollectionModel> { collection in
                collection.owner?.id == userID
            },
            sort: \CollectionModel.updatedAt,
            order: .reverse
        )
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xLarge) {
                    ProfileHeaderView(user: user)
                    
                    ProfileStatsView(
                        collections: collections.count,
                        followers: user.followers.count,
                        following: user.following.count
                    )
                    
                    Divider()
                        .padding(.horizontal, Spacing.large)
                    
                    if collections.isEmpty {
                        EmptyCollectionsView()
                    } else {
                        CollectionsGridView(collections: collections)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: CollectionModel.self) { collection in
                CollectionDetailView(collection: collection)
                    .environment(authService)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edit Profile") {
                            // Edit action
                        }
                        
                        Button("Settings") {
                            // Settings action
                        }
                        
                        Divider()
                        
                        Button("Sign Out", role: .destructive) {
                            try? authService.signOut()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
        }
    }
}

struct ProfileHeaderView: View {
    let user: UserProfile
    
    var body: some View {
        VStack(spacing: Spacing.medium) {
            Group {
                if let avatarURL = user.avatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(Color.separator, lineWidth: 1)
            }
            
            VStack(spacing: Spacing.xSmall) {
                Text(user.displayName)
                    .font(.headlineMedium)
                    .foregroundStyle(Color.textPrimary)
                
                Text("@\(user.username)")
                    .font(.bodyMedium)
                    .foregroundStyle(Color.textSecondary)
            }
            
            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .font(.bodyMedium)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.large)
            }
        }
        .padding(.top, Spacing.medium)
    }
}

struct ProfileStatsView: View {
    let collections: Int
    let followers: Int
    let following: Int
    
    var body: some View {
        HStack(spacing: Spacing.xLarge) {
            StatView(title: "Collections", value: collections)
            StatView(title: "Followers", value: followers)
            StatView(title: "Following", value: following)
        }
        .padding(.horizontal, Spacing.large)
    }
}

struct StatView: View {
    let title: String
    let value: Int
    
    var body: some View {
        VStack(spacing: Spacing.xSmall) {
            Text("\(value)")
                .font(.headlineMedium)
                .foregroundStyle(Color.textPrimary)
            
            Text(title)
                .font(.labelMedium)
                .foregroundStyle(Color.textSecondary)
        }
    }
}

struct EmptyCollectionsView: View {
    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)
            
            VStack(spacing: Spacing.small) {
                Text("No collections yet")
                    .font(.headlineSmall)
                    .foregroundStyle(Color.textPrimary)
                
                Text("Start building your first collection")
                    .font(.bodyMedium)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxLarge)
    }
}

struct CollectionsGridView: View {
    let collections: [CollectionModel]
    
    let columns = [
        GridItem(.flexible(), spacing: Spacing.small),
        GridItem(.flexible(), spacing: Spacing.small)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.small) {
            ForEach(collections) { collection in
                CollectionThumbnailView(collection: collection)
            }
        }
        .padding(.horizontal, Spacing.large)
    }
}

struct CollectionThumbnailView: View {
    let collection: CollectionModel
    
    var body: some View {
        NavigationLink(value: collection) {
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
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
                                    .font(.title)
                                    .foregroundStyle(Color.textTertiary)
                            }
                    }
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                
                Text(collection.title)
                    .font(.labelLarge)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                
                Text("\(collection.items.count) items")
                    .font(.labelSmall)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, configurations: config)
    let user = UserProfile(
        firebaseUID: "preview",
        username: "johndoe",
        displayName: "John Doe",
        bio: "Passionate collector"
    )
    container.mainContext.insert(user)
    
    return ProfileView(user: user)
        .environment(AuthenticationService())
        .modelContainer(container)
}
