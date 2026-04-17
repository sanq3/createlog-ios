import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case japanese
    case english

    var localizedKey: LocalizedStringKey {
        switch self {
        case .system: "common.systemDefault"
        case .japanese: "settings.language.japanese"
        case .english: "settings.language.english"
        }
    }

    var locale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        case .japanese: Locale(identifier: "ja")
        case .english: Locale(identifier: "en")
        }
    }
}

@MainActor
@Observable
final class LocalizationManager {
    private static let storageKey = "appLanguage"

    private(set) var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: Self.storageKey)
        }
    }

    var currentLocale: Locale {
        appLanguage.locale
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? AppLanguage.system.rawValue
        self.appLanguage = AppLanguage(rawValue: raw) ?? .system
    }

    func setLanguage(_ lang: AppLanguage) {
        appLanguage = lang
    }
}
