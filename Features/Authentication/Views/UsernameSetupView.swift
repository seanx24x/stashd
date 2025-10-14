//
//  UsernameSetupView.swift
//  stashd
//
//  Created by Sean Lynch on 10/9/25.
//

// File: Features/Authentication/Views/UsernameSetupView.swift

import SwiftUI
import SwiftData

struct UsernameSetupView: View {
    let userID: String
    let email: String?
    
    @Environment(AuthenticationService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    
    @State private var username = ""
    @State private var displayName = ""
    @State private var bio = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var validationError: String? = nil  // ← NEW
    @State private var usernameAvailable: Bool?
    @State private var checkTask: Task<Void, Never>?
    
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case username, displayName, bio
    }
    
    // ← UPDATED VALIDATION
    var isFormValid: Bool {
        let sanitizedUsername = username.sanitized
        let sanitizedDisplayName = displayName.sanitized
        
        return sanitizedUsername.isValidUsername &&
               sanitizedDisplayName.isValidDisplayName &&
               usernameAvailable == true
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xLarge) {
                VStack(spacing: Spacing.small) {
                    Text("Create Your Profile")
                        .font(.displayMedium)
                        .foregroundStyle(.textPrimary)
                    
                    Text("Set up your collector profile")
                        .font(.bodyLarge)
                        .foregroundStyle(.textSecondary)
                }
                .padding(.top, Spacing.xxLarge)
                
                Button {
                    showImagePicker = true
                } label: {
                    ZStack {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.surfaceElevated)
                                .frame(width: 120, height: 120)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.textTertiary)
                                }
                        }
                        
                        Circle()
                            .fill(Color.stashdPrimary)
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: "camera.fill")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                            .offset(x: 40, y: 40)
                    }
                }
                .buttonStyle(.plain)
                
                VStack(spacing: Spacing.large) {
                    // ← USERNAME FIELD WITH VALIDATION
                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        CollectTextField(
                            title: "Username",
                            placeholder: "johndoe",
                            text: $username,
                            icon: "at",
                            keyboardType: .alphabet,
                            textContentType: .username,
                            autocapitalization: .never
                        )
                        .focused($focusedField, equals: .username)
                        .onChange(of: username) { oldValue, newValue in
                            // Sanitize: only letters, numbers, underscore
                            username = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                            
                            // Clear validation error when typing
                            if !username.isEmpty {
                                validationError = nil
                            }
                            
                            checkUsernameAvailability()
                        }
                        
                        if !username.isEmpty {
                            HStack(spacing: Spacing.xSmall) {
                                if let available = usernameAvailable {
                                    Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(available ? .success : .error)
                                    
                                    Text(available ? "Username available" : "Username taken")
                                        .font(.labelSmall)
                                        .foregroundStyle(available ? .success : .error)
                                } else {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Checking...")
                                        .font(.labelSmall)
                                        .foregroundStyle(.textTertiary)
                                }
                            }
                            .padding(.leading, Spacing.xSmall)
                        }
                    }
                    
                    // ← DISPLAY NAME FIELD
                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        CollectTextField(
                            title: "Display Name",
                            placeholder: "John Doe",
                            text: $displayName,
                            icon: "person.fill",
                            textContentType: .name
                        )
                        .focused($focusedField, equals: .displayName)
                        .onChange(of: displayName) { oldValue, newValue in
                            // Clear validation error when typing
                            if !displayName.isEmpty {
                                validationError = nil
                            }
                        }
                    }
                    
                    // ← BIO FIELD WITH VALIDATION
                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        Text("Bio (Optional)")
                            .font(.labelMedium)
                            .foregroundStyle(.textSecondary)
                        
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $bio)
                                .frame(height: 100)
                                .padding(Spacing.small)
                                .background(.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                                .overlay {
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        .strokeBorder(Color.separator, lineWidth: 1)
                                }
                                .focused($focusedField, equals: .bio)
                                .onChange(of: bio) { oldValue, newValue in
                                    // Limit bio to 200 characters
                                    if bio.count > 200 {
                                        bio = String(bio.prefix(200))
                                    }
                                }
                            
                            if bio.isEmpty {
                                Text("Tell us about your collecting journey...")
                                    .font(.bodyMedium)
                                    .foregroundStyle(.textTertiary)
                                    .padding(.leading, Spacing.small + 4)
                                    .padding(.top, Spacing.small + 8)
                                    .allowsHitTesting(false)
                            }
                        }
                        
                        // Character counter for bio
                        if !bio.isEmpty {
                            Text("\(bio.count)/200")
                                .font(.caption)
                                .foregroundStyle(bio.count > 200 ? .error : .textTertiary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
                
                // ← VALIDATION ERROR DISPLAY
                if let error = validationError {
                    Text(error)
                        .font(.bodySmall)
                        .foregroundStyle(.error)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
                
                // Error message display
                if let errorMessage {
                    Text(errorMessage)
                        .font(.bodySmall)
                        .foregroundStyle(.error)
                        .multilineTextAlignment(.center)
                }
                
                Spacer(minLength: Spacing.xLarge)
                
                CTAButton("Continue") {
                    validateAndComplete()  // ← CHANGED
                }
                .disabled(!isFormValid || isLoading)
            }
            .padding(.horizontal, Spacing.large)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .overlay {
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: Spacing.medium) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                    
                    Text("Setting up your profile...")
                        .font(.bodyLarge)
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    private func checkUsernameAvailability() {
        checkTask?.cancel()
        usernameAvailable = nil
        
        // Must be at least 3 characters
        guard username.count >= 3 else { return }
        
        // Must be valid format
        guard username.isValidUsername else {
            usernameAvailable = false
            return
        }
        
        checkTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            
            guard !Task.isCancelled else { return }
            
            let descriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate { $0.username == username }
            )
            
            do {
                let profiles = try modelContext.fetch(descriptor)
                await MainActor.run {
                    usernameAvailable = profiles.isEmpty
                }
            } catch {
                await MainActor.run {
                    usernameAvailable = false
                }
            }
        }
    }
    
    // ← NEW VALIDATION FUNCTION
    private func validateAndComplete() {
        // Clear previous errors
        validationError = nil
        errorMessage = nil
        
        // Sanitize inputs
        let sanitizedUsername = username.sanitized.lowercased()
        let sanitizedDisplayName = displayName.sanitized
        let sanitizedBio = bio.sanitized
        
        // Validate username
        guard sanitizedUsername.isValidUsername else {
            validationError = InputValidator.errorMessage(for: .username)
            HapticManager.shared.error()
            return
        }
        
        // Validate display name
        guard sanitizedDisplayName.isValidDisplayName else {
            validationError = InputValidator.errorMessage(for: .displayName)
            HapticManager.shared.error()
            return
        }
        
        // Validate bio if provided
        if !sanitizedBio.isEmpty {
            guard InputValidator.isValidBio(sanitizedBio) else {
                validationError = InputValidator.errorMessage(for: .bio)
                HapticManager.shared.error()
                return
            }
        }
        
        // Check username availability
        guard usernameAvailable == true else {
            validationError = "Username is not available"
            HapticManager.shared.error()
            return
        }
        
        // Proceed with setup
        completeSetup(
            username: sanitizedUsername,
            displayName: sanitizedDisplayName,
            bio: sanitizedBio.isEmpty ? nil : sanitizedBio
        )
    }
    
    // ← UPDATED COMPLETE SETUP
    private func completeSetup(username: String, displayName: String, bio: String?) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.completeOnboarding(
                    userID: userID,
                    username: username,
                    displayName: displayName,
                    bio: bio,
                    avatar: selectedImage
                )
                
                await MainActor.run {
                    HapticManager.shared.success()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    HapticManager.shared.error()
                }
            }
        }
    }
}

#Preview {
    UsernameSetupView(
        userID: "preview-uid",
        email: "preview@example.com"
    )
    .environment(AuthenticationService())
    .modelContainer(for: [UserProfile.self], inMemory: true)
}
