//
//  LoadingButton.swift
//  stashd
//
//  Created by Sean Lynch on 10/11/25.
//


// File: DesignSystem/Components/LoadingButton.swift

import SwiftUI

struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(.white)
                    .opacity(isLoading ? 0 : 1)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.stashdPrimary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .disabled(isLoading)
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: Spacing.medium) {
        LoadingButton(title: "Continue", isLoading: false) {}
        LoadingButton(title: "Loading...", isLoading: true) {}
    }
    .padding()
}