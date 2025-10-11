//
//  CreateCollectionView.swift
//  stashd
//
//  Created by Sean Lynch on 10/10/25.
//


// File: Features/Collections/Views/CreateCollectionView.swift

import SwiftUI
import SwiftData

struct CreateCollectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthenticationService.self) private var authService
    
    @State private var viewModel = CollectionViewModel()
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedCategory: CollectionCategory = .other
    @State private var coverImage: UIImage?
    @State private var showError = false
    
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case title, description
    }
    
    var isFormValid: Bool {
        !title.isEmpty && title.count >= 3
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xLarge) {
                    VStack(spacing: Spacing.small) {
                        Text("Create Collection")
                            .font(.displayMedium)
                            .foregroundStyle(.textPrimary)
                        
                        Text("Start showcasing your collection")
                            .font(.bodyLarge)
                            .foregroundStyle(.textSecondary)
                    }
                    .padding(.top, Spacing.medium)
                    
                    ImageUploader(
                        selectedImage: $coverImage,
                        placeholder: "Add Cover Image",
                        height: 200
                    )
                    
                    VStack(spacing: Spacing.large) {
                        CollectTextField(
                            title: "Collection Title",
                            placeholder: "My Vinyl Collection",
                            text: $title,
                            icon: "text.alignleft"
                        )
                        .focused($focusedField, equals: .title)
                        
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
                    Button("Create") {
                        createCollection()
                    }
                    .foregroundStyle(Color.stashdPrimary)
                    .fontWeight(.semibold)
                    .disabled(!isFormValid || viewModel.isLoading)
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
                        
                        Text("Creating collection...")
                            .font(.bodyLarge)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .task {
            viewModel.configure(modelContext: modelContext)
        }
    }
    
    private func createCollection() {
        guard let currentUser = authService.currentUser else { return }
        
        Task {
            do {
                try await viewModel.createCollection(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    category: selectedCategory,
                    coverImage: coverImage,
                    owner: currentUser
                )
                
                dismiss()
            } catch {
                showError = true
            }
        }
    }
}

#Preview {
    CreateCollectionView()
        .environment(AuthenticationService())
        .modelContainer(for: [UserProfile.self, CollectionModel.self], inMemory: true)
}
