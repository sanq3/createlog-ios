import SwiftUI
import SwiftData

@main
struct CreateLogApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false

    let modelContainer: ModelContainer
    let dependencies: DependencyContainer
    @State private var authViewModel: AuthViewModel
    @State private var deepLinkHandler = DeepLinkHandler()
    @State private var storeKitManager = StoreKitManager()
    @State private var splashFinished = false

    init() {
        let schema = Schema([SDCategory.self, SDProject.self, SDTimeEntry.self])
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("ModelContainer failed: \(error). Falling back to inMemory.")
            do {
                let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
                modelContainer = try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("Could not create even in-memory ModelContainer: \(error)")
            }
        }
        let deps = DependencyContainer()
        dependencies = deps
        _authViewModel = State(initialValue: AuthViewModel(authService: deps.authService))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Base: 本編 (onboarding or main)
                if onboardingCompleted {
                    MainTabView()
                        .modelContainer(modelContainer)
                        .environment(\.dependencies, dependencies)
                        .onAppear {
                            applyTheme(animated: false)
                            seedDefaultCategories()
                        }
                        .onChange(of: appearanceMode) {
                            applyTheme(animated: true)
                        }
                        .task { await authViewModel.observeAuthState() }
                        .onOpenURL { url in deepLinkHandler.handle(url) }
                        .opacity(splashFinished ? 1.0 : 0.0)
                        .animation(.easeIn(duration: 0.15), value: splashFinished)
                } else {
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

                // Overlay: 起動時動画スプラッシュ (onboarding/main を覆って再生、終了後に fade out)
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
        }
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
