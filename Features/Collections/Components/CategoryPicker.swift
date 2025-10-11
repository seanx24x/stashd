//
//  CategoryPicker.swift
//  stashd
//
//  Created by Sean Lynch on 10/10/25.
//


// File: Features/Collections/Components/CategoryPicker.swift

import SwiftUI

struct CategoryPicker: View {
    @Binding var selectedCategory: CollectionCategory
    
    let columns = [
        GridItem(.flexible(), spacing: Spacing.small),
        GridItem(.flexible(), spacing: Spacing.small)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Category")
                .font(.labelLarge)
                .foregroundStyle(.textSecondary)
            
            LazyVGrid(columns: columns, spacing: Spacing.small) {
                ForEach(CollectionCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.smooth) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }
}

struct CategoryButton: View {
    let category: CollectionCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xSmall) {
                Image(systemName: category.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? .white : .stashdPrimary)
                
                Text(category.rawValue)
                    .font(.labelSmall)
                    .foregroundStyle(isSelected ? .white : .textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isSelected ? Color.stashdPrimary : Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(
                        isSelected ? Color.stashdPrimary : Color.separator,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .shadow(
                color: isSelected ? Color.stashdPrimary.opacity(0.3) : .clear,
                radius: 8,
                y: 4
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var selectedCategory: CollectionCategory = .vinyl
    
    return CategoryPicker(selectedCategory: $selectedCategory)
        .padding()
}