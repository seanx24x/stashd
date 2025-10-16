// File: Features/Collections/Views/CollectionDetailView.swift

import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    let collection: CollectionModel
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppCoordinator.self) private var coordinator
    
    @State private var showAddItem = false
    @State private var showAIScan = false
    @State private var showEditCollection = false
    @State private var showDeleteAlert = false
    @State private var showGenerateDescription = false
    @State private var isGeneratingDescription = false
    @State private var selectedTag: String? = nil
    @State private var showTagFilter = false
    @State private var collectionInsights: CollectionInsights?
    @State private var isGeneratingInsights = false
    @State private var completionSuggestions: [CompletionSuggestion]? = nil
    @State private var isGeneratingCompletions = false
    @State private var showInsights = false
    
    // ✅ FIXED: Computed property for all tags - safely unwrap items
    private var allTags: [String] {
        guard let items = collection.items else { return [] }
        let tagSet = Set(items.flatMap { $0.tags })
        return Array(tagSet).sorted()
    }
    
    // ✅ FIXED: Computed property for filtered items - safely unwrap
    private var filteredItems: [CollectionItem] {
        guard let items = collection.items else { return [] }
        if let selectedTag {
            return items.filter { $0.tags.contains(selectedTag) }
        }
        return items
    }
    
    // ✅ FIXED: Computed property for total collection value - safely unwrap
    private var totalValue: Decimal {
        guard let items = collection.items else { return 0 }
        return items.reduce(0) { $0 + $1.estimatedValue }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.large) {
                // Cover Image
                if let coverURL = collection.coverImageURL {
                    CachedAsyncImage(url: coverURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.surfaceElevated)
                            .overlay {
                                ProgressView()
                            }
                    }
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                }
                
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    // Collection Info
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                                Text(collection.title)
                                    .font(.displayMedium)
                                    .foregroundStyle(.textPrimary)
                                
                                // ✅ FIXED: Use categoryEnum
                                Label(collection.categoryEnum.rawValue, systemImage: collection.categoryEnum.iconName)
                                    .font(.labelLarge)
                                    .foregroundStyle(.textSecondary)
                            }
                            
                            Spacer()
                            
                            // Stats - ✅ FIXED: Safely unwrap items
                            VStack(alignment: .trailing, spacing: Spacing.xSmall) {
                                Text("\(collection.items?.count ?? 0)")
                                    .font(.headlineLarge)
                                    .foregroundStyle(Color.stashdPrimary)
                                
                                Text("Items")
                                    .font(.labelSmall)
                                    .foregroundStyle(.textSecondary)
                            }
                        }
                        
                        // Description
                        if let description = collection.collectionDescription {
                            Text(description)
                                .font(.bodyMedium)
                                .foregroundStyle(.textSecondary)
                                .padding(.top, Spacing.xSmall)
                        } else {
                            // Generate Description Button
                            Button {
                                HapticManager.shared.light()
                                showGenerateDescription = true
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Generate Description with AI")
                                        .font(.labelLarge.weight(.medium))
                                }
                                .foregroundStyle(Color.stashdPrimary)
                                .padding(.top, Spacing.xSmall)
                            }
                            // ✅ FIXED: Check if items exist and not empty
                            .disabled(isGeneratingDescription || (collection.items?.isEmpty ?? true))
                        }
                        
                        // AI Insights Section
                        if let insights = collectionInsights {
                            InsightsCard(insights: insights)
                                .transition(.scale.combined(with: .opacity))
                        } else if !(collection.items?.isEmpty ?? true) {
                            Button {
                                HapticManager.shared.light()
                                generateInsights()
                            } label: {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                    Text(isGeneratingInsights ? "Generating Insights..." : "Generate AI Insights")
                                        .font(.labelLarge.weight(.medium))
                                    
                                    if isGeneratingInsights {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .padding(.leading, Spacing.xSmall)
                                    }
                                }
                                .foregroundStyle(Color.stashdPrimary)
                                .padding(.top, Spacing.xSmall)
                            }
                            .disabled(isGeneratingInsights)
                        }
                        
                        // Completion Suggestions Section
                        if let suggestions = completionSuggestions, !suggestions.isEmpty {
                            CompletionSuggestionsCard(suggestions: suggestions)
                                .transition(.scale.combined(with: .opacity))
                        } else if !(collection.items?.isEmpty ?? true) && collectionInsights != nil {
                            Button {
                                HapticManager.shared.light()
                                generateCompletions()
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text(isGeneratingCompletions ? "Generating Suggestions..." : "Get Completion Suggestions")
                                        .font(.labelLarge.weight(.medium))
                                    
                                    if isGeneratingCompletions {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .padding(.leading, Spacing.xSmall)
                                    }
                                }
                                .foregroundStyle(Color.stashdPrimary)
                                .padding(.top, Spacing.xSmall)
                            }
                            .disabled(isGeneratingCompletions)
                        }
                        
                        // Total Value
                        if totalValue > 0 {
                            HStack {
                                Text("Total Value:")
                                    .font(.bodyMedium)
                                    .foregroundStyle(.textSecondary)
                                
                                Text(formatCurrency(totalValue))
                                    .font(.bodyMedium.weight(.semibold))
                                    .foregroundStyle(Color.stashdPrimary)
                            }
                            .padding(.top, Spacing.xSmall)
                        }
                    }
                    
                    Divider()
                    
                    // Tag Filter Section
                    if !allTags.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            HStack {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.caption)
                                    .foregroundStyle(Color.stashdPrimary)
                                
                                Text("Filter by Tag")
                                    .font(.labelLarge.weight(.semibold))
                                    .foregroundStyle(.textPrimary)
                                
                                Spacer()
                                
                                if selectedTag != nil {
                                    Button {
                                        HapticManager.shared.light()
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedTag = nil
                                        }
                                    } label: {
                                        Text("Clear")
                                            .font(.labelMedium)
                                            .foregroundStyle(Color.stashdPrimary)
                                    }
                                }
                            }
                            
                            FlowLayout(spacing: Spacing.xSmall) {
                                ForEach(allTags, id: \.self) { tag in
                                    FilterTagChip(
                                        text: tag,
                                        isSelected: selectedTag == tag
                                    )
                                    .onTapGesture {
                                        HapticManager.shared.light()
                                        withAnimation(.spring(response: 0.3)) {
                                            if selectedTag == tag {
                                                selectedTag = nil
                                            } else {
                                                selectedTag = tag
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, Spacing.small)
                        
                        Divider()
                    }
                    
                    // Items Header with count
                    HStack {
                        Text(selectedTag != nil ? "Filtered Items (\(filteredItems.count))" : "Items (\(collection.items?.count ?? 0))")
                            .font(.headlineSmall)
                            .foregroundStyle(.textPrimary)
                        
                        Spacer()
                        
                        Menu {
                            Button {
                                HapticManager.shared.light()
                                showAIScan = true
                            } label: {
                                Label("AI Scan", systemImage: "wand.and.stars")
                            }
                            
                            Button {
                                HapticManager.shared.light()
                                showAddItem = true
                            } label: {
                                Label("Add Manually", systemImage: "plus.circle")
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.stashdPrimary)
                        }
                    }
                    
                    // Items Grid - USE FILTERED ITEMS
                    if filteredItems.isEmpty {
                        if selectedTag != nil {
                            // No items with this tag
                            VStack(spacing: Spacing.medium) {
                                Image(systemName: "tag.slash")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.textTertiary)
                                
                                Text("No items with tag '\(selectedTag!)'")
                                    .font(.bodyLarge)
                                    .foregroundStyle(.textSecondary)
                                
                                Button {
                                    HapticManager.shared.light()
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedTag = nil
                                    }
                                } label: {
                                    Text("Clear Filter")
                                        .font(.labelLarge.weight(.medium))
                                        .foregroundStyle(Color.stashdPrimary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.xxLarge)
                        } else {
                            EmptyItemsView()
                        }
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: Spacing.medium),
                                GridItem(.flexible(), spacing: Spacing.medium)
                            ],
                            spacing: Spacing.medium
                        ) {
                            ForEach(filteredItems) { item in
                                Button {
                                    HapticManager.shared.light()
                                    coordinator.navigate(to: .itemDetail(item.id))
                                } label: {
                                    ItemGridCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.large)
            }
            .padding(.bottom, Spacing.xxLarge)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        HapticManager.shared.light()
                        showInsights = true
                    } label: {
                        Label("View Insights", systemImage: "chart.bar.fill")
                    }
                    
                    Divider()
                    
                    Button {
                        HapticManager.shared.light()
                        showEditCollection = true
                    } label: {
                        Label("Edit Collection", systemImage: "pencil")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        HapticManager.shared.warning()
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Collection", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.textPrimary)
                }
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddItemView(collection: collection)
                .environment(coordinator)
        }
        .sheet(isPresented: $showInsights) {
            CollectionInsightsView(collection: collection)
        }
        .sheet(isPresented: $showAIScan) {
            AIItemScanView(collection: collection) { newItem in
                // Item added successfully
            }
        }
        .sheet(isPresented: $showEditCollection) {
            Text("Edit Collection Coming Soon")
        }
        .sheet(isPresented: $showGenerateDescription) {
            NavigationStack {
                VStack(spacing: Spacing.large) {
                    if isGeneratingDescription {
                        VStack(spacing: Spacing.medium) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Generating description...")
                                .font(.bodyLarge)
                                .foregroundStyle(.textSecondary)
                        }
                        .padding()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Generate Description")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showGenerateDescription = false
                        }
                    }
                }
                .task {
                    await generateDescription()
                }
            }
        }
        .alert("Delete Collection?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteCollection()
            }
        } message: {
            Text("This will permanently delete '\(collection.title)' and all its items. This action cannot be undone.")
        }
    }
    
    private func deleteCollection() {
        modelContext.delete(collection)
        try? modelContext.save()
        HapticManager.shared.success()
        dismiss()
    }
    
    // ✅ FIXED: Generate description with safe array access
    private func generateDescription() async {
        isGeneratingDescription = true
        
        do {
            guard let items = collection.items, !items.isEmpty else {
                isGeneratingDescription = false
                showGenerateDescription = false
                return
            }
            
            let topItems = items.prefix(5).map { $0.name }
            
            let description = try await OpenAIService.shared.generateCollectionDescription(
                title: collection.title,
                category: collection.categoryEnum.rawValue,  // ✅ FIXED: Use categoryEnum
                itemCount: items.count,
                topItems: topItems,
                totalValue: totalValue,
                dateRange: nil
            )
            
            collection.collectionDescription = description
            try? modelContext.save()
            
            HapticManager.shared.success()
            showGenerateDescription = false
        } catch {
            print("Failed to generate description: \(error)")
        }
        
        isGeneratingDescription = false
    }
    
    private func generateInsights() {
        Task {
            isGeneratingInsights = true
            
            do {
                let stats = CollectionInsightsService.shared.calculateStats(for: collection)
                let insights = try await CollectionInsightsService.shared.generateInsights(
                    for: collection,
                    stats: stats
                )
                
                withAnimation(.spring(response: 0.3)) {
                    collectionInsights = insights
                }
                
                HapticManager.shared.success()
            } catch {
                print("Failed to generate insights: \(error)")
                HapticManager.shared.error()
            }
            
            isGeneratingInsights = false
        }
    }
    
    private func generateCompletions() {
        Task {
            isGeneratingCompletions = true
            
            do {
                let suggestions = try await CollectionInsightsService.shared.generateCompletionSuggestions(
                    for: collection
                )
                
                withAnimation(.spring(response: 0.3)) {
                    completionSuggestions = suggestions
                }
                
                HapticManager.shared.success()
            } catch {
                print("Failed to generate completions: \(error)")
                HapticManager.shared.error()
            }
            
            isGeneratingCompletions = false
        }
    }
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
    }
}

