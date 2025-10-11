// File: Navigation/MainTabView.swift

import SwiftUI

struct MainTabView: View {
    let currentUser: UserProfile
    
    @Environment(AppCoordinator.self) private var coordinator
    @State private var selectedTab: AppTab = .home
    
    var body: some View {
        @Bindable var coordinator = coordinator
        
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "house.fill")
                }
                .tag(AppTab.home)
            
            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "square.grid.2x2")
                }
                .tag(AppTab.explore)
            
            CreateButton()
                .tabItem {
                    Label("Create", systemImage: "plus.circle.fill")
                }
                .tag(AppTab.create)
            
            NotificationsView()
                .tabItem {
                    Label("Activity", systemImage: "bell.fill")
                }
                .tag(AppTab.notifications)
            
            ProfileView(user: currentUser)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(AppTab.profile)
        }
        .tint(.stashdPrimary)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == .create {
                coordinator.presentedSheet = .createCollection
                selectedTab = oldValue
            }
        }
        .sheet(item: $coordinator.presentedSheet) { destination in
            switch destination {
            case .createCollection:
                CreateCollectionView()  // ← Use the real view now
                    .presentationDragIndicator(.visible)
                
            case .addItem(let collectionID):
                Text("Add Item Sheet")
                    .presentationDetents([.large])
                
            case .editProfile:
                Text("Edit Profile Sheet")
                    .presentationDetents([.large])
                
            case .filters:
                Text("Filters Sheet")
                    .presentationDetents([.medium])
            }
        }
    }
}

struct CreateButton: View {
    var body: some View {
        Color.clear
    }
}
