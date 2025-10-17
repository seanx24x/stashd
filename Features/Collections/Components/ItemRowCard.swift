//
//  ItemRowCard.swift
//  stashd
//
//  Created by Sean Lynch on 10/17/25.
//


//
//  ItemRowCard.swift
//  stashd
//
//  Created by Sean Lynch
//

import SwiftUI

struct ItemRowCard: View {
    let item: CollectionItem
    
    var body: some View {
        HStack(spacing: Spacing.medium) {
            // Image
            if let firstImageURL = item.imageURLs.first {
                CachedAsyncImage(url: firstImageURL) { image in
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
            } else {
                Rectangle()
                    .fill(Color.surfaceElevated)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.textTertiary)
                    }
            }
            
            // Info
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(item.name)
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2)
                
                if let condition = item.condition {
                    Text(condition.rawValue)
                        .font(.labelSmall)
                        .foregroundStyle(.textSecondary)
                }
                
                Text(formatCurrency(item.estimatedValue))
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.stashdPrimary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.textTertiary)
        }
        .padding(Spacing.medium)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
    }
}