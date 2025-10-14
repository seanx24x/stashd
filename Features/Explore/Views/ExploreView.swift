// File: Features/Explore/Views/ExploreView.swift

import SwiftUI
import SwiftData

struct ExploreView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppCoordinator.self) private var coordinator
    
    @State private var viewModel: ExploreViewModel?
    @State private var showSearch = false
    
    var body: some View {
        @Bindable var bindableCoordinator = coordinator
        
        NavigationStack(path: $bindableCoordinator.navigationPath) {
            Group {
                if let viewModel {
                    if viewModel.isLoading && viewModel.allCollections.isEmpty {
                        ScrollView {
                            VStack(spacing: Spacing.large) {
                                ForEach(0..<6, id: \.self) { _ in
                                    SkeletonCollectionCard()
                                }
                            }
                            .padding(.horizontal, Spacing.large)
                            .padding(.vertical, Spacing.medium)
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: Spacing.xLarge) {
                                // Search Bar
                                if showSearch {
                                    SearchBarView(searchText: Binding(
                                        get: { viewModel.searchText },
                                        set: { viewModel.searchText = $0 }
                                    ))
                                    .padding(.horizontal, Spacing.large)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                                
                                // Categories Section
                                CategoriesSection(
                                    onCategoryTap: { category in
                                        HapticManager.shared.light()
                                        coordinator.navigate(to: .categoryBrowse(category))
                                    }
                                )
                                
                                // Trending Collections
                                if !viewModel.trendingCollections.isEmpty {
                                    CollectionSection(
                                        title: "Trending",
                                        collections: viewModel.trendingCollections,
                                        onCollectionTap: { collection in
                                            coordinator.navigate(to: .collectionDetail(collection.id))
                                        }
                                    )
                                }
                                
                                // Recent Collections
                                if !viewModel.recentCollections.isEmpty {
                                    CollectionSection(
                                        title: "Recently Updated",
                                        collections: viewModel.recentCollections,
                                        onCollectionTap: { collection in
                                            coordinator.navigate(to: .collectionDetail(collection.id))
                                        }
                                    )
                                }
                                
                                // All Collections
                                if !viewModel.filteredCollections.isEmpty {
                                    AllCollectionsSection(
                                        collections: viewModel.filteredCollections,
                                        onCollectionTap: { collection in
                                            coordinator.navigate(to: .collectionDetail(collection.id))
                                        }
                                    )
                                } else if viewModel.allCollections.isEmpty {
                                    EmptyExploreView()
                                }
                            }
                            .padding(.vertical, Spacing.medium)
                        }
                        .refreshable {
                            HapticManager.shared.light()
                            await viewModel.loadAllCollections()
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.3)) {
                            showSearch.toggle()
                        }
                    } label: {
                        Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                            .foregroundStyle(.textPrimary)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SearchByTag"))) { notification in
                if let tag = notification.userInfo?["tag"] as? String,
                   let viewModel = viewModel {
                    viewModel.searchByTag(tag)
                    showSearch = true
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ExploreViewModel(modelContext: modelContext)
                await viewModel?.loadAllCollections()
            }
        }
    }
    
    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .collectionDetail(let collectionID):
            CollectionDetailViewLoader(collectionID: collectionID)
            
        case .userProfile(let userID):
            UserProfileView(userID: userID)
            
        case .categoryBrowse(let category):
            if let viewModel {
                CategoryBrowseView(
                    category: category,
                    collections: viewModel.collectionsForCategory(category)
                )
            }
            
        case .itemDetail(let itemID):
            ItemDetailViewLoader(itemID: itemID)
            
        case .editCollection(let collectionID):
            Text("Edit Collection")
            
        case .settings:
            Text("Settings")
        }
    }
}


// MARK: - Supporting Views

struct SearchBarView: View {
    @Binding var searchText: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.textTertiary)
            
            TextField("Search collections, users...", text: $searchText)
                .textInputAutocapitalization(.never)
                .focused($isFocused)
            
            if !searchText.isEmpty {
                Button {
                    HapticManager.shared.light()
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.textTertiary)
                }
            }
        }
        .padding(Spacing.medium)
        .background(.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .onAppear {
            isFocused = true
        }
    }
}

