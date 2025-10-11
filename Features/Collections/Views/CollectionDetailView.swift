//
//  CollectionDetailView.swift
//  stashd
//
//  Created by Sean Lynch on 10/10/25.
//


// File: Features/Collections/Views/CollectionDetailView.swift

import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    let collection: CollectionModel
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthenticationService.self) private var authService
    
    @State private var viewModel = CollectionViewModel()
    @State private var showAddItem = false
    @State private var showEditCollection = false
    @State private var showDeleteAlert = false
    
    var isOwner: Bool {
        collection.owner?.id == authService.currentUser?.id
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero Cover Image
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
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.stashdPrimary.opacity(0.3),
                                    Color.stashdAccent.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 300)
                        .overlay {
                            Image(systemName: collection.category.iconName)
                                .font(.system(size: 80))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                }
                
                VStack(alignment: .leading, spacing: Spacing.large) {
                    // Collection Info
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                                Text(collection.title)
                                    .font(.displayMedium)
                                    .foregroundStyle(.textPrimary)
                                
                                HStack(spacing: Spacing.small) {
                                    Image(systemName: collection.category.iconName)
                                        .font(.labelMedium)
                                    Text(collection.category.rawValue)
                                        .font(.labelLarge)
                                }
                                .foregroundStyle(.textSecondary)
                            }
                            
                            Spacer()
                            
                            if isOwner {
                                Menu {
                                    Button {
                                        showEditCollection = true
                                    } label: {
                                        Label("Edit Collection", systemImage: "pencil")
                                    }
                                    
                                    Button {
                                        // Share action
                                    } label: {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive) {
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Delete Collection", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title2)
                                        .foregroundStyle(.textPrimary)
                                }
                            }
                        }
                        
                        if let description = collection.collectionDescription, !description.isEmpty {
                            Text(description)
                                .font(.bodyLarge)
                                .foregroundStyle(.textSecondary)
                        }
                        
                        // Stats
                        HStack(spacing: Spacing.large) {
                            StatLabel(
                                icon: "square.stack.3d.up.fill",
                                value: collection.items.count,
                                label: "Items"
                            )
                            
                            StatLabel(
                                icon: "heart.fill",
                                value: collection.likes.count,
                                label: "Likes"
                            )
                            
                            StatLabel(
                                icon: "eye.fill",
                                value: collection.viewCount,
                                label: "Views"
                            )
                        }
                        .padding(.top, Spacing.small)
                    }
                    .padding(.horizontal, Spacing.large)
                    .padding(.top, Spacing.large)
                    
                    Divider()
                        .padding(.horizontal, Spacing.large)
                    
                    // Items Section
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        HStack {
                            Text("Items")
                                .font(.headlineSmall)
                                .foregroundStyle(.textPrimary)
                            
                            Spacer()
                            
                            if isOwner {
                                Button {
                                    showAddItem = true
                                } label: {
                                    HStack(spacing: Spacing.xSmall) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Item")
                                    }
                                    .font(.labelLarge.weight(.semibold))
                                    .foregroundStyle(Color.stashdPrimary)
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.large)
                        
                        if collection.items.isEmpty {
                            EmptyItemsView(isOwner: isOwner) {
                                showAddItem = true
                            }
                        } else {
                            ItemGridView(items: collection.items)
                        }
                    }
                }
                .padding(.bottom, Spacing.xxLarge)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(collection.title)
                    .font(.headline)
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddItemView(collection: collection)
                .environment(authService)
        }
        .sheet(isPresented: $showEditCollection) {
            EditCollectionView(collection: collection)
                .environment(authService)
        }
        .alert("Delete Collection?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteCollection()
            }
        } message: {
            Text("This will permanently delete '\(collection.title)' and all its items. This action cannot be undone.")
        }
        .task {
            viewModel.configure(modelContext: modelContext)
        }
    }
    
    private func deleteCollection() {
        viewModel.deleteCollection(collection)
        dismiss()
    }
}

struct StatLabel: View {
    let icon: String
    let value: Int
    let label: String
    
    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            Image(systemName: icon)
                .font(.labelMedium)
                .foregroundStyle(Color.stashdPrimary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.labelLarge.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                
                Text(label)
                    .font(.labelSmall)
                    .foregroundStyle(.textSecondary)
            }
        }
    }
}

struct EmptyItemsView: View {
    let isOwner: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "photo.stack")
                .font(.system(size: 48))
                .foregroundStyle(.textTertiary)
            
            VStack(spacing: Spacing.small) {
                Text(isOwner ? "No items yet" : "This collection is empty")
                    .font(.headlineSmall)
                    .foregroundStyle(.textPrimary)
                
                Text(isOwner ? "Add your first item to start building your collection" : "Check back later for updates")
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if isOwner {
                Button {
                    action()
                } label: {
                    HStack(spacing: Spacing.small) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add First Item")
                    }
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.large)
                    .padding(.vertical, Spacing.medium)
                    .background(Color.stashdPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxLarge)
        .padding(.horizontal, Spacing.large)
    }
}

#Preview {
    NavigationStack {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: CollectionModel.self, configurations: config)
        
        let user = UserProfile(
            firebaseUID: "preview",
            username: "johndoe",
            displayName: "John Doe"
        )
        
        let collection = CollectionModel(
            title: "My Vinyl Collection",
            category: .vinyl,
            owner: user
        )
        collection.collectionDescription = "A curated collection of classic records"
        
        container.mainContext.insert(user)
        container.mainContext.insert(collection)
        
        return CollectionDetailView(collection: collection)
            .environment(AuthenticationService())
            .modelContainer(container)
    }
}
