import Foundation
import SwiftUI

enum ResolvedLanguage: String, Equatable {
    case en
    case zhHans
    case zhHant
}

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case auto
    case zhHans
    case zhHant
    case en

    var id: String { rawValue }

    func resolvedLanguage(preferredLanguages: [String] = Locale.preferredLanguages) -> ResolvedLanguage {
        switch self {
        case .zhHans:
            return .zhHans
        case .zhHant:
            return .zhHant
        case .en:
            return .en
        case .auto:
            let preferred = (preferredLanguages.first ?? "zh-Hans").lowercased()
            if preferred.contains("hant")
                || preferred.hasPrefix("zh-tw")
                || preferred.hasPrefix("zh_tw")
                || preferred.hasPrefix("zh-hk")
                || preferred.hasPrefix("zh_hk")
                || preferred.hasPrefix("zh-mo")
                || preferred.hasPrefix("zh_mo") {
                return .zhHant
            }
            if preferred.hasPrefix("zh") {
                return .zhHans
            }
            return .en
        }
    }

    var resolvedIsChinese: Bool {
        resolvedLanguage() != .en
    }

    var displayName: String {
        switch self {
        case .auto:
            return L10n.t(en: "System", zhHans: "跟随系统", zhHant: "跟隨系統")
        case .zhHans:
            return "简体中文"
        case .zhHant:
            return "繁體中文"
        case .en:
            return "English"
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

    static var resolvedLanguage: ResolvedLanguage {
        currentLanguage.resolvedLanguage()
    }

    static var isChinese: Bool {
        resolvedLanguage != .en
    }

    static var isTraditionalChinese: Bool {
        resolvedLanguage == .zhHant
    }

    /// Backward-compatible 2-arg localization helper matching existing PureScan call sites `(zhHans, en)`.
    /// Automatically renders authentic Traditional Chinese when Hong Kong / Taiwan (`zh-Hant`) is active.
    static func t(_ zhHans: String, _ en: String) -> String {
        switch resolvedLanguage {
        case .en:
            return en
        case .zhHans:
            return zhHans
        case .zhHant:
            return toTraditionalChinese(zhHans)
        }
    }

    /// Explicit 3-arg localization helper with dedicated authentic Traditional Chinese copy.
    static func t(en: String, zhHans: String, zhHant: String) -> String {
        switch resolvedLanguage {
        case .en:
            return en
        case .zhHans:
            return zhHans
        case .zhHant:
            return zhHant
        }
    }

    /// Curated HK/TW lexical normalizations applied after ICU Hans->Hant conversion
    /// so Hong Kong & Taiwan users never see Mainland-only terminology.
    private static let twHkReplacements: [(String, String)] = [
        ("軟件", "軟體"),
        ("信息", "資訊"),
        ("質量", "品質"),
        ("默認", "預設"),
        ("設置", "設定"),
        ("登錄", "登入"),
        ("賬號", "帳號"),
        ("賬戶", "帳戶"),
        ("相冊", "相簿"),
        ("剪貼板", "剪貼簿"),
        ("屏幕", "螢幕"),
        ("網絡", "網路"),
        ("識別", "辨識"),
        ("數據", "資料"),
        ("鏈接", "連結"),
        ("點擊", "點選"),
        ("優化", "最佳化"),
        ("酸奶", "優格"),
        ("方便面", "泡麵"),
        ("泡面", "泡麵"),
        ("面包", "麵包"),
        ("面粉", "麵粉"),
        ("過敏原", "致敏原"),
        ("支持", "支援"),
        ("反饋", "回饋"),
        ("干飯", "吃飯")
    ]

    static func toTraditionalChinese(_ simplified: String) -> String {
        let converted = simplified.applyingTransform(StringTransform(rawValue: "Hans-Hant"), reverse: false) ?? simplified
        var result = converted
        for (src, dst) in twHkReplacements {
            if result.contains(src) {
                result = result.replacingOccurrences(of: src, with: dst)
            }
        }
        return result
    }

    static func toSimplifiedForMatching(_ text: String) -> String {
        text.applyingTransform(StringTransform(rawValue: "Hant-Hans"), reverse: false) ?? text
    }
}
