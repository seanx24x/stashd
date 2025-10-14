//
//  AIItemScanView.swift
//  stashd
//
//  Created by Sean Lynch on 10/12/25.
//

// File: Features/Collections/Views/AIItemScanView.swift

import SwiftUI
import PhotosUI
import SwiftData

struct AIItemScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let collection: CollectionModel
    let onItemCreated: (CollectionItem) -> Void
    
    @State private var selectedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var analysis: OpenAIService.ItemAnalysis?
    @State private var errorMessage: String?
    @State private var showImagePicker = false
    @State private var generatedTags: [String] = []
    @State private var isGeneratingTags = false
    @State private var duplicateCheckResult: DuplicateCheckResult?
    @State private var showDuplicateWarning = false
    @State private var isCheckingDuplicates = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xLarge) {
                    // Header
                    VStack(spacing: Spacing.small) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.stashdPrimary)
                            .symbolEffect(.bounce, value: isAnalyzing)
                        
                        Text("AI Item Scanner")
                            .font(.headlineLarge)
                            .foregroundStyle(.textPrimary)
                        
                        Text("Take a photo and let AI identify your item")
                            .font(.bodyMedium)
                            .foregroundStyle(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Spacing.large)
                    
                    // Image Preview
                    if let image = selectedImage {
                        VStack(spacing: Spacing.medium) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                                .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
                            
                            Button {
                                HapticManager.shared.light()
                                showImagePicker = true
                            } label: {
                                Label("Change Photo", systemImage: "photo")
                                    .font(.bodyMedium)
                                    .foregroundStyle(Color.stashdPrimary)
                            }
                        }
                    } else {
                        // Image Picker Button
                        Button {
                            HapticManager.shared.light()
                            showImagePicker = true
                        } label: {
                            VStack(spacing: Spacing.medium) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.textTertiary)
                                
                                Text("Take or Choose Photo")
                                    .font(.bodyLarge.weight(.semibold))
                                    .foregroundStyle(.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .background(.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                            .overlay {
                                RoundedRectangle(cornerRadius: CornerRadius.large)
                                    .strokeBorder(Color.separator, style: StrokeStyle(lineWidth: 2, dash: [8]))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Analysis Results
                    if let analysis {
                        AIAnalysisCard(
                            analysis: analysis,
                            tags: generatedTags,
                            isGeneratingTags: isGeneratingTags,
                            duplicateResult: duplicateCheckResult,
                            isCheckingDuplicates: isCheckingDuplicates
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Error Message
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.bodyMedium)
                            .foregroundStyle(.error)
                            .multilineTextAlignment(.center)
                            .padding(Spacing.medium)
                            .background(.error.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    }
                }
                .padding(.horizontal, Spacing.large)
                .padding(.bottom, Spacing.xxLarge)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.light()
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: Spacing.medium) {
                    if selectedImage != nil && analysis == nil {
                        LoadingButton(
                            title: isAnalyzing ? "Analyzing..." : "Analyze with AI",
                            isLoading: isAnalyzing
                        ) {
                            analyzeImage()
                        }
                        .disabled(isAnalyzing)
                        .padding(.horizontal, Spacing.large)
                    }
                    
                    if analysis != nil {
                        LoadingButton(
                            title: "Add to Collection",
                            isLoading: false
                        ) {
                            createItem()
                        }
                        .padding(.horizontal, Spacing.large)
                    }
                }
                .padding(.vertical, Spacing.medium)
                .background(.ultraThinMaterial)
            }
            .photosPicker(isPresented: $showImagePicker, selection: Binding(
                get: { nil },
                set: { newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImage = image
                            analysis = nil
                            errorMessage = nil
                            generatedTags = []
                            duplicateCheckResult = nil
                        }
                    }
                }
            ))
            .alert("Possible Duplicate", isPresented: $showDuplicateWarning) {
                Button("Add Anyway", role: .none) {
                    duplicateCheckResult = nil
                }
                Button("Cancel", role: .cancel) {
                    analysis = nil
                    generatedTags = []
                    duplicateCheckResult = nil
                }
            } message: {
                if let result = duplicateCheckResult {
                    Text("This item might already be in your collection.\n\n\(result.reason ?? "Similar items found")\n\nConfidence: \(result.confidence)%\n\nMatched: \(result.matchedItems.joined(separator: ", "))")
                }
            }
        }
    }
    
    private func analyzeImage() {
        guard let image = selectedImage else { return }
        
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            do {
                // Step 1: Analyze the image
                let result = try await OpenAIService.shared.analyzeItem(image: image)
                
                await MainActor.run {
                    HapticManager.shared.success()
                    withAnimation(.spring(response: 0.3)) {
                        analysis = result
                    }
                    isAnalyzing = false
                }
                
                // Step 2: Generate tags
                await generateTags(for: result)
                
                // Step 3: Check for duplicates
                await checkForDuplicates(result: result)
                
            } catch {
                await MainActor.run {
                    HapticManager.shared.error()
                    errorMessage = error.localizedDescription
                    isAnalyzing = false
                }
            }
        }
    }
    
    private func generateTags(for analysis: OpenAIService.ItemAnalysis) async {
        isGeneratingTags = true
        
        do {
            let tags = try await OpenAIService.shared.generateSmartTags(
                itemName: analysis.name,
                category: analysis.category,
                description: analysis.description
            )
            
            await MainActor.run {
                withAnimation(.spring(response: 0.3)) {
                    generatedTags = tags
                }
                isGeneratingTags = false
            }
        } catch {
            await MainActor.run {
                print("Failed to generate tags: \(error)")
                isGeneratingTags = false
            }
        }
    }
    
    // ✅ FIXED: Duplicate Detection
    private func checkForDuplicates(result: OpenAIService.ItemAnalysis) async {
        isCheckingDuplicates = true
        
        do {
            // ✅ FIX: Safely unwrap optional items array
            let existingItems = collection.items ?? []
            
            let duplicateResult = try await CollectionInsightsService.shared.checkForDuplicates(
                newItemName: result.name,
                newItemDescription: result.description,
                existingItems: existingItems
            )
            
            await MainActor.run {
                withAnimation(.spring(response: 0.3)) {
                    duplicateCheckResult = duplicateResult
                }
                
                if duplicateResult.isDuplicate && duplicateResult.confidence > 70 {
                    showDuplicateWarning = true
                    HapticManager.shared.warning()
                }
                
                isCheckingDuplicates = false
            }
        } catch {
            await MainActor.run {
                print("Failed to check duplicates: \(error)")
                isCheckingDuplicates = false
            }
        }
    }
    
    // ✅ FIXED: Create Item
    private func createItem() {
        guard let image = selectedImage,
              let analysis else { return }
        
        // Create the item with required parameters only
        let item = CollectionItem(
            name: analysis.name,
            collection: collection
        )
        
        // Set optional properties
        item.notes = analysis.description
        
        // Parse estimated value
        let valueString = analysis.estimatedValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let value = Double(valueString), value > 0 {
            item.estimatedValue = Decimal(value)
        }
        
        // Set condition if available
        if let conditionString = analysis.condition {
            switch conditionString.lowercased() {
            case "mint":
                item.condition = .mint
            case "near mint":
                item.condition = .nearMint
            case "excellent", "good":
                item.condition = .good
            case "fair":
                item.condition = .fair
            case "poor":
                item.condition = .poor
            default:
                item.condition = .good
            }
        }
        
        // Set generated tags
        item.tags = generatedTags
        
        // ✅ FIX: Insert into modelContext instead of appending
        // SwiftData automatically establishes the relationship
        modelContext.insert(item)
        
        // Upload image to Firebase Storage
        Task {
            do {
                let imageURL = try await StorageService.shared.uploadItemImage(
                    image,
                    itemID: item.id.uuidString
                )
                
                await MainActor.run {
                    item.imageURLs = [imageURL]
                    try? modelContext.save()
                    
                    HapticManager.shared.success()
                    onItemCreated(item)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    HapticManager.shared.error()
                    errorMessage = "Failed to upload image: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct AIAnalysisCard: View {
    let analysis: OpenAIService.ItemAnalysis
    let tags: [String]
    let isGeneratingTags: Bool
    let duplicateResult: DuplicateCheckResult?
    let isCheckingDuplicates: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.stashdPrimary)
                
                Text("AI Analysis")
                    .font(.labelLarge.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: Spacing.small) {
                AnalysisRow(label: "Name", value: analysis.name)
                AnalysisRow(label: "Category", value: analysis.category)
                AnalysisRow(label: "Est. Value", value: analysis.estimatedValue)
                if let condition = analysis.condition {
                    AnalysisRow(label: "Condition", value: condition)
                }
            }
            
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text("Description")
                    .font(.labelMedium)
                    .foregroundStyle(.textSecondary)
                
                Text(analysis.description)
                    .font(.bodyMedium)
                    .foregroundStyle(.textPrimary)
            }
            
            if !analysis.details.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text("Details")
                        .font(.labelMedium)
                        .foregroundStyle(.textSecondary)
                    
                    ForEach(analysis.details, id: \.self) { detail in
                        HStack(spacing: Spacing.xSmall) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.stashdPrimary)
                            
                            Text(detail)
                                .font(.bodySmall)
                                .foregroundStyle(.textPrimary)
                        }
                    }
                }
            }
            
            // Tags Section
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                HStack {
                    Image(systemName: "tag.fill")
                        .font(.caption)
                        .foregroundStyle(Color.stashdPrimary)
                    
                    Text("Smart Tags")
                        .font(.labelMedium)
                        .foregroundStyle(.textSecondary)
                    
                    if isGeneratingTags {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.leading, Spacing.xSmall)
                    }
                }
                
                if !tags.isEmpty {
                    FlowLayout(spacing: Spacing.xSmall) {
                        ForEach(tags, id: \.self) { tag in
                            TagChip(text: tag)
                        }
                    }
                } else if !isGeneratingTags {
                    Text("No tags generated")
                        .font(.bodySmall)
                        .foregroundStyle(.textTertiary)
                }
            }
            
            // Duplicate Warning Section
            if isCheckingDuplicates {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Checking for duplicates...")
                        .font(.labelSmall)
                        .foregroundStyle(.textSecondary)
                }
                .padding(Spacing.small)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.stashdPrimary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            } else if let duplicateResult, duplicateResult.isDuplicate {
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        
                        Text("Possible Duplicate")
                            .font(.labelMedium.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    
                    Text(duplicateResult.reason ?? "This item might already be in your collection")
                        .font(.bodySmall)
                        .foregroundStyle(.textSecondary)
                    
                    if !duplicateResult.matchedItems.isEmpty {
                        Text("Similar to: \(duplicateResult.matchedItems.joined(separator: ", "))")
                            .font(.bodySmall)
                            .foregroundStyle(.textTertiary)
                    }
                    
                    Text("Confidence: \(duplicateResult.confidence)%")
                        .font(.labelSmall)
                        .foregroundStyle(.textTertiary)
                }
                .padding(Spacing.small)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
        }
        .padding(Spacing.medium)
        .background(.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

struct TagChip: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.labelSmall.weight(.medium))
            .foregroundStyle(Color.stashdPrimary)
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, 4)
            .background(Color.stashdPrimary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

struct AnalysisRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.bodyMedium)
                .foregroundStyle(.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.bodyMedium.weight(.semibold))
                .foregroundStyle(.textPrimary)
        }
    }
}

#Preview {
    AIItemScanView(
        collection: CollectionModel(
            title: "Preview",
            category: .sneakers,
            owner: UserProfile(firebaseUID: "preview", username: "test", displayName: "Test")
        ),
        onItemCreated: { _ in }
    )
}
