// File: Features/Profile/Views/ProfileView.swift

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(AuthenticationService.self) private var authService
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \CollectionModel.updatedAt, order: .reverse)
    private var allCollections: [CollectionModel]
    
    @State private var showSettings = false
    @State private var nlSearchText = ""
    @State private var isNLSearching = false
    @State private var nlSearchResults: [CollectionItem] = []
    @State private var showNLResults = false
    
    private var userCollections: [CollectionModel] {
        guard let currentUser = authService.currentUser else { return [] }
        return allCollections.filter { $0.owner?.id == currentUser.id }
    }
    
    var body: some View {
        @Bindable var bindableCoordinator = coordinator
        
        NavigationStack(path: $bindableCoordinator.navigationPath) {
            ScrollView {
                VStack(spacing: Spacing.xLarge) {
                    // Profile Header
                    if let currentUser = authService.currentUser {
                        ProfileHeaderView(user: currentUser)
                    }
                    
                    // ✅ NATURAL LANGUAGE SEARCH
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("Ask about your collection")
                            .font(.labelMedium)
                            .foregroundStyle(.textSecondary)
                            .padding(.horizontal, Spacing.large)
                        
                        NaturalLanguageSearchBar(
                            searchText: $nlSearchText,
                            isSearching: $isNLSearching,
                            placeholder: "e.g., 'Show expensive Nike sneakers'",
                            onSearch: performNLSearch
                        )
                        .padding(.horizontal, Spacing.large)
                    }
                    
                    // ✅ SHOW NL SEARCH RESULTS IF ACTIVE
                    if showNLResults {
                        nlSearchResultsSection
                    }
                    
                    // Collections Section
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        HStack {
                            Text("My Collections")
                                .font(.headlineSmall)
                                .foregroundStyle(.textPrimary)
                            
                            Spacer()
                            
                            Text("\(userCollections.count)")
                                .font(.labelLarge)
                                .foregroundStyle(.textSecondary)
                        }
                        .padding(.horizontal, Spacing.large)
                        
                        if userCollections.isEmpty {
                            EmptyCollectionsView()
                        } else {
                            LazyVStack(spacing: Spacing.medium) {
                                ForEach(userCollections) { collection in
                                    Button {
                                        HapticManager.shared.light()
                                        coordinator.navigate(to: .collectionDetail(collection.id))
                                    } label: {
                                        ProfileCollectionCard(collection: collection)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, Spacing.large)
                        }
                    }
                }
                .padding(.vertical, Spacing.large)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
            .toolbar {
                // Sync status on the left
                ToolbarItem(placement: .topBarLeading) {
                    SyncStatusView()
                }
                
                // Settings button on the right
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.shared.selection()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
    
    // ✅ NL SEARCH RESULTS SECTION
    private var nlSearchResultsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search Results")
                        .font(.headlineSmall.weight(.semibold))
                        .foregroundStyle(.textPrimary)
                    
                    Text("\(nlSearchResults.count) items found")
                        .font(.labelSmall)
                        .foregroundStyle(.textSecondary)
                }
                
                Spacer()
                
                Button {
                    HapticManager.shared.light()
                    clearNLSearch()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                        Text("Clear")
                            .font(.labelMedium)
                    }
                    .foregroundStyle(Color.stashdPrimary)
                }
            }
            .padding(.horizontal, Spacing.large)
            
            if nlSearchResults.isEmpty {
                VStack(spacing: Spacing.medium) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.textTertiary)
                    
                    Text("No items match your search")
                        .font(.bodyLarge)
                        .foregroundStyle(.textSecondary)
                    
                    Text("Try different keywords or filters")
                        .font(.bodySmall)
                        .foregroundStyle(.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xLarge)
            } else {
                LazyVStack(spacing: Spacing.medium) {
                    ForEach(nlSearchResults) { item in
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            ItemRowCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.large)
            }
        }
    }
    
    // ✅ NL SEARCH ACTIONS
    private func performNLSearch() {
        guard !nlSearchText.isEmpty else { return }
        
        Task {
            isNLSearching = true
            
            do {
                print("🔍 Starting NL search: '\(nlSearchText)'")
                
                // Parse natural language query
                let query = try await NaturalLanguageSearchService.shared.parseQuery(nlSearchText)
                
                // Execute search across all user's collections
                let results = NaturalLanguageSearchService.shared.search(
                    query: query,
                    in: userCollections,
                    context: modelContext
                )
                
                await MainActor.run {
                    nlSearchResults = results
                    showNLResults = true
                    isNLSearching = false
                    HapticManager.shared.success()
                }
                
                print("✅ NL Search complete: \(results.count) items found")
                
            } catch {
                await MainActor.run {
                    isNLSearching = false
                    showNLResults = true
                    nlSearchResults = []
                    HapticManager.shared.error()
                }
                print("❌ NL Search failed: \(error)")
            }
        }
    }
    
    private func clearNLSearch() {
        nlSearchText = ""
        nlSearchResults = []
        showNLResults = false
    }
    
    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .collectionDetail(let collectionID):
            CollectionDetailViewLoader(collectionID: collectionID)
            
        case .userProfile(let userID):
            UserProfileView(userID: userID)
            
        case .itemDetail(let itemID):
            ItemDetailViewLoader(itemID: itemID)
            
        case .editCollection(let collectionID):
            Text("Edit Collection")
            
        case .settings:
            SettingsView()
            
        case .categoryBrowse(let category):
            Text("Browse \(category.rawValue)")
            
        case .pricePrediction(let itemID):  // ✅ ADD THIS
            PricePredictionViewLoader(itemID: itemID)
        }
    }
}

