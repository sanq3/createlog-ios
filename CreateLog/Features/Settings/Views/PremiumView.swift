import SwiftUI

struct PremiumView: View {
    @State private var selectedPlan: PremiumPlan = .monthly
    @State private var storeKitManager = StoreKitManager()
    @State private var showTermsSheet = false
    @Environment(\.dismiss) private var dismiss

    /// App Store 連携前の mock 表示価格。loadProducts() 後は実価格 (localizedPrice) で上書きされる。
    private var subscribeTitle: String {
        if storeKitManager.isPremium {
            return "プレミアム登録済み"
        }
        return "プレミアムに登録"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                    .padding(.bottom, 32)

                featuresSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                planSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                subscribeButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                Button {
                    Task { await storeKitManager.restorePurchases() }
                    HapticManager.light()
                } label: {
                    Text("購入履歴を復元")
                        .font(.clCaption)
                        .foregroundStyle(Color.clTextTertiary)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)

                Text("いつでもキャンセル可能 - Apple IDで管理")
                    .font(.clCaption)
                    .foregroundStyle(Color.clTextTertiary)
                    .padding(.bottom, 8)

                Button {
                    HapticManager.light()
                    showTermsSheet = true
                } label: {
                    Text("利用規約とプライバシーポリシー")
                        .font(.clCaption)
                        .foregroundStyle(Color.clAccent)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)

                if let errorMessage = storeKitManager.errorMessage {
                    Text(errorMessage)
                        .font(.clCaption)
                        .foregroundStyle(Color.clError)
                        .padding(.bottom, 20)
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.clBackground)
        .navigationTitle("プレミアム")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await storeKitManager.loadProducts()
        }
        .sheet(isPresented: $showTermsSheet) {
            NavigationStack {
                List {
                    Link("利用規約", destination: URL(string: "https://createlog.app/terms")!)
                    Link("プライバシーポリシー", destination: URL(string: "https://createlog.app/privacy")!)
                }
                .navigationTitle("利用規約とプライバシー")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { showTermsSheet = false }
                    }
                }
            }
        }
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

                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.clSuccess)
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

    // MARK: - Plan Selection

    private var planSection: some View {
        HStack(spacing: 12) {
            planCard(plan: .monthly)
            planCard(plan: .yearly)
        }
    }

    private func planCard(plan: PremiumPlan) -> some View {
        let isSelected = selectedPlan == plan

        return Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                selectedPlan = plan
            }
            HapticManager.selection()
        } label: {
            VStack(spacing: 8) {
                if plan == .yearly {
                    Text("2ヶ月分お得")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.clAccent, in: .capsule)
                }

                Text(plan.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.clTextSecondary)

                Text(plan.price)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)

                Text(plan.period)
                    .font(.clCaption)
                    .foregroundStyle(Color.clTextTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? Color.clAccent : Color.clBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subscribe

    private var subscribeButton: some View {
        Button {
            HapticManager.medium()
            Task {
                // 選択されたプランに対応する product を取得 (現時点では monthly のみ存在)
                guard let product = storeKitManager.products.first else {
                    storeKitManager.errorMessage = "商品情報が読み込めません"
                    return
                }
                await storeKitManager.purchase(product)
            }
        } label: {
            HStack {
                if storeKitManager.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(subscribeTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(storeKitManager.isPremium ? Color.clTextTertiary : Color.clAccent, in: .capsule)
        }
        .buttonStyle(.bounce)
        .disabled(storeKitManager.isPremium || storeKitManager.isLoading || storeKitManager.products.isEmpty)
    }
}

// MARK: - Plan Model

private enum PremiumPlan: CaseIterable {
    case monthly
    case yearly

    var label: String {
        switch self {
        case .monthly: "月額プラン"
        case .yearly: "年額プラン"
        }
    }

    var price: String {
        switch self {
        case .monthly: "¥480"
        case .yearly: "¥4,800"
        }
    }

    var period: String {
        switch self {
        case .monthly: "/月"
        case .yearly: "/年（¥400/月）"
        }
    }
}
