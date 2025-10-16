// File: App/StashdApp.swift

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct StashdApp: App {
    @State private var coordinator = AppCoordinator()
    @State private var authService = AuthenticationService()
    
    let modelContainer: ModelContainer
    
    init() {
        // Configure Firebase FIRST
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // ✅ DEBUG: Print API keys
            AppConfig.debugPrintKeys()
        
        // Initialize FirebaseService
        _ = FirebaseService.shared
        
        // ✅ NEW: Configure Push Notifications
        PushNotificationService.shared.configure()
        
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
                            
                            // Schedule auto backup
                            BackupService.shared.scheduleAutoBackup(
                                for: currentUser,
                                modelContext: modelContainer.mainContext
                            )
                            
                            // Start real-time sync
                            RealtimeSyncService.shared.startSync(
                                for: currentUser.firebaseUID,
                                modelContext: modelContainer.mainContext
                            )
                            
                            // ✅ NEW: Save FCM token
                            await PushNotificationService.shared.saveFCMToken(
                                for: currentUser.firebaseUID
                            )
                        }
                    }
                }
                .preferredColorScheme(nil)
        }
    }
}
