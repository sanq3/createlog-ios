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
        let lang = AppLanguage(rawValue: raw) ?? .system
        self.appLanguage = lang
        Self.applyAppleLanguages(lang)
    }

    func setLanguage(_ lang: AppLanguage) {
        appLanguage = lang
        Self.applyAppleLanguages(lang)
    }

    /// AppleLanguages UserDefaults を書き換えることで Bundle の localization lookup を切替える。
    /// `.environment(\.locale)` だけでは LocalizedStringKey の Bundle lookup には効かないため、
    /// 業界標準 (LINE/Twitter/Mercari 等) の in-app 言語切替パターンとして AppleLanguages を使う。
    /// 完全反映には app restart が必要 (UI には「再起動してください」案内を出す想定)。
    private static func applyAppleLanguages(_ lang: AppLanguage) {
        switch lang {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .japanese:
            UserDefaults.standard.set(["ja"], forKey: "AppleLanguages")
        case .english:
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        }
    }
}
