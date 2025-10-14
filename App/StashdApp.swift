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
    
    let modelContainer: ModelContainer
    
    init() {
        // ✅ NEW: Validate API keys at launch
        AppConfig.validateConfiguration()
        
        // Configure Firebase FIRST - but only here, not in FirebaseService
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Initialize FirebaseService to set up references
        _ = FirebaseService.shared
        
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
            RootView()  // ← This is correct - you use RootView not ContentView
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
                        }
                    }
                }
                .preferredColorScheme(nil)
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
