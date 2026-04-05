import SwiftUI

/// スケルトンローディング用の汎用プレースホルダー
struct SkeletonView: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16

    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.clTextTertiary.opacity(0.15))
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.clTextTertiary.opacity(0.08),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 200 : -200)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

/// カード型スケルトン (フィード用)
struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.clTextTertiary.opacity(0.15))
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonView(width: 100, height: 14)
                    SkeletonView(width: 60, height: 12)
                }
                Spacer()
            }
            SkeletonView(height: 14)
            SkeletonView(width: 200, height: 14)
            SkeletonView(height: 140)
        }
        .padding(16)
        .background(Color.clSurfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// リスト型スケルトン (通知等)
struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.clTextTertiary.opacity(0.15))
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                SkeletonView(width: 160, height: 14)
                SkeletonView(width: 100, height: 12)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}
