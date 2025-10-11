//
//  AuthenticationService.swift
//  stashd
//
//  Created by Sean Lynch on 10/9/25.
//


// File: Features/Authentication/Services/AuthenticationService.swift

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class AuthenticationService {
    var currentUser: UserProfile?
    var authState: AuthState = .unauthenticated
    var errorMessage: String?
    
    private var modelContext: ModelContext?
    
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
        
        let descriptor = FetchDescriptor<UserProfile>()
        if let profiles = try? modelContext.fetch(descriptor),
           let firstProfile = profiles.first {
            currentUser = firstProfile
            authState = .authenticated(firstProfile)
        }
    }
    
    func signInWithApple() async throws {
        authState = .authenticating
        errorMessage = nil
        
        try await Task.sleep(for: .seconds(1))
        
        if let existing = currentUser {
            authState = .authenticated(existing)
        } else {
            authState = .onboardingRequired(
                userID: UUID().uuidString,
                email: "demo@stashd.app"
            )
        }
    }
    
    func completeOnboarding(
        userID: String,
        username: String,
        displayName: String,
        bio: String? = nil,
        avatar: Data? = nil
    ) async throws {
        guard let modelContext else {
            throw AuthError.noModelContext
        }
        
        authState = .authenticating
        
        try await Task.sleep(for: .seconds(1))
        
        var avatarURL: URL?
        if let avatar {
            let filename = "\(userID)_avatar.jpg"
            if let documentsDirectory = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first {
                let fileURL = documentsDirectory.appendingPathComponent(filename)
                try? avatar.write(to: fileURL)
                avatarURL = fileURL
            }
        }
        
        let profile = UserProfile(
            firebaseUID: userID,
            username: username,
            displayName: displayName,
            bio: bio,
            avatarURL: avatarURL
        )
        
        modelContext.insert(profile)
        try modelContext.save()
        
        currentUser = profile
        authState = .authenticated(profile)
    }
    
    func signOut() throws {
        guard let modelContext else { return }
        
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
}

enum AuthError: LocalizedError {
    case noModelContext
    case invalidCredential
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .noModelContext:
            return "Model context not configured"
        case .invalidCredential:
            return "Invalid authentication credential"
        case .userNotFound:
            return "User profile not found"
        }
    }
}