import Foundation
import SwiftUI

@MainActor
final class HistoryStore: ObservableObject {
    @Published var records: [ScanRecord] = []
    @Published var activeRadars: Set<RadarType> = [.cleanFood, .sugarDiet]
    @Published var customBlacklist: [String] = []
    @Published var pkLeft: ScanRecord?
    @Published var pkRight: ScanRecord?
    @Published var languageVersion: Int = 0

    private let recordsURL: URL
    private let radarsKey = "purescan.active.radars"
    private let blacklistKey = "purescan.custom.blacklist"

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        recordsURL = docs.appendingPathComponent("purescan_history_v1.json")
        loadPersistedState()
        seedInitialDemoIfEmpty()
    }

    func setLanguage(_ lang: AppLanguage) {
        L10n.currentLanguage = lang
        languageVersion += 1
    }

    /// Free users always have `.cleanFood` + up to 1 extra radar. Pro users unlock all 6 simultaneously.
    func toggleRadar(_ radar: RadarType, isPro: Bool) -> Bool {
        if radar == .cleanFood {
            // Base radar stays active unless another radar is on
            if activeRadars.contains(.cleanFood) && activeRadars.count > 1 {
                activeRadars.remove(.cleanFood)
            } else {
                activeRadars.insert(.cleanFood)
            }
            savePreferences()
            return true
        }

        if activeRadars.contains(radar) {
            activeRadars.remove(radar)
            if activeRadars.isEmpty { activeRadars.insert(.cleanFood) }
            savePreferences()
            return true
        }

        let extraCount = activeRadars.filter { !$0.isFreeBase }.count
        if !isPro && extraCount >= 1 {
            // Signal caller to show Pro paywall for multi-radar stacking
            return false
        }

        activeRadars.insert(radar)
        savePreferences()
        return true
    }

    func addCustomBlacklist(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !customBlacklist.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            customBlacklist.insert(trimmed, at: 0)
            savePreferences()
        }
    }

    func removeCustomBlacklist(_ term: String) {
        customBlacklist.removeAll { $0 == term }
        savePreferences()
    }

    func saveRecord(_ record: ScanRecord) {
        records.insert(record, at: 0)
        persistRecords()
    }

    func updateCabinet(for id: UUID, bucket: CabinetBucket) {
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        records[idx].cabinet = bucket
        persistRecords()
    }

    func renameRecord(id: UUID, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = records.firstIndex(where: { $0.id == id }) else { return }
        records[idx].productName = trimmed
        persistRecords()
    }

    func deleteRecord(id: UUID) {
        records.removeAll { $0.id == id }
        persistRecords()
    }

    func assignToPK(_ record: ScanRecord) {
        if pkLeft == nil {
            pkLeft = record
        } else if pkRight == nil {
            pkRight = record
        } else {
            pkLeft = pkRight
            pkRight = record
        }
    }

    var greenListCount: Int { records.filter { $0.cabinet == .greenList }.count }
    var redListCount: Int { records.filter { $0.cabinet == .redList }.count }
    var averageScore: Int {
        guard !records.isEmpty else { return 0 }
        return records.reduce(0) { $0 + $1.score } / records.count
    }

    private func loadPersistedState() {
        if let rawRadars = UserDefaults.standard.stringArray(forKey: radarsKey) {
            let parsed = Set(rawRadars.compactMap { RadarType(rawValue: $0) })
            if !parsed.isEmpty { activeRadars = parsed }
        }
        if let savedList = UserDefaults.standard.stringArray(forKey: blacklistKey) {
            customBlacklist = savedList
        }
        if let data = try? Data(contentsOf: recordsURL),
           let decoded = try? JSONDecoder().decode([ScanRecord].self, from: data) {
            records = decoded
        }
    }

    private func savePreferences() {
        UserDefaults.standard.set(activeRadars.map { $0.rawValue }, forKey: radarsKey)
        UserDefaults.standard.set(customBlacklist, forKey: blacklistKey)
    }

    private func persistRecords() {
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: recordsURL, options: .atomic)
        }
    }

    /// Seeds 2 crisp starter items into PK slots so the VS Showdown tab looks instantly alive on first open.
    private func seedInitialDemoIfEmpty() {
        if pkLeft == nil, let toast = SampleCatalog.all.first(where: { $0.id == "toast_bread" }) {
            pkLeft = IngredientAnalyzer.analyze(
                rawText: toast.rawText,
                productName: toast.displayName,
                preferredDomain: toast.domain,
                activeRadars: [.cleanFood, .sugarDiet, .momBaby]
            )
        }
        if pkRight == nil, let yogurt = SampleCatalog.all.first(where: { $0.id == "clean_yogurt" }) {
            pkRight = IngredientAnalyzer.analyze(
                rawText: yogurt.rawText,
                productName: yogurt.displayName,
                preferredDomain: yogurt.domain,
                activeRadars: [.cleanFood, .sugarDiet, .momBaby]
            )
        }
    }
}
