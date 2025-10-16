//
//  StashdApp.swift
//  stashd
//
//  Created by Sean Lynch
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct StashdApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @State private var coordinator = AppCoordinator()
    @State private var authService = AuthenticationService()
    
    // ✅ NEW: Security state
    @State private var showSecurityWarning = false
    @State private var securityCheckResult: SecurityCheckResult?
    
    let modelContainer: ModelContainer
    
    init() {
        // ✅ Validate API keys at launch
        AppConfig.validateConfiguration()
        
        // Configure Firebase FIRST
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Initialize FirebaseService
        _ = FirebaseService.shared
        
        // ✅ NEW: Start offline monitoring
        _ = OfflineManager.shared
        
        // ✅ NEW: Perform security checks
        let result = SecurityService.shared.performSecurityChecks()
        if !result.isSecure {
            _showSecurityWarning = State(initialValue: true)
            _securityCheckResult = State(initialValue: result)
        }
        
        do {
            let schema = Schema([
                UserProfile.self,
                CollectionModel.self,
                CollectionItem.self,
                Like.self,
                Comment.self,
                ActivityItem.self
            ])
            
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: config
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(coordinator)
                .environment(authService)
                .modelContainer(modelContainer)
                .task {
                    authService.configure(modelContext: modelContainer.mainContext)
                    
                    // Sync data if user is authenticated
                    if let currentUser = authService.currentUser {
                        Task {
                            try? await DataSyncService.shared.loadUserData(
                                for: currentUser,
                                modelContext: modelContainer.mainContext
                            )
                            
                            // ✅ NEW: Schedule auto backup (encrypted)
                            BackupService.shared.scheduleAutoBackup(
                                for: currentUser,
                                modelContext: modelContainer.mainContext
                            )
                        }
                    }
                }
                .preferredColorScheme(nil)
                // ✅ NEW: Security warning alert
                .alert("Security Warning", isPresented: $showSecurityWarning) {
                    Button("I Understand", role: .cancel) {
                        // User acknowledges the warning
                        // Optionally, you could restrict certain features here
                    }
                    Button("Exit App", role: .destructive) {
                        exit(0)
                    }
                } message: {
                    if let result = securityCheckResult,
                       let message = result.warningMessage {
                        Text(message)
                    } else {
                        Text("A security issue was detected. Some features may be restricted.")
                    }
                }
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Firebase is configured in StashdApp init
        print("🔥 Firebase configured")
        
        // ✅ NEW: Log security check on app launch
        let securityResult = SecurityService.shared.performSecurityChecks()
        if !securityResult.isSecure {
            print("⚠️ Security warning: Device may be compromised")
        } else {
            print("✅ Security check passed")
        }
        
        return true
    }
    
    // Handle remote notifications
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("📱 Registered for remote notifications")
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
}
