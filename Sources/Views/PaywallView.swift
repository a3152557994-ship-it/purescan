import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    let previewRecord: ScanRecord?
    @State private var selectedPlan: String = PureScanProductID.lifetime

    private let privacyURL = URL(string: "https://a3152557994-ship-it.github.io/purescan/privacy.html")!
    private let termsURL = URL(string: "https://a3152557994-ship-it.github.io/purescan/terms.html")!

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if let rec = previewRecord {
                        sunkCostPreviewBanner(rec)
                    } else {
                        defaultHeroBanner
                    }

                    benefitsListCard
                    planPickerStack
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
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(LabTheme.muted.opacity(0.6))
                    }
                }
            }
        }
    }

    private func sunkCostPreviewBanner(_ rec: ScanRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.t("刚刚扫出的实测样本 · 升级解锁完整雷达", "YOUR SCAN IS READY · UNLOCK FULL PROTECTION"))
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

    private var defaultHeroBanner: some View {
        VStack(spacing: 8) {
            StampBadge(text: L10n.t("永久 0 广告 · 0 摇一摇跳屏", "ZERO ADS FOREVER"), color: LabTheme.danger, angle: -2)
            Text(L10n.t("升级配料照妖镜 Pro", "Upgrade to PureScan Pro"))
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(LabTheme.ink)
            Text(L10n.t("不到一顿外卖，全家控糖、痛风、宝妈、护肤、猫狗粮全解锁", "One coffee to protect food, skincare & pet shopping forever"))
                .font(.system(size: 13))
                .foregroundStyle(LabTheme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }

    private var benefitsListCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            benefitRow(icon: "dial.high.fill", title: L10n.t("全 6 大忌口雷达同时叠开", "Stack All 6 Personal Radars"), detail: L10n.t("控糖减脂 + 痛风高尿酸 + 宝妈孕期 + 敏肌护肤 + 猫狗粮避毒", "Low Sugar, Gout, Mom & Kids, Skincare INCI & Pet Food"))
            benefitRow(icon: "bolt.horizontal.fill", title: L10n.t("超市「双品 VS 成分大决战」", "Supermarket VS PK Comparison"), detail: L10n.t("两包酸奶/吐司/猫粮同屏比出更干净款，一键出高清避雷长图", "Compare two labels side-by-side & export clean HD cards"))
            benefitRow(icon: "infinity", title: L10n.t("无限次离线拍照 + 无限红黑囤货柜", "Unlimited Offline Scans & Cabinet"), detail: L10n.t("地下超市没信号 0.3 秒直出，永不弹任何广告", "0.3s on-device OCR anywhere, zero ads forever"))
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

    private var planPickerStack: some View {
        VStack(spacing: 10) {
            // Lifetime (Default Highlighted Anchor)
            planCard(
                productId: PureScanProductID.lifetime,
                title: L10n.t("永久买断 Pro（一次付清）", "Lifetime Pro (Pay Once)"),
                subtitle: L10n.t("买断终身用 · 不再扣费 · 包后续全部新增成分库", "Own forever · Zero recurring bills · All future updates"),
                price: store.displayPrice(for: PureScanProductID.lifetime),
                strikePrice: L10n.t("原价 ¥98", "$39.99"),
                badge: L10n.t("🔥 87% 人选 · 最划算", "🔥 BEST VALUE")
            )

            // Yearly w/ 3-day free trial + Day-2 Reminder Promise
            planCard(
                productId: PureScanProductID.yearly,
                title: L10n.t("年度会员（3 天免费试用）", "Annual Pro (3-Day Free Trial)"),
                subtitle: L10n.t("🔔 第 2 天主动推送到期提醒，绝不悄悄扣年费", "🔔 Built-in Day-2 reminder before renewal — no surprise bills"),
                price: "\(store.displayPrice(for: PureScanProductID.yearly))\(L10n.t("/年", "/yr"))",
                strikePrice: nil,
                badge: L10n.t("免费试 3 天", "3-DAY TRIAL")
            )

            // Monthly impulse tier
            planCard(
                productId: PureScanProductID.monthly,
                title: L10n.t("月度应急卡", "Monthly Pro"),
                subtitle: L10n.t("逛山姆/大促囤货随开随停，按月续订可随时取消", "Flexible monthly access, cancel anytime in Settings"),
                price: "\(store.displayPrice(for: PureScanProductID.monthly))\(L10n.t("/月", "/mo"))",
                strikePrice: nil,
                badge: nil
            )
        }
    }

    private func planCard(productId: String, title: String, subtitle: String, price: String, strikePrice: String?, badge: String?) -> some View {
        let isSelected = selectedPlan == productId
        return Button {
            selectedPlan = productId
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
            }
        }
    }

    private var ctaTitle: String {
        switch selectedPlan {
        case PureScanProductID.lifetime:
            return L10n.t("一次买断永久解锁（\(store.displayPrice(for: PureScanProductID.lifetime))）", "Unlock Forever (\(store.displayPrice(for: PureScanProductID.lifetime)))")
        case PureScanProductID.yearly:
            return L10n.t("开启 3 天免费试用（随后 \(store.displayPrice(for: PureScanProductID.yearly))/年）", "Start 3-Day Free Trial (\(store.displayPrice(for: PureScanProductID.yearly))/yr)")
        default:
            return L10n.t("立即开通月卡（\(store.displayPrice(for: PureScanProductID.monthly))/月）", "Subscribe Monthly (\(store.displayPrice(for: PureScanProductID.monthly))/mo)")
        }
    }

    private var nonHostileFreeExit: some View {
        Button {
            dismiss()
        } label: {
            Text(L10n.t(
                "暂不升级，继续免费扫（今日还剩 \(store.remainingFreeScansToday) 次 · 永无广告）→",
                "Not now, keep scanning free (\(store.remainingFreeScansToday) left today · zero ads) →"
            ))
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(LabTheme.muted)
            .padding(.vertical, 4)
        }
    }

    private var complianceFooter: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button(L10n.t("恢复购买", "Restore Purchases")) {
                    Task { await store.restorePurchases() }
                }
                Link(L10n.t("隐私政策", "Privacy Policy"), destination: privacyURL)
                Link(L10n.t("使用条款", "Terms (EULA)"), destination: termsURL)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(LabTheme.muted)

            Text(L10n.t(
                "订阅将通过您的 Apple ID 账户扣款。年度会员（含 3 天免费试用）与月度会员到期前 24 小时自动续费，您可随时在 iPhone「设置 → Apple ID → 订阅」中取消。永久买断为一次性非消耗型内购，不自动续费。",
                "Payment is charged to your Apple ID account. Monthly and Annual subscriptions (3-day free trial on Annual) auto-renew unless canceled at least 24 hours before period end in iOS Settings > Subscriptions. Lifetime is a one-time non-consumable purchase."
            ))
            .font(.system(size: 10))
            .foregroundStyle(LabTheme.muted.opacity(0.85))
            .multilineTextAlignment(.center)
        }
        .padding(.bottom, 10)
    }
}
