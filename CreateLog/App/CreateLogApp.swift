import SwiftUI

@main
struct CreateLogApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    applyTheme(animated: false)
                }
                .onChange(of: appearanceMode) {
                    applyTheme(animated: true)
                }
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
