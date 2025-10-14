// File: Features/Notifications/Views/NotificationsView.swift

import SwiftUI
import SwiftData

struct NotificationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthenticationService.self) private var authService
    @Environment(AppCoordinator.self) private var coordinator
    
    @State private var viewModel: ActivityFeedViewModel?
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    if viewModel.activities.isEmpty {
                        EmptyActivityView()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.groupedActivities, id: \.0) { section, items in
                                    Section {
                                        ForEach(items) { activity in
                                            ActivityRowView(
                                                activity: activity,
                                                onTap: {
                                                    handleActivityTap(activity)
                                                },
                                                onDelete: {
                                                    viewModel.deleteActivity(activity)
                                                }
                                            )
                                            .padding(.horizontal, Spacing.large)
                                        }
                                    } header: {
                                        Text(section)
                                            .font(.labelLarge.weight(.semibold))
                                            .foregroundStyle(.textSecondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, Spacing.large)
                                            .padding(.top, Spacing.medium)
                                            .padding(.bottom, Spacing.small)
                                    }
                                }
                            }
                            .padding(.vertical, Spacing.small)
                        }
                        .refreshable {
                            await viewModel.loadActivities()
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if let viewModel, viewModel.hasUnread {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Mark All Read") {
                            viewModel.markAllAsRead()
                        }
                        .font(.labelMedium)
                        .foregroundStyle(Color.stashdPrimary)
                    }
                }
            }
        }
        .task {
            if viewModel == nil, let currentUser = authService.currentUser {
                viewModel = ActivityFeedViewModel(
                    modelContext: modelContext,
                    currentUser: currentUser
                )
                await viewModel?.loadActivities()
            }
        }
    }
    
    private func handleActivityTap(_ activity: ActivityItem) {
        viewModel?.markAsRead(activity)
        
        switch activity.type {
        case .follow:
            if let actorID = activity.actor?.id {
                coordinator.navigate(to: .userProfile(actorID))
            }
            
        case .like, .comment:
            if let collectionID = activity.collection?.id {
                coordinator.navigate(to: .collectionDetail(collectionID))
            }
            
        case .mention:
            if let collectionID = activity.collection?.id {
                coordinator.navigate(to: .collectionDetail(collectionID))
            }
        }
    }
}

struct EmptyActivityView: View {
    var body: some View {
        VStack(spacing: Spacing.large) {
            Spacer()
            
            Image(systemName: "bell.slash")
                .font(.system(size: 64))
                .foregroundStyle(.textTertiary)
            
            VStack(spacing: Spacing.small) {
                Text("No notifications yet")
                    .font(.headlineMedium)
                    .foregroundStyle(.textPrimary)
                
                Text("When people interact with your collections, you'll see it here")
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            
            Spacer()
        }
        .padding(.horizontal, Spacing.large)
    }
}

#Preview {
    NotificationsView()
        .environment(AuthenticationService())
        .environment(AppCoordinator())
        .modelContainer(for: [ActivityItem.self], inMemory: true)
}
