//
//  AddItemOptionsSheet.swift
//  stashd
//
//  Created by Sean Lynch on 10/17/25.
//


//
//  AddItemOptionsSheet.swift
//  stashd
//
//  Created by Sean Lynch
//

import SwiftUI

struct AddItemOptionsSheet: View {
    let collection: CollectionModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var showCameraScan = false
    @State private var showLibraryScan = false
    @State private var showManualAdd = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.medium) {
                // Handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.textTertiary.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, Spacing.small)
                
                Text("Add Item")
                    .font(.headlineSmall.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                    .padding(.top, Spacing.small)
                
                VStack(spacing: Spacing.small) {
                    // PRIMARY: Camera Scan
                    Button {
                        HapticManager.shared.light()
                        dismiss()
                        showCameraScan = true
                    } label: {
                        HStack(spacing: Spacing.medium) {
                            ZStack {
                                Circle()
                                    .fill(Color.stashdPrimary.opacity(0.15))
                                    .frame(width: 48, height: 48)
                                
                                Image(systemName: "camera.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.stashdPrimary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Scan with Camera")
                                    .font(.bodyLarge.weight(.semibold))
                                    .foregroundStyle(.textPrimary)
                                
                                Text("Take a photo and AI will identify it")
                                    .font(.labelSmall)
                                    .foregroundStyle(.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.textTertiary)
                        }
                        .padding(Spacing.medium)
                        .background(Color.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    }
                    .buttonStyle(.plain)
                    
                    // SECONDARY: Library
                    Button {
                        HapticManager.shared.light()
                        dismiss()
                        showLibraryScan = true
                    } label: {
                        HStack(spacing: Spacing.medium) {
                            ZStack {
                                Circle()
                                    .fill(Color.backgroundSecondary)
                                    .frame(width: 48, height: 48)
                                
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title3)
                                    .foregroundStyle(.textSecondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Choose from Library")
                                    .font(.bodyMedium.weight(.medium))
                                    .foregroundStyle(.textPrimary)
                                
                                Text("Select an existing photo")
                                    .font(.labelSmall)
                                    .foregroundStyle(.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.textTertiary)
                        }
                        .padding(Spacing.medium)
                        .background(Color.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    }
                    .buttonStyle(.plain)
                    
                    // FALLBACK: Manual
                    Button {
                        HapticManager.shared.light()
                        dismiss()
                        showManualAdd = true
                    } label: {
                        HStack(spacing: Spacing.medium) {
                            ZStack {
                                Circle()
                                    .fill(Color.backgroundSecondary)
                                    .frame(width: 48, height: 48)
                                
                                Image(systemName: "pencil")
                                    .font(.title3)
                                    .foregroundStyle(.textSecondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Add Manually")
                                    .font(.bodyMedium.weight(.medium))
                                    .foregroundStyle(.textPrimary)
                                
                                Text("Enter details yourself")
                                    .font(.labelSmall)
                                    .foregroundStyle(.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.textTertiary)
                        }
                        .padding(Spacing.medium)
                        .background(Color.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.large)
                
                Spacer()
            }
            .fullScreenCover(isPresented: $showCameraScan) {
                CameraScanView(collection: collection)
            }
            .fullScreenCover(isPresented: $showLibraryScan) {
                LibraryScanView(collection: collection)
            }
            .fullScreenCover(isPresented: $showManualAdd) {
                ManualAddItemView(collection: collection)
            }
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }
}