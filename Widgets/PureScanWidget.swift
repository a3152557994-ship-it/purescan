import SwiftUI
import WidgetKit

struct PureScanWidgetEntry: TimelineEntry {
    let date: Date
    let tipZH: String
    let tipHant: String
    let tipEN: String
}

struct PureScanWidgetProvider: TimelineProvider {
    private static let tips: [(zh: String, hant: String, en: String)] = [
        ("面包见「脱氢乙酸钠」直接放下，新国标已禁！", "麵包見「脫氫乙酸鈉」直接放下，高風險防腐劑避雷！", "Skip breads with Sodium Dehydroacetate!"),
        ("痛风党避雷隐形嘌呤：酵母抽提物 & 呈味核苷酸二钠", "痛風族避雷隱形嘌呤：酵母抽提物 & 呈味核苷酸二鈉", "Gout alert: Watch for Yeast Extract & E635"),
        ("猫粮前 6 位塞 2 种以上谷物 = 典型谷物分割法", "貓糧前 6 位塞 2 種以上穀物 = 典型穀物分割法", "2+ grains in top 6 pet ingredients = grain splitting"),
        ("0反式脂肪≠无氢化植物油，扫配料表才不被骗", "0反式脂肪≠無氫化植物油，掃成分表才不被騙", "0g trans fat can still hide hydrogenated oils")
    ]

    func placeholder(in context: Context) -> PureScanWidgetEntry {
        let t = Self.tips[0]
        return PureScanWidgetEntry(date: Date(), tipZH: t.zh, tipHant: t.hant, tipEN: t.en)
    }

    func getSnapshot(in context: Context, completion: @escaping (PureScanWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PureScanWidgetEntry>) -> Void) {
        let idx = Calendar.current.component(.hour, from: Date()) % Self.tips.count
        let t = Self.tips[idx]
        let entry = PureScanWidgetEntry(date: Date(), tipZH: t.zh, tipHant: t.hant, tipEN: t.en)
        let next = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date().addingTimeInterval(14400)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct PureScanWidgetView: View {
    let entry: PureScanWidgetEntry
    @Environment(\.widgetFamily) var family

    private var preferredLang: String {
        (Locale.preferredLanguages.first ?? "zh-Hans").lowercased()
    }

    private var isTraditionalChinese: Bool {
        preferredLang.contains("hant")
            || preferredLang.hasPrefix("zh-tw")
            || preferredLang.hasPrefix("zh_tw")
            || preferredLang.hasPrefix("zh-hk")
            || preferredLang.hasPrefix("zh_hk")
            || preferredLang.hasPrefix("zh-mo")
            || preferredLang.hasPrefix("zh_mo")
    }

    private var isSimplifiedChinese: Bool {
        preferredLang.hasPrefix("zh") && !isTraditionalChinese
    }

    private func pick(_ zh: String, _ hant: String, _ en: String) -> String {
        if isTraditionalChinese { return hant }
        if isSimplifiedChinese { return zh }
        return en
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "viewfinder.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 0.855, green: 0.145, blue: 0.145))
                Text(pick("配料照妖镜", "配料照妖鏡", "PureScan"))
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color(red: 0.08, green: 0.08, blue: 0.08))
                Spacer()
            }

            Spacer(minLength: 2)

            Text(pick(entry.tipZH, entry.tipHant, entry.tipEN))
                .font(.system(size: family == .systemSmall ? 11 : 13, weight: .bold))
                .foregroundStyle(Color(red: 0.18, green: 0.18, blue: 0.17))
                .lineLimit(3)

            Spacer(minLength: 2)

            HStack {
                Label(pick("秒扫配料", "秒掃成分", "Scan Now"), systemImage: "camera.viewfinder")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.855, green: 0.145, blue: 0.145))
                    .clipShape(Capsule())
                Spacer()
            }
        }
        .padding(12)
        .widgetURL(URL(string: "purescan://scan"))
        .containerBackground(Color(red: 0.969, green: 0.961, blue: 0.937), for: .widget)
    }
}

@main
struct PureScanWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PureScanQuickWidget()
    }
}

struct PureScanQuickWidget: Widget {
    let kind: String = "PureScanQuickWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PureScanWidgetProvider()) { entry in
            PureScanWidgetView(entry: entry)
        }
        .configurationDisplayName("PureScan · 配料照妖鏡")
        .description("1-tap offline ingredient scanner & daily additive tips.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
