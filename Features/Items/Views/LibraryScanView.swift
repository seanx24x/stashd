//
//  LibraryScanView.swift
//  stashd
//
//  Created by Sean Lynch on 10/17/25.
//

import SwiftUI
import SwiftData
import PhotosUI

struct LibraryScanView: View {
    let collection: CollectionModel
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = true
    @State private var isAnalyzing = false
    @State private var itemAnalysis: OpenAIService.ItemAnalysis?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                if let selectedImage = selectedImage {
                    if isAnalyzing {
                        analyzingView(image: selectedImage)
                    } else if let itemAnalysis = itemAnalysis {
                        confirmedAnalysisView(image: selectedImage, analysis: itemAnalysis)
                    } else if let errorMessage = errorMessage {
                        errorView(image: selectedImage, error: errorMessage)
                    }
                } else {
                    instructionView
                }
            }
            .navigationTitle("Scan from Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                if let image = newValue {
                    Task {
                        await analyzeImage(image)
                    }
                }
            }
        }
    }
    
    private var instructionView: some View {
        VStack(spacing: Spacing.large) {
            Spacer()
            
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 64))
                .foregroundStyle(.textTertiary)
            
            VStack(spacing: Spacing.small) {
                Text("Select a photo to analyze")
                    .font(.headlineMedium)
                    .foregroundStyle(.textPrimary)
                
                Text("Choose from your photo library")
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
            }
            
            Spacer()
        }
        .padding(Spacing.large)
    }
    
    private func confirmedAnalysisView(image: UIImage, analysis: OpenAIService.ItemAnalysis) -> some View {
        ScrollView {
            VStack(spacing: Spacing.large) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    Text(analysis.name)
                        .font(.headlineLarge)
                        .foregroundStyle(.textPrimary)
                    
                    Text(analysis.description)
                        .font(.bodyMedium)
                        .foregroundStyle(.textSecondary)
                    
                    HStack {
                        Text("Estimated Value:")
                            .font(.labelLarge)
                            .foregroundStyle(.textSecondary)
                        
                        Text(analysis.estimatedValue)
                            .font(.headlineMedium)
                            .foregroundStyle(Color.stashdPrimary)
                    }
                }
                .padding(Spacing.medium)
                
                HStack(spacing: Spacing.medium) {
                    Button {
                        selectedImage = nil
                        itemAnalysis = nil
                        errorMessage = nil
                        showImagePicker = true
                    } label: {
                        Text("Choose Another")
                            .font(.bodyMedium.weight(.semibold))
                            .foregroundStyle(.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.medium)
                            .background(Color.surfaceElevated)
                            .clipShape(Capsule())
                    }
                    
                    Button {
                        Task {
                            await saveItem(image: image, analysis: analysis)
                        }
                    } label: {
                        Text("Add to Collection")
                            .font(.bodyMedium.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.medium)
                            .background(Color.stashdPrimary)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, Spacing.large)
            }
            .padding(Spacing.large)
        }
    }
    
    private func analyzingView(image: UIImage) -> some View {
        VStack(spacing: Spacing.xLarge) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            
            VStack(spacing: Spacing.medium) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("AI is analyzing your item...")
                    .font(.bodyLarge)
                    .foregroundStyle(.textSecondary)
            }
        }
        .padding(Spacing.large)
    }
    
    private func errorView(image: UIImage, error: String) -> some View {
        VStack(spacing: Spacing.large) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            
            VStack(spacing: Spacing.medium) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
                
                Text("Analysis Failed")
                    .font(.headlineMedium)
                    .foregroundStyle(.textPrimary)
                
                Text(error)
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    selectedImage = nil
                    errorMessage = nil
                    showImagePicker = true
                } label: {
                    Text("Try Another Photo")
                        .font(.bodyMedium.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.large)
                        .padding(.vertical, Spacing.medium)
                        .background(Color.stashdPrimary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(Spacing.large)
    }
    
    private func analyzeImage(_ image: UIImage) async {
        isAnalyzing = true
        errorMessage = nil
        
        do {
            let result = try await OpenAIService.shared.analyzeItem(image: image)
            
            await MainActor.run {
                itemAnalysis = result
                isAnalyzing = false
                HapticManager.shared.success()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isAnalyzing = false
                HapticManager.shared.error()
            }
        }
    }
    
    private func saveItem(image: UIImage, analysis: OpenAIService.ItemAnalysis) async {
        do {
            // Upload to Firebase Storage
            let imageURL = try await StorageService.shared.uploadItemImage(
                image,
                itemID: UUID().uuidString
            )
            
            let item = CollectionItem(
                name: analysis.name,
                collection: collection
            )
            item.notes = analysis.description
            
            let valueString = analysis.estimatedValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let value = Double(valueString), value > 0 {
                item.estimatedValue = Decimal(value)
            }
            
            item.imageURLs = [imageURL]
            item.displayOrder = collection.items?.count ?? 0
            
            modelContext.insert(item)
            try modelContext.save()
            
            await MainActor.run {
                HapticManager.shared.success()
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                HapticManager.shared.error()
            }
        }
    }
}
