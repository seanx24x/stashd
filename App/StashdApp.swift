//
//  StashdApp.swift
//  stashd
//
//  Created by Sean Lynch on 10/9/25.
//


// File: App/StashdApp.swift

import SwiftUI
import SwiftData

@main
struct StashdApp: App {
    @State private var coordinator = AppCoordinator()
    @State private var authService = AuthenticationService()
    
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                UserProfile.self,
                CollectionModel.self,
                CollectionItem.self,
                Like.self,
                Comment.self
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
                }
                .preferredColorScheme(nil)
        }
    }
}