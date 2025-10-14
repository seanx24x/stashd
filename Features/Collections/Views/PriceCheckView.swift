//
//  PriceCheckView.swift
//  stashd
//
//  Created by Sean Lynch on 10/12/25.
//


// File: Features/Collections/Views/PriceCheckView.swift

import SwiftUI

struct PriceCheckView: View {
    let item: CollectionItem
    @Environment(\.dismiss) private var dismiss
    
    @State private var priceAnalysis: eBayService.PriceAnalysis?
    @State private var recentListings: [eBayService.PriceInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xLarge) {
                    // Header
                    VStack(spacing: Spacing.small) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.stashdPrimary)
                            .symbolEffect(.pulse, value: isLoading)
                        
                        Text("Market Price Check")
                            .font(.headlineLarge)
                            .foregroundStyle(.textPrimary)
                        
                        Text(item.name)
                            .font(.bodyMedium)
                            .foregroundStyle(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Spacing.large)
                    
                    if isLoading {
                        VStack(spacing: Spacing.medium) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text("Searching eBay...")
                                .font(.bodyMedium)
                                .foregroundStyle(.textSecondary)
                        }
                        .padding(.vertical, Spacing.xxLarge)
                    } else if let analysis = priceAnalysis {
                        // Price Analysis Card
                        PriceAnalysisCard(analysis: analysis)
                        
                        // Recent Listings
                        if !recentListings.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.medium) {
                                Text("Recent Sales")
                                    .font(.headlineSmall)
                                    .foregroundStyle(.textPrimary)
                                
                                ForEach(recentListings) { listing in
                                    eBayListingCard(listing: listing)
                                }
                            }
                        }
                    } else if let errorMessage {
                        ErrorStateView(message: errorMessage) {
                            checkPrice()
                        }
                    }
                }
                .padding(.horizontal, Spacing.large)
                .padding(.bottom, Spacing.xxLarge)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        HapticManager.shared.light()
                        dismiss()
                    }
                }
            }
        }
        .task {
            checkPrice()
        }
    }
    
    private func checkPrice() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let analysis = try await eBayService.shared.analyzePrices(
                    for: item.name,
                    condition: item.condition?.rawValue
                )
                
                let listings = try await eBayService.shared.searchItem(
                    query: item.name,
                    condition: item.condition?.rawValue
                )
                
                await MainActor.run {
                    HapticManager.shared.success()
                    withAnimation(.spring(response: 0.3)) {
                        priceAnalysis = analysis
                        recentListings = listings
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    HapticManager.shared.error()
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct PriceAnalysisCard: View {
    let analysis: eBayService.PriceAnalysis
    
    var body: some View {
        VStack(spacing: Spacing.large) {
            // Average Price (Hero)
            VStack(spacing: Spacing.xSmall) {
                Text("Average Market Price")
                    .font(.labelMedium)
                    .foregroundStyle(.textSecondary)
                
                Text(analysis.formattedAverage)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(Color.stashdPrimary)
            }
            
            Divider()
            
            // Stats Grid
            HStack(spacing: Spacing.large) {
                PriceStat(
                    label: "Price Range",
                    value: analysis.priceRange,
                    icon: "arrow.up.arrow.down"
                )
                
                Divider()
                    .frame(height: 60)
                
                PriceStat(
                    label: "Listings",
                    value: "\(analysis.totalListings)",
                    icon: "list.bullet"
                )
            }
        }
        .padding(Spacing.large)
        .background(.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }
}

struct PriceStat: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: Spacing.small) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.stashdPrimary)
            
            Text(value)
                .font(.headlineSmall)
                .foregroundStyle(.textPrimary)
            
            Text(label)
                .font(.labelSmall)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct eBayListingCard: View {
    let listing: eBayService.PriceInfo
    
    var body: some View {
        Link(destination: URL(string: listing.listingURL)!) {
            HStack(spacing: Spacing.medium) {
                // Image
                if let imageURL = listing.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.surfaceElevated)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.textTertiary)
                            }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }
                
                // Info
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text(listing.title)
                        .font(.bodyMedium.weight(.semibold))
                        .foregroundStyle(.textPrimary)
                        .lineLimit(2)
                    
                    Text(listing.condition)
                        .font(.labelSmall)
                        .foregroundStyle(.textSecondary)
                    
                    Text(listing.formattedPrice)
                        .font(.labelLarge.weight(.bold))
                        .foregroundStyle(Color.stashdPrimary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.textTertiary)
            }
            .padding(Spacing.medium)
            .background(.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        }
        .buttonStyle(.plain)
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.error)
            
            Text(message)
                .font(.bodyMedium)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                HapticManager.shared.light()
                retry()
            } label: {
                Text("Try Again")
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.large)
                    .padding(.vertical, Spacing.medium)
                    .background(Color.stashdPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
        }
        .padding(.vertical, Spacing.xxLarge)
    }
}

#Preview {
    PriceCheckView(
        item: CollectionItem(
            name: "Air Jordan 1 Chicago",
            collection: CollectionModel(
                title: "Preview",
                category: .sneakers,
                owner: UserProfile(firebaseUID: "preview", username: "test", displayName: "Test")
            )
        )
    )
}
