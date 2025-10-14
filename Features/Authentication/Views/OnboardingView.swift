//
//  OnboardingView.swift
//  stashd
//
//  Created by Sean Lynch on 10/9/25.
//


// File: Features/Authentication/Views/OnboardingView.swift

import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @Environment(AuthenticationService.self) private var authService
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.stashdPrimary.opacity(0.1),
                    Color.stashdAccent.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    OnboardingPageView(
                        icon: "square.grid.3x3.fill",
                        title: "Stash Your Collection",
                        description: "Organize your vinyl, sneakers, books, art, and more in beautiful galleries"
                    )
                    .tag(0)
                    
                    OnboardingPageView(
                        icon: "person.2.fill",
                        title: "Connect with Collectors",
                        description: "Follow other collectors, discover rare finds, and share your passion"
                    )
                    .tag(1)
                    
                    OnboardingPageView(
                        icon: "sparkles",
                        title: "Explore & Discover",
                        description: "Browse trending collections, find inspiration, and grow your stash"
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)
                
                HStack(spacing: Spacing.xSmall) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.stashdPrimary : Color.separator)
                            .frame(width: 8, height: 8)
                            .animation(.smooth, value: currentPage)
                    }
                }
                .padding(.bottom, Spacing.large)
                
                VStack(spacing: Spacing.medium) {
                    CTAButton("Get Started", icon: "arrow.right") {
                        Task {
                            try? await authService.signInWithApple()
                        }
                    }
                    .disabled(authService.authState == .authenticating)
                    
                    if let errorMessage = authService.errorMessage {
                        Text(errorMessage)
                            .font(.bodySmall)
                            .foregroundStyle(.error)
                            .multilineTextAlignment(.center)
                    }
                    
                    Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                        .font(.labelSmall)
                        .foregroundStyle(.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Spacing.large)
                .padding(.bottom, Spacing.large)
            }
        }
        .overlay {
            if authService.authState == .authenticating {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
    }
}

struct OnboardingPageView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: Spacing.xLarge) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.stashdPrimary, .stashdAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.bounce, value: icon)
            
            VStack(spacing: Spacing.medium) {
                Text(title)
                    .font(.displayMedium)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.bodyLarge)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            
            Spacer()
        }
        .padding(.horizontal, Spacing.large)
    }
}

#Preview {
    OnboardingView()
        .environment(AuthenticationService())
}