struct CategoriesSection: View {
    let onCategoryTap: (CollectionCategory) -> Void
    
    let columns = [
        GridItem(.flexible(), spacing: Spacing.medium),
        GridItem(.flexible(), spacing: Spacing.medium)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Categories")
                .font(.headlineSmall)
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, Spacing.large)
            
            LazyVGrid(columns: columns, spacing: Spacing.medium) {
                ForEach(CollectionCategory.allCases, id: \.self) { category in
                    Button {
                        onCategoryTap(category)
                    } label: {
                        CategoryCard(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.large)
        }
    }
}

struct CategoryCard: View {
    let category: CollectionCategory
    
    var body: some View {
        VStack(spacing: Spacing.small) {
            Image(systemName: category.iconName)
                .font(.system(size: 32))
                .foregroundStyle(Color.stashdPrimary)
            
            Text(category.rawValue)
                .font(.labelLarge)
                .foregroundStyle(.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

struct CollectionSection: View {
    let title: String
    let collections: [CollectionModel]
    let onCollectionTap: (CollectionModel) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text(title)
                .font(.headlineSmall)
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, Spacing.large)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.medium) {
                    ForEach(collections) { collection in
                        Button {
                            HapticManager.shared.light()
                            onCollectionTap(collection)
                        } label: {
                            HorizontalCollectionCard(collection: collection)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.large)
            }
        }
    }
}

struct HorizontalCollectionCard: View {
    let collection: CollectionModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            // Cover Image - SUPER CLEAN NOW! ✨
            if let coverURL = collection.coverImageURL {
                CachedAsyncImage(url: coverURL)
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            } else {
                Rectangle()
                    .fill(Color.surfaceElevated)
                    .frame(width: 200, height: 200)
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
                    .lineLimit(1)
                
                if let owner = collection.owner {
                    Text("by @\(owner.username)")
                        .font(.labelSmall)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: Spacing.small) {
                    if collection.likes.count > 0 {
                        Label("\(collection.likes.count)", systemImage: "heart")
                    }
                    Label("\(collection.items?.count ?? 0)", systemImage: "square.stack.3d.up")
                }
                .font(.labelSmall)
                .foregroundStyle(.textTertiary)
            }
        }
        .frame(width: 200)
    }
}

struct AllCollectionsSection: View {
    let collections: [CollectionModel]
    let onCollectionTap: (CollectionModel) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("All Collections")
                .font(.headlineSmall)
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, Spacing.large)
            
            LazyVStack(spacing: Spacing.medium) {
                ForEach(collections) { collection in
                    Button {
                        HapticManager.shared.light()
                        onCollectionTap(collection)
                    } label: {
                        ExploreCollectionCard(collection: collection)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.large)
        }
    }
}

struct ExploreCollectionCard: View {
    let collection: CollectionModel
    
    var body: some View {
        HStack(spacing: Spacing.medium) {
            // Thumbnail - SIMPLE! ✨
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
                
                if let owner = collection.owner {
                    Text("@\(owner.username)")
                        .font(.labelSmall)
                        .foregroundStyle(.textSecondary)
                }
                
                HStack(spacing: Spacing.small) {
                    if collection.likes.count > 0 {
                        Label("\(collection.likes.count)", systemImage: "heart")
                    }
                    Label("\(collection.items?.count ?? 0)", systemImage: "square.stack.3d.up")
                    Label(collection.categoryEnum.rawValue, systemImage: collection.categoryEnum.iconName)
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
    }
}

struct EmptyExploreView: View {
    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 64))
                .foregroundStyle(.textTertiary)
                .symbolEffect(.pulse)
            
            VStack(spacing: Spacing.small) {
                Text("No collections yet")
                    .font(.headlineSmall)
                    .foregroundStyle(.textPrimary)
                
                Text("Be the first to create a collection")
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxLarge)
    }
}

#Preview {
    ExploreView()
        .environment(AppCoordinator())
        .modelContainer(for: [CollectionModel.self], inMemory: true)
}
