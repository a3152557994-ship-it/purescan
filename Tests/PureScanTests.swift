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
}
