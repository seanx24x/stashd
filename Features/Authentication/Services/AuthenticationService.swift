// File: Features/Authentication/Services/AuthenticationService.swift

import Foundation
import SwiftData
import Observation
import AuthenticationServices
import CryptoKit
import FirebaseAuth

@Observable
@MainActor
final class AuthenticationService: NSObject {
    var currentUser: UserProfile?
    var authState: AuthState = .unauthenticated
    var errorMessage: String?
    
    private var modelContext: ModelContext?
    private var currentNonce: String?
    
    enum AuthState: Equatable {
        case unauthenticated
        case authenticating
        case authenticated(UserProfile)
        case onboardingRequired(userID: String, email: String?)
    }
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        checkForExistingUser()
    }
    
    private func checkForExistingUser() {
        guard let modelContext else { return }
        
        // Check if we have a local user
        let descriptor = FetchDescriptor<UserProfile>()
        if let profiles = try? modelContext.fetch(descriptor),
           let firstProfile = profiles.first {
            currentUser = firstProfile
            authState = .authenticated(firstProfile)
        } else {
            // Check Firebase auth state
            if let firebaseUser = FirebaseService.shared.auth.currentUser {
                // User is signed into Firebase but no local profile
                // This means they need to complete onboarding
                authState = .onboardingRequired(
                    userID: firebaseUser.uid,
                    email: firebaseUser.email
                )
            }
        }
    }
    
    // MARK: - Sign in with Apple
    
    func signInWithApple() async throws {
        authState = .authenticating
        errorMessage = nil
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.performRequests()
    }
    
    func completeOnboarding(
        userID: String,
        username: String,
        displayName: String,
        bio: String? = nil,
        avatar: UIImage? = nil
    ) async throws {
        guard let modelContext else {
            throw AuthError.noModelContext
        }
        
        authState = .authenticating
        
        // ✅ NEW: Validate inputs BEFORE any network calls
        do {
            try ValidationService.validateUsername(username)
            try ValidationService.validateDisplayName(displayName)
            try ValidationService.validateBio(bio)
        } catch {
            authState = .onboardingRequired(userID: userID, email: nil)
            throw error
        }
        
        // ✅ NEW: Sanitize inputs
        let sanitizedUsername = ValidationService.sanitizeInput(username)
        let sanitizedDisplayName = ValidationService.sanitizeInput(displayName)
        let sanitizedBio = bio.map { ValidationService.sanitizeInput($0) }
        
        // Check username availability in Firestore
        let isAvailable = try await FirestoreService.shared.checkUsernameAvailable(sanitizedUsername)
        guard isAvailable else {
            authState = .onboardingRequired(userID: userID, email: nil)
            throw AuthError.usernameTaken
        }
        
        // Upload avatar if provided
        var avatarURL: URL?
        if let avatar {
            avatarURL = try await StorageService.shared.uploadAvatar(avatar, userID: userID)
        }
        
        // Create profile with sanitized values
        let profile = UserProfile(
            firebaseUID: userID,
            username: sanitizedUsername,
            displayName: sanitizedDisplayName,
            bio: sanitizedBio,
            avatarURL: avatarURL
        )
        
        // Save locally
        modelContext.insert(profile)
        try modelContext.save()
        
        // Save to Firestore
        try await FirestoreService.shared.saveUserProfile(profile)

        // Sync any existing local data to Firestore
        try await DataSyncService.shared.syncLocalChanges(modelContext: modelContext)

        currentUser = profile
        authState = .authenticated(profile)
    }
    
    func signOut() throws {
        guard let modelContext else { return }
        
        // Sign out from Firebase
        try FirebaseService.shared.auth.signOut()
        
        // Clear local data
        let descriptor = FetchDescriptor<UserProfile>()
        if let profiles = try? modelContext.fetch(descriptor) {
            profiles.forEach { profile in
                modelContext.delete(profile)
            }
            try? modelContext.save()
        }
        
        authState = .unauthenticated
        currentUser = nil
        errorMessage = nil
    }
    
    // MARK: - Helper Methods
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            Task { @MainActor in
                self.errorMessage = "Unable to fetch identity token"
                self.authState = .unauthenticated
            }
            return
        }
        
        Task { @MainActor in
            do {
                // Sign in to Firebase
                let credential = OAuthProvider.credential(
                    providerID: AuthProviderID.apple,
                    idToken: idTokenString,
                    rawNonce: nonce
                )
                
                let result = try await FirebaseService.shared.auth.signIn(with: credential)
                let firebaseUser = result.user
                
                // Check if user profile exists in Firestore
                if let firestoreData = try await FirestoreService.shared.fetchUserProfile(firebaseUID: firebaseUser.uid) {
                    // User exists - fetch their profile
                    // For now, we'll need to complete onboarding
                    // (In a real app, you'd reconstruct the UserProfile from Firestore)
                    self.authState = .onboardingRequired(
                        userID: firebaseUser.uid,
                        email: firebaseUser.email
                    )
                } else {
                    // New user - needs onboarding
                    self.authState = .onboardingRequired(
                        userID: firebaseUser.uid,
                        email: firebaseUser.email ?? appleIDCredential.email
                    )
                }
            } catch {
                self.errorMessage = "Sign in failed: \(error.localizedDescription)"
                self.authState = .unauthenticated
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = "Sign in failed: \(error.localizedDescription)"
            self.authState = .unauthenticated
        }
    }
}

enum AuthError: LocalizedError {
    case noModelContext
    case invalidCredential
    case userNotFound
    case usernameTaken
    
    var errorDescription: String? {
        switch self {
        case .noModelContext:
            return "Model context not configured"
        case .invalidCredential:
            return "Invalid authentication credential"
        case .userNotFound:
            return "User profile not found"
        case .usernameTaken:
            return "Username is already taken"
        }
    }
}
