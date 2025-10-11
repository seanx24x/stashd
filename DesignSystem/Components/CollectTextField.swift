//
//  CollectTextField.swift
//  stashd
//
//  Created by Sean Lynch on 10/9/25.
//


// File: DesignSystem/Components/CollectTextField.swift

import SwiftUI

struct CollectTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var icon: String?
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isSecure: Bool = false
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(title)
                .font(.labelMedium)
                .foregroundStyle(.textSecondary)
            
            HStack(spacing: Spacing.small) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(.textTertiary)
                        .font(.body)
                }
                
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textContentType(textContentType)
                        .focused($isFocused)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textContentType(textContentType)
                        .textInputAutocapitalization(autocapitalization)
                        .focused($isFocused)
                }
            }
            .padding(Spacing.medium)
            .background(.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(
                        isFocused ? Color.stashdPrimary : Color.separator,
                        lineWidth: isFocused ? 2 : 1
                    )
            }
            .animation(.smooth(duration: 0.2), value: isFocused)
        }
    }
}