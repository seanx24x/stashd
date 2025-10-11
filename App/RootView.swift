//
//  RootView.swift
//  stashd
//
//  Created by Sean Lynch on 10/9/25.
//


// File: App/RootView.swift

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AuthenticationService.self) private var authService
    
    var body: some View {
        Group {
            switch authService.authState {
            case .unauthenticated:
                OnboardingView()
                    .transition(.opacity.combined(with: .scale))
                
            case .authenticating:
                LoadingView(message: "Signing in...")
                    .transition(.opacity)
                
            case .onboardingRequired(let userID, let email):
                UsernameSetupView(userID: userID, email: email)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                
            case .authenticated(let profile):
                MainTabView(currentUser: profile)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.4), value: authService.authState)
    }
}

struct LoadingView: View {
    let message: String
    
    var body: some View {
        ZStack {
            SwiftUI.Color.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: Spacing.large) {
                ProgressView()
                    .tint(.stashdPrimary)
                    .scaleEffect(1.5)
                
                Text(message)
                    .font(.bodyLarge)
                    .foregroundStyle(.textSecondary)
            }
        }
    }
}

#Preview("Unauthenticated") {
    RootView()
        .environment(AppCoordinator())
        .environment(AuthenticationService())
        .modelContainer(for: [UserProfile.self], inMemory: true)
}
