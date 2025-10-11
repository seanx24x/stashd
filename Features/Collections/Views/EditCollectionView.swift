//
//  EditCollectionView.swift
//  stashd
//
//  Created by Sean Lynch on 10/10/25.
//


// File: Features/Collections/Views/EditCollectionView.swift

import SwiftUI
import SwiftData

struct EditCollectionView: View {
    let collection: CollectionModel
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var viewModel = CollectionViewModel()
    
    @State private var title: String
    @State private var description: String
    @State private var selectedCategory: CollectionCategory
    @State private var coverImage: UIImage?
    @State private var hasChanges = false
    
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case title, description
    }
    
    init(collection: CollectionModel) {
        self.collection = collection
        _title = State(initialValue: collection.title)
        _description = State(initialValue: collection.collectionDescription ?? "")
        _selectedCategory = State(initialValue: collection.category)
    }
    
    var isFormValid: Bool {
        !title.isEmpty && title.count >= 3
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xLarge) {
                    VStack(spacing: Spacing.small) {
                        Text("Edit Collection")
                            .font(.displayMedium)
                            .foregroundStyle(.textPrimary)
                        
                        Text("Update your collection details")
                            .font(.bodyLarge)
                            .foregroundStyle(.textSecondary)
                    }
                    .padding(.top, Spacing.medium)
                    
                    ImageUploader(
                        selectedImage: $coverImage,
                        placeholder: "Change Cover Image",
                        height: 200
                    )
                    .onChange(of: coverImage) { _, _ in
                        hasChanges = true
                    }
                    
                    VStack(spacing: Spacing.large) {
                        CollectTextField(
                            title: "Collection Title",
                            placeholder: "My Vinyl Collection",
                            text: $title,
                            icon: "text.alignleft"
                        )
                        .focused($focusedField, equals: .title)
                        .onChange(of: title) { _, _ in
                            hasChanges = true
                        }
                        
                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            Text("Description (Optional)")
                                .font(.labelMedium)
                                .foregroundStyle(.textSecondary)
                            
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $description)
                                    .frame(height: 100)
                                    .padding(Spacing.small)
                                    .background(.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                                            .strokeBorder(Color.separator, lineWidth: 1)
                                    }
                                    .focused($focusedField, equals: .description)
                                    .onChange(of: description) { _, _ in
                                        hasChanges = true
                                    }
                                
                                if description.isEmpty {
                                    Text("Describe your collection...")
                                        .font(.bodyMedium)
                                        .foregroundStyle(.textTertiary)
                                        .padding(.leading, Spacing.small + 4)
                                        .padding(.top, Spacing.small + 8)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                        
                        CategoryPicker(selectedCategory: $selectedCategory)
                            .onChange(of: selectedCategory) { _, _ in
                                hasChanges = true
                            }
                    }
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.bodySmall)
                            .foregroundStyle(.error)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, Spacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateCollection()
                    }
                    .foregroundStyle(Color.stashdPrimary)
                    .fontWeight(.semibold)
                    .disabled(!isFormValid || !hasChanges || viewModel.isLoading)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: Spacing.medium) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        
                        Text("Updating collection...")
                            .font(.bodyLarge)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .task {
            viewModel.configure(modelContext: modelContext)
            
            // Load existing cover image
            if let coverURL = collection.coverImageURL,
               let imageData = try? Data(contentsOf: coverURL),
               let image = UIImage(data: imageData) {
                coverImage = image
            }
        }
    }
    
    private func updateCollection() {
        Task {
            do {
                try await viewModel.updateCollection(
                    collection,
                    title: title,
                    description: description.isEmpty ? nil : description,
                    category: selectedCategory,
                    coverImage: coverImage
                )
                
                dismiss()
            } catch {
                // Error already handled in viewModel
            }
        }
    }
}

#Preview {
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
    
    return EditCollectionView(collection: collection)
        .modelContainer(container)
}
