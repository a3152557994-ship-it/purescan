import Foundation
import StoreKit
import SwiftUI
import UserNotifications

enum PureScanProductID {
    static let monthly = "com.yanghe.purescan.pro.monthly"
    static let yearly = "com.yanghe.purescan.pro.yearly"
    static let lifetime = "com.yanghe.purescan.pro.lifetime"
    static let all: [String] = [monthly, yearly, lifetime]
}

@MainActor
final class StoreManager: ObservableObject {
    static let freeDailyScanLimit = 10

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var isPurchasing: Bool = false
    @Published var statusMessage: String?

    @Published private(set) var scansUsedToday: Int = 0
    @Published private(set) var totalSuccessfulScans: Int = 0

    private let scansDateKey = "purescan.quota.date"
    private let scansCountKey = "purescan.quota.count"
    private let totalScansKey = "purescan.total.scans"
    private let proCacheKey = "purescan.pro.cached"

    private var updatesTask: Task<Void, Never>?

    init() {
        isPro = UserDefaults.standard.bool(forKey: proCacheKey)
        totalSuccessfulScans = UserDefaults.standard.integer(forKey: totalScansKey)
        syncDailyQuotaIfNeeded()

        updatesTask = Task {
            await listenForTransactions()
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var remainingFreeScansToday: Int {
        syncDailyQuotaIfNeeded()
        return max(0, Self.freeDailyScanLimit - scansUsedToday)
    }

    var canScanForFree: Bool {
        isPro || remainingFreeScansToday > 0
    }

    func recordCompletedScan() {
        syncDailyQuotaIfNeeded()
        scansUsedToday += 1
        totalSuccessfulScans += 1
        UserDefaults.standard.set(scansUsedToday, forKey: scansCountKey)
        UserDefaults.standard.set(totalSuccessfulScans, forKey: totalScansKey)
    }

    private func syncDailyQuotaIfNeeded() {
        let today = Self.todayStamp()
        let savedDate = UserDefaults.standard.string(forKey: scansDateKey)
        if savedDate != today {
            UserDefaults.standard.set(today, forKey: scansDateKey)
            UserDefaults.standard.set(0, forKey: scansCountKey)
            scansUsedToday = 0
        } else {
            scansUsedToday = UserDefaults.standard.integer(forKey: scansCountKey)
        }
    }

    private static func todayStamp() -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    func displayPrice(for id: String) -> String {
        if let p = product(for: id) {
            return p.displayPrice
        }
        switch id {
        case PureScanProductID.monthly: return L10n.t("¥6", "$1.99")
        case PureScanProductID.yearly: return L10n.t("¥18", "$9.99")
        case PureScanProductID.lifetime: return L10n.t("¥28", "$14.99")
        default: return ""
        }
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: PureScanProductID.all)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            // Offline fallback keeps fallback prices visible
        }
    }

    func purchase(_ productId: String) async -> Bool {
        isPurchasing = true
        statusMessage = nil
        defer { isPurchasing = false }

        if products.isEmpty {
            await loadProducts()
        }
        guard let target = product(for: productId) else {
            statusMessage = L10n.t("商店商品正在同步，请检查网络后重试。", "Store products are syncing. Please retry shortly.")
            return false
        }

        do {
            let result = try await target.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    if productId == PureScanProductID.yearly {
                        scheduleTrialReminderNotification()
                    }
                    statusMessage = L10n.t("已解锁配料照妖镜 Pro！", "PureScan Pro unlocked!")
                    return true
                case .unverified:
                    statusMessage = L10n.t("购买校验未通过，请重试。", "Purchase could not be verified.")
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                statusMessage = L10n.t("交易等待批准中。", "Purchase is pending approval.")
                return false
            @unknown default:
                return false
            }
        } catch {
            statusMessage = L10n.t("购买未完成：\(error.localizedDescription)", "Purchase failed: \(error.localizedDescription)")
            return false
        }
    }

    func restorePurchases() async {
        isPurchasing = true
        statusMessage = nil
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            statusMessage = isPro
                ? L10n.t("已成功恢复 Pro 权益！", "Pro membership restored!")
                : L10n.t("未查到有效购买记录。", "No active purchases found.")
        } catch {
            statusMessage = L10n.t("恢复购买失败，请稍后重试。", "Restore failed. Please try again.")
        }
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               PureScanProductID.all.contains(transaction.productID),
               transaction.revocationDate == nil {
                unlocked = true
                break
            }
        }
        isPro = unlocked
        UserDefaults.standard.set(unlocked, forKey: proCacheKey)
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update {
                await transaction.finish()
                await refreshEntitlements()
            }
        }
    }

    /// Proactively schedules a Day-2 local notification for 3-day yearly trial users so nobody gets surprise-billed.
    private func scheduleTrialReminderNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = L10n.t("配料照妖镜 · 免费试用明天到期", "PureScan · Trial Ends Tomorrow")
            content.body = L10n.t(
                "你的 3 天免费试用还剩 24 小时。如满意无需操作，如暂不需要可在系统“订阅”中一键取消，绝不悄悄扣费。",
                "Your 3-day free trial ends in 24 hours. Cancel anytime in iOS Settings > Subscriptions if you don't wish to renew."
            )
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 48 * 3600, repeats: false)
            let request = UNNotificationRequest(identifier: "purescan.trial.reminder", content: content, trigger: trigger)
            center.add(request)
        }
    }
}
