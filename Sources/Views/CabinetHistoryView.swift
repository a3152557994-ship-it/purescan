import SwiftUI

struct CabinetHistoryView: View {
    @EnvironmentObject var history: HistoryStore
    @State private var selectedFilter: CabinetFilter = .all
    @State private var searchText = ""

    var onSelectRecord: (ScanRecord) -> Void

    enum CabinetFilter: String, CaseIterable, Identifiable {
        case all
        case green
        case red

        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return L10n.t("全部扫描", "All")
            case .green: return L10n.t("🟢 安心回购", "🟢 Buy Again")
            case .red: return L10n.t("🔴 永久拉黑", "🔴 Blacklist")
            }
        }
    }

    private var filteredRecords: [ScanRecord] {
        history.records.filter { rec in
            let matchesBucket: Bool
            switch selectedFilter {
            case .all: matchesBucket = true
            case .green: matchesBucket = rec.cabinet == .greenList
            case .red: matchesBucket = rec.cabinet == .redList
            }
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesQuery = q.isEmpty || rec.productName.lowercased().contains(q) || rec.rawText.lowercased().contains(q)
            return matchesBucket && matchesQuery
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                summaryStrip
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                Picker("", selection: $selectedFilter) {
                    ForEach(CabinetFilter.allCases) { f in
                        Text(f.title).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                if filteredRecords.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredRecords) { rec in
                            Button {
                                onSelectRecord(rec)
                            } label: {
                                recordRow(rec)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    history.deleteRecord(id: rec.id)
                                } label: {
                                    Label(L10n.t("删除", "Delete"), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(LabTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("我的红黑囤货柜", "My Red & Green Cabinet"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: L10n.t("搜商品名或具体添加剂...", "Search product or ingredient..."))
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: 10) {
            statBox(value: "\(history.records.count)", label: L10n.t("累计扫雷", "Scanned"), color: LabTheme.ink)
            statBox(value: "\(history.greenListCount)", label: L10n.t("安心回购", "Buy Again"), color: LabTheme.clean)
            statBox(value: "\(history.redListCount)", label: L10n.t("永久拉黑", "Blacklist"), color: LabTheme.danger)
        }
    }

    private func statBox(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LabTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(LabTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LabTheme.hairline, lineWidth: 1))
    }

    private func recordRow(_ rec: ScanRecord) -> some View {
        HStack(spacing: 12) {
            VStack {
                Text("\(rec.score)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(LabTheme.color(for: rec.grade))
                Text(rec.grade.shortStamp)
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(LabTheme.color(for: rec.grade))
            }
            .frame(width: 66)
            .padding(.vertical, 8)
            .background(LabTheme.softColor(for: rec.grade))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(rec.productName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(LabTheme.ink)
                        .lineLimit(1)
                    if rec.cabinet == .greenList {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(LabTheme.clean)
                    } else if rec.cabinet == .redList {
                        Image(systemName: "xmark.octagon.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(LabTheme.danger)
                    }
                }
                Text(rec.displayHeadline)
                    .font(.system(size: 12))
                    .foregroundStyle(LabTheme.muted)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(LabTheme.muted)
        }
        .labCard(padding: 12)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray.full")
                .font(.system(size: 42))
                .foregroundStyle(LabTheme.muted.opacity(0.6))
            Text(L10n.t("囤货柜还是空的", "Your cabinet is empty"))
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(LabTheme.ink)
            Text(L10n.t("去“照妖镜”拍一包零食、护肤品或猫粮，把好的放进回购榜，把踩雷的永久拉黑！", "Scan snacks, skincare, or pet food to build your personal Buy-Again and Never-Buy lists."))
                .font(.system(size: 13))
                .foregroundStyle(LabTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Spacer()
        }
    }
}
