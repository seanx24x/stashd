//
//  SettingsView.swift
//  stashd
//
//  Created by Sean Lynch on 10/13/25.
//


//
//  SettingsView.swift
//  stashd
//
//  Created by Sean Lynch
//

// File: Features/Profile/Views/SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationService.self) private var authService
    
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section {
                    if let user = authService.currentUser {
                        HStack {
                            Text("Username")
                            Spacer()
                            Text("@\(user.username)")
                                .foregroundStyle(.textSecondary)
                        }
                        
                        HStack {
                            Text("Display Name")
                            Spacer()
                            Text(user.displayName)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                } header: {
                    Text("Account")
                }
                
                // App Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.textSecondary)
                    }
                    
                    Link(destination: URL(string: "https://stashd.app/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://stashd.app/terms")!) {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                } header: {
                    Text("About")
                }
                
                // Logout Section
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Log Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Log Out?", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Log Out", role: .destructive) {
                    Task {
                        try? await authService.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthenticationService())
}