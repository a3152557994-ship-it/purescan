import SwiftUI
import UIKit

struct ComparePKView: View {
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var store: StoreManager

    var onRequirePro: (ScanRecord?) -> Void

    @State private var pickingSlot: Int? = nil // 0 = left, 1 = right
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false

    private var winner: Int {
        guard let l = history.pkLeft, let r = history.pkRight else { return 0 }
        return IngredientAnalyzer.compareWinner(left: l, right: r)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    bannerHeader

                    if let left = history.pkLeft, let right = history.pkRight {
                        HStack(spacing: 12) {
                            slotCard(record: left, slot: 0, isWinner: winner == -1)
                            slotCard(record: right, slot: 1, isWinner: winner == 1)
                        }

                        deltaBreakdownCard(left: left, right: right)

                        Button {
                            if !store.isPro {
                                onRequirePro(left)
                            } else if let img = ReceiptCardRenderer.renderPKCard(left: left, right: right, includeWatermark: false) {
                                shareImage = img
                                showShareSheet = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up.fill")
                                Text(L10n.t("生成高清「双品 PK 避雷图」晒朋友圈 / 小红书", "Export HD VS Comparison Card"))
                                    .font(.system(size: 14, weight: .black))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LabTheme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    quickPresetShowdowns
                }
                .padding(16)
            }
            .background(LabTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("超市双品 VS 大决战", "Ingredient VS PK"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: Binding(
                get: { pickingSlot != nil },
                set: { if !$0 { pickingSlot = nil } }
            )) {
                itemPickerSheet
            }
            .sheet(isPresented: $showShareSheet) {
                if let shareImage {
                    ActivityShareSheet(items: [shareImage])
                }
            }
        }
    }

    private var bannerHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.horizontal.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(LabTheme.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("纠结买哪包？左扫一包、右扫一包", "Torn between two shelves? Compare them"))
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(LabTheme.ink)
                Text(L10n.t("谁科技更少、谁对你的忌口更友好，1 秒盖章决胜负", "Instant verdict on cleaner label, fewer red flags & radar fit"))
                    .font(.system(size: 12))
                    .foregroundStyle(LabTheme.muted)
            }
            Spacer()
        }
        .labCard(padding: 14)
    }

    private func slotCard(record: ScanRecord, slot: Int, isWinner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(isWinner ? L10n.t("🏆 更干净胜出", "🏆 CLEANER WIN") : L10n.t("⚠️ 避雷落败", "⚠️ HIGHER RISK"))
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isWinner ? LabTheme.clean : LabTheme.danger)
                    .clipShape(Capsule())
                Spacer()
                Button {
                    pickingSlot = slot
                } label: {
                    Text(L10n.t("换一款", "Swap"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LabTheme.muted)
                }
            }

            Text(record.productName)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(LabTheme.ink)
                .lineLimit(2)
                .frame(height: 40, alignment: .topLeading)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(record.score)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(isWinner ? LabTheme.clean : LabTheme.danger)
                Text("/100")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(LabTheme.muted)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("红灯雷区：\(record.dangerCount) 项", "Red Flags: \(record.dangerCount)"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(record.dangerCount == 0 ? LabTheme.clean : LabTheme.danger)
                Text(L10n.t("轻度留意：\(record.cautionCount) 项", "Cautions: \(record.cautionCount)"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LabTheme.muted)
                Text(L10n.t("配料总数：\(record.normalizedTokens.count) 项", "Total Items: \(record.normalizedTokens.count)"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LabTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(LabTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isWinner ? LabTheme.clean : LabTheme.hairline, lineWidth: isWinner ? 2.5 : 1)
        )
    }

    private func deltaBreakdownCard(left: ScanRecord, right: ScanRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("逐项胜负拆解", "HEAD-TO-HEAD METRICS"))
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(LabTheme.muted)

            metricRow(
                title: L10n.t("干净评分", "Clean Score"),
                leftVal: "\(left.score)",
                rightVal: "\(right.score)",
                leftBetter: left.score >= right.score
            )
            Divider()
            metricRow(
                title: L10n.t("高危红灯数（越少越好）", "Red Flags (lower wins)"),
                leftVal: "\(left.dangerCount)",
                rightVal: "\(right.dangerCount)",
                leftBetter: left.dangerCount <= right.dangerCount
            )
            Divider()
            metricRow(
                title: L10n.t("配料表精简度（越短越干净）", "Label Length (shorter wins)"),
                leftVal: L10n.t("\(left.normalizedTokens.count) 项", "\(left.normalizedTokens.count)"),
                rightVal: L10n.t("\(right.normalizedTokens.count) 项", "\(right.normalizedTokens.count)"),
                leftBetter: left.normalizedTokens.count <= right.normalizedTokens.count
            )
        }
        .labCard()
    }

    private func metricRow(title: String, leftVal: String, rightVal: String, leftBetter: Bool) -> some View {
        HStack {
            Text(leftVal)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(leftBetter ? LabTheme.clean : LabTheme.danger)
                .frame(width: 66, alignment: .leading)
            Spacer()
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(LabTheme.muted)
            Spacer()
            Text(rightVal)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(!leftBetter ? LabTheme.clean : LabTheme.danger)
                .frame(width: 66, alignment: .trailing)
        }
    }

    private var quickPresetShowdowns: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("一键体验热门对照局", "ONE-TAP POPULAR SHOWDOWNS"))
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(LabTheme.muted)

            presetButton(
                title: L10n.t("🍞 网红手撕吐司  VS  🥛 极简低温酸奶", "🍞 Store Toast  VS  🥛 Plain Greek Yogurt"),
                leftId: "toast_bread",
                rightId: "clean_yogurt",
                radars: [.cleanFood, .sugarDiet, .momBaby]
            )
            presetButton(
                title: L10n.t("🐱 谷物分割猫粮  VS  🍗 鲜肉烘焙猫粮", "🐱 Budget Cat Kibble  VS  🍗 Baked Fresh Meat"),
                leftId: "trap_cat_food",
                rightId: "clean_cat_food",
                radars: [.petSafety]
            )
            presetButton(
                title: L10n.t("🧴 致痘抗老面霜  VS  🌿 敏肌修护乳", "🧴 Viral Glow Cream  VS  🌿 Barrier Lotion"),
                leftId: "acne_cream",
                rightId: "gentle_lotion",
                radars: [.acneSkincare, .momBaby]
            )
        }
    }

    private func presetButton(title: String, leftId: String, rightId: String, radars: Set<RadarType>) -> some View {
        Button {
            if let l = SampleCatalog.all.first(where: { $0.id == leftId }),
               let r = SampleCatalog.all.first(where: { $0.id == rightId }) {
                history.pkLeft = IngredientAnalyzer.analyze(rawText: l.rawText, productName: l.displayName, preferredDomain: l.domain, activeRadars: radars)
                history.pkRight = IngredientAnalyzer.analyze(rawText: r.rawText, productName: r.displayName, preferredDomain: r.domain, activeRadars: radars)
            }
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LabTheme.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LabTheme.muted)
            }
            .padding(14)
            .background(LabTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LabTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var itemPickerSheet: some View {
        NavigationStack {
            List {
                if !history.records.isEmpty {
                    Section(L10n.t("我的扫描记录", "My Scanned Items")) {
                        ForEach(history.records) { rec in
                            Button {
                                if pickingSlot == 0 { history.pkLeft = rec } else { history.pkRight = rec }
                                pickingSlot = nil
                            } label: {
                                HStack {
                                    Text(rec.productName).foregroundStyle(LabTheme.ink).fontWeight(.semibold)
                                    Spacer()
                                    Text("\(rec.score)").fontWeight(.black).foregroundStyle(LabTheme.color(for: rec.grade))
                                }
                            }
                        }
                    }
                }
                Section(L10n.t("内置爆款样本", "Built-in Samples")) {
                    ForEach(SampleCatalog.all) { sample in
                        Button {
                            let rec = IngredientAnalyzer.analyze(
                                rawText: sample.rawText,
                                productName: sample.displayName,
                                preferredDomain: sample.domain,
                                activeRadars: history.activeRadars
                            )
                            if pickingSlot == 0 { history.pkLeft = rec } else { history.pkRight = rec }
                            pickingSlot = nil
                        } label: {
                            HStack {
                                Text(sample.displayName).foregroundStyle(LabTheme.ink)
                                Spacer()
                                Text(sample.displayBadge).font(.caption).foregroundStyle(LabTheme.muted)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.t("选择要对比的商品", "Pick Item for PK"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("取消", "Cancel")) { pickingSlot = nil }
                }
            }
        }
    }
}
