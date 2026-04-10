import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: "端末の設定に従う"
        case .light: "ライト"
        case .dark: "ダーク"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @AppStorage("durationFormat") private var durationFormat: String = DurationFormat.system.rawValue
    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.system.rawValue
    @State private var showOnboarding = false

    private var selectedMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceMode) ?? .system
    }

    private var selectedDurationFormat: DurationFormat {
        DurationFormat(rawValue: durationFormat) ?? .system
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguage) ?? .system
    }

    var body: some View {
        List {
            // Premium
            Section {
                NavigationLink {
                    PremiumView()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.clAccent)
                            .frame(width: 24)
                        Text("プレミアム")
                            .font(.clBody)
                            .foregroundStyle(Color.clTextPrimary)
                    }
                }
            }

            // Account & Notifications
            Section {
                NavigationLink {
                    AccountSettingsView()
                } label: {
                    settingsRow(icon: "person", title: "アカウント")
                }

                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    settingsRow(icon: "bell", title: "通知")
                }

                NavigationLink {
                    IntegrationSettingsView()
                } label: {
                    settingsRow(icon: "link", title: "連携管理")
                }
            }

            // Appearance
            Section {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Button {
                        appearanceMode = mode.rawValue
                        HapticManager.light()
                    } label: {
                        HStack {
                            Text(mode.label)
                                .font(.clBody)
                                .foregroundStyle(Color.clTextPrimary)

                            Spacer()

                            if selectedMode == mode {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.clAccent)
                            }
                        }
                    }
                }
            } header: {
                Text("外観")
            }

            // Duration format
            Section {
                ForEach(DurationFormat.allCases, id: \.self) { format in
                    Button {
                        durationFormat = format.rawValue
                        HapticManager.light()
                    } label: {
                        HStack {
                            Text(format.label)
                                .font(.clBody)
                                .foregroundStyle(Color.clTextPrimary)

                            Spacer()

                            if selectedDurationFormat == format {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.clAccent)
                            }
                        }
                    }
                }
            } header: {
                Text("時間の表示形式")
            }

            // Language
            Section {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Button {
                        appLanguage = lang.rawValue
                        HapticManager.light()
                    } label: {
                        HStack {
                            Text(lang.label)
                                .font(.clBody)
                                .foregroundStyle(Color.clTextPrimary)

                            Spacer()

                            if selectedLanguage == lang {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.clAccent)
                            }
                        }
                    }
                }
            } header: {
                Text("言語")
            }

            // Legal & Support
            Section {
                NavigationLink {
                    LegalTextView(type: .privacy)
                } label: {
                    settingsRow(icon: "hand.raised", title: "プライバシーポリシー")
                }

                NavigationLink {
                    LegalTextView(type: .terms)
                } label: {
                    settingsRow(icon: "doc.text", title: "利用規約")
                }

                NavigationLink {
                    SupportView()
                } label: {
                    settingsRow(icon: "questionmark.circle", title: "お問い合わせ")
                }
            } header: {
                Text("サポート")
            }

            // Version
            Section {
                HStack {
                    Text("バージョン")
                        .font(.clBody)
                        .foregroundStyle(Color.clTextPrimary)
                    Spacer()
                    Text("2.0.0")
                        .font(.clBody)
                        .foregroundStyle(Color.clTextTertiary)
                }
            }

            // DEBUG: オンボーディング確認用（開発時のみ）
            Section {
                Button {
                    showOnboarding = true
                } label: {
                    settingsRow(icon: "arrow.counterclockwise", title: "オンボーディングを表示")
                }
            } header: {
                Text("開発用")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clBackground)
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(
                isPresented: $showOnboarding,
                authViewModel: AuthViewModel(authService: NoOpAuthService())
            )
        }
    }

    private func settingsRow(icon: String, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.clTextSecondary)
                .frame(width: 24)
            Text(title)
                .font(.clBody)
                .foregroundStyle(Color.clTextPrimary)
        }
    }
}

// MARK: - Language

enum AppLanguage: String, CaseIterable {
    case system
    case japanese
    case english

    var label: String {
        switch self {
        case .system: "端末の設定に従う"
        case .japanese: "日本語"
        case .english: "English"
        }
    }
}

// MARK: - Integration Settings

