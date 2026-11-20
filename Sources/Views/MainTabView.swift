import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var store: StoreManager

    @State private var selectedTab: Int = 0
    @State private var activeResult: ScanRecord?
    @State private var showPaywall = false
    @State private var paywallPreview: ScanRecord?
    @State private var didApplyLaunchDemo = false

    var body: some View {
        TabView(selection: $selectedTab) {
            ScannerHomeView(
                activeResult: $activeResult,
                paywallRecordPreview: $paywallPreview,
                showPaywall: $showPaywall,
                onOpenPK: { selectedTab = 1 }
            )
            .tabItem {
                Label(L10n.t("照妖镜", "Scan"), systemImage: "viewfinder")
            }
            .tag(0)

            ComparePKView(
                onRequirePro: { preview in
                    paywallPreview = preview
                    showPaywall = true
                }
            )
            .tabItem {
                Label(L10n.t("双品 PK", "VS PK"), systemImage: "bolt.horizontal.fill")
            }
            .tag(1)

            CabinetHistoryView(
                onSelectRecord: { rec in
                    activeResult = rec
                }
            )
            .tabItem {
                Label(L10n.t("红黑柜", "Cabinet"), systemImage: "archivebox.fill")
            }
            .tag(2)

            RadarProfileView(
                onOpenPaywall: {
                    paywallPreview = history.records.first
                    showPaywall = true
                }
            )
            .tabItem {
                Label(L10n.t("忌口雷达", "Radar"), systemImage: "dial.high.fill")
            }
            .tag(3)
        }
        .tint(LabTheme.danger)
        .id(history.languageVersion)
        .sheet(item: $activeResult) { record in
            ScanResultSheet(
                record: record,
                onSendToPK: { _ in selectedTab = 1 },
                onRequirePro: { preview in
                    activeResult = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        paywallPreview = preview
                        showPaywall = true
                    }
                }
            )
            .environmentObject(history)
            .environmentObject(store)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(previewRecord: paywallPreview)
                .environmentObject(store)
        }
        .onOpenURL { url in
            guard url.scheme?.lowercased() == "purescan" else { return }
            switch url.host?.lowercased() {
            case "pk": selectedTab = 1
            case "cabinet": selectedTab = 2
            case "radar": selectedTab = 3
            default: selectedTab = 0
            }
        }
        .onAppear {
            applyLaunchDemoIfRequested()
        }
    }

    private func applyLaunchDemoIfRequested() {
        guard !didApplyLaunchDemo else { return }
        didApplyLaunchDemo = true

        let args = ProcessInfo.processInfo.arguments
        if let langIdx = args.firstIndex(of: "-ui_lang"), langIdx + 1 < args.count {
            let code = args[langIdx + 1].lowercased()
            history.setLanguage(code.hasPrefix("en") ? .en : .zhHans)
        }

        guard let screenIdx = args.firstIndex(of: "-ui_demo_screen"), screenIdx + 1 < args.count else {
            return
        }
        let target = args[screenIdx + 1].lowercased()

        // Seed rich realistic cabinet records for demo screenshots
        if history.records.isEmpty {
            let demoSpecs: [(String, Set<RadarType>, CabinetBucket)] = [
                ("toast_bread", [.cleanFood, .sugarDiet, .momBaby], .redList),
                ("clean_yogurt", [.cleanFood, .sugarDiet, .momBaby], .greenList),
                ("instant_noodle_soup", [.cleanFood, .goutPurine], .redList),
                ("clean_cat_food", [.petSafety], .greenList),
                ("trap_cat_food", [.petSafety], .redList),
                ("gentle_lotion", [.acneSkincare], .greenList)
            ]
            for (sid, radars, bucket) in demoSpecs.reversed() {
                if let sample = SampleCatalog.all.first(where: { $0.id == sid }) {
                    var rec = IngredientAnalyzer.analyze(
                        rawText: sample.rawText,
                        productName: sample.displayName,
                        preferredDomain: sample.domain,
                        activeRadars: radars
                    )
                    rec.cabinet = bucket
                    history.saveRecord(rec)
                }
            }
        }

        // Refresh PK pair in the active demo language
        if let toast = SampleCatalog.all.first(where: { $0.id == "toast_bread" }),
           let yogurt = SampleCatalog.all.first(where: { $0.id == "clean_yogurt" }) {
            history.pkLeft = IngredientAnalyzer.analyze(rawText: toast.rawText, productName: toast.displayName, preferredDomain: .food, activeRadars: [.cleanFood, .sugarDiet, .momBaby])
            history.pkRight = IngredientAnalyzer.analyze(rawText: yogurt.rawText, productName: yogurt.displayName, preferredDomain: .food, activeRadars: [.cleanFood, .sugarDiet, .momBaby])
        }

        switch target {
        case "result":
            selectedTab = 0
            if let toast = SampleCatalog.all.first(where: { $0.id == "toast_bread" }) {
                let rec = IngredientAnalyzer.analyze(
                    rawText: toast.rawText,
                    productName: toast.displayName,
                    preferredDomain: .food,
                    activeRadars: [.cleanFood, .sugarDiet, .momBaby]
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    activeResult = rec
                }
            }
        case "pk":
            selectedTab = 1
        case "cabinet":
            selectedTab = 2
        case "radar":
            selectedTab = 3
        case "paywall":
            selectedTab = 0
            if let toast = SampleCatalog.all.first(where: { $0.id == "toast_bread" }) {
                let rec = IngredientAnalyzer.analyze(
                    rawText: toast.rawText,
                    productName: toast.displayName,
                    preferredDomain: .food,
                    activeRadars: [.cleanFood, .sugarDiet, .momBaby]
                )
                paywallPreview = rec
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showPaywall = true
            }
        default:
            selectedTab = 0
        }
    }
}
