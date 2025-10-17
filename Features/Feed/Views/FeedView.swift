// File: Features/Feed/Views/FeedView.swift

import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(AuthenticationService.self) private var authService
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    
    @State private var viewModel: FeedViewModel?
    
    var body: some View {
        @Bindable var bindableCoordinator = coordinator
        
        NavigationStack(path: $bindableCoordinator.navigationPath) {
            Group {
                if let viewModel {
                    ScrollView {
                        LazyVStack(spacing: Spacing.large) {
                            if viewModel.isLoading && viewModel.feedItems.isEmpty {
                                // Skeleton Loading
                                ForEach(0..<3, id: \.self) { _ in
                                    SkeletonFeedCard()
                                }
                            } else if viewModel.feedItems.isEmpty {
                                EmptyFeedView()
                            } else {
                                ForEach(viewModel.feedItems) { collection in
                                    CollectionFeedCard(
                                        collection: collection,
                                        isLiked: viewModel.isLiked(collection),
                                        onLikeTapped: {
                                            withAnimation(.spring(response: 0.3)) {
                                                viewModel.toggleLike(for: collection)
                                            }
                                        },
                                        onCommentTapped: {
                                            coordinator.navigate(to: .collectionDetail(collection.id))
                                        },
                                        onProfileTapped: {
                                            if let ownerID = collection.owner?.id {
                                                coordinator.navigate(to: .userProfile(ownerID))
                                            }
                                        }
                                    )
                                    .onTapGesture {
                                        coordinator.navigate(to: .collectionDetail(collection.id))
                                    }
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                    .onAppear {
                                        if collection == viewModel.feedItems.last {
                                            Task {
                                                await viewModel.loadMore()
                                            }
                                        }
                                    }
                                }
                                
                                if viewModel.isLoading {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .padding(.vertical, Spacing.medium)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.large)
                        .padding(.vertical, Spacing.medium)
                    }
                    .refreshable {
                        HapticManager.shared.light()
                        await viewModel.loadFeed()
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
            .toolbar {
                // ✅ NEW: Add sync status on the left
                ToolbarItem(placement: .topBarLeading) {
                    SyncStatusView()
                }
                
                // Existing filter button on the right
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.shared.selection()
                        // Settings or filter
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(.textPrimary)
                    }
                }
            }
        }
        .task {
            if viewModel == nil, let currentUser = authService.currentUser {
                viewModel = FeedViewModel(modelContext: modelContext, currentUser: currentUser)
                await viewModel?.loadFeed()
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
            
        case .itemDetail(let itemID):
            ItemDetailViewLoader(itemID: itemID)
            
        case .editCollection(let collectionID):
            Text("Edit Collection")
            
        case .settings:
            Text("Settings")
            
        case .categoryBrowse(let category):
            Text("Browse \(category.rawValue)")
            
        case .pricePrediction(let itemID):  // ✅ ADD THIS
            PricePredictionViewLoader(itemID: itemID)
        }
    }
}
// MARK: - Empty Feed View

struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: Spacing.large) {
            Spacer()
            
            Image(systemName: "person.2.slash")
                .font(.system(size: 64))
                .foregroundStyle(.textTertiary)
                .symbolEffect(.pulse)
            
            VStack(spacing: Spacing.small) {
                Text("Your feed is empty")
                    .font(.headlineMedium)
                    .foregroundStyle(.textPrimary)
                
                Text("Follow other collectors to see their collections here")
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            
            Spacer()
        }
        .padding(.horizontal, Spacing.large)
    }
}
