import SwiftUI
import UIKit

struct ScanResultSheet: View {
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State var record: ScanRecord
    var onSendToPK: (ScanRecord) -> Void
    var onRequirePro: (ScanRecord) -> Void

    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @State private var editingName = false
    @State private var draftName = ""

    private var gradeColor: Color { LabTheme.color(for: record.grade) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    verdictHeroCard
                    cabinetActionBar
                    if !record.structuralAlerts.isEmpty {
                        structuralAlertsCard
                    }
                    flaggedIngredientsSection
                    highlightedRawTokensCard
                    disclaimerFoot
                }
                .padding(16)
            }
            .background(LabTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("照妖镜体检报告", "Inspection Report"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.t("关闭", "Done")) { dismiss() }
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exportPosterCard()
                    } label: {
                        Label(L10n.t("晒避雷小票", "Share Card"), systemImage: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(LabTheme.danger)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let shareImage {
                    ActivityShareSheet(items: [shareImage])
                }
            }
            .alert(L10n.t("修改商品名称", "Rename Item"), isPresented: $editingName) {
                TextField(L10n.t("输入商品名", "Product name"), text: $draftName)
                Button(L10n.t("保存", "Save")) {
                    let clean = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty {
                        record.productName = clean
                        history.renameRecord(id: record.id, newName: clean)
                    }
                }
                Button(L10n.t("取消", "Cancel"), role: .cancel) {}
            }
        }
    }

    private var verdictHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Label(record.domain.title, systemImage: record.domain.icon)
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(LabTheme.muted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(LabTheme.paper)
                            .clipShape(Capsule())

                        Button {
                            draftName = record.productName
                            editingName = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(LabTheme.muted)
                        }
                    }

                    Text(record.productName)
                        .font(.system(size: 21, weight: .black))
                        .foregroundStyle(LabTheme.ink)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(record.score)")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(gradeColor)
                    Text(L10n.t("干净分 / 100", "CLEAN / 100"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(LabTheme.muted)
                }
            }

            HStack {
                StampBadge(text: record.grade.stampTitle, color: gradeColor, angle: -2)
                Spacer()
            }

            Text(record.displayHeadline)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LabTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                metricPill(count: record.dangerCount, title: L10n.t("红灯雷区", "Red Flags"), color: LabTheme.danger, bg: LabTheme.dangerSoft)
                metricPill(count: record.cautionCount, title: L10n.t("轻度留意", "Cautions"), color: LabTheme.caution, bg: LabTheme.cautionSoft)
                metricPill(count: record.normalizedTokens.count, title: L10n.t("总配料数", "Ingredients"), color: LabTheme.ink, bg: LabTheme.paper)
            }
        }
        .labCard(padding: 18)
    }

    private func metricPill(count: Int, title: String, color: Color, bg: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LabTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var cabinetActionBar: some View {
        HStack(spacing: 8) {
            Button {
                let next: CabinetBucket = record.cabinet == .greenList ? .none : .greenList
                record.cabinet = next
                history.updateCabinet(for: record.id, bucket: next)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: record.cabinet == .greenList ? "checkmark.circle.fill" : "checkmark.circle")
                    Text(L10n.t("安心回购", "Buy Again"))
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(record.cabinet == .greenList ? .white : LabTheme.clean)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(record.cabinet == .greenList ? LabTheme.clean : LabTheme.cleanSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                let next: CabinetBucket = record.cabinet == .redList ? .none : .redList
                record.cabinet = next
                history.updateCabinet(for: record.id, bucket: next)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: record.cabinet == .redList ? "xmark.octagon.fill" : "xmark.octagon")
                    Text(L10n.t("永久拉黑", "Blacklist"))
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(record.cabinet == .redList ? .white : LabTheme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(record.cabinet == .redList ? LabTheme.danger : LabTheme.dangerSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                if !store.isPro {
                    onRequirePro(record)
                } else {
                    history.assignToPK(record)
                    dismiss()
                    onSendToPK(record)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.horizontal.fill")
                    Text(L10n.t("拿去 PK", "VS PK"))
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(LabTheme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var structuralAlertsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("⚡ 配料结构陷阱警报", "⚡ STRUCTURAL TRAP ALERTS"))
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(LabTheme.danger)

            ForEach(record.structuralAlerts) { alert in
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.displayTitle)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(LabTheme.color(for: alert.risk))
                    Text(alert.displayDetail)
                        .font(.system(size: 13))
                        .foregroundStyle(LabTheme.ink)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LabTheme.softColor(for: alert.risk))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .labCard()
    }

    private var flaggedIngredientsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("成分逐项拆解（按风险排序）", "INGREDIENT BREAKDOWN"))
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(LabTheme.muted)

            if record.hits.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(LabTheme.clean)
                    Text(L10n.t("未检出任何高危防腐剂、人工色素、反式脂肪或个人忌口雷区！", "No high-risk additives, trans fats, or personal red flags found!"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LabTheme.clean)
                }
                .labCard()
            } else {
                ForEach(record.hits) { hit in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center) {
                            Text(hit.risk.label)
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(LabTheme.color(for: hit.risk))
                                .clipShape(Capsule())

                            Text(hit.displayName)
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(LabTheme.ink)

                            Spacer()

                            Text(L10n.t("第 \(hit.positionIndex) 位", "#\(hit.positionIndex)"))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(LabTheme.muted)
                        }

                        HStack(spacing: 6) {
                            Text(hit.displayCategory)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(LabTheme.color(for: hit.risk))
                            Text("·")
                                .foregroundStyle(LabTheme.muted)
                            Text(hit.standardRef)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(LabTheme.muted)
                        }

                        Text(hit.displayReason)
                            .font(.system(size: 13))
                            .foregroundStyle(LabTheme.ink.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .labCard(padding: 14)
                }
            }
        }
    }

    private var highlightedRawTokensCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("原文荧光高亮对照", "ORIGINAL LABEL HIGHLIGHT"))
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(LabTheme.muted)

            FlowTagLayout(spacing: 6) {
                ForEach(Array(record.normalizedTokens.enumerated()), id: \.offset) { _, token in
                    let matchedHit = record.hits.first { $0.matchedToken == token }
                    let risk = matchedHit?.risk
                    Text(token)
                        .font(.system(size: 12, weight: risk == .danger ? .black : .semibold))
                        .foregroundStyle(risk == .danger ? .white : (risk == .caution ? LabTheme.caution : (risk == .safe ? LabTheme.clean : LabTheme.ink)))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            risk == .danger ? LabTheme.danger :
                            risk == .caution ? LabTheme.cautionSoft :
                            risk == .safe ? LabTheme.cleanSoft : LabTheme.paper
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .labCard()
    }

    private var disclaimerFoot: some View {
        Text(L10n.t(
            "说明：评分依据配料排序与公开标准（GB 2760 / FDA / EFSA / INCI / AAFCO）综合计算，仅作日常消费科普参考，不替代医生或兽医专业意见。",
            "Note: Scores reflect ingredient order and public GB 2760 / FDA / EFSA / INCI / AAFCO references for educational guidance only, not medical advice."
        ))
        .font(.system(size: 11))
        .foregroundStyle(LabTheme.muted)
        .padding(.bottom, 12)
    }

    private func exportPosterCard() {
        if let img = ReceiptCardRenderer.renderScanCard(record: record, includeWatermark: !store.isPro) {
            shareImage = img
            showShareSheet = true
        }
    }
}

/// Simple wrapping tag flow layout (iOS 16+ Layout protocol) for highlighted ingredients.
struct FlowTagLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 340
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
