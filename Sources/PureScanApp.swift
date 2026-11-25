import SwiftUI

@main
struct PureScanApp: App {
    @StateObject private var history: HistoryStore
    @StateObject private var store = StoreManager()

    init() {
        let args = ProcessInfo.processInfo.arguments
        if let langIdx = args.firstIndex(of: "-ui_lang"), langIdx + 1 < args.count {
            let code = args[langIdx + 1].lowercased()
            if code.hasPrefix("en") {
                L10n.currentLanguage = .en
            } else if code.contains("hant") || code.contains("tw") || code.contains("hk") {
                L10n.currentLanguage = .zhHant
            } else {
                L10n.currentLanguage = .zhHans
            }
        }
        FunnelMetrics.shared.record(.appLaunch)
        _history = StateObject(wrappedValue: HistoryStore())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let demoRecord = launchResultDemoRecord() {
                    ScanResultSheet(
                        record: demoRecord,
                        onSendToPK: { _ in },
                        onRequirePro: { _ in }
                    )
                } else {
                    MainTabView()
                }
            }
            .environmentObject(history)
            .environmentObject(store)
            .preferredColorScheme(.light)
        }
    }

    private func launchResultDemoRecord() -> ScanRecord? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-ui_demo_screen"),
              idx + 1 < args.count,
              args[idx + 1].lowercased() == "result",
              let toast = SampleCatalog.all.first(where: { $0.id == "toast_bread" }) else {
            return nil
        }
        return IngredientAnalyzer.analyze(
            rawText: toast.rawText,
            productName: toast.displayName,
            preferredDomain: .food,
            activeRadars: [.cleanFood, .sugarDiet, .momBaby]
        )
    }
}
