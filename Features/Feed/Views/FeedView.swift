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
                                ProgressView()
                                    .padding(.top, Spacing.xxLarge)
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
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.large)
                        .padding(.vertical, Spacing.medium)
                    }
                    .refreshable {
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
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
            // Find the collection from the ID
            if let collection = viewModel?.feedItems.first(where: { $0.id == collectionID }) {
                CollectionDetailView(collection: collection)
            } else {
                // Fallback if not found in feed
                CollectionDetailViewLoader(collectionID: collectionID)
            }
            
        case .userProfile(let userID):
            Text("User Profile: \(userID)")
            
        case .itemDetail(let itemID):
            Text("Item Detail")
            
        case .editCollection(let collectionID):
            Text("Edit Collection")
            
        case .settings:
            Text("Settings")
            
        case .categoryBrowse(let category):
            Text("Browse \(category.rawValue)")
        }
    }
}

// Helper view to load collection by ID if not in feed
struct CollectionDetailViewLoader: View {
    let collectionID: UUID
    
    @Environment(\.modelContext) private var modelContext
    @State private var collection: CollectionModel?
    
    var body: some View {
        Group {
            if let collection {
                CollectionDetailView(collection: collection)
            } else {
                ProgressView()
                    .task {
                        loadCollection()
                    }
            }
        }
    }
    
    private func loadCollection() {
        let descriptor = FetchDescriptor<CollectionModel>(
            predicate: #Predicate { $0.id == collectionID }
        )
        collection = try? modelContext.fetch(descriptor).first
    }
}

struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: Spacing.large) {
            Spacer()
            
            Image(systemName: "person.2.slash")
                .font(.system(size: 64))
                .foregroundStyle(.textTertiary)
            
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
