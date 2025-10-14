// File: Features/Collections/Views/AddItemView.swift

import SwiftUI
import SwiftData
import PhotosUI

struct AddItemView: View {
    let collection: CollectionModel
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var itemDescription = ""
    @State private var selectedImages: [UIImage] = []
    @State private var selectedCondition: ItemCondition?
    @State private var purchasePrice = ""
    @State private var estimatedValue = ""
    @State private var purchaseDate = Date()
    @State private var showDatePicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showImagePicker = false
    
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case name, description, price, value
    }
    
    var isFormValid: Bool {
        !name.isEmpty && name.count >= 2 && !selectedImages.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xLarge) {
                    headerSection
                    
                    imageSelectionSection
                    
                    itemDetailsSection
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.bodySmall)
                            .foregroundStyle(Color.error)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, Spacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addItem()
                    }
                    .foregroundStyle(Color.stashdPrimary)
                    .fontWeight(.semibold)
                    .disabled(!isFormValid || isLoading)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                MultiImagePicker(selectedImages: $selectedImages, maxSelection: 10)
            }
            .overlay {
                if isLoading {
                    loadingOverlay
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: Spacing.small) {
            Text("Add Item")
                .font(.displayMedium)
                .foregroundStyle(Color.textPrimary)
            
            Text("Add to \(collection.title)")
                .font(.bodyLarge)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.top, Spacing.medium)
    }
    
    private var imageSelectionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Text("Photos")
                    .font(.labelLarge)
                    .foregroundStyle(Color.textSecondary)
                
                Spacer()
                
                Text("\(selectedImages.count)/10")
                    .font(.labelMedium)
                    .foregroundStyle(Color.textTertiary)
            }
            
            if selectedImages.isEmpty {
                emptyImagePlaceholder
            } else {
                imageScrollView
            }
        }
    }
    
    private var emptyImagePlaceholder: some View {
        Button {
            showImagePicker = true
        } label: {
            VStack(spacing: Spacing.medium) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.textTertiary)
                
                Text("Add Photos")
                    .font(.bodyLarge)
                    .foregroundStyle(Color.textSecondary)
                
                Text("Tap to select up to 10 photos")
                    .font(.labelMedium)
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .strokeBorder(
                        Color.separator,
                        style: StrokeStyle(lineWidth: 2, dash: [8])
                    )
            }
        }
        .buttonStyle(.plain)
    }
    
    private var imageScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.small) {
                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                    imageCell(image: image, index: index)
                }
                
                if selectedImages.count < 10 {
                    addMoreButton
                }
            }
        }
    }
    
    private func imageCell(image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            
            Button {
                removeImage(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .background(
                        Circle()
                            .fill(.black.opacity(0.5))
                            .padding(4)
                    )
            }
            .padding(4)
        }
    }

    private func removeImage(at index: Int) {
        _ = withAnimation {
            selectedImages.remove(at: index)
        }
    }
    
    private var addMoreButton: some View {
        Button {
            showImagePicker = true
        } label: {
            VStack(spacing: Spacing.xSmall) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color.stashdPrimary)
                
                Text("Add More")
                    .font(.labelSmall)
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(width: 120, height: 120)
            .background(Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(Color.separator, lineWidth: 1)
            }
        }
    }
    
    private var itemDetailsSection: some View {
        VStack(spacing: Spacing.large) {
            CollectTextField(
                title: "Item Name",
                placeholder: "Blue Note Classics Vol. 1",
                text: $name,
                icon: "tag"
            )
            .focused($focusedField, equals: .name)
            
            descriptionField
            conditionPicker
            priceFields
            dateAcquiredPicker
        }
    }
    
    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("Description (Optional)")
                .font(.labelMedium)
                .foregroundStyle(Color.textSecondary)
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $itemDescription)
                    .frame(height: 100)
                    .padding(Spacing.small)
                    .background(Color.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    .overlay {
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .strokeBorder(Color.separator, lineWidth: 1)
                    }
                    .focused($focusedField, equals: .description)
                
                if itemDescription.isEmpty {
                    Text("Add details about this item...")
                        .font(.bodyMedium)
                        .foregroundStyle(Color.textTertiary)
                        .padding(.leading, Spacing.small + 4)
                        .padding(.top, Spacing.small + 8)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    private var conditionPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("Condition (Optional)")
                .font(.labelMedium)
                .foregroundStyle(Color.textSecondary)
            
            Menu {
                Button("None") {
                    selectedCondition = nil
                }
                
                Divider()
                
                ForEach(ItemCondition.allCases, id: \.self) { condition in
                    Button(condition.rawValue) {
                        selectedCondition = condition
                    }
                }
            } label: {
                HStack {
                    Text(selectedCondition?.rawValue ?? "Select condition")
                        .foregroundStyle(selectedCondition == nil ? Color.textTertiary : Color.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(Spacing.medium)
                .background(Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .strokeBorder(Color.separator, lineWidth: 1)
                }
            }
        }
    }
    
    private var priceFields: some View {
        HStack(spacing: Spacing.medium) {
            priceField(title: "Purchase Price", text: $purchasePrice, field: .price)
            priceField(title: "Current Value", text: $estimatedValue, field: .value)
        }
    }
    
    private func priceField(title: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(title)
                .font(.labelMedium)
                .foregroundStyle(Color.textSecondary)
            
            HStack(spacing: Spacing.xSmall) {
                Text("$")
                    .foregroundStyle(Color.textSecondary)
                
                TextField("0.00", text: text)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: field)
            }
            .padding(Spacing.medium)
            .background(Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(Color.separator, lineWidth: 1)
            }
        }
    }
    
    private var dateAcquiredPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("Purchase Date (Optional)")
                .font(.labelMedium)
                .foregroundStyle(Color.textSecondary)
            
            Button {
                showDatePicker.toggle()
            } label: {
                HStack {
                    Text(purchaseDate.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(Color.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(Spacing.medium)
                .background(Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .strokeBorder(Color.separator, lineWidth: 1)
                }
            }
            
            if showDatePicker {
                DatePicker(
                    "",
                    selection: $purchaseDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
            }
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: Spacing.medium) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                
                Text("Adding item...")
                    .font(.bodyLarge)
                    .foregroundStyle(.white)
            }
        }
    }
    
    // MARK: - Actions
    
    private func addItem() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Save images
                var imageURLs: [URL] = []
                for (index, image) in selectedImages.enumerated() {
                    if let url = try await saveItemImage(image, itemID: UUID().uuidString, index: index) {
                        imageURLs.append(url)
                    }
                }
                
                // Create item
                let item = CollectionItem(
                    name: name,
                    collection: collection,
                    notes: itemDescription.isEmpty ? nil : itemDescription,
                    condition: selectedCondition,
                    purchaseDate: purchaseDate,
                    imageURLs: imageURLs
                )
                
                // Set display order based on current items count
                item.displayOrder = collection.items.count
                
                // Set estimated value from either field (prioritize current value over purchase price)
                if let valueEstimate = Decimal(string: estimatedValue) {
                    item.estimatedValue = valueEstimate
                } else if let purchaseValue = Decimal(string: purchasePrice) {
                    // If no current value is set, use purchase price as estimated value
                    item.estimatedValue = purchaseValue
                }
                
                modelContext.insert(item)
                try modelContext.save()
                
                isLoading = false
                dismiss()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func saveItemImage(_ image: UIImage, itemID: String, index: Int) async throws -> URL? {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            return nil
        }
        
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        
        let filename = "\(itemID)_\(index).jpg"
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        try imageData.write(to: fileURL)
        return fileURL
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
    
    return AddItemView(collection: collection)
        .modelContainer(container)
}
