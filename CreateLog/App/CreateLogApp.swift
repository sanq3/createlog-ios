import SwiftUI
import SwiftData
import OSLog

private let appLogger = Logger(subsystem: "com.sanq3.createlog", category: "App")

@main
struct CreateLogApp: App {
    @UIApplicationDelegateAdaptor(AppDelegateAdapter.self) private var appDelegate
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false

    let modelContainer: ModelContainer
    let dependencies: DependencyContainer
    @State private var authViewModel: AuthViewModel
    @State private var deepLinkHandler = DeepLinkHandler()
    @State private var storeKitManager = StoreKitManager()
    @State private var pushService: PushNotificationService
    @State private var localizationManager = LocalizationManager()
    @State private var splashFinished = false

    init() {
        let schema = Schema([
            SDCategory.self,
            SDProject.self,
            SDTimeEntry.self,
            SDOfflineOperation.self,
            SDLogCache.self,
            // T7c: SNS キャッシュ層 5 種
            SDPostCache.self,
            SDLikeCache.self,
            SDBookmarkCache.self,
            SDFollowCache.self,
            SDCommentCache.self,
            SDNotificationCache.self,
            // 2026-04-16: Profile flicker 根本修正 (SWR + cache-first rendering)
            SDProfileCache.self
        ])
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            appLogger.error("ModelContainer failed: \(String(describing: error), privacy: .public). Falling back to inMemory.")
            do {
                let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
                modelContainer = try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("Could not create even in-memory ModelContainer: \(error)")
            }
        }
        let deps = DependencyContainer(modelContainer: modelContainer)
        dependencies = deps
        let authVM = AuthViewModel(authService: deps.authService)
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "devBypassAuth") {
            authVM.devForceAuthenticated()
            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
            print("[CreateLogApp] ⚠️ DEV BYPASS AUTH enabled — OAuth skipped, MainTab forced")
        }
        #endif
        _authViewModel = State(initialValue: authVM)
        // PushNotificationService は init 内で NotificationCenter を observe するので
        // AppDelegateAdapter への明示的な参照設定は不要 (疎結合)。
        _pushService = State(initialValue: PushNotificationService(client: deps.supabaseClient))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Base: 本編 (auth session + onboardingCompleted の 2 軸で分岐)
                // - session なし → Onboarding (welcome → login / signup)
                // - session あり + onboardingCompleted=false → Onboarding (プロフィール設定途中)
                // - session あり + onboardingCompleted=true → MainTabView
                // - session unknown (起動直後) → 空背景 (Splash に覆われる)
                rootView

                // Overlay: 起動時動画スプラッシュ (rootView を覆って再生、終了後に fade out)
                if !splashFinished {
                    SplashView {
                        withAnimation(.spring(duration: 0.35, bounce: 0.0)) {
                            splashFinished = true
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .modifier(
                            active: SplashDismissModifier(active: true),
                            identity: SplashDismissModifier(active: false)
                        )
                    ))
                    .zIndex(1)
                }
            }
            .environment(\.locale, localizationManager.currentLocale)
            .environment(localizationManager)
            .task {
                #if DEBUG
                if UserDefaults.standard.bool(forKey: "devBypassAuth") { return }
                #endif
                await authViewModel.observeAuthState()
            }
        }
    }

    /// 現在の認証状態と onboarding 完了フラグから root view を決定する。
    /// 業界標準 (X/Instagram 等) の session-gated ルーティング: session が無ければ必ず auth 画面を経由させる。
    @ViewBuilder
    private var rootView: some View {
        switch authViewModel.authState {
        case .unknown:
            // Splash に覆われる想定。observe 完了前にたまたま splash が終わっても背景だけ見える。
            Color.clBackground.ignoresSafeArea()

        case .unauthenticated:
            onboardingScreen

        case .authenticated:
            if onboardingCompleted {
                mainScreen
            } else {
                onboardingScreen
            }
        }
    }

    private var mainScreen: some View {
        MainTabView()
            .modelContainer(modelContainer)
            .environment(\.dependencies, dependencies)
            .environment(deepLinkHandler)
            .environment(pushService)
            .onAppear {
                applyTheme(animated: false)
                seedDefaultCategories()
            }
            .onChange(of: appearanceMode) {
                applyTheme(animated: true)
            }
            .task {
                // onboarding 完了後の初回起動時に通知許可を要求する
                await pushService.refreshAuthorizationStatus()
                if pushService.authorizationStatus == .notDetermined {
                    await pushService.requestAuthorization()
                }
            }
            .onOpenURL { url in deepLinkHandler.handle(url) }
            .opacity(splashFinished ? 1.0 : 0.0)
            .animation(.easeIn(duration: 0.15), value: splashFinished)
    }

    private var onboardingScreen: some View {
        OnboardingView(
            isPresented: Binding(
                get: { !onboardingCompleted },
                set: { if !$0 { onboardingCompleted = true } }
            ),
            authViewModel: authViewModel
        )
        .modelContainer(modelContainer)
        .environment(\.dependencies, dependencies)
        .onAppear { applyTheme(animated: false) }
        .onChange(of: appearanceMode) { applyTheme(animated: true) }
        .opacity(splashFinished ? 1.0 : 0.0)
        .animation(.easeIn(duration: 0.15), value: splashFinished)
    }

    private func seedDefaultCategories() {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SDCategory>(predicate: #Predicate { $0.isStandard == true })
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        let defaults: [(String, Int)] = [
            ("開発", 1), ("デザイン", 2), ("学習", 3),
            ("ミーティング", 4), ("ライティング", 5),
            ("マーケティング", 6), ("事務", 7),
        ]
        for (index, item) in defaults.enumerated() {
            context.insert(SDCategory(name: item.0, colorIndex: item.1, isStandard: true, sortOrder: index))
        }
    }

    // MARK: - Theme

    private func applyTheme(animated: Bool) {
        let mode = AppearanceMode(rawValue: appearanceMode) ?? .system
        let style: UIUserInterfaceStyle = switch mode {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        if animated {
            UIView.transition(
                with: window,
                duration: 0.4,
                options: .transitionCrossDissolve
            ) {
                window.overrideUserInterfaceStyle = style
            }
        } else {
            window.overrideUserInterfaceStyle = style
        }
    }
}

/// スプラッシュ退場: わずかに拡大 + ブラー + フェードアウト
private struct SplashDismissModifier: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(active ? 1.06 : 1.0)
            .opacity(active ? 0.0 : 1.0)
            .blur(radius: active ? 12 : 0)
    }
}
