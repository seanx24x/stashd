// File: Features/Notifications/ViewModels/ActivityFeedViewModel.swift

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class ActivityFeedViewModel {
    var activities: [ActivityItem] = []
    var isLoading = false
    var errorMessage: String?
    
    private let modelContext: ModelContext
    private let currentUser: UserProfile
    
    init(modelContext: ModelContext, currentUser: UserProfile) {
        self.modelContext = modelContext
        self.currentUser = currentUser
    }
    
    func loadActivities() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch all activities
            let descriptor = FetchDescriptor<ActivityItem>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            
            let allActivities = try modelContext.fetch(descriptor)
            
            // Filter for current user's activities
            activities = allActivities.filter { activity in
                activity.recipient?.id == currentUser.id
            }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load activities: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func markAsRead(_ activity: ActivityItem) {
        activity.isRead = true
        try? modelContext.save()
    }
    
    func markAllAsRead() {
        activities.forEach { $0.isRead = true }
        try? modelContext.save()
    }
    
    func deleteActivity(_ activity: ActivityItem) {
        modelContext.delete(activity)
        try? modelContext.save()
        activities.removeAll { $0.id == activity.id }
    }
    
    var unreadCount: Int {
        activities.filter { !$0.isRead }.count
    }
    
    var hasUnread: Bool {
        unreadCount > 0
    }
    
    // Group activities by date
    var groupedActivities: [(String, [ActivityItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: activities) { activity -> String in
            if calendar.isDateInToday(activity.createdAt) {
                return "Today"
            } else if calendar.isDateInYesterday(activity.createdAt) {
                return "Yesterday"
            } else if calendar.isDate(activity.createdAt, equalTo: Date(), toGranularity: .weekOfYear) {
                return "This Week"
            } else {
                return "Earlier"
            }
        }
        
        let order = ["Today", "Yesterday", "This Week", "Earlier"]
        return order.compactMap { key in
            guard let items = grouped[key] else { return nil }
            return (key, items)
        }
    }
}
