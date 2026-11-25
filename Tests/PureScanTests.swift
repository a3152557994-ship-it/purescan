import XCTest
@testable import PureScan

final class PureScanTests: XCTestCase {

    func testFuzzyOCRCorrectionAndGB2760Alert() {
        let noisyOCR = "配料：小麦粉、白砂糖、人造奶油、氢化植勿油、脱氢乙酦钠、阿斯巴田、诱惑红"
        let record = IngredientAnalyzer.analyze(
            rawText: noisyOCR,
            productName: "测试吐司",
            preferredDomain: .food,
            activeRadars: [.cleanFood, .sugarDiet, .momBaby]
        )

        XCTAssertLessThan(record.score, 40, "Additive bomb should score in danger zone")
        XCTAssertEqual(record.grade, .danger)
        XCTAssertTrue(record.hits.contains(where: { $0.id == "sodium_dehydroacetate" }), "Should fix OCR typo 脱氢乙酦钠")
        XCTAssertTrue(record.hits.contains(where: { $0.id == "hydrogenated_oil" }), "Should fix OCR typo 氢化植勿油")
        XCTAssertTrue(record.hits.contains(where: { $0.id == "aspartame" }), "Should fix OCR typo 阿斯巴田")
        XCTAssertTrue(record.structuralAlerts.contains(where: { $0.id == "top3_sugar" }), "Should catch sugar in top 3")
    }

    func testCleanYogurtNotFalselyPenalized() {
        let cleanText = "配料：生牛乳（≥99%）、嗜热链球菌、保加利亚乳杆菌、维生素C"
        let record = IngredientAnalyzer.analyze(
            rawText: cleanText,
            productName: "纯酸奶",
            preferredDomain: .food,
            activeRadars: [.cleanFood, .sugarDiet, .momBaby]
        )

        XCTAssertGreaterThanOrEqual(record.score, 95, "Clean yogurt with Vitamin C must not be falsely penalized")
        XCTAssertEqual(record.grade, .clean)
        XCTAssertEqual(record.dangerCount, 0)
    }

    func testGoutPurineRadarCatchesYeastExtractAndNucleotides() {
        let soupText = "配料：小麦粉、食盐、酵母抽提物、呈味核苷酸二钠、虾粉、果葡糖浆"
        let record = IngredientAnalyzer.analyze(
            rawText: soupText,
            preferredDomain: .food,
            activeRadars: [.goutPurine]
        )

        XCTAssertTrue(record.hits.contains(where: { $0.id == "yeast_extract" && $0.risk == .danger }))
        XCTAssertTrue(record.hits.contains(where: { $0.id == "ig_nucleotides" && $0.risk == .danger }))
        XCTAssertTrue(record.hits.contains(where: { $0.id == "hfcs" && $0.risk == .danger }))
        XCTAssertLessThan(record.score, 40)
    }

    func testPetFoodGrainSplittingTrapDetector() {
        let petText = "原料组成：鸡肉粉、玉米、大米、小麦粉、豆粕、宠物饲料复合调味料、BHA"
        let record = IngredientAnalyzer.analyze(
            rawText: petText,
            preferredDomain: nil,
            activeRadars: [.petSafety]
        )

        XCTAssertEqual(record.domain, .pet, "Should auto-detect pet food domain")
        XCTAssertTrue(record.structuralAlerts.contains(where: { $0.id == "pet_grain_splitting" }))
        XCTAssertTrue(record.hits.contains(where: { $0.id == "pet_attractants" }))
        XCTAssertLessThan(record.score, 40)
    }

    func testSkincareINCIAndCustomAllergenBlacklist() {
        let creamText = "Ingredients: Aqua, Glycerin, Isopropyl Myristate, Retinol, Methylisothiazolinone, Peanut Oil"
        let record = IngredientAnalyzer.analyze(
            rawText: creamText,
            preferredDomain: nil,
            activeRadars: [.acneSkincare, .momBaby],
            customBlacklist: ["Peanut"]
        )

        XCTAssertEqual(record.domain, .skincare)
        XCTAssertTrue(record.hits.contains(where: { $0.isCustomBlacklist && $0.risk == .danger }))
        XCTAssertTrue(record.hits.contains(where: { $0.id == "retinol" }))
        XCTAssertTrue(record.hits.contains(where: { $0.id == "mit_cmit" }))
    }

    func testPKCompareWinner() {
        let bad = SampleCatalog.all.first(where: { $0.id == "toast_bread" })!
        let good = SampleCatalog.all.first(where: { $0.id == "clean_yogurt" })!
        let left = IngredientAnalyzer.analyze(rawText: bad.rawTextZH, preferredDomain: .food, activeRadars: [.cleanFood, .sugarDiet])
        let right = IngredientAnalyzer.analyze(rawText: good.rawTextZH, preferredDomain: .food, activeRadars: [.cleanFood, .sugarDiet])

        XCTAssertEqual(IngredientAnalyzer.compareWinner(left: left, right: right), 1, "Clean yogurt must beat additive toast")
    }