// MARK: - Profile Header

struct ProfileHeaderView: View {
    let user: UserProfile
    
    var body: some View {
        VStack(spacing: Spacing.medium) {
            // Avatar
            Circle()
                .fill(Color.stashdPrimary.opacity(0.2))
                .frame(width: 100, height: 100)
                .overlay {
                    Text(user.displayName.prefix(1).uppercased())
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Color.stashdPrimary)
                }
            
            // Name & Username
            VStack(spacing: Spacing.xSmall) {
                Text(user.displayName)
                    .font(.headlineLarge)
                    .foregroundStyle(.textPrimary)
                
                Text("@\(user.username)")
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
            }
            
            // Bio
            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            
            // Stats
            HStack(spacing: Spacing.xLarge) {
                StatView(value: "0", label: "Followers")
                StatView(value: "0", label: "Following")
            }
        }
        .padding(.horizontal, Spacing.large)
    }
}

struct StatView: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: Spacing.xSmall) {
            Text(value)
                .font(.headlineMedium)
                .foregroundStyle(.textPrimary)
            
            Text(label)
                .font(.labelMedium)
                .foregroundStyle(.textSecondary)
        }
    }
}

// MARK: - Profile Collection Card

struct ProfileCollectionCard: View {
    let collection: CollectionModel
    
    var body: some View {
        HStack(spacing: Spacing.medium) {
            // Cover Image
            if let coverURL = collection.coverImageURL {
                CachedAsyncImage(url: coverURL)
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            } else {
                Rectangle()
                    .fill(Color.surfaceElevated)
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: collection.categoryEnum.iconName)
                            .font(.title)
                            .foregroundStyle(.textTertiary)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            
            // Info
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(collection.title)
                    .font(.labelLarge.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2)
                
                Label(collection.categoryEnum.rawValue, systemImage: collection.categoryEnum.iconName)
                    .font(.labelSmall)
                    .foregroundStyle(.textSecondary)
                
                HStack(spacing: Spacing.small) {
                    if collection.likes.count > 0 {
                        Label("\(collection.likes.count)", systemImage: "heart")
                    }
                    Label("\(collection.items?.count ?? 0)", systemImage: "square.stack.3d.up")
                }
                .font(.labelSmall)
                .foregroundStyle(.textTertiary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.textTertiary)
        }
        .padding(Spacing.medium)
        .background(.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Empty Collections View

struct EmptyCollectionsView: View {
    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 64))
                .foregroundStyle(.textTertiary)
            
            VStack(spacing: Spacing.small) {
                Text("No collections yet")
                    .font(.headlineMedium)
                    .foregroundStyle(.textPrimary)
                
                Text("Create your first collection to get started")
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxLarge)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CollectionModel.self, configurations: config)
    
    return ProfileView()
        .environment(AuthenticationService())
        .environment(AppCoordinator())
        .modelContainer(container)
}
