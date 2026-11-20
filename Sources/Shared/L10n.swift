import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case auto
    case zhHans
    case en

    var id: String { rawValue }

    var resolvedIsChinese: Bool {
        switch self {
        case .zhHans:
            return true
        case .en:
            return false
        case .auto:
            let preferred = Locale.preferredLanguages.first ?? "zh-Hans"
            return preferred.lowercased().hasPrefix("zh")
        }
    }

    var displayName: String {
        switch self {
        case .auto: return L10n.t("跟随系统", "System")
        case .zhHans: return "简体中文"
        case .en: return "English"
        }
    }
}

enum L10n {
    private static let storageKey = "purescan.language.override"

    static var currentLanguage: AppLanguage {
        get {
            if let raw = UserDefaults.standard.string(forKey: storageKey),
               let lang = AppLanguage(rawValue: raw) {
                return lang
            }
            return .auto
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }

    static var isChinese: Bool {
        currentLanguage.resolvedIsChinese
    }

    static func t(_ zh: String, _ en: String) -> String {
        isChinese ? zh : en
    }
}
