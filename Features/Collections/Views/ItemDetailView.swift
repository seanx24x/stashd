//
//  ItemDetailView.swift
//  stashd
//
//  Created by Sean Lynch on 10/12/25.
//

// File: Features/Collections/Views/ItemDetailView.swift

import SwiftUI
import SwiftData

struct ItemDetailView: View {
    let item: CollectionItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var showPriceCheck = false
    @State private var showDeleteAlert = false
    @State private var showEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.large) {
                // Item Images
                if !item.imageURLs.isEmpty {
                    TabView {
                        ForEach(item.imageURLs, id: \.self) { imageURL in
                            CachedAsyncImage(url: imageURL) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.surfaceElevated)
                                    .overlay {
                                        ProgressView()
                                    }
                            }
                        }
                    }
                    .frame(height: 400)
                    .tabViewStyle(.page)
                } else {
                    Rectangle()
                        .fill(Color.surfaceElevated)
                        .frame(height: 400)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundStyle(.textTertiary)
                        }
                }
                
                VStack(alignment: .leading, spacing: Spacing.large) {
                    // Item Info
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text(item.name)
                            .font(.displayMedium)
                            .foregroundStyle(.textPrimary)
                        
                        // Condition
                        if let condition = item.condition {
                            HStack {
                                Text("Condition:")
                                    .font(.bodyMedium)
                                    .foregroundStyle(.textSecondary)
                                
                                Text(condition.rawValue)
                                    .font(.bodyMedium.weight(.semibold))
                                    .foregroundStyle(.textPrimary)
                            }
                        }
                        
                        // Estimated Value
                        if item.estimatedValue > 0 {
                            HStack {
                                Text("Estimated Value:")
                                    .font(.bodyMedium)
                                    .foregroundStyle(.textSecondary)
                                
                                Text(formatCurrency(item.estimatedValue))
                                    .font(.bodyMedium.weight(.semibold))
                                    .foregroundStyle(Color.stashdPrimary)
                            }
                        }
                        
                        // Purchase Price
                        if let purchasePrice = item.purchasePrice, purchasePrice > 0 {
                            HStack {
                                Text("Purchase Price:")
                                    .font(.bodyMedium)
                                    .foregroundStyle(.textSecondary)
                                
                                Text(formatCurrency(purchasePrice))
                                    .font(.bodyMedium.weight(.semibold))
                                    .foregroundStyle(.textPrimary)
                            }
                            
                            // Show growth if both values exist
                            if item.estimatedValue > 0 {
                                let growth = item.estimatedValue - purchasePrice
                                let growthPercent = (growth / purchasePrice) * 100
                                
                                HStack {
                                    Text("Value Change:")
                                        .font(.bodyMedium)
                                        .foregroundStyle(.textSecondary)
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: growth >= 0 ? "arrow.up" : "arrow.down")
                                            .font(.caption)
                                        
                                        Text(formatCurrency(abs(growth)))
                                        
                                        Text("(\(String(format: "%+.1f%%", Double(truncating: growthPercent as NSNumber))))")
                                    }
                                    .font(.bodyMedium.weight(.semibold))
                                    .foregroundStyle(growth >= 0 ? .green : .red)
                                }
                            }
                        }
                        
                        // Purchase Date
                        if let purchaseDate = item.purchaseDate {
                            HStack {
                                Text("Acquired:")
                                    .font(.bodyMedium)
                                    .foregroundStyle(.textSecondary)
                                
                                Text(purchaseDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.bodyMedium)
                                    .foregroundStyle(.textPrimary)
                            }
                        }
                        
                        // Tags Section
                        if !item.tags.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.small) {
                                HStack {
                                    Image(systemName: "tag.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.stashdPrimary)
                                    
                                    Text("Tags")
                                        .font(.labelLarge.weight(.semibold))
                                        .foregroundStyle(.textPrimary)
                                }
                                
                                FlowLayout(spacing: Spacing.xSmall) {
                                    ForEach(item.tags, id: \.self) { tag in
                                        TagChip(text: tag)
                                            .onTapGesture {
                                                HapticManager.shared.light()
                                                searchByTag(tag)
                                            }
                                    }
                                }
                            }
                            .padding(.top, Spacing.small)
                        }
                        
                        // Notes/Description
                        if let notes = item.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                                Text("Notes")
                                    .font(.labelLarge.weight(.semibold))
                                    .foregroundStyle(.textPrimary)
                                
                                Text(notes)
                                    .font(.bodyMedium)
                                    .foregroundStyle(.textSecondary)
                            }
                            .padding(.top, Spacing.small)
                        }
                    }
                    
                    Divider()
                    
                    // Actions
                    VStack(spacing: Spacing.medium) {
                        // Check Price Button
                        Button {
                            HapticManager.shared.medium()
                            showPriceCheck = true
                        } label: {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                Text("Check Market Price")
                            }
                            .font(.bodyLarge.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                LinearGradient(
                                    colors: [Color.stashdPrimary, Color.stashdPrimary.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        }
                        .buttonStyle(.plain)
                        
                        // Edit Button
                        Button {
                            HapticManager.shared.light()
                            showEditSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Item")
                            }
                            .font(.bodyLarge.weight(.semibold))
                            .foregroundStyle(.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                            .overlay {
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .strokeBorder(Color.separator, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        // Delete Button
                        Button(role: .destructive) {
                            HapticManager.shared.warning()
                            showDeleteAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Item")
                            }
                            .font(.bodyLarge.weight(.semibold))
                            .foregroundStyle(.error)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(.error.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.large)
            }
            .padding(.bottom, Spacing.xxLarge)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)
            }
        }
        .sheet(isPresented: $showPriceCheck) {
            PriceCheckView(item: item)
        }
        .sheet(isPresented: $showEditSheet) {
            Text("Edit Item Coming Soon")
                .font(.headlineLarge)
                .foregroundStyle(.textPrimary)
        }
        .alert("Delete Item?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("This will permanently delete '\(item.name)'. This action cannot be undone.")
        }
    }
    
    private func deleteItem() {
        modelContext.delete(item)
        try? modelContext.save()
        HapticManager.shared.success()
        dismiss()
    }
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
    }
    
    private func searchByTag(_ tag: String) {
        // Dismiss current view
        dismiss()
        
        // Post notification to navigate to Explore with tag search
        NotificationCenter.default.post(
            name: Notification.Name("SearchByTag"),
            object: nil,
            userInfo: ["tag": tag]
        )
    }
}

#Preview {
    NavigationStack {
        let item = CollectionItem(
            name: "Air Jordan 1 Chicago",
            collection: CollectionModel(
                title: "Preview",
                category: .sneakers,
                owner: UserProfile(firebaseUID: "preview", username: "test", displayName: "Test")
            )
        )
        item.tags = ["Vintage", "1980s", "Basketball", "Nike", "High-Top", "Red & Black"]
        
        return ItemDetailView(item: item)
    }
}
