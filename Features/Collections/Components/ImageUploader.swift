//
//  ImageUploader.swift
//  stashd
//
//  Created by Sean Lynch on 10/10/25.
//


// File: Features/Collections/Components/ImageUploader.swift

import SwiftUI
import PhotosUI

struct ImageUploader: View {
    @Binding var selectedImage: UIImage?
    let placeholder: String
    let height: CGFloat
    
    @State private var showImagePicker = false
    
    init(
        selectedImage: Binding<UIImage?>,
        placeholder: String = "Add Cover Image",
        height: CGFloat = 200
    ) {
        self._selectedImage = selectedImage
        self.placeholder = placeholder
        self.height = height
    }
    
    var body: some View {
        Button {
            showImagePicker = true
        } label: {
            ZStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: height)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                withAnimation {
                                    selectedImage = nil
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .background(
                                        Circle()
                                            .fill(.black.opacity(0.5))
                                            .padding(4)
                                    )
                            }
                            .padding(Spacing.small)
                        }
                } else {
                    VStack(spacing: Spacing.medium) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundStyle(.textTertiary)
                        
                        Text(placeholder)
                            .font(.bodyLarge)
                            .foregroundStyle(.textSecondary)
                        
                        Text("Tap to select")
                            .font(.labelMedium)
                            .foregroundStyle(.textTertiary)
                    }
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
                    .background(.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                    .overlay {
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .strokeBorder(
                                Color.separator,
                                style: StrokeStyle(lineWidth: 2, dash: [8])
                            )
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }
}

#Preview {
    @Previewable @State var image: UIImage? = nil
    
    return ImageUploader(selectedImage: $image)
        .padding()
}