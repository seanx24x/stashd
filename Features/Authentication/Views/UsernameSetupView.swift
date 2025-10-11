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
    @State private var usernameAvailable: Bool?
    @State private var checkTask: Task<Void, Never>?
    
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case username, displayName, bio
    }
    
    var isFormValid: Bool {
        !username.isEmpty &&
        username.count >= 3 &&
        !displayName.isEmpty &&
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
                            username = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
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
                    
                    CollectTextField(
                        title: "Display Name",
                        placeholder: "John Doe",
                        text: $displayName,
                        icon: "person.fill",
                        textContentType: .name
                    )
                    .focused($focusedField, equals: .displayName)
                    
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
                            
                            if bio.isEmpty {
                                Text("Tell us about your collecting journey...")
                                    .font(.bodyMedium)
                                    .foregroundStyle(.textTertiary)
                                    .padding(.leading, Spacing.small + 4)
                                    .padding(.top, Spacing.small + 8)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(.bodySmall)
                        .foregroundStyle(.error)
                        .multilineTextAlignment(.center)
                }
                
                Spacer(minLength: Spacing.xLarge)
                
                CTAButton("Continue") {
                    completeSetup()
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
        
        guard username.count >= 3 else { return }
        
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
    
    private func completeSetup() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                var avatarData: Data?
                if let image = selectedImage {
                    avatarData = image.jpegData(compressionQuality: 0.7)
                }
                
                try await authService.completeOnboarding(
                    userID: userID,
                    username: username,
                    displayName: displayName,
                    bio: bio.isEmpty ? nil : bio,
                    avatar: avatarData
                )
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
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
