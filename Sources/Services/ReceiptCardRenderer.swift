import SwiftUI
import UIKit

@MainActor
enum ReceiptCardRenderer {
    static func renderScanCard(record: ScanRecord, includeWatermark: Bool) -> UIImage? {
        let view = ReceiptPosterView(record: record, includeWatermark: includeWatermark)
            .frame(width: 420)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    static func renderPKCard(left: ScanRecord, right: ScanRecord, includeWatermark: Bool) -> UIImage? {
        let view = PKPosterView(left: left, right: right, includeWatermark: includeWatermark)
            .frame(width: 420)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}

/// Editorial supermarket inspection receipt card designed as social currency for Xiaohongshu / WeChat / TikTok.
struct ReceiptPosterView: View {
    let record: ScanRecord
    let includeWatermark: Bool

    private var accentColor: Color {
        switch record.grade {
        case .clean: return Color(red: 0.08, green: 0.55, blue: 0.34)
        case .mild: return Color(red: 0.85, green: 0.52, blue: 0.06)
        case .warning, .danger: return Color(red: 0.86, green: 0.16, blue: 0.16)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("配料照妖镜 · 成分质检小票", "PURESCAN · LABEL INSPECTION"))
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color(red: 0.42, green: 0.40, blue: 0.37))
                    Text(record.productName)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(Color(red: 0.09, green: 0.09, blue: 0.08))
                        .lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(record.score)")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(accentColor)
                    Text("/ 100")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            // Stamp banner
            HStack {
                Text(record.grade.stampTitle)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(accentColor, lineWidth: 2)
                    )
                Spacer()
                Text(record.domain.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text(record.displayHeadline)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.16, green: 0.15, blue: 0.14))

            // Top flagged hits
            let topHits = Array(record.hits.filter { $0.risk != .safe }.prefix(5))
            if !topHits.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("揪出的重点成分", "FLAGGED INGREDIENTS"))
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    ForEach(topHits) { hit in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(hit.risk == .danger ? Color(red: 0.86, green: 0.16, blue: 0.16) : Color(red: 0.85, green: 0.52, blue: 0.06))
                                .frame(width: 8, height: 8)
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(hit.displayName)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color(red: 0.09, green: 0.09, blue: 0.08))
                                    Spacer()
                                    Text(hit.displayCategory)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(hit.risk == .danger ? Color(red: 0.86, green: 0.16, blue: 0.16) : Color(red: 0.85, green: 0.52, blue: 0.06))
                                }
                                Text(hit.displayReason)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(red: 0.35, green: 0.34, blue: 0.32))
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color(red: 0.08, green: 0.55, blue: 0.34))
                    Text(L10n.t("未检出高危添加剂、反式脂肪或忌口雷区", "Zero high-risk additives or personal red flags detected"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.08, green: 0.55, blue: 0.34))
                }
            }

            Divider()

            HStack {
                Text(includeWatermark
                     ? L10n.t("App Store 搜「配料照妖镜」· 0广告离线秒扫", "Get PureScan on App Store · Offline Label OCR")
                     : L10n.t("配料照妖镜 Pro · 离线质检卡", "PureScan Pro · Clean Label Report"))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(L10n.t("科普参考", "Info Only"))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .background(Color(red: 0.98, green: 0.97, blue: 0.94))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
        .padding(14)
        .background(Color(red: 0.11, green: 0.11, blue: 0.10))
    }
}

struct PKPosterView: View {
    let left: ScanRecord
    let right: ScanRecord
    let includeWatermark: Bool

    private var winner: Int {
        IngredientAnalyzer.compareWinner(left: left, right: right)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.t("配料照妖镜 · 超市双品 VS 大决战", "PURESCAN · INGREDIENT SHOWDOWN"))
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color(red: 0.42, green: 0.40, blue: 0.37))

            HStack(spacing: 12) {
                pkColumn(record: left, isWinner: winner == -1)
                pkColumn(record: right, isWinner: winner == 1)
            }

            Divider()

            HStack {
                Text(includeWatermark
                     ? L10n.t("App Store 搜「配料照妖镜」· 一秒比出更干净", "PureScan on App Store · Compare Labels in 1s")
                     : L10n.t("PureScan Pro · VS Report", "PureScan Pro · VS Report"))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(20)
        .background(Color(red: 0.98, green: 0.97, blue: 0.94))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(14)
        .background(Color(red: 0.11, green: 0.11, blue: 0.10))
    }

    private func pkColumn(record: ScanRecord, isWinner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if isWinner {
                Text(L10n.t("🏆 更干净胜出", "🏆 CLEANER WIN"))
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.08, green: 0.55, blue: 0.34))
                    .clipShape(Capsule())
            } else {
                Text(L10n.t("⚠️ 落败避雷", "⚠️ MORE ADDITIVES"))
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.86, green: 0.16, blue: 0.16))
                    .clipShape(Capsule())
            }
            Text(record.productName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(red: 0.09, green: 0.09, blue: 0.08))
                .lineLimit(2)
            Text("\(record.score)")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(isWinner ? Color(red: 0.08, green: 0.55, blue: 0.34) : Color(red: 0.86, green: 0.16, blue: 0.16))
            Text(L10n.t("红灯 \(record.dangerCount) 项 · 配料 \(record.normalizedTokens.count) 项", "\(record.dangerCount) red · \(record.normalizedTokens.count) items"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isWinner ? Color(red: 0.08, green: 0.55, blue: 0.34) : Color.black.opacity(0.08), lineWidth: isWinner ? 2 : 1)
        )
    }
}
