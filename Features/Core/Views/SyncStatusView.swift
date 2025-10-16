//
//  SyncStatusView.swift
//  stashd
//
//  Created by Sean Lynch on 10/16/25.
//


//
//  SyncStatusView.swift
//  stashd
//
//  Created by Sean Lynch
//

import SwiftUI

struct SyncStatusView: View {
    @Environment(\.modelContext) private var modelContext
    
    let offlineManager = OfflineManager.shared
    let syncService = RealtimeSyncService.shared
    
    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: statusIcon)
                .font(.caption)
                .foregroundStyle(statusColor)
            
            Text(statusText)
                .font(.labelSmall)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(statusBackgroundColor)
        .clipShape(Capsule())
    }
    
    private var statusIcon: String {
        if !offlineManager.isOnline {
            return "wifi.slash"
        } else if syncService.isSyncing {
            return "arrow.triangle.2.circlepath"
        } else if offlineManager.hasPendingOperations {
            return "clock.arrow.circlepath"
        } else {
            return "checkmark.icloud"
        }
    }
    
    private var statusText: String {
        if !offlineManager.isOnline {
            return "Offline"
        } else if syncService.isSyncing {
            return "Syncing..."
        } else if offlineManager.hasPendingOperations {
            return "Syncing \(offlineManager.hasPendingOperations) items"
        } else {
            return "Synced"
        }
    }
    
    private var statusColor: Color {
        if !offlineManager.isOnline {
            return .orange
        } else if syncService.isSyncing || offlineManager.hasPendingOperations {
            return .blue
        } else {
            return .green
        }
    }
    
    private var statusBackgroundColor: Color {
        statusColor.opacity(0.15)
    }
}

#Preview {
    SyncStatusView()
}