// MARK: - Insights Card

struct InsightsCard: View {
    let insights: CollectionInsights
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Color.stashdPrimary)
                
                Text("AI Insights")
                    .font(.labelLarge.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(Color.stashdPrimary)
            }
            
            VStack(spacing: Spacing.small) {
                // Value Analysis
                InsightRow(
                    icon: "dollarsign.circle.fill",
                    title: "Value Analysis",
                    content: insights.valueAnalysis,
                    color: .green
                )
                
                Divider()
                
                // Rarity Score
                InsightRow(
                    icon: "star.fill",
                    title: "Rarity",
                    content: insights.rarityScore,
                    color: .orange
                )
                
                Divider()
                
                // Market Trend
                InsightRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Market Trend",
                    content: insights.marketTrend,
                    color: .blue
                )
                
                // Completion Suggestions
                if !insights.completionSuggestions.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        HStack {
                            Image(systemName: "checklist")
                                .font(.caption)
                                .foregroundStyle(Color.purple)
                            
                            Text("Suggestions")
                                .font(.labelMedium.weight(.semibold))
                                .foregroundStyle(.textPrimary)
                        }
                        
                        ForEach(insights.completionSuggestions, id: \.self) { suggestion in
                            HStack(alignment: .top, spacing: Spacing.xSmall) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.textTertiary)
                                    .padding(.top, 2)
                                
                                Text(suggestion)
                                    .font(.bodySmall)
                                    .foregroundStyle(.textSecondary)
                            }
                        }
                    }
                }
                
                // General Insights
                if !insights.insights.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.stashdPrimary)
                            
                            Text("Key Insights")
                                .font(.labelMedium.weight(.semibold))
                                .foregroundStyle(.textPrimary)
                        }
                        
                        ForEach(insights.insights, id: \.self) { insight in
                            HStack(alignment: .top, spacing: Spacing.xSmall) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.stashdPrimary)
                                    .padding(.top, 2)
                                
                                Text(insight)
                                    .font(.bodySmall)
                                    .foregroundStyle(.textSecondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(Spacing.medium)
        .background(
            LinearGradient(
                colors: [
                    Color.stashdPrimary.opacity(0.05),
                    Color.stashdPrimary.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .strokeBorder(
                    Color.stashdPrimary.opacity(0.2),
                    lineWidth: 1
                )
        }
        .padding(.top, Spacing.small)
    }
}

struct InsightRow: View {
    let icon: String
    let title: String
    let content: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.labelMedium.weight(.semibold))
                    .foregroundStyle(.textPrimary)
            }
            
            Text(content)
                .font(.bodySmall)
                .foregroundStyle(.textSecondary)
        }
    }
}

