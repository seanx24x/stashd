// File: DesignSystem/Components/SkeletonView.swift

import SwiftUI

struct SkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.surfaceElevated,
                        Color.surfaceElevated.opacity(0.6),
                        Color.surfaceElevated
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .mask {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white, .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.3)
                        .offset(x: isAnimating ? geometry.size.width : -geometry.size.width * 0.3)
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// Skeleton Cards for different views
struct SkeletonCollectionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            // Image skeleton
            SkeletonView()
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            
            // Title skeleton
            SkeletonView()
                .frame(height: 20)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            
            // Subtitle skeleton
            SkeletonView()
                .frame(height: 16)
                .frame(maxWidth: 200)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        }
        .padding(Spacing.medium)
        .background(Color.surfaceElevated)  // ← FIXED
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
}

struct SkeletonFeedCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            // Header
            HStack(spacing: Spacing.medium) {
                SkeletonView()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    SkeletonView()
                        .frame(width: 120, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    
                    SkeletonView()
                        .frame(width: 80, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                }
                
                Spacer()
            }
            
            // Image
            SkeletonView()
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            
            // Actions
            HStack(spacing: Spacing.large) {
                ForEach(0..<3) { _ in
                    SkeletonView()
                        .frame(width: 60, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                }
            }
        }
        .padding(Spacing.large)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
}

#Preview {
    VStack(spacing: Spacing.large) {
        SkeletonFeedCard()
        SkeletonCollectionCard()
    }
    .padding()
}