    func testTraditionalChineseLocalizationAndOCRMatching() {
        XCTAssertEqual(AppLanguage.auto.resolvedLanguage(preferredLanguages: ["zh-Hant-TW"]), .zhHant)
        XCTAssertEqual(AppLanguage.auto.resolvedLanguage(preferredLanguages: ["zh-HK"]), .zhHant)
        XCTAssertEqual(AppLanguage.auto.resolvedLanguage(preferredLanguages: ["zh-Hans-CN"]), .zhHans)
        XCTAssertEqual(AppLanguage.auto.resolvedLanguage(preferredLanguages: ["en-US"]), .en)

        let savedLang = L10n.currentLanguage
        defer { L10n.currentLanguage = savedLang }

        L10n.currentLanguage = .zhHant
        XCTAssertTrue(L10n.isTraditionalChinese)
        XCTAssertEqual(L10n.t(en: "Close", zhHans: "关闭", zhHant: "關閉"), "關閉")
        let converted = L10n.t("默认设置与隐私政策", "Default Settings & Privacy Policy")
        XCTAssertTrue(converted.contains("預設設定"), "Expected authentic TW/HK phrasing, got \(converted)")

        // Traditional Chinese scanned package label must still trigger database matches
        let tradLabel = "成分：小麥粉、白砂糖、氫化植物油、脫氫乙酸鈉、酵母抽提物、呈味核苷酸二鈉"
        let record = IngredientAnalyzer.analyze(
            rawText: tradLabel,
            productName: "台灣麵包測試",
            preferredDomain: .food,
            activeRadars: [.cleanFood, .goutPurine, .sugarDiet]
        )
        XCTAssertTrue(record.hits.contains(where: { $0.id == "sodium_dehydroacetate" }))
        XCTAssertTrue(record.hits.contains(where: { $0.id == "hydrogenated_oil" }))
        XCTAssertTrue(record.hits.contains(where: { $0.id == "yeast_extract" }))
        XCTAssertTrue(record.structuralAlerts.contains(where: { $0.id == "top3_sugar" }))
    }

    func testReviewPromptManagerHappyPathAnd90DayThrottle() {
        let suite = "purescan.test.review.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let mgr = ReviewPromptManager(defaults: defaults)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertFalse(mgr.shouldShowReviewGate(completedScans: 1, now: t0, isDemoLaunch: false))
        XCTAssertTrue(mgr.shouldShowReviewGate(completedScans: 2, now: t0, isDemoLaunch: false))
        XCTAssertFalse(mgr.shouldShowReviewGate(completedScans: 2, now: t0, isDemoLaunch: true))

        mgr.recordPositiveReviewTapped(now: t0)
        // Throttled for 90 days
        let day89 = t0.addingTimeInterval(89 * 24 * 60 * 60)
        let day91 = t0.addingTimeInterval(91 * 24 * 60 * 60)
        XCTAssertFalse(mgr.shouldShowReviewGate(completedScans: 5, now: day89, isDemoLaunch: false))
        XCTAssertTrue(mgr.shouldShowReviewGate(completedScans: 5, now: day91, isDemoLaunch: false))
    }

    func testFunnelMetricsLocalCounters() {
        let suite = "purescan.test.funnel.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let metrics = FunnelMetrics(defaults: defaults)
        metrics.record(.appLaunch)
        metrics.record(.scanCompleted(domain: "food"))
        metrics.record(.scanCompleted(domain: "skincare"))
        metrics.record(.paywallImpression(region: "angloROI"))
        metrics.record(.paywallImpression(region: "angloROI"))
        metrics.record(.purchaseSucceeded(productId: PureScanProductID.lifetime))

        XCTAssertEqual(metrics.count(for: .appLaunch), 1)
        XCTAssertEqual(metrics.count(for: .scanCompleted(domain: "")), 2)
        XCTAssertEqual(metrics.paywallConversionRate, 0.5, accuracy: 0.001)
    }

    func testPaywallThreeRegionProfiles() {
        XCTAssertEqual(PaywallRegionProfile.resolve(regionCode: "US", language: .en), .angloROI)
        XCTAssertEqual(PaywallRegionProfile.resolve(regionCode: "GB", language: .en), .angloROI)
        XCTAssertEqual(PaywallRegionProfile.resolve(regionCode: "DE", language: .en), .euPrivacyLifetime)
        XCTAssertEqual(PaywallRegionProfile.resolve(regionCode: "FR", language: .en), .euPrivacyLifetime)
        XCTAssertEqual(PaywallRegionProfile.resolve(regionCode: "HK", language: .zhHant), .eastAsiaDetail)
        XCTAssertEqual(PaywallRegionProfile.resolve(regionCode: "TW", language: .zhHant), .eastAsiaDetail)
        XCTAssertEqual(PaywallRegionProfile.resolve(regionCode: "CN", language: .zhHans), .eastAsiaDetail)
        XCTAssertEqual(PaywallRegionProfile.resolve(regionCode: "JP", language: .en), .eastAsiaDetail)
    }
}
