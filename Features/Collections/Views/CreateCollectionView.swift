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
    @State private var validationError: String? = nil  // ← ADDED
    
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case title, description
    }
    
    // ← UPDATED VALIDATION
    var isFormValid: Bool {
        title.sanitized.isValidCollectionName
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
                        // ← TITLE FIELD WITH VALIDATION
                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            CollectTextField(
                                title: "Collection Title",
                                placeholder: "My Vinyl Collection",
                                text: $title,
                                icon: "text.alignleft"
                            )
                            .focused($focusedField, equals: .title)
                            
                            // ← SHOW VALIDATION ERROR
                            if let error = validationError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .transition(.opacity)
                            }
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
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    Spacer(minLength: Spacing.xxLarge)
                }
                .padding(.horizontal, Spacing.large)
                .padding(.bottom, Spacing.xxLarge)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.light()
                        dismiss()
                    }
                    .foregroundStyle(.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                LoadingButton(
                    title: "Create Collection",
                    isLoading: viewModel.isLoading
                ) {
                    HapticManager.shared.medium()
                    validateAndCreate()  // ← CHANGED
                }
                .disabled(!isFormValid)
                .opacity(isFormValid ? 1.0 : 0.5)
                .animation(.easeInOut(duration: 0.2), value: isFormValid)
                .padding(.horizontal, Spacing.large)
                .padding(.vertical, Spacing.medium)
                .background(.ultraThinMaterial)
            }
        }
        .task {
            viewModel.configure(modelContext: modelContext)
        }
    }
    
    // ← NEW VALIDATION FUNCTION
    private func validateAndCreate() {
        // Sanitize inputs
        let sanitizedTitle = title.sanitized
        let sanitizedDescription = description.sanitized
        
        // Validate title
        guard sanitizedTitle.isValidCollectionName else {
            validationError = InputValidator.errorMessage(for: .collectionName)
            HapticManager.shared.error()
            return
        }
        
        // Validate description if provided
        if !sanitizedDescription.isEmpty {
            guard InputValidator.isValidDescription(sanitizedDescription) else {
                validationError = InputValidator.errorMessage(for: .description)
                HapticManager.shared.error()
                return
            }
        }
        
        // Clear error
        validationError = nil
        
        // Proceed with creation using sanitized values
        createCollection(
            withTitle: sanitizedTitle,
            description: sanitizedDescription.isEmpty ? nil : sanitizedDescription
        )
    }
    
    // ← UPDATED CREATE FUNCTION
    private func createCollection(withTitle title: String, description: String?) {
        guard let currentUser = authService.currentUser else { return }
        
        focusedField = nil
        
        Task {
            do {
                try await viewModel.createCollection(
                    title: title,  // Use sanitized title
                    description: description,  // Use sanitized description
                    category: selectedCategory,
                    coverImage: coverImage,
                    owner: currentUser
                )
                
                await MainActor.run {
                    HapticManager.shared.success()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    showError = true
                    HapticManager.shared.error()
                }
            }
        }
    }
}

#Preview {
    CreateCollectionView()
        .environment(AuthenticationService())
        .modelContainer(for: [UserProfile.self, CollectionModel.self], inMemory: true)
}
