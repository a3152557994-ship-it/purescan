import Foundation

/// 3-Region Paywall Psychology tailored to regional buying mindsets while keeping
/// identical approved StoreKit 2 product IDs and full Apple 3.1.2 transparency.
enum PaywallRegionProfile: String, Equatable {
    case angloROI
    case euPrivacyLifetime
    case eastAsiaDetail

    private static let eastAsiaRegions: Set<String> = ["CN", "HK", "TW", "MO", "JP", "KR", "SG"]
    private static let euPrivacyRegions: Set<String> = [
        "DE", "FR", "AT", "CH", "NL", "BE", "LU", "SE", "NO", "DK", "FI", "IS",
        "ES", "IT", "PT", "PL", "CZ", "SK", "HU", "RO", "BG", "HR", "SI", "GR",
        "EE", "LV", "LT", "CY", "MT"
    ]
    private static let angloRegions: Set<String> = ["US", "CA", "GB", "AU", "NZ", "IE"]

    static func resolve(
        regionCode: String? = Locale.current.region?.identifier,
        language: ResolvedLanguage = L10n.resolvedLanguage
    ) -> PaywallRegionProfile {
        if let code = regionCode?.uppercased() {
            if eastAsiaRegions.contains(code) { return .eastAsiaDetail }
            if euPrivacyRegions.contains(code) { return .euPrivacyLifetime }
            if angloRegions.contains(code) { return .angloROI }
        }
        // Fallback by active UI language if region is unavailable
        if language == .zhHans || language == .zhHant {
            return .eastAsiaDetail
        }
        return .angloROI
    }

    /// Default highlighted plan tuned to regional purchase preference.
    /// All 3 approved products remain selectable in every region.
    var defaultSelectedProductID: String {
        switch self {
        case .angloROI:
            return PureScanProductID.yearly
        case .euPrivacyLifetime, .eastAsiaDetail:
            return PureScanProductID.lifetime
        }
    }

    var heroStamp: String {
        switch self {
        case .angloROI:
            return L10n.t(
                en: "PAYS FOR ITSELF IN 1 GROCERY TRIP",
                zhHans: "逛一次超市就回本 · 永久 0 广告",
                zhHant: "逛一次超市就回本 · 永久 0 廣告"
            )
        case .euPrivacyLifetime:
            return L10n.t(
                en: "100% ON-DEVICE · ZERO SUBSCRIPTION LOCK-IN",
                zhHans: "100% 本地离线 · 一次买断永不续费",
                zhHant: "100% 本機離線 · 一次買斷永不續費"
            )
        case .eastAsiaDetail:
            return L10n.t(
                en: "ZERO ADS FOREVER · ALL 6 HEALTH RADARS",
                zhHans: "永久 0 广告 · 0 摇一摇跳屏 · 买断终身用",
                zhHant: "永久 0 廣告 · 0 搖一搖跳頁 · 買斷終身用"
            )
        }
    }

    var heroTitle: String {
        switch self {
        case .angloROI:
            return L10n.t(
                en: "Stop Paying $49/yr for Bloated Scanners",
                zhHans: "升级配料照妖镜 Pro",
                zhHant: "升級配料照妖鏡 Pro"
            )
        case .euPrivacyLifetime:
            return L10n.t(
                en: "Own PureScan Forever — 100% Private",
                zhHans: "一次买断 · 永久掌控全家配料安全",
                zhHant: "一次買斷 · 永久掌握全家成分安全"
            )
        case .eastAsiaDetail:
            return L10n.t(
                en: "Upgrade to PureScan Pro",
                zhHans: "升级配料照妖镜 Pro",
                zhHant: "升級配料照妖鏡 Pro"
            )
        }
    }

    var heroSubtitle: String {
        switch self {
        case .angloROI:
            return L10n.t(
                en: "One avoided junk purchase covers Pro. Unlock all 6 health radars, side-by-side VS PK & unlimited offline scans.",
                zhHans: "避开两包坑货就回本，全家控糖、痛风、宝妈、护肤、猫狗粮全解锁。",
                zhHant: "避開兩包踩雷零食就回本，全家控糖、痛風、孕媽、護膚、寵糧全解鎖。"
            )
        case .euPrivacyLifetime:
            return L10n.t(
                en: "Every scan runs offline on your iPhone with zero cloud uploads or tracking. Pay once for Lifetime or start a risk-free trial.",
                zhHans: "照片绝不上传云端、无需注册账号。支持一次买断终身拥有，或开启 3 天免费试用。",
                zhHant: "照片絕不上傳雲端、無須註冊帳號。支援一次買斷終身擁有，或開啟 3 天免費試用。"
            )
        case .eastAsiaDetail:
            return L10n.t(
                en: "Less than one coffee for lifetime protection across food, skincare INCI & pet food — zero ads forever.",
                zhHans: "不到一杯奶茶钱，一次解锁全家 6 大忌口雷达、超市双品 PK 与无限离线扫雷。",
                zhHant: "不到一杯手搖飲價格，一次解鎖全家 6 大忌口雷達、超市雙品 PK 與無限離線掃雷。"
            )
        }
    }
}
