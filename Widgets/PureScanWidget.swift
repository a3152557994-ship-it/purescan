import SwiftUI
import WidgetKit

struct PureScanWidgetEntry: TimelineEntry {
    let date: Date
    let tipZH: String
    let tipEN: String
}

struct PureScanWidgetProvider: TimelineProvider {
    private static let tips: [(String, String)] = [
        ("面包见「脱氢乙酸钠」直接放下，新国标已禁！", "Skip breads with Sodium Dehydroacetate!"),
        ("痛风党避雷隐形嘌呤：酵母抽提物 & 呈味核苷酸二钠", "Gout alert: Watch for Yeast Extract & E635"),
        ("猫粮前 6 位塞 2 种以上谷物 = 典型谷物分割法", "2+ grains in top 6 pet ingredients = grain splitting"),
        ("0反式脂肪≠无氢化植物油，扫配料表才不被骗", "0g trans fat can still hide hydrogenated oils")
    ]

    func placeholder(in context: Context) -> PureScanWidgetEntry {
        PureScanWidgetEntry(date: Date(), tipZH: Self.tips[0].0, tipEN: Self.tips[0].1)
    }

    func getSnapshot(in context: Context, completion: @escaping (PureScanWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PureScanWidgetEntry>) -> Void) {
        let idx = Calendar.current.component(.hour, from: Date()) % Self.tips.count
        let entry = PureScanWidgetEntry(date: Date(), tipZH: Self.tips[idx].0, tipEN: Self.tips[idx].1)
        let next = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date().addingTimeInterval(14400)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct PureScanWidgetView: View {
    let entry: PureScanWidgetEntry
    @Environment(\.widgetFamily) var family

    private var isChinese: Bool {
        (Locale.preferredLanguages.first ?? "zh-Hans").lowercased().hasPrefix("zh")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "viewfinder.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 0.855, green: 0.145, blue: 0.145))
                Text(isChinese ? "配料照妖镜" : "PureScan")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color(red: 0.08, green: 0.08, blue: 0.08))
                Spacer()
            }

            Spacer(minLength: 2)

            Text(isChinese ? entry.tipZH : entry.tipEN)
                .font(.system(size: family == .systemSmall ? 11 : 13, weight: .bold))
                .foregroundStyle(Color(red: 0.18, green: 0.18, blue: 0.17))
                .lineLimit(3)

            Spacer(minLength: 2)

            HStack {
                Label(isChinese ? "秒扫配料" : "Scan Now", systemImage: "camera.viewfinder")
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
        .configurationDisplayName("配料照妖镜 · 一键秒扫")
        .description("逛超市桌面一点立刻扫配料，附每日添加剂避雷口诀。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
