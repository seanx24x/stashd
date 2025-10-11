//
//  CTAButton.swift
//  stashd
//
//  Created by Sean Lynch on 10/9/25.
//


// File: DesignSystem/Components/CTAButton.swift

import SwiftUI

struct CTAButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let action: () -> Void
    
    @Environment(\.isEnabled) private var isEnabled
    
    init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.small) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                }
                
                Text(title)
                    .font(.bodyLarge.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .shadow(color: shadowColor, radius: style == .primary ? 8 : 0, y: 4)
        }
        .opacity(isEnabled ? 1 : 0.6)
        .animation(.smooth, value: isEnabled)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return .stashdPrimary
        case .secondary:
            return .surfaceElevated
        case .outline:
            return .clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary, .outline:
            return .textPrimary
        }
    }
    
    private var shadowColor: Color {
        Color.stashdPrimary.opacity(0.3)
    }
    
    enum ButtonStyle {
        case primary
        case secondary
        case outline
    }
}