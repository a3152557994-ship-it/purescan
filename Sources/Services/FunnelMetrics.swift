import Foundation

/// 100% privacy-safe, strictly on-device funnel counters persisted in UserDefaults.
/// Zero network calls, zero third-party SDKs, zero user identifiers — preserves Apple "Data Not Collected" privacy label.
enum FunnelEvent: Hashable {
    case appLaunch
    case scanCompleted(domain: String)
    case paywallImpression(region: String)
    case paywallPlanSelected(productId: String)
    case paywallAbandonOfferShown
    case paywallAbandonOfferAccepted(productId: String)
    case purchaseStarted(productId: String)
    case purchaseSucceeded(productId: String)
    case purchaseCancelled(productId: String)
    case reviewGateShown
    case reviewGatePositive
    case reviewGateFeedback
    case reviewGateDismissed
    case crossPromoTapped(appId: String)

    var storageKey: String {
        switch self {
        case .appLaunch: return "app_launch"
        case .scanCompleted: return "scan_completed"
        case .paywallImpression: return "paywall_impression"
        case .paywallPlanSelected(let pid): return "plan_selected_\(pid)"
        case .paywallAbandonOfferShown: return "paywall_abandon_shown"
        case .paywallAbandonOfferAccepted: return "paywall_abandon_accepted"
        case .purchaseStarted: return "purchase_started"
        case .purchaseSucceeded: return "purchase_succeeded"
        case .purchaseCancelled: return "purchase_cancelled"
        case .reviewGateShown: return "review_gate_shown"
        case .reviewGatePositive: return "review_gate_positive"
        case .reviewGateFeedback: return "review_gate_feedback"
        case .reviewGateDismissed: return "review_gate_dismissed"
        case .crossPromoTapped(let appId): return "cross_promo_\(appId)"
        }
    }
}

final class FunnelMetrics {
    static let shared = FunnelMetrics()

    private let defaults: UserDefaults
    private let storageKey = "purescan.local.funnel.metrics.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    @discardableResult
    func record(_ event: FunnelEvent) -> Int {
        var counts = snapshot()
        let next = (counts[event.storageKey] ?? 0) + 1
        counts[event.storageKey] = next
        defaults.set(counts, forKey: storageKey)
        return next
    }

    func count(for event: FunnelEvent) -> Int {
        snapshot()[event.storageKey] ?? 0
    }

    func snapshot() -> [String: Int] {
        (defaults.dictionary(forKey: storageKey) as? [String: Int]) ?? [:]
    }

    /// Local-only paywall-to-purchase conversion ratio for on-device diagnostics.
    var paywallConversionRate: Double {
        let impressions = count(for: .paywallImpression(region: ""))
        guard impressions > 0 else { return 0 }
        let purchases = count(for: .purchaseSucceeded(productId: ""))
        return Double(purchases) / Double(impressions)
    }

    func reset() {
        defaults.removeObject(forKey: storageKey)
    }
}
