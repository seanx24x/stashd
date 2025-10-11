//
//  Spacing.swift
//  stashd
//
//  Created by Sean Lynch on 10/9/25.
//


// File: DesignSystem/Tokens/DesignTokens.swift

import SwiftUI

// MARK: - Colors

extension Color {
    // Brand Colors
    static let stashdPrimary = Color("Primary")
    static let stashdAccent = Color("Accent")
    static let stashdSecondary = Color("Secondary")
    
    // Semantic Colors
    static let BackgroundPrimary = Color("BackgroundPrimary")
    static let BackgroundSecondary = Color("BackgroundSecondary")
    static let BackgroundTertiary = Color("BackgroundTertiary")
    
    static let TextPrimary = Color("TextPrimary")
    static let TextSecondary = Color("TextSecondary")
    static let TextTertiary = Color("TextTertiary")
    
    static let SurfaceElevated = Color("SurfaceElevated")
    static let separatorLine = Color("Separator")
    
    // Status Colors
    static let Success = Color("Success")
    static let Warning = Color("Warning")
    static let Error = Color("Error")
}

// MARK: - Typography

extension Font {
    // Display
    static let displayLarge = Font.system(size: 57, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 45, weight: .bold, design: .rounded)
    
    // Headline
    static let headlineLarge = Font.system(size: 32, weight: .semibold, design: .rounded)
    static let headlineMedium = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let headlineSmall = Font.system(size: 24, weight: .semibold, design: .rounded)
    
    // Body
    static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)
    
    // Label
    static let labelLarge = Font.system(size: 14, weight: .medium, design: .default)
    static let labelMedium = Font.system(size: 12, weight: .medium, design: .default)
    static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)
}

// MARK: - Spacing

enum Spacing {
    static let xxSmall: CGFloat = 4
    static let xSmall: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
    static let xxLarge: CGFloat = 48
}

enum CornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
}