// MARK: - Completion Suggestions Card

struct CompletionSuggestionsCard: View {
    let suggestions: [CompletionSuggestion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(Color.purple)
                
                Text("Completion Suggestions")
                    .font(.labelLarge.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(Color.purple)
            }
            
            VStack(spacing: Spacing.small) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                    SuggestionRow(suggestion: suggestion, index: index)
                    
                    if index < suggestions.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(Spacing.medium)
        .background(
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.05),
                    Color.purple.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .strokeBorder(
                    Color.purple.opacity(0.2),
                    lineWidth: 1
                )
        }
        .padding(.top, Spacing.small)
    }
}

struct SuggestionRow: View {
    let suggestion: CompletionSuggestion
    let index: Int
    
    private var priorityColor: Color {
        switch suggestion.priority.lowercased() {
        case "high":
            return .red
        case "medium":
            return .orange
        case "low":
            return .green
        default:
            return .gray
        }
    }
    
    private var priorityIcon: String {
        switch suggestion.priority.lowercased() {
        case "high":
            return "exclamationmark.3"
        case "medium":
            return "exclamationmark.2"
        case "low":
            return "exclamationmark"
        default:
            return "circle"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(alignment: .top, spacing: Spacing.small) {
                // Number badge
                Text("\(index + 1)")
                    .font(.labelSmall.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.purple)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    // Item name with priority badge
                    HStack {
                        Text(suggestion.itemName)
                            .font(.bodyMedium.weight(.semibold))
                            .foregroundStyle(.textPrimary)
                        
                        Spacer()
                        
                        // Priority badge
                        HStack(spacing: 4) {
                            Image(systemName: priorityIcon)
                                .font(.caption2)
                            Text(suggestion.priority.capitalized)
                                .font(.labelSmall.weight(.medium))
                        }
                        .foregroundStyle(priorityColor)
                        .padding(.horizontal, Spacing.xSmall)
                        .padding(.vertical, 2)
                        .background(priorityColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    // Reason
                    Text(suggestion.reason)
                        .font(.bodySmall)
                        .foregroundStyle(.textSecondary)
                }
            }
        }
    }
}

// Filter Tag Chip (different style from regular TagChip)
struct FilterTagChip: View {
    let text: String
    let isSelected: Bool
    
    var body: some View {
        Text(text)
            .font(.labelSmall.weight(.medium))
            .foregroundStyle(isSelected ? .white : Color.stashdPrimary)
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, 6)
            .background(isSelected ? Color.stashdPrimary : Color.stashdPrimary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.stashdPrimary.opacity(0.3), lineWidth: 1)
                }
            }
    }
}

struct EmptyItemsView: View {
    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 64))
                .foregroundStyle(.textTertiary)
            
            VStack(spacing: Spacing.small) {
                Text("No items yet")
                    .font(.headlineSmall)
                    .foregroundStyle(.textPrimary)
                
                Text("Add your first item to get started")
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxLarge)
    }
}

struct ItemGridCard: View {
    let item: CollectionItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            // Image
            Group {
                if let firstImageURL = item.imageURLs.first {
                    CachedAsyncImage(url: firstImageURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.surfaceElevated)
                            .overlay {
                                ProgressView()
                            }
                    }
                } else {
                    Rectangle()
                        .fill(Color.surfaceElevated)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.textTertiary)
                        }
                }
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            
            // Info
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(item.name)
                    .font(.labelLarge.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2)
                
                if item.estimatedValue > 0 {
                    Text(formatCurrency(item.estimatedValue))
                        .font(.labelMedium)
                        .foregroundStyle(Color.stashdPrimary)
                }
            }
        }
        .background(.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
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
        title: "My Vinyl Collection",
        category: .vinyl,
        owner: user
    )
    
    return NavigationStack {
        AddItemView(collection: collection)
            .modelContainer(container)
            .environment(AppCoordinator())  // ✅ ADD THIS
    }
}