struct IntegrationSettingsView: View {
    var body: some View {
        List {
            Section {
                integrationRow(
                    name: "VS Code",
                    icon: "chevron.left.forwardslash.chevron.right",
                    status: .notConnected
                )
                integrationRow(
                    name: "Cursor",
                    icon: "cursorarrow.rays",
                    status: .notConnected
                )
            } header: {
                Text("エディタ連携")
            } footer: {
                Text("拡張機能をインストールして、コーディング時間を自動で記録します")
                    .font(.clCaption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clBackground)
        .navigationTitle("連携管理")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func integrationRow(
        name: String,
        icon: String,
        status: IntegrationStatus
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.clTextPrimary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.clBody)
                    .foregroundStyle(Color.clTextPrimary)
                Text(status.label)
                    .font(.clCaption)
                    .foregroundStyle(status.color)
            }

            Spacer()

            Button {
                HapticManager.light()
            } label: {
                Text("設定")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.clAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.clAccent.opacity(0.12), in: .capsule)
            }
            .buttonStyle(.plain)
        }
    }
}

private enum IntegrationStatus {
    case connected
    case notConnected

    var label: String {
        switch self {
        case .connected: "接続済み"
        case .notConnected: "未接続"
        }
    }

    var color: Color {
        switch self {
        case .connected: Color.clSuccess
        case .notConnected: Color.clTextTertiary
        }
    }
}

// MARK: - Legal

enum LegalType {
    case privacy
    case terms

    var title: String {
        switch self {
        case .privacy: "プライバシーポリシー"
        case .terms: "利用規約"
        }
    }
}

struct LegalTextView: View {
    let type: LegalType

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("最終更新日: 2026年4月1日")
                    .font(.clCaption)
                    .foregroundStyle(Color.clTextTertiary)

                Text(placeholderText)
                    .font(.clBody)
                    .foregroundStyle(Color.clTextSecondary)
                    .lineSpacing(6)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(Color.clBackground)
        .navigationTitle(type.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var placeholderText: String {
        switch type {
        case .privacy:
            """
            1. 収集する情報

            CreateLog（以下「本アプリ」）は、サービス提供に必要な最小限の情報を収集します。

            - アカウント情報（メールアドレス、表示名、ハンドル名）
            - 作業記録データ（カテゴリ、時間、メモ）
            - 投稿コンテンツ（テキスト、画像、コード）
            - 利用状況データ（アクセスログ、機能使用頻度）

            2. 情報の利用目的

            収集した情報は以下の目的で利用します。

            - サービスの提供・運営・改善
            - ユーザーサポート
            - 統計データの作成（個人を特定しない形式）
            - 不正利用の防止

            3. 第三者への提供

            法令に基づく場合を除き、ユーザーの同意なく第三者に個人情報を提供することはありません。

            4. データの保管

            データはSupabaseのインフラストラクチャ上で安全に保管されます。

            5. お問い合わせ

            プライバシーに関するお問い合わせは、アプリ内のお問い合わせフォームからご連絡ください。
            """
        case .terms:
            """
            1. サービスの概要

            CreateLogは、エンジニア向けの作業記録・共有プラットフォームです。

            2. アカウント

            ユーザーは正確な情報を提供し、アカウントの安全管理に責任を持つものとします。

            3. 禁止事項

            以下の行為を禁止します。

            - 法令または公序良俗に違反する行為
            - 他のユーザーへの嫌がらせ、誹謗中傷
            - 虚偽の情報の投稿
            - スパム行為、商業目的の無差別な投稿
            - 著作権を侵害するコンテンツの投稿
            - 本サービスの運営を妨害する行為

            4. コンテンツ

            ユーザーが投稿したコンテンツの著作権はユーザーに帰属します。ただし、サービス提供に必要な範囲で利用を許諾するものとします。

            5. 免責事項

            本サービスは現状有姿で提供されます。サービスの中断・停止について、運営者は責任を負いません。

            6. 規約の変更

            本規約は予告なく変更される場合があります。変更後の利用をもって同意とみなします。
            """
        }
    }
}

// MARK: - Support

struct SupportView: View {
    @State private var category: SupportCategory = .bug
    @State private var message = ""

    var body: some View {
        List {
            Section {
                Picker("カテゴリ", selection: $category) {
                    ForEach(SupportCategory.allCases) { cat in
                        Text(cat.label).tag(cat)
                    }
                }
                .font(.clBody)
                .foregroundStyle(Color.clTextPrimary)
            }

            Section {
                TextField("お問い合わせ内容", text: $message, axis: .vertical)
                    .font(.clBody)
                    .lineLimit(5...10)
            } header: {
                Text("メッセージ")
            }

            Section {
                Button {
                    HapticManager.success()
                } label: {
                    Text("送信")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            message.isEmpty ? Color.clTextTertiary : Color.clAccent,
                            in: .capsule
                        )
                }
                .disabled(message.isEmpty)
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clBackground)
        .navigationTitle("お問い合わせ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum SupportCategory: String, CaseIterable, Identifiable {
    case bug
    case feature
    case account
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bug: "不具合報告"
        case .feature: "機能リクエスト"
        case .account: "アカウント"
        case .other: "その他"
        }
    }
}
