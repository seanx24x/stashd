//
//  MultiSourcePriceView.swift
//  stashd
//
//  Created by Sean Lynch on 10/17/25.
//


//
//  MultiSourcePriceView.swift
//  stashd
//
//  Created by Sean Lynch
//

import SwiftUI
import SwiftData

struct MultiSourcePriceView: View {
    let item: CollectionItem
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var priceResult: MultiSourcePriceResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    loadingView
                } else if let priceResult {
                    priceContent(result: priceResult)
                } else if let errorMessage {
                    errorView(message: errorMessage)
                }
            }
            .navigationTitle("Price Intelligence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.stashdPrimary)
                }
            }
            .task {
                await fetchPrices()
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: Spacing.large) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Searching multiple sources...")
                .font(.bodyLarge)
                .foregroundStyle(.textSecondary)
            
            Text("This may take a moment")
                .font(.bodySmall)
                .foregroundStyle(.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.error)
            
            Text("Unable to fetch prices")
                .font(.headlineSmall)
                .foregroundStyle(.textPrimary)
            
            Text(message)
                .font(.bodyMedium)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await fetchPrices()
                }
            }
            .font(.bodyLarge.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.medium)
            .background(Color.stashdPrimary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .padding()
    }
    
    // MARK: - Price Content
    
    private func priceContent(result: MultiSourcePriceResult) -> some View {
        VStack(spacing: Spacing.large) {
            // AI Recommendation Card
            aiRecommendationCard(recommendation: result.aiRecommendation)
            
            // MSRP Section
            if let msrp = result.msrp {
                priceSection(
                    title: "Official Retail (MSRP)",
                    icon: "building.2",
                    color: .blue,
                    prices: [msrp]
                )
            }
            
            // Retail Prices
            if !result.retailPrices.isEmpty {
                priceSection(
                    title: "Current Retailers",
                    icon: "cart",
                    color: .green,
                    prices: result.retailPrices
                )
            }
            
            // Specialty Prices
            if !result.specialtyPrices.isEmpty {
                priceSection(
                    title: "Specialty Markets",
                    icon: "star.circle",
                    color: .purple,
                    prices: result.specialtyPrices
                )
            }
            
            // Market Prices
            if !result.marketPrices.isEmpty {
                priceSection(
                    title: "Recent Sales",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .orange,
                    prices: result.marketPrices
                )
            }
            
            // Update Value Button
            updateValueButton(recommendedPrice: result.aiRecommendation.recommendedPrice)
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.medium)
    }
    
    // MARK: - AI Recommendation Card
    
    private func aiRecommendationCard(recommendation: AIRecommendation) -> some View {
        VStack(spacing: Spacing.medium) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.stashdPrimary)
                
                Text("AI Recommendation")
                    .font(.headlineSmall.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                
                Spacer()
                
                // Confidence Badge
                HStack(spacing: 4) {
                    Image(systemName: confidenceIcon(recommendation.confidence))
                        .font(.caption2)
                    Text("\(recommendation.confidence)%")
                        .font(.labelSmall.weight(.semibold))
                }
                .foregroundStyle(confidenceColor(recommendation.confidence))
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, 4)
                .background(confidenceColor(recommendation.confidence).opacity(0.1))
                .clipShape(Capsule())
            }
            
            Divider()
            
            VStack(spacing: Spacing.small) {
                Text(formatCurrency(recommendation.recommendedPrice))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(Color.stashdPrimary)
                
                Text(recommendation.reasoning)
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.large)
        .background(
            LinearGradient(
                colors: [Color.stashdPrimary.opacity(0.1), Color.stashdPrimary.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    // MARK: - Price Section
    
    private func priceSection(title: String, icon: String, color: Color, prices: [PriceInfo]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.headlineSmall.weight(.semibold))
                    .foregroundStyle(.textPrimary)
            }
            
            VStack(spacing: Spacing.small) {
                ForEach(prices) { price in
                    priceRow(price: price)
                }
            }
        }
        .padding(Spacing.large)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    // MARK: - Price Row
    
    private func priceRow(price: PriceInfo) -> some View {
        VStack(spacing: Spacing.xSmall) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(price.source)
                        .font(.bodyMedium.weight(.semibold))
                        .foregroundStyle(.textPrimary)
                    
                    if let availability = price.availability {
                        Text(availability)
                            .font(.labelSmall)
                            .foregroundStyle(.textTertiary)
                    }
                }
                
                Spacer()
                
                Text(formatCurrency(price.price))
                    .font(.bodyLarge.weight(.bold))
                    .foregroundStyle(Color.stashdPrimary)
            }
            
            if let url = price.url, let validURL = URL(string: url) {
                Link(destination: validURL) {
                    HStack(spacing: 4) {
                        Text("View Source")
                            .font(.labelSmall)
                        
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.stashdPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Spacing.medium)
        .background(Color.surfaceElevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
    
    // MARK: - Update Value Button
    
    private func updateValueButton(recommendedPrice: Decimal) -> some View {
        Button {
            updateItemValue(to: recommendedPrice)
        } label: {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Update Item Value to \(formatCurrency(recommendedPrice))")
            }
            .font(.bodyLarge.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [Color.stashdPrimary, Color.stashdPrimary.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        }
    }
    
    // MARK: - Actions
    
    private func fetchPrices() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await SmartPriceService.shared.fetchPrices(for: item)
            
            await MainActor.run {
                self.priceResult = result
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            
            ErrorLoggingService.shared.logError(
                error,
                context: "Fetch Multi-Source Prices"
            )
        }
    }
    
    private func updateItemValue(to newValue: Decimal) {
        item.estimatedValue = newValue
        try? modelContext.save()
        
        HapticManager.shared.success()
        dismiss()
    }
    
    // MARK: - Helpers
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
    }
    
    private func confidenceIcon(_ confidence: Int) -> String {
        if confidence >= 80 { return "checkmark.circle.fill" }
        if confidence >= 60 { return "checkmark.circle" }
        return "exclamationmark.circle"
    }
    
    private func confidenceColor(_ confidence: Int) -> Color {
        if confidence >= 80 { return .green }
        if confidence >= 60 { return .orange }
        return .red
    }
}

#Preview {
    let item = CollectionItem(
        name: "Warhammer 40,000 Raven Guard",
        collection: CollectionModel(
            title: "Warhammer Collection",
            category: .toys,
            owner: UserProfile(firebaseUID: "preview", username: "test", displayName: "Test")
        )
    )
    
    return MultiSourcePriceView(item: item)
}