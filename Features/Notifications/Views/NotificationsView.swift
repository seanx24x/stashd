//
//  NotificationsView.swift
//  stashd
//
//  Created by Sean Lynch on 10/9/25.
//


// File: Features/Notifications/Views/NotificationsView.swift

import SwiftUI

struct NotificationsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.medium) {
                    Text("No new notifications")
                        .font(.bodyLarge)
                        .foregroundStyle(.textSecondary)
                        .padding(.top, Spacing.xxLarge)
                }
            }
            .navigationTitle("Activity")
        }
    }
}

#Preview {
    NotificationsView()
}