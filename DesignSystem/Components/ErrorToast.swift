//
//  ErrorToast.swift
//  stashd
//
//  Created by Sean Lynch on 10/11/25.
//


// File: DesignSystem/Components/ErrorToast.swift

import SwiftUI

struct ErrorToast: View {
    let message: String
    @Binding var isPresented: Bool
    
    var body: some View {
        if isPresented {
            VStack {
                Spacer()
                
                HStack(spacing: Spacing.medium) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.error)
                    
                    Text(message)
                        .font(.bodyMedium)
                        .foregroundStyle(.textPrimary)
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.textSecondary)
                    }
                }
                .padding(Spacing.medium)
                .background(.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
                .padding(.horizontal, Spacing.large)
                .padding(.bottom, Spacing.large)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .onAppear {
                HapticManager.shared.error()
                
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.spring(response: 0.3)) {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// Usage example - add this modifier to any view:
extension View {
    func errorToast(message: String, isPresented: Binding<Bool>) -> some View {
        self.overlay {
            ErrorToast(message: message, isPresented: isPresented)
        }
    }
}