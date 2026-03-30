import SwiftUI
import SwiftData

@main
struct CreateLogApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    let modelContainer: ModelContainer = {
        let schema = Schema([SDCategory.self, SDProject.self, SDTimeEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(modelContainer)
                .onAppear {
                    applyTheme(animated: false)
                    seedDefaultCategories()
                }
                .onChange(of: appearanceMode) {
                    applyTheme(animated: true)
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
