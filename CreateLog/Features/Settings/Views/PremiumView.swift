import SwiftUI

/// プレミアム案内画面。v2.0.0 では marketing/期待値醸成のみに留め、購入フローは未提供。
/// v2.1 で Premium 機能を公開するタイミングで、購入ボタン / プラン選択 / StoreKit 連携を再有効化する。
/// StoreKitManager は残してあるが、現在はどこからも呼ばれない (v2.1 で再配線予定)。
struct PremiumView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                    .padding(.bottom, 32)

                featuresSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                comingSoonNotice
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.clBackground)
        .navigationTitle("プレミアム")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clAccent, Color.clAccent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "star.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
            .padding(.top, 32)

            Text("CreateLog Premium")
                .font(.clTitle)
                .foregroundStyle(Color.clTextPrimary)

            Text("より深い分析と快適な体験を")
                .font(.clBody)
                .foregroundStyle(Color.clTextSecondary)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 0) {
            featureRow(
                icon: "chart.bar.fill",
                title: "詳細分析",
                description: "カテゴリ別トレンド、他ユーザーとの比較"
            )
            featureRow(
                icon: "eye.slash.fill",
                title: "広告なし",
                description: "フィード・検索画面の広告を完全に削除"
            )
            featureRow(
                icon: "clock.arrow.circlepath",
                title: "無制限の履歴",
                description: "過去全期間のログを閲覧・エクスポート"
            )
            featureRow(
                icon: "paintbrush.fill",
                title: "テーマカスタマイズ",
                description: "アクセントカラーの変更"
            )
            featureRow(
                icon: "star.fill",
                title: "プレミアムバッジ",
                description: "プロフィールにバッジを表示",
                isLast: true
            )
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private func featureRow(
        icon: String,
        title: String,
        description: String,
        isLast: Bool = false
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.clAccent)
                    .frame(width: 32, height: 32)
                    .background(Color.clAccent.opacity(0.1), in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.clTextPrimary)
                    Text(description)
                        .font(.clCaption)
                        .foregroundStyle(Color.clTextTertiary)
                }

                Spacer()

                Image(systemName: "sparkle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.clAccent.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !isLast {
                Rectangle()
                    .fill(Color.clBorder)
                    .frame(height: 0.5)
                    .padding(.leading, 62)
            }
        }
    }

    // MARK: - Coming Soon Notice

    private var comingSoonNotice: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 22))
                .foregroundStyle(Color.clAccent)

            Text("プレミアム機能は今後のアップデートで公開予定です")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.clTextPrimary)
                .multilineTextAlignment(.center)

            Text("現在はすべての機能を無料でご利用いただけます。公開時に改めてアプリ内でご案内します。")
                .font(.clCaption)
                .foregroundStyle(Color.clTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.clSurfaceLow)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.clBorder, lineWidth: 1)
                )
        )
    }
}
