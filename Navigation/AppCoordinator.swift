//
//  AppCoordinator.swift
//  stashd
//
//  Created by Sean Lynch on 10/9/25.
//


// File: Navigation/AppCoordinator.swift

import SwiftUI
import Observation

@Observable
final class AppCoordinator {
    var selectedTab: AppTab = .home
    var navigationPath = NavigationPath()
    var presentedSheet: SheetDestination?
    var presentedFullScreenCover: FullScreenDestination?
    
    func handle(_ url: URL) {
        // Parse URL and navigate
    }
    
    func navigate(to destination: NavigationDestination) {
        navigationPath.append(destination)
    }
    
    func popToRoot() {
        navigationPath.removeLast(navigationPath.count)
    }
}

enum AppTab: Hashable {
    case home
    case explore
    case create
    case notifications
    case profile
}

enum NavigationDestination: Hashable {
    case collectionDetail(UUID)
    case userProfile(UUID)
    case itemDetail(UUID)
    case editCollection(UUID)
    case settings
    case categoryBrowse(CollectionCategory)
}

enum SheetDestination: Identifiable {
    case createCollection
    case addItem(UUID)
    case editProfile
    case filters
    
    var id: String {
        switch self {
        case .createCollection: return "createCollection"
        case .addItem(let id): return "addItem-\(id)"
        case .editProfile: return "editProfile"
        case .filters: return "filters"
        }
    }
}

enum FullScreenDestination: Identifiable {
    case onboarding
    case imageViewer([URL], initialIndex: Int)
    
    var id: String {
        switch self {
        case .onboarding: return "onboarding"
        case .imageViewer: return "imageViewer"
        }
    }
}