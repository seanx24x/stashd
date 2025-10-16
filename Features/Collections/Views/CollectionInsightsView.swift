//
//  CollectionInsightsView.swift
//  stashd
//
//  Created by Sean Lynch on 10/16/25.
//

import SwiftUI
import SwiftData

struct CollectionInsightsView: View {
    let collection: CollectionModel
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var stats: CollectionStats?
    @State private var insights: CollectionInsights?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    loadingView
                } else if let stats, let insights {
                    insightsContent(stats: stats, insights: insights)
                } else if let errorMessage {
                    errorView(message: errorMessage)
                }
            }
            .navigationTitle("Collection Insights")
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
                await loadInsights()
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: Spacing.large) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Analyzing your collection...")
                .font(.bodyLarge)
                .foregroundStyle(.textSecondary)
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
            
            Text("Failed to load insights")
                .font(.headlineSmall)
                .foregroundStyle(.textPrimary)
            
            Text(message)
                .font(.bodyMedium)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await loadInsights()
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
    
    // MARK: - Insights Content
    
    private func insightsContent(stats: CollectionStats, insights: CollectionInsights) -> some View {
        VStack(spacing: Spacing.large) {
            // Header with total value
            totalValueCard(stats: stats)
            
            // Quick Stats Grid
            quickStatsGrid(stats: stats)
            
            // Value Growth Card
            if stats.valueGrowth.growthPercentage != 0 {
                valueGrowthCard(growth: stats.valueGrowth)
            }
            
            // AI Insights
            aiInsightsSection(insights: insights)
            
            // Top Items
            if !stats.topValuedItems.isEmpty {
                topItemsSection(items: stats.topValuedItems)
            }
            
            // Condition Breakdown
            if !stats.conditionBreakdown.isEmpty {
                conditionBreakdownSection(breakdown: stats.conditionBreakdown)
            }
            
            // Top Tags
            if !stats.topTags.isEmpty {
                topTagsSection(tags: stats.topTags)
            }
            
            // Completion Suggestions
            completionSuggestionsSection(suggestions: insights.completionSuggestions)
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.medium)
    }
    
    // MARK: - Total Value Card
    
    private func totalValueCard(stats: CollectionStats) -> some View {
        VStack(spacing: Spacing.small) {
            Text("Total Collection Value")
                .font(.bodyMedium)
                .foregroundStyle(.textSecondary)
            
            Text(CollectionInsightsService.shared.formatCurrency(stats.totalValue))
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(Color.stashdPrimary)
            
            Text("\(stats.itemCount) items • Avg: \(CollectionInsightsService.shared.formatCurrency(stats.averageValue))")
                .font(.bodySmall)
                .foregroundStyle(.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xLarge)
        .background(
            LinearGradient(
                colors: [Color.stashdPrimary.opacity(0.1), Color.stashdPrimary.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    // MARK: - Quick Stats Grid
    
    private func quickStatsGrid(stats: CollectionStats) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: Spacing.medium
        ) {
            statCard(
                title: "Items",
                value: "\(stats.itemCount)",
                icon: "square.stack.3d.up.fill",
                color: .blue
            )
            
            statCard(
                title: "Mint Condition",
                value: "\(stats.mintConditionCount)",
                icon: "star.fill",
                color: .yellow
            )
            
            statCard(
                title: "Unique Tags",
                value: "\(stats.uniqueTagsCount)",
                icon: "tag.fill",
                color: .purple
            )
            
            statCard(
                title: "Recent Items",
                value: "\(stats.recentItems.count)",
                icon: "clock.fill",
                color: .green
            )
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: Spacing.small) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.headlineLarge.weight(.bold))
                .foregroundStyle(.textPrimary)
            
            Text(title)
                .font(.bodySmall)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.medium)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
    
    // MARK: - Value Growth Card
    
    private func valueGrowthCard(growth: ValueGrowth) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Image(systemName: growth.growthPercentage >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    .foregroundStyle(growth.growthPercentage >= 0 ? .green : .red)
                
                Text("Value Growth")
                    .font(.headlineSmall.weight(.semibold))
                    .foregroundStyle(.textPrimary)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                Text(String(format: "%+.1f%%", growth.growthPercentage))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(growth.growthPercentage >= 0 ? .green : .red)
                
                Text(CollectionInsightsService.shared.formatCurrency(growth.growthAmount))
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text("Purchase Value")
                        .font(.labelSmall)
                        .foregroundStyle(.textTertiary)
                    
                    Text(CollectionInsightsService.shared.formatCurrency(growth.purchaseValue))
                        .font(.bodyMedium.weight(.semibold))
                        .foregroundStyle(.textPrimary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.textTertiary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: Spacing.xSmall) {
                    Text("Current Value")
                        .font(.labelSmall)
                        .foregroundStyle(.textTertiary)
                    
                    Text(CollectionInsightsService.shared.formatCurrency(growth.currentValue))
                        .font(.bodyMedium.weight(.semibold))
                        .foregroundStyle(Color.stashdPrimary)
                }
            }
        }
        .padding(Spacing.large)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    // MARK: - AI Insights Section
    
    private func aiInsightsSection(insights: CollectionInsights) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.stashdPrimary)
                
                Text("AI Insights")
                    .font(.headlineSmall.weight(.semibold))
                    .foregroundStyle(.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: Spacing.small) {
                insightRow(icon: "chart.line.uptrend.xyaxis", text: insights.valueAnalysis)
                insightRow(icon: "crown.fill", text: insights.rarityScore)
                insightRow(icon: "chart.bar.fill", text: insights.marketTrend)
            }
        }
        .padding(Spacing.large)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    private func insightRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.small) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.stashdPrimary)
                .frame(width: 20)
            
            Text(text)
                .font(.bodyMedium)
                .foregroundStyle(.textPrimary)
        }
    }
    
    // MARK: - Top Items Section
    
    private func topItemsSection(items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                
                Text("Most Valuable Items")
                    .font(.headlineSmall.weight(.semibold))
                    .foregroundStyle(.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: Spacing.small) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text("\(index + 1).")
                            .font(.bodyMedium.weight(.bold))
                            .foregroundStyle(.textTertiary)
                            .frame(width: 24)
                        
                        Text(item)
                            .font(.bodyMedium)
                            .foregroundStyle(.textPrimary)
                    }
                }
            }
        }
        .padding(Spacing.large)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    // MARK: - Condition Breakdown
    
    private func conditionBreakdownSection(breakdown: [ItemCondition: Int]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.blue)
                
                Text("Condition Breakdown")
                    .font(.headlineSmall.weight(.semibold))
                    .foregroundStyle(.textPrimary)
            }
            
            VStack(spacing: Spacing.small) {
                ForEach(breakdown.sorted(by: { $0.value > $1.value }), id: \.key) { condition, count in
                    HStack {
                        Text(condition.rawValue)
                            .font(.bodyMedium)
                            .foregroundStyle(.textPrimary)
                        
                        Spacer()
                        
                        Text("\(count)")
                            .font(.bodyMedium.weight(.semibold))
                            .foregroundStyle(.textSecondary)
                    }
                }
            }
        }
        .padding(Spacing.large)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    // MARK: - Top Tags Section
    
    private func topTagsSection(tags: [(tag: String, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundStyle(.purple)
                
                Text("Popular Tags")
                    .font(.headlineSmall.weight(.semibold))
                    .foregroundStyle(.textPrimary)
            }
            
            FlowLayout(spacing: Spacing.small) {
                ForEach(tags, id: \.tag) { tag, count in
                    HStack(spacing: Spacing.xSmall) {
                        Text(tag)
                            .font(.labelMedium)
                        
                        Text("(\(count))")
                            .font(.labelSmall)
                            .foregroundStyle(.textTertiary)
                    }
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, Spacing.small)
                    .background(Color.stashdPrimary.opacity(0.1))
                    .foregroundStyle(Color.stashdPrimary)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(Spacing.large)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    // MARK: - Completion Suggestions
    
    private func completionSuggestionsSection(suggestions: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.orange)
                
                Text("Suggestions to Complete")
                    .font(.headlineSmall.weight(.semibold))
                    .foregroundStyle(.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: Spacing.small) {
                ForEach(suggestions, id: \.self) { suggestion in
                    HStack(alignment: .top, spacing: Spacing.small) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(Color.stashdPrimary)
                            .padding(.top, 6)
                        
                        Text(suggestion)
                            .font(.bodyMedium)
                            .foregroundStyle(.textPrimary)
                    }
                }
            }
        }
        .padding(Spacing.large)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    // MARK: - Actions
    
    private func loadInsights() async {
        isLoading = true
        errorMessage = nil
        
        // ✅ FIX EXISTING DATA FIRST
        fixItemValues()
        
        do {
            // ✅ DEBUG LOGGING
            if let items = collection.items {
                print("🔍 DEBUG: Collection has \(items.count) items (AFTER FIX)")
                for item in items {
                    print("📦 Item: \(item.name)")
                    print("   💰 Estimated Value: \(item.estimatedValue)")
                    print("   💵 Purchase Price: \(item.purchasePrice ?? 0)")
                }
            }
            
            // Calculate stats
            let calculatedStats = CollectionInsightsService.shared.calculateStats(for: collection)
            
            // ✅ DEBUG STATS
            print("📊 STATS:")
            print("   Total Value: \(calculatedStats.totalValue)")
            print("   Average Value: \(calculatedStats.averageValue)")
            print("   Item Count: \(calculatedStats.itemCount)")
            
            // Generate AI insights
            let generatedInsights = try await CollectionInsightsService.shared.generateInsights(
                for: collection,
                stats: calculatedStats
            )
            
            await MainActor.run {
                self.stats = calculatedStats
                self.insights = generatedInsights
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            
            ErrorLoggingService.shared.logError(
                error,
                context: "Load Collection Insights"
            )
        }
    }
    
    // ✅ TEMPORARY: Fix incorrect values (values stored as cents instead of dollars)
    private func fixItemValues() {
        guard let items = collection.items else { return }
        
        for item in items {
            // If estimated value is suspiciously high (> 1000), divide by 100
            if item.estimatedValue > 1000 {
                print("🔧 Fixing \(item.name): \(item.estimatedValue) -> \(item.estimatedValue / 100)")
                item.estimatedValue = item.estimatedValue / 100
            }
            
            // Same for purchase price
            if let purchasePrice = item.purchasePrice, purchasePrice > 1000 {
                print("🔧 Fixing purchase price: \(purchasePrice) -> \(purchasePrice / 100)")
                item.purchasePrice = purchasePrice / 100
            }
        }
        
        try? modelContext.save()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CollectionModel.self, configurations: config)
    
    let user = UserProfile(
        firebaseUID: "preview",
        username: "johndoe",
        displayName: "John Doe"
    )
    
    let collection = CollectionModel(
        title: "My Sneaker Collection",
        category: .sneakers,
        owner: user,
        estimatedValue: 5000
    )
    
    return CollectionInsightsView(collection: collection)
        .modelContainer(container)
        .environment(AppCoordinator())
}
