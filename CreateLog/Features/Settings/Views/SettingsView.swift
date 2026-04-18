import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var localizedKey: LocalizedStringKey {
        switch self {
        case .system: "common.systemDefault"
        case .light: "settings.appearance.light"
        case .dark: "settings.appearance.dark"
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
    @Environment(\.dependencies) private var dependencies
    @Environment(LocalizationManager.self) private var localizationManager
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @AppStorage("durationFormat") private var durationFormat: String = DurationFormat.system.rawValue
    @State private var showOnboarding = false
    @State private var showLanguageRestartAlert = false
    @State private var pendingLanguage: AppLanguage?

    private var selectedMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceMode) ?? .system
    }

    private var selectedDurationFormat: DurationFormat {
        DurationFormat(rawValue: durationFormat) ?? .system
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
                        Text("settings.premium")
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
                    settingsRow(icon: "person", title: "settings.account")
                }

                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    settingsRow(icon: "bell", title: "settings.notifications")
                }

                NavigationLink {
                    IntegrationSettingsView()
                } label: {
                    settingsRow(icon: "link", title: "settings.integration")
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
                            Text(mode.localizedKey)
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
                Text("settings.appearance.section")
            }

            // Duration format
            Section {
                ForEach(DurationFormat.allCases, id: \.self) { format in
                    Button {
                        durationFormat = format.rawValue
                        HapticManager.light()
                    } label: {
                        HStack {
                            Text(format.localizedKey)
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
                Text("settings.duration.section")
            }

            // Language
            Section {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Button {
                        guard lang != localizationManager.appLanguage else { return }
                        pendingLanguage = lang
                        showLanguageRestartAlert = true
                        HapticManager.light()
                    } label: {
                        HStack {
                            Text(lang.localizedKey)
                                .font(.clBody)
                                .foregroundStyle(Color.clTextPrimary)

                            Spacer()

                            if localizationManager.appLanguage == lang {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.clAccent)
                            }
                        }
                    }
                }
            } header: {
                Text("settings.language.section")
            }

            // Legal & Support
            Section {
                NavigationLink {
                    LegalTextView(type: .privacy)
                } label: {
                    settingsRow(icon: "hand.raised", title: "settings.support.privacy")
                }

                NavigationLink {
                    LegalTextView(type: .terms)
                } label: {
                    settingsRow(icon: "doc.text", title: "settings.support.terms")
                }

                NavigationLink {
                    SupportView()
                } label: {
                    settingsRow(icon: "questionmark.circle", title: "settings.support.contact")
                }
            } header: {
                Text("settings.support.section")
            }

            // Version
            Section {
                HStack {
                    Text("settings.version")
                        .font(.clBody)
                        .foregroundStyle(Color.clTextPrimary)
                    Spacer()
                    Text(verbatim: "2.0.0")
                        .font(.clBody)
                        .foregroundStyle(Color.clTextTertiary)
                }
            }

            // DEBUG: オンボーディング確認用（開発時のみ）
            Section {
                Button {
                    showOnboarding = true
                } label: {
                    settingsRow(icon: "arrow.counterclockwise", title: "settings.dev.showOnboarding")
                }
            } header: {
                Text("settings.dev.section")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clBackground)
        .navigationTitle(Text("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(
                isPresented: $showOnboarding,
                authViewModel: AuthViewModel(authService: dependencies.authService)
            )
        }
        .alert("settings.language.restart.title", isPresented: $showLanguageRestartAlert, presenting: pendingLanguage) { lang in
            Button("common.cancel", role: .cancel) {
                pendingLanguage = nil
            }
            Button("settings.language.restart.apply") {
                localizationManager.setLanguage(lang)
                pendingLanguage = nil
            }
        } message: { _ in
            Text("settings.language.restart.message")
        }
    }

    private func settingsRow(icon: String, title: LocalizedStringKey) -> some View {
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

// MARK: - Integration Settings

/// エディタ連携画面。v2.0.0 では marketing/予告のみ。
/// v2.1 で `AutoTrackingRepository` (現在 stub) の Edge Function 実装 + VS Code / Cursor 拡張の
/// publish を経て、実際の「コーディング時間自動記録」機能を有効化する。
struct IntegrationSettingsView: View {
    var body: some View {
        List {
            Section {
                comingSoonRow(
                    name: "VS Code",
                    icon: "chevron.left.forwardslash.chevron.right"
                )
                comingSoonRow(
                    name: "Cursor",
                    icon: "cursorarrow.rays"
                )
            } header: {
                Text("integration.editor.section")
            } footer: {
                Text("integration.editor.footer")
                    .font(.clCaption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clBackground)
        .navigationTitle(Text("integration.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func comingSoonRow(name: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.clTextPrimary)
                .frame(width: 28)

            Text(verbatim: name)
                .font(.clBody)
                .foregroundStyle(Color.clTextPrimary)

            Spacer()

            Text("integration.comingSoon")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.clTextTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.clTextTertiary.opacity(0.12), in: .capsule)
        }
        .opacity(0.75)
    }
}

// MARK: - Legal

enum LegalType {
    case privacy
    case terms

    var localizedKey: LocalizedStringKey {
        switch self {
        case .privacy: "legal.privacy.title"
        case .terms: "legal.terms.title"
        }
    }
}

struct LegalTextView: View {
    let type: LegalType

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("legal.lastUpdated")
                    .font(.clCaption)
                    .foregroundStyle(Color.clTextTertiary)

                Text(verbatim: content)
                    .font(.clBody)
                    .foregroundStyle(Color.clTextSecondary)
                    .lineSpacing(6)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(Color.clBackground)
        .navigationTitle(Text(type.localizedKey))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// v2.0.0 公開用の利用規約 / プライバシーポリシー本文。
    /// legal review を経ていない汎用文面のため、TestFlight 外部配布 / App Store 公開前に
    /// 弁護士レビューを受けた正式版への差し替えを強く推奨する (最終更新日も合わせて更新)。
    private var content: String {
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
    @Environment(\.openURL) private var openURL
    @State private var category: SupportCategory = .bug
    @State private var message = ""
    @State private var sent = false

    /// サポートメール送信先。運用開始後はプロダクトで個別メールへ変更予定。
    private let supportEmail = "support@createlog.app"

    var body: some View {
        List {
            Section {
                Picker("support.categoryLabel", selection: $category) {
                    ForEach(SupportCategory.allCases) { cat in
                        Text(cat.localizedKey).tag(cat)
                    }
                }
                .font(.clBody)
                .foregroundStyle(Color.clTextPrimary)
            }

            Section {
                TextField("support.messagePlaceholder", text: $message, axis: .vertical)
                    .font(.clBody)
                    .lineLimit(5...10)
            } header: {
                Text("support.messageSection")
            }

            if sent {
                Section {
                    Text("support.sentHint")
                        .font(.clCaption)
                        .foregroundStyle(Color.clSuccess)
                }
            }

            Section {
                Button {
                    HapticManager.success()
                    sendMail()
                } label: {
                    Text("support.submit")
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
        .navigationTitle(Text("support.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// メールアプリを mailto: で起動。body に category + message を prefill する。
    private func sendMail() {
        let subject = "[CreateLog] \(category.englishLabel)"
        let body = message
        var components = URLComponents(string: "mailto:\(supportEmail)")
        components?.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        if let url = components?.url {
            openURL(url)
            sent = true
        }
    }
}

private enum SupportCategory: String, CaseIterable, Identifiable {
    case bug
    case feature
    case account
    case other

    var id: String { rawValue }

    var localizedKey: LocalizedStringKey {
        switch self {
        case .bug: "support.category.bug"
        case .feature: "support.category.feature"
        case .account: "support.category.account"
        case .other: "support.category.other"
        }
    }

    /// メール subject 用の English 固定ラベル (locale 非依存)
    var englishLabel: String {
        switch self {
        case .bug: "Bug Report"
        case .feature: "Feature Request"
        case .account: "Account"
        case .other: "Other"
        }
    }
}
