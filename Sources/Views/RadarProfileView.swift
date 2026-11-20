import SwiftUI

struct RadarProfileView: View {
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var store: StoreManager

    var onOpenPaywall: () -> Void

    @State private var newAllergen = ""
    @State private var selectedLang: AppLanguage = L10n.currentLanguage

    private let privacyURL = URL(string: "https://a3152557994-ship-it.github.io/purescan/privacy.html")!
    private let termsURL = URL(string: "https://a3152557994-ship-it.github.io/purescan/terms.html")!
    private let supportURL = URL(string: "https://a3152557994-ship-it.github.io/purescan/support.html")!

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    proStatusBanner
                    radarsCard
                    customBlacklistCard
                    languageAndLegalCard
                }
                .padding(16)
            }
            .background(LabTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("专属忌口雷达", "Personal Radar"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var proStatusBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: store.isPro ? "checkmark.seal.fill" : "crown.fill")
                .font(.system(size: 26))
                .foregroundStyle(store.isPro ? LabTheme.clean : .yellow)
            VStack(alignment: .leading, spacing: 3) {
                Text(store.isPro
                     ? L10n.t("配料照妖镜 Pro 已激活", "PureScan Pro Active")
                     : L10n.t("免费版 · 已启用基础雷达 + 1 项自选", "Free Plan · Base + 1 Custom Radar"))
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                Text(store.isPro
                     ? L10n.t("全 6 大雷达叠开 · 无限离线扫雷 · 永久 0 广告", "All 6 radars stacked · Unlimited offline scans · Zero ads")
                     : L10n.t("升级 Pro 一次解锁全家 6 大雷达、双品 PK 与无水印导出", "Unlock all 6 radars, VS PK showdown & HD export"))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            if !store.isPro {
                Button(L10n.t("升级", "Upgrade")) {
                    onOpenPaywall()
                }
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(LabTheme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white)
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(LabTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var radarsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("你的身体与家人忌口雷达（可叠加）", "YOUR PERSONALIZED SCORING RADARS"))
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(LabTheme.muted)

            ForEach(RadarType.allCases) { radar in
                let isOn = history.activeRadars.contains(radar)
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: radar.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isOn ? LabTheme.danger : LabTheme.muted)
                        .frame(width: 28)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(radar.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(LabTheme.ink)
                            if radar.isFreeBase {
                                Text(L10n.t("免费默认", "FREE"))
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(LabTheme.clean)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(LabTheme.cleanSoft)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(radar.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(LabTheme.muted)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { isOn },
                        set: { _ in
                            let allowed = history.toggleRadar(radar, isPro: store.isPro)
                            if !allowed { onOpenPaywall() }
                        }
                    ))
                    .labelsHidden()
                    .tint(LabTheme.danger)
                }
                .padding(.vertical, 4)

                if radar != RadarType.allCases.last {
                    Divider()
                }
            }
        }
        .labCard()
    }

    private var customBlacklistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("个人过敏原 / 死敌关键词黑名单", "CUSTOM ALLERGEN BLACKLIST"))
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(LabTheme.muted)

            Text(L10n.t("输入你绝不能碰的词（如：花生、牛奶、大豆、麸质、香菜、乙醇），一旦扫到立刻全屏标红警报！", "Add any allergen or ingredient to avoid (e.g. Peanut, Soy, Gluten, Milk) for instant red alerts."))
                .font(.system(size: 12))
                .foregroundStyle(LabTheme.muted)

            HStack(spacing: 8) {
                TextField(L10n.t("例：花生、乳糖、大豆...", "e.g. Peanut, Soy, Gluten..."), text: $newAllergen)
                    .padding(10)
                    .background(LabTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Button {
                    history.addCustomBlacklist(newAllergen)
                    newAllergen = ""
                } label: {
                    Text(L10n.t("添加", "Add"))
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(LabTheme.danger)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(newAllergen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !history.customBlacklist.isEmpty {
                FlowTagLayout(spacing: 8) {
                    ForEach(history.customBlacklist, id: \.self) { term in
                        HStack(spacing: 5) {
                            Text("🚫 \(term)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LabTheme.danger)
                            Button {
                                history.removeCustomBlacklist(term)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(LabTheme.danger.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(LabTheme.dangerSoft)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .labCard()
    }

    private var languageAndLegalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.t("界面语言 / Language", "App Language"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LabTheme.ink)
                Spacer()
                Picker("", selection: $selectedLang) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedLang) { _, newVal in
                    history.setLanguage(newVal)
                }
            }

            Divider()

            Button {
                Task { await store.restorePurchases() }
            } label: {
                HStack {
                    Text(L10n.t("恢复已购 Pro 权益", "Restore Purchases"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LabTheme.ink)
                    Spacer()
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(LabTheme.muted)
                }
            }

            if let msg = store.statusMessage {
                Text(msg)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LabTheme.clean)
            }

            Divider()

            HStack(spacing: 16) {
                Link(L10n.t("隐私政策", "Privacy Policy"), destination: privacyURL)
                Link(L10n.t("使用条款 (EULA)", "Terms (EULA)"), destination: termsURL)
                Link(L10n.t("技术支持", "Support"), destination: supportURL)
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(LabTheme.muted)

            Text(L10n.t(
                "配料照妖镜 100% 本地离线运算，绝不收集照片或个人数据。成分说明基于公开国标 GB 2760 / FDA / EFSA / INCI 整理，仅作生活科普参考。",
                "PureScan processes 100% on-device with zero cloud tracking. Ingredient explanations follow public GB 2760 / FDA / EFSA / INCI references for educational use only."
            ))
            .font(.system(size: 11))
            .foregroundStyle(LabTheme.muted)
        }
        .labCard()
    }
}
