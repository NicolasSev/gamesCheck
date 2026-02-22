//
//  SkeletonLoadingView.swift
//  FishAndChips
//
//  Phase 2: Skeleton loading для списков во время загрузки
//

import SwiftUI

struct SkeletonLoadingView: View {
    @State private var isAnimating = false
    var itemCount: Int = 5

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<itemCount, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .opacity(isAnimating ? 0.6 : 0.3)

                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 16)
                            .opacity(isAnimating ? 0.6 : 0.3)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 12)
                            .opacity(isAnimating ? 0.6 : 0.3)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    SkeletonLoadingView()
        .padding()
}
