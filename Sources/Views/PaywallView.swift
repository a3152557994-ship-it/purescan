import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    let previewRecord: ScanRecord?
    private let regionProfile: PaywallRegionProfile
    @State private var selectedPlan: String
    @State private var showAbandonOffer = false

    private let abandonOfferShownKey = "purescan.paywall.abandonOfferShown"
    private let privacyURL = URL(string: "https://a3152557994-ship-it.github.io/purescan/privacy.html")!
    private let termsURL = URL(string: "https://a3152557994-ship-it.github.io/purescan/terms.html")!

    init(previewRecord: ScanRecord?, regionProfile: PaywallRegionProfile = PaywallRegionProfile.resolve()) {
        self.previewRecord = previewRecord
        self.regionProfile = regionProfile
        _selectedPlan = State(initialValue: regionProfile.defaultSelectedProductID)
    }

    private var canTriggerAbandonOffer: Bool {
        guard !store.isPro else { return false }
        guard !ProcessInfo.processInfo.arguments.contains("-ui_demo_screen") else { return false }
        return !UserDefaults.standard.bool(forKey: abandonOfferShownKey)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 15) {
                    if let rec = previewRecord {
                        sunkCostPreviewBanner(rec)
                    } else {
                        regionHeroBanner
                    }

                    regionHighlightCard
                    benefitsListCard
                    planPickerStack
                    transparentTimelineCard
                    ctaButton
                    nonHostileFreeExit
                    complianceFooter
                }
                .padding(16)
            }
            .background(LabTheme.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        handleDismissAttempt()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(LabTheme.muted.opacity(0.6))
                    }
                    .accessibilityLabel(L10n.t(en: "Close", zhHans: "关闭", zhHant: "關閉"))
                }
            }
            .onAppear {
                FunnelMetrics.shared.record(.paywallImpression(region: regionProfile.rawValue))
            }
            .sheet(isPresented: $showAbandonOffer) {
                abandonOfferSheet
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func handleDismissAttempt() {
        if canTriggerAbandonOffer {
            UserDefaults.standard.set(true, forKey: abandonOfferShownKey)
            FunnelMetrics.shared.record(.paywallAbandonOfferShown)
            showAbandonOffer = true
        } else {
            dismiss()
        }
    }

    // MARK: - Banners

    private func sunkCostPreviewBanner(_ rec: ScanRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.t(
                    en: "YOUR SCAN IS READY · UNLOCK FULL PROTECTION",
                    zhHans: "刚刚扫出的实测样本 · 升级解锁完整雷达",
                    zhHant: "剛剛掃出的實測樣本 · 升級解鎖完整雷達"
                ))
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(LabTheme.danger)
                Spacer()
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rec.productName)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(LabTheme.ink)
                        .lineLimit(1)
                    Text(rec.displayHeadline)
                        .font(.system(size: 12))
                        .foregroundStyle(LabTheme.muted)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(rec.score)")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(LabTheme.color(for: rec.grade))
            }
        }
        .labCard(padding: 15)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(LabTheme.danger.opacity(0.45), lineWidth: 1.5)
        )
    }

    private var regionHeroBanner: some View {
        VStack(spacing: 8) {
            StampBadge(text: regionProfile.heroStamp, color: LabTheme.danger, angle: -2)
            Text(regionProfile.heroTitle)
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(LabTheme.ink)
                .multilineTextAlignment(.center)
            Text(regionProfile.heroSubtitle)
                .font(.system(size: 13))
                .foregroundStyle(LabTheme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    // MARK: - 3-Region Psychology Accent Block

    @ViewBuilder
    private var regionHighlightCard: some View {
        switch regionProfile {
        case .angloROI:
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t(en: "Typical Scanner Apps", zhHans: "常见订阅制扫码 App", zhHant: "常見訂閱制掃碼 App"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(LabTheme.muted)
                    Text(L10n.t(en: "$39–$59 / yr", zhHans: "¥168–¥298 / 年", zhHant: "NT$990–1,490 / 年"))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .strikethrough(true, color: LabTheme.danger)
                        .foregroundStyle(LabTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(LabTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(LabTheme.hairline, lineWidth: 1))

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t(en: "PureScan Lifetime", zhHans: "配料照妖镜永久买断", zhHant: "配料照妖鏡永久買斷"))
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(LabTheme.clean)
                    Text("\(store.displayPrice(for: PureScanProductID.lifetime)) \(L10n.t(en: "once", zhHans: "一次付清", zhHant: "一次付清"))")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(LabTheme.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(LabTheme.cleanSoft)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(LabTheme.clean.opacity(0.5), lineWidth: 1.2))
            }

        case .euPrivacyLifetime:
            HStack(spacing: 8) {
                privacyPill(
                    icon: "iphone.gen3",
                    label: L10n.t(en: "100% On-Device", zhHans: "100% 本机离线", zhHant: "100% 本機離線")
                )
                privacyPill(
                    icon: "hand.raised.shield.fill",
                    label: L10n.t(en: "Zero Tracking", zhHans: "零数据收集", zhHant: "零資料收集")
                )
                privacyPill(
                    icon: "person.2.fill",
                    label: L10n.t(en: "Family Shareable", zhHans: "支持家人共享", zhHant: "支援家人共享")
                )
            }

        case .eastAsiaDetail:
            VStack(spacing: 8) {
                HStack {
                    Text(L10n.t(en: "FEATURE COMPARISON", zhHans: "免费版 vs Pro 完整对比", zhHant: "免費版 vs Pro 完整對比"))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(LabTheme.muted)
                    Spacer()
                    Text(L10n.t(en: "Free", zhHans: "免费版", zhHant: "免費版"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(LabTheme.muted)
                        .frame(width: 56)
                    Text("PRO")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(LabTheme.danger)
                        .frame(width: 68)
                }
                Divider()
                specRow(
                    title: L10n.t(en: "6 Health Radars", zhHans: "6 大专属忌口雷达叠加", zhHant: "6 大專屬忌口雷達疊加"),
                    freeVal: L10n.t(en: "1+1", zhHans: "基础+1", zhHant: "基礎+1"),
                    proVal: L10n.t(en: "All 6", zhHans: "全 6 叠开", zhHant: "全 6 疊開")
                )
                specRow(
                    title: L10n.t(en: "Daily Offline Scans", zhHans: "每日离线拍照扫雷", zhHant: "每日離線拍照掃雷"),
                    freeVal: L10n.t(en: "10 / day", zhHans: "10 次/天", zhHant: "10 次/天"),
                    proVal: L10n.t(en: "Unlimited", zhHans: "无限次", zhHant: "無限次")
                )
                specRow(
                    title: L10n.t(en: "VS PK & Clean HD Cards", zhHans: "双品 PK 与无水印长图", zhHant: "雙品 PK 與無浮水印長圖"),
                    freeVal: "—",
                    proVal: "✓"
                )
            }
            .labCard(padding: 13)
        }
    }

    private func privacyPill(icon: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(LabTheme.clean)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(LabTheme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(LabTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LabTheme.hairline, lineWidth: 1))
    }

    private func specRow(title: String, freeVal: String, proVal: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LabTheme.ink)
            Spacer()
            Text(freeVal)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LabTheme.muted)
                .frame(width: 56)
            Text(proVal)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(LabTheme.clean)
                .frame(width: 68)
        }
    }

    // MARK: - Core Benefits

    private var benefitsListCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            benefitRow(
                icon: "dial.high.fill",
                title: L10n.t(en: "Stack All 6 Personal Radars", zhHans: "全 6 大忌口雷达同时叠开", zhHant: "全 6 大忌口雷達同時疊開"),
                detail: L10n.t(en: "Low Sugar, Gout/Purine, Mom & Kids, Skincare INCI & Pet Food", zhHans: "控糖减脂 + 痛风高尿酸 + 宝妈孕期 + 敏肌护肤 + 猫狗粮避毒", zhHant: "控糖減脂 + 痛風高尿酸 + 孕期寶媽 + 敏肌護膚 + 貓狗糧避毒")
            )
            benefitRow(
                icon: "bolt.horizontal.fill",
                title: L10n.t(en: "Supermarket VS PK Comparison", zhHans: "超市「双品 VS 成分大决战」", zhHant: "超市「雙品 VS 成分大對決」"),
                detail: L10n.t(en: "Compare two labels side-by-side & export clean HD receipt cards", zhHans: "两包酸奶/吐司/猫粮同屏比出更干净款，一键出高清避雷长图", zhHant: "兩包優格/吐司/貓糧同螢幕比出更乾淨款，一鍵輸出高清避雷長圖")
            )
            benefitRow(
                icon: "infinity",
                title: L10n.t(en: "Unlimited Offline Scans & Cabinet", zhHans: "无限次离线拍照 + 无限红黑囤货柜", zhHant: "無限次離線拍照 + 無限紅黑囤貨櫃"),
                detail: L10n.t(en: "0.3s on-device OCR with zero signal, zero ads forever", zhHans: "地下超市没信号 0.3 秒直出，永不弹任何广告", zhHant: "地下超市無訊號 0.3 秒直出，永不彈出任何廣告")
            )
        }
        .labCard(padding: 15)
    }

    private func benefitRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(LabTheme.clean)
                .frame(width: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LabTheme.ink)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(LabTheme.muted)
            }
        }
    }

    // MARK: - Approved StoreKit 2 Plans

    private var planPickerStack: some View {
        VStack(spacing: 10) {
            planCard(
                productId: PureScanProductID.lifetime,
                title: L10n.t(en: "Lifetime Pro (Pay Once)", zhHans: "永久买断 Pro（一次付清）", zhHant: "永久買斷 Pro（一次付清）"),
                subtitle: L10n.t(en: "Own forever · Zero recurring bills · Family Shareable", zhHans: "买断终身用 · 永不续费 · 支持家人共享与后续新增成分库", zhHant: "買斷終身用 · 永不續費 · 支援家人共享與後續新增成分庫"),
                price: store.displayPrice(for: PureScanProductID.lifetime),
                strikePrice: L10n.t(en: "$39.99", zhHans: "原价 ¥98", zhHant: "原價 NT$990"),
                badge: regionProfile == .euPrivacyLifetime
                    ? L10n.t(en: "OWN FOREVER", zhHans: "一次买断", zhHant: "一次買斷")
                    : L10n.t(en: "BEST VALUE", zhHans: "最划算 · 买断", zhHant: "最划算 · 買斷")
            )

            planCard(
                productId: PureScanProductID.yearly,
                title: L10n.t(en: "Annual Pro (3-Day Free Trial)", zhHans: "年度会员（3 天免费试用）", zhHant: "年度會員（3 天免費試用）"),
                subtitle: L10n.t(en: "Day-2 local reminder before renewal — zero surprise bills", zhHans: "第 2 天主动推送到期提醒，绝不悄悄扣年费", zhHant: "第 2 天主動推送到期提醒，絕不悄悄扣年費"),
                price: "\(store.displayPrice(for: PureScanProductID.yearly))\(L10n.t(en: "/yr", zhHans: "/年", zhHant: "/年"))",
                strikePrice: nil,
                badge: L10n.t(en: "3-DAY FREE TRIAL", zhHans: "免费试 3 天", zhHant: "免費試 3 天")
            )

            planCard(
                productId: PureScanProductID.monthly,
                title: L10n.t(en: "Monthly Pro", zhHans: "月度应急卡", zhHant: "月度彈性方案"),
                subtitle: L10n.t(en: "Flexible monthly access, cancel anytime in iOS Settings", zhHans: "逛山姆/大促囤货随开随停，按月续订可随时取消", zhHant: "逛超市/採購囤貨隨開隨停，按月續訂可隨時取消"),
                price: "\(store.displayPrice(for: PureScanProductID.monthly))\(L10n.t(en: "/mo", zhHans: "/月", zhHant: "/月"))",
                strikePrice: nil,
                badge: nil
            )
        }
    }

    private func planCard(productId: String, title: String, subtitle: String, price: String, strikePrice: String?, badge: String?) -> some View {
        let isSelected = selectedPlan == productId
        return Button {
            selectedPlan = productId
            FunnelMetrics.shared.record(.paywallPlanSelected(productId: productId))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isSelected ? LabTheme.danger : LabTheme.muted)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(LabTheme.ink)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(productId == PureScanProductID.lifetime ? LabTheme.danger : LabTheme.clean)
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(LabTheme.muted)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(price)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? LabTheme.danger : LabTheme.ink)
                    if let strikePrice {
                        Text(strikePrice)
                            .font(.system(size: 10))
                            .strikethrough()
                            .foregroundStyle(LabTheme.muted)
                    }
                }
            }
            .padding(14)
            .background(isSelected ? LabTheme.dangerSoft.opacity(0.65) : LabTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? LabTheme.danger : LabTheme.hairline, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Transparent Trial / Ownership Timeline

    private var transparentTimelineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if selectedPlan == PureScanProductID.yearly {
                Text(L10n.t(
                    en: "HOW YOUR 3-DAY FREE TRIAL WORKS",
                    zhHans: "3 天免费试用透明时间线",
                    zhHant: "3 天免費試用透明時間軸"
                ))
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(LabTheme.clean)

                timelineRow(
                    icon: "lock.open.fill",
                    color: LabTheme.clean,
                    step: L10n.t(en: "Today · Free ($0 due now)", zhHans: "今天 · 立即免费解锁（今日 ¥0）", zhHant: "今天 · 立即免費解鎖（今日 $0）"),
                    detail: L10n.t(en: "Instant access to all 6 radars, VS PK & unlimited offline scans.", zhHans: "立刻叠开全 6 大忌口雷达、双品 PK 与无限离线扫雷。", zhHant: "立刻疊開全 6 大忌口雷達、雙品 PK 與無限離線掃雷。")
                )
                timelineRow(
                    icon: "bell.badge.fill",
                    color: LabTheme.caution,
                    step: L10n.t(en: "Day 2 · Local Reminder", zhHans: "第 2 天 · 本地提醒不偷扣", zhHant: "第 2 天 · 本機提醒不偷扣"),
                    detail: L10n.t(en: "PureScan sends a local reminder 24h before trial ends so you stay in control.", zhHans: "到期前 24 小时主动推送本机提醒，不满意一键取消。", zhHant: "到期前 24 小時主動推送本機提醒，不滿意一鍵取消。")
                )
                timelineRow(
                    icon: "checkmark.shield.fill",
                    color: LabTheme.ink,
                    step: L10n.t(
                        en: "Day 3 · Trial Ends (\(store.displayPrice(for: PureScanProductID.yearly))/yr)",
                        zhHans: "第 3 天 · 按 \(store.displayPrice(for: PureScanProductID.yearly))/年续订",
                        zhHant: "第 3 天 · 按 \(store.displayPrice(for: PureScanProductID.yearly))/年續訂"
                    ),
                    detail: L10n.t(en: "Renews automatically only if you love it. Cancel anytime in iOS Settings.", zhHans: "如满意继续守护全家，随时可在 iOS「设置 → 订阅」取消。", zhHant: "如滿意繼續守護全家，隨時可在 iOS「設定 → 訂閱」取消。")
                )
            } else if selectedPlan == PureScanProductID.lifetime {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LabTheme.clean)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.t(
                            en: "Pay Once (\(store.displayPrice(for: PureScanProductID.lifetime))) · Zero Renewals Ever",
                            zhHans: "一次买断（\(store.displayPrice(for: PureScanProductID.lifetime))）· 永不自动续费",
                            zhHant: "一次買斷（\(store.displayPrice(for: PureScanProductID.lifetime))）· 永不自動續費"
                        ))
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(LabTheme.ink)
                        Text(L10n.t(
                            en: "One-time non-consumable purchase tied to your Apple ID with Family Sharing included. No subscription to remember to cancel.",
                            zhHans: "一次性非消耗型内购，永久绑定您的 Apple ID 并支持家人共享，彻底告别续费焦虑。",
                            zhHant: "一次性非消耗型內購，永久綁定您的 Apple ID 並支援家人共享，徹底告別續費焦慮。"
                        ))
                        .font(.system(size: 11))
                        .foregroundStyle(LabTheme.muted)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LabTheme.ink)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.t(
                            en: "Flexible Monthly (\(store.displayPrice(for: PureScanProductID.monthly))/mo) · Cancel Anytime",
                            zhHans: "灵活按月（\(store.displayPrice(for: PureScanProductID.monthly))/月）· 随时可停",
                            zhHant: "彈性按月（\(store.displayPrice(for: PureScanProductID.monthly))/月）· 隨時可停"
                        ))
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(LabTheme.ink)
                        Text(L10n.t(
                            en: "Try full Pro access for a month and cancel with 2 taps in iOS Settings > Subscriptions whenever you want.",
                            zhHans: "低门槛体验全部 Pro 功能，随时在 iOS「设置 → 订阅」中两步关闭续订。",
                            zhHant: "低門檻體驗全部 Pro 功能，隨時在 iOS「設定 → 訂閱」中兩步關閉續訂。"
                        ))
                        .font(.system(size: 11))
                        .foregroundStyle(LabTheme.muted)
                    }
                }
            }
        }
        .labCard(padding: 14)
    }

    private func timelineRow(icon: String, color: Color, step: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(color)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(step)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(LabTheme.ink)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(LabTheme.muted)
            }
        }
    }

    // MARK: - CTA & Compliance Footer

    private var ctaButton: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    let ok = await store.purchase(selectedPlan)
                    if ok { dismiss() }
                }
            } label: {
                HStack(spacing: 8) {
                    if store.isPurchasing {
                        ProgressView().tint(.white)
                    }
                    Text(ctaTitle)
                        .font(.system(size: 16, weight: .black))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(LabTheme.danger)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .disabled(store.isPurchasing)

            if let status = store.statusMessage {
                Text(status)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LabTheme.clean)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var ctaTitle: String {
        switch selectedPlan {
        case PureScanProductID.lifetime:
            return L10n.t(
                en: "Unlock Forever (\(store.displayPrice(for: PureScanProductID.lifetime)))",
                zhHans: "一次买断永久解锁（\(store.displayPrice(for: PureScanProductID.lifetime))）",
                zhHant: "一次買斷永久解鎖（\(store.displayPrice(for: PureScanProductID.lifetime))）"
            )
        case PureScanProductID.yearly:
            return L10n.t(
                en: "Start 3-Day Free Trial (\(store.displayPrice(for: PureScanProductID.yearly))/yr)",
                zhHans: "开启 3 天免费试用（随后 \(store.displayPrice(for: PureScanProductID.yearly))/年）",
                zhHant: "開啟 3 天免費試用（隨後 \(store.displayPrice(for: PureScanProductID.yearly))/年）"
            )
        default:
            return L10n.t(
                en: "Subscribe Monthly (\(store.displayPrice(for: PureScanProductID.monthly))/mo)",
                zhHans: "立即开通月卡（\(store.displayPrice(for: PureScanProductID.monthly))/月）",
                zhHant: "立即開通月卡（\(store.displayPrice(for: PureScanProductID.monthly))/月）"
            )
        }
    }

    private var nonHostileFreeExit: some View {
        Button {
            handleDismissAttempt()
        } label: {
            Text(L10n.t(
                en: "Not now, keep scanning free (\(store.remainingFreeScansToday) left today · zero ads) →",
                zhHans: "暂不升级，继续免费扫（今日还剩 \(store.remainingFreeScansToday) 次 · 永无广告）→",
                zhHant: "暫不升級，繼續免費掃（今日還剩 \(store.remainingFreeScansToday) 次 · 永無廣告）→"
            ))
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(LabTheme.muted)
            .padding(.vertical, 4)
        }
    }

    private var complianceFooter: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button(L10n.t(en: "Restore Purchases", zhHans: "恢复购买", zhHant: "恢復購買")) {
                    Task { await store.restorePurchases() }
                }
                Link(L10n.t(en: "Privacy Policy", zhHans: "隐私政策", zhHant: "隱私權政策"), destination: privacyURL)
                Link(L10n.t(en: "Terms (EULA)", zhHans: "使用条款", zhHant: "使用條款"), destination: termsURL)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(LabTheme.muted)

            Text(L10n.t(
                en: "Payment is charged to your Apple Account. Monthly (\(store.displayPrice(for: PureScanProductID.monthly))/mo) and Annual (\(store.displayPrice(for: PureScanProductID.yearly))/yr after 3-day free trial) subscriptions auto-renew unless canceled at least 24 hours before period end in iOS Settings > Apple Account > Subscriptions. Lifetime (\(store.displayPrice(for: PureScanProductID.lifetime))) is a one-time non-consumable purchase.",
                zhHans: "款项将通过您的 Apple 账户扣除。年度会员（含 3 天免费试用，随后 \(store.displayPrice(for: PureScanProductID.yearly))/年）与月度会员（\(store.displayPrice(for: PureScanProductID.monthly))/月）到期前 24 小时自动续费，您可随时在 iPhone「设置 → Apple 账户 → 订阅」中取消。永久买断（\(store.displayPrice(for: PureScanProductID.lifetime))）为一次性非消耗型内购，不自动续费。",
                zhHant: "款項將透過您的 Apple 帳號扣款。年度會員（含 3 天免費試用，隨後 \(store.displayPrice(for: PureScanProductID.yearly))/年）與月度會員（\(store.displayPrice(for: PureScanProductID.monthly))/月）將於到期前 24 小時自動續訂，您可隨時在 iPhone「設定 → Apple 帳號 → 訂閱」中取消。永久買斷（\(store.displayPrice(for: PureScanProductID.lifetime))）為一次性非消耗型內購，不會自動續訂。"
            ))
            .font(.system(size: 10))
            .foregroundStyle(LabTheme.muted.opacity(0.85))
            .multilineTextAlignment(.center)
        }
        .padding(.bottom, 10)
    }

    // MARK: - 1-Time Honest Abandon Offer (Uses Existing Approved Product IDs Only)

    private var abandonOfferSheet: some View {
        VStack(spacing: 16) {
            StampBadge(
                text: L10n.t(en: "ONE-TIME REMINDER", zhHans: "仅弹出这一次", zhHant: "僅彈出這一次"),
                color: LabTheme.clean,
                angle: -2
            )

            Text(L10n.t(
                en: "Prefer No Subscriptions?",
                zhHans: "不想办订阅？看眼这两种轻选择",
                zhHant: "不想辦訂閱？看看這兩種無壓力選擇"
            ))
            .font(.system(size: 21, weight: .black))
            .foregroundStyle(LabTheme.ink)
            .multilineTextAlignment(.center)

            Text(L10n.t(
                en: "Skip recurring bills with Lifetime Pay-Once (\(store.displayPrice(for: PureScanProductID.lifetime))) — or test full Pro for just \(store.displayPrice(for: PureScanProductID.monthly))/mo with zero lock-in.",
                zhHans: "一次买断终身版只需 \(store.displayPrice(for: PureScanProductID.lifetime)) 永不再扣费；或者先花 \(store.displayPrice(for: PureScanProductID.monthly)) 开一个月应急卡，逛完超市随时停。",
                zhHant: "一次買斷終身版只需 \(store.displayPrice(for: PureScanProductID.lifetime)) 永不再扣費；或先花 \(store.displayPrice(for: PureScanProductID.monthly)) 體驗一個月彈性方案，隨時可取消。"
            ))
            .font(.system(size: 13))
            .foregroundStyle(LabTheme.muted)
            .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Button {
                    FunnelMetrics.shared.record(.paywallAbandonOfferAccepted(productId: PureScanProductID.lifetime))
                    Task {
                        let ok = await store.purchase(PureScanProductID.lifetime)
                        if ok {
                            showAbandonOffer = false
                            dismiss()
                        }
                    }
                } label: {
                    Text(L10n.t(
                        en: "Own Lifetime Forever — \(store.displayPrice(for: PureScanProductID.lifetime)) Once",
                        zhHans: "一次买断用终身 — \(store.displayPrice(for: PureScanProductID.lifetime))",
                        zhHant: "一次買斷用終身 — \(store.displayPrice(for: PureScanProductID.lifetime))"
                    ))
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LabTheme.danger)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(store.isPurchasing)

                Button {
                    FunnelMetrics.shared.record(.paywallAbandonOfferAccepted(productId: PureScanProductID.monthly))
                    Task {
                        let ok = await store.purchase(PureScanProductID.monthly)
                        if ok {
                            showAbandonOffer = false
                            dismiss()
                        }
                    }
                } label: {
                    Text(L10n.t(
                        en: "Try 1 Month First — \(store.displayPrice(for: PureScanProductID.monthly))/mo",
                        zhHans: "先开 1 个月应急体验 — \(store.displayPrice(for: PureScanProductID.monthly))/月",
                        zhHant: "先開 1 個月彈性體驗 — \(store.displayPrice(for: PureScanProductID.monthly))/月"
                    ))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LabTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(LabTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(LabTheme.hairline, lineWidth: 1.2))
                }
                .disabled(store.isPurchasing)
            }

            Button {
                showAbandonOffer = false
                dismiss()
            } label: {
                Text(L10n.t(
                    en: "No thanks, continue using free version",
                    zhHans: "不用了，继续免费使用",
                    zhHant: "不用了，繼續免費使用"
                ))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(LabTheme.muted)
                .padding(.top, 2)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LabTheme.paper.ignoresSafeArea())
    }
}
