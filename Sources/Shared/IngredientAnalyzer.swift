import Foundation

enum IngredientAnalyzer {

    /// Automatically detect whether raw OCR text looks like Food, Skincare, or Pet Food.
    static func detectDomain(from text: String, activeRadars: Set<RadarType>) -> ScanDomain {
        let lower = text.lowercased()
        let petSignals = ["原料组成", "猫粮", "狗粮", "宠物饲料", "全价", "牛磺酸", "丝兰提取物", "鲜鸡肉", "肉粉", "动物副产品", "chicken meal", "meat by-products", "taurine", "kibble", "cat food", "dog food", "pet"]
        let skinSignals = ["aqua", "glycerin", "parfum", "retinol", "ceramide", "niacinamide", "salicylic", "hyaluronate", "methylisothiazolinone", "isopropyl myristate", "神经酰胺", "积雪草", "透明质酸", "烟酰胺", "视黄醇", "水杨酸", "羟苯", "变性乙醇", "肉豆蔻酸", "洁面", "面霜", "精华"]

        let petScore = petSignals.filter { lower.contains($0) }.count
        let skinScore = skinSignals.filter { lower.contains($0) }.count

        if petScore >= 2 { return .pet }
        if skinScore >= 2 { return .skincare }
        if activeRadars == [.acneSkincare] { return .skincare }
        if activeRadars == [.petSafety] { return .pet }
        return .food
    }

    /// Normalize noisy OCR output into clean ordered ingredient tokens.
    static func normalizeAndTokenize(_ raw: String) -> (cleanedText: String, tokens: [String]) {
        var text = raw
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")

        for pair in IngredientDatabase.ocrCorrections {
            text = text.replacingOccurrences(of: pair.wrong, with: pair.right)
        }

        // Strip common leading prefixes like "配料表：", "配料:", "Ingredients:", "原料组成："
        let prefixPatterns = [
            "^(?:产品)?配料表?\\s*[:：]",
            "^原料组成\\s*[:：]",
            "^主要成分\\s*[:：]",
            "^成分表?\\s*[:：]",
            "^ingredients\\s*[:：]"
        ]
        var working = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for pattern in prefixPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(working.startIndex..., in: working)
                working = regex.stringByReplacingMatches(in: working, options: [], range: range, withTemplate: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Split by Chinese/English delimiters while flattening nested additive parentheses
        let flattened = working
            .replacingOccurrences(of: "食品添加剂", with: "")
            .replacingOccurrences(of: "（", with: "、")
            .replacingOccurrences(of: "）", with: "、")
            .replacingOccurrences(of: "(", with: ",")
            .replacingOccurrences(of: ")", with: ",")
            .replacingOccurrences(of: "。", with: "、")
            .replacingOccurrences(of: ";", with: ",")
            .replacingOccurrences(of: "；", with: "、")

        let separators = CharacterSet(charactersIn: "、,，/\\|")
        let rawTokens = flattened
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 64 }

        // Deduplicate preserving original order
        var seen = Set<String>()
        var ordered: [String] = []
        for tok in rawTokens {
            let key = tok.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                ordered.append(tok)
            }
        }
        return (text, ordered)
    }

    /// Analyze an ingredient label completely offline with personalized radar weighting.
    static func analyze(
        rawText: String,
        productName: String? = nil,
        preferredDomain: ScanDomain? = nil,
        activeRadars: Set<RadarType>,
        customBlacklist: [String] = []
    ) -> ScanRecord {
        let effectiveRadars = activeRadars.isEmpty ? Set([RadarType.cleanFood]) : activeRadars
        let (cleanedText, tokens) = normalizeAndTokenize(rawText)
        let domain = preferredDomain ?? detectDomain(from: cleanedText, activeRadars: effectiveRadars)

        var hits: [IngredientHit] = []
        var matchedEntryIds = Set<String>()

        // 1. Custom User Allergen / Blacklist check (ALWAYS Danger!)
        let cleanBlacklist = customBlacklist
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for (index, token) in tokens.enumerated() {
            let lowerToken = token.lowercased()
            for blocked in cleanBlacklist {
                if lowerToken.contains(blocked.lowercased()) {
                    let hitId = "custom_\(blocked.lowercased())"
                    if !matchedEntryIds.contains(hitId) {
                        matchedEntryIds.insert(hitId)
                        hits.append(
                            IngredientHit(
                                id: hitId,
                                matchedToken: token,
                                nameZH: "个人忌口：\(blocked)",
                                nameEN: "Personal Alert: \(blocked)",
                                risk: .danger,
                                penalty: 30,
                                triggeredRadars: Array(effectiveRadars),
                                categoryZH: "自定义过敏/忌口",
                                categoryEN: "Custom Blacklist",
                                reasonZH: "命中你亲手设置的个人忌口/过敏关键词「\(blocked)」，务必避开！",
                                reasonEN: "Matches your personal blacklist/allergen keyword '\(blocked)'. Avoid!",
                                standardRef: "Personal Radar",
                                positionIndex: index + 1,
                                isCustomBlacklist: true
                            )
                        )
                    }
                }
            }
        }

        // 2. Match curated database entries relevant to domain + cross-domain toxic triggers
        let candidateEntries = IngredientDatabase.entries.filter { entry in
            if entry.domain == domain { return true }
            if domain == .pet && entry.radars.contains(.petSafety) { return true }
            if domain == .skincare && entry.radars.contains(.acneSkincare) { return true }
            if domain == .food && entry.domain == .food { return true }
            return false
        }

        for (index, token) in tokens.enumerated() {
            let lowerToken = token.lowercased()
            for entry in candidateEntries {
                if matchedEntryIds.contains(entry.id) { continue }
                let matched = entry.aliases.contains { alias in
                    let a = alias.lowercased()
                    if a.count <= 3 && a.allSatisfy({ $0.isASCII }) {
                        // Avoid short ASCII false positives like "bha" matching inside unrelated words
                        let pattern = "(?<![a-z0-9])\(NSRegularExpression.escapedPattern(for: a))(?![a-z0-9])"
                        return lowerToken.range(of: pattern, options: .regularExpression) != nil
                    }
                    return lowerToken.contains(a)
                }
                if matched {
                    matchedEntryIds.insert(entry.id)
                    let relevantRadars = entry.radars.filter { effectiveRadars.contains($0) }
                    let radarTriggered = !relevantRadars.isEmpty

                    // Escalate penalty slightly if user explicitly turned on that specialized radar
                    let adjustedPenalty: Int
                    let adjustedRisk: RiskLevel
                    if entry.risk == .safe {
                        adjustedPenalty = 0
                        adjustedRisk = .safe
                    } else if radarTriggered {
                        adjustedPenalty = entry.penalty
                        adjustedRisk = entry.risk
                    } else {
                        // Still visible as mild informational notice if user didn't activate that specific radar
                        adjustedPenalty = max(3, entry.penalty / 3)
                        adjustedRisk = entry.risk == .danger ? .caution : .caution
                    }

                    hits.append(
                        IngredientHit(
                            id: entry.id,
                            matchedToken: token,
                            nameZH: entry.nameZH,
                            nameEN: entry.nameEN,
                            risk: adjustedRisk,
                            penalty: adjustedPenalty,
                            triggeredRadars: relevantRadars.isEmpty ? entry.radars : relevantRadars,
                            categoryZH: entry.categoryZH,
                            categoryEN: entry.categoryEN,
                            reasonZH: entry.reasonZH,
                            reasonEN: entry.reasonEN,
                            standardRef: entry.standardRef,
                            positionIndex: index + 1,
                            isCustomBlacklist: false
                        )
                    )
                }
            }
        }

        // 3. Structural Intelligence Alerts (Top-3 Sugar, Grain-Splitting Trap, Ultra-Processed Length)
        var structuralAlerts: [StructuralAlert] = []

        if domain == .food {
            let top3 = tokens.prefix(3).map { $0.lowercased() }
            let sugarTerms = ["白砂糖", "绵白糖", "蔗糖", "果葡糖浆", "葡萄糖浆", "麦芽糊精", "sugar", "corn syrup", "hfcs", "glucose syrup"]
            if top3.contains(where: { tok in sugarTerms.contains(where: { tok.contains($0) }) }) {
                structuralAlerts.append(
                    StructuralAlert(
                        id: "top3_sugar",
                        titleZH: "配料前三位含游离糖 / 糖浆",
                        titleEN: "Added Sugar in Top 3 Ingredients",
                        detailZH: "配料表按含量从高到低排列，前三位出现糖类说明游离糖占比偏高，控糖减脂党请谨慎。",
                        detailEN: "Ingredients are listed by weight—sugar in the top 3 signals high added sugar content.",
                        risk: effectiveRadars.contains(.sugarDiet) ? .danger : .caution,
                        penalty: effectiveRadars.contains(.sugarDiet) ? 14 : 6
                    )
                )
            }

            if tokens.count >= 14 {
                structuralAlerts.append(
                    StructuralAlert(
                        id: "ultra_processed_length",
                        titleZH: "超长配料表（共 \(tokens.count) 项）",
                        titleEN: "Ultra-Processed Label (\(tokens.count) items)",
                        detailZH: "配料超过 14 项通常意味着重度工业深加工，日常主食建议优先选择 5 项以内的干净配料。",
                        detailEN: "Labels exceeding 14 ingredients typically signal heavy ultra-processing; cleaner options stay under 6.",
                        risk: .caution,
                        penalty: 6
                    )
                )
            }
        }

        if domain == .pet {
            let top6 = tokens.prefix(6).map { $0.lowercased() }
            let grainTerms = ["玉米", "小麦", "大米", "碎米", "豆粕", "谷蛋白", "corn", "wheat", "rice", "soy"]
            let grainCountInTop6 = top6.filter { tok in grainTerms.contains(where: { tok.contains($0) }) }.count
            if grainCountInTop6 >= 2 {
                structuralAlerts.append(
                    StructuralAlert(
                        id: "pet_grain_splitting",
                        titleZH: "识破「谷物分割法」猫狗粮陷阱！",
                        titleEN: "Sneaky 'Grain-Splitting' Trap Detected!",
                        detailZH: "前 6 位里塞了 \(grainCountInTop6) 种谷物/豆粕（把玉米、大米、小麦拆分写，故意把肉排在第一位），实际高碳水低鲜肉！",
                        detailEN: "\(grainCountInTop6) grain/soy fillers split across the top 6 spots to artificially push meat to #1—classic cheap kibble trick!",
                        risk: .danger,
                        penalty: 18
                    )
                )
            }
        }

        // 4. Score Computation (0 - 100, calibrated so clean whole foods hit 92-100 and additive bombs hit 15-45)
        let hitPenalty = hits.reduce(0) { $0 + $1.penalty }
        let structPenalty = structuralAlerts.reduce(0) { $0 + $1.penalty }
        let cleanBonus = min(6, hits.filter { $0.risk == .safe }.count * 2)
        let rawScore = max(8, min(100, 100 - hitPenalty - structPenalty + (hitPenalty == 0 ? cleanBonus : 0)))

        let grade: VerdictGrade
        switch rawScore {
        case 85...100: grade = .clean
        case 65...84: grade = .mild
        case 40...64: grade = .warning
        default: grade = .danger
        }

        // Sort hits: Custom blacklist first -> Danger -> Caution -> Safe
        hits.sort { lhs, rhs in
            if lhs.isCustomBlacklist != rhs.isCustomBlacklist { return lhs.isCustomBlacklist }
            if lhs.risk != rhs.risk { return lhs.risk > rhs.risk }
            return lhs.positionIndex < rhs.positionIndex
        }

        let dangerCount = hits.filter { $0.risk == .danger }.count + structuralAlerts.filter { $0.risk == .danger }.count
        let cautionCount = hits.filter { $0.risk == .caution }.count + structuralAlerts.filter { $0.risk == .caution }.count
        let cleanCount = hits.filter { $0.risk == .safe }.count

        let (headlineZH, headlineEN) = buildHeadline(
            grade: grade,
            domain: domain,
            dangerCount: dangerCount,
            topDanger: hits.first(where: { $0.risk == .danger }),
            structuralTop: structuralAlerts.first(where: { $0.risk == .danger })
        )

        let inferredName = productName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName: String
        if let n = inferredName, !n.isEmpty {
            finalName = n
        } else {
            let first = tokens.first ?? L10n.t("未命名商品", "Scanned Item")
            finalName = L10n.t("扫雷样本 · \(first)", "Label · \(first)")
        }

        return ScanRecord(
            id: UUID(),
            productName: finalName,
            rawText: cleanedText,
            normalizedTokens: tokens,
            domain: domain,
            activeRadars: Array(effectiveRadars).sorted { $0.rawValue < $1.rawValue },
            score: rawScore,
            grade: grade,
            dangerCount: dangerCount,
            cautionCount: cautionCount,
            cleanCount: cleanCount,
            hits: hits,
            structuralAlerts: structuralAlerts,
            headlineZH: headlineZH,
            headlineEN: headlineEN,
            createdAt: Date(),
            cabinet: .none
        )
    }

    private static func buildHeadline(
        grade: VerdictGrade,
        domain: ScanDomain,
        dangerCount: Int,
        topDanger: IngredientHit?,
        structuralTop: StructuralAlert?
    ) -> (String, String) {
        if grade == .clean {
            switch domain {
            case .food:
                return ("配料干净清爽，没发现高危科技狠活，可以放心塞进购物车！", "Super clean ingredient list with zero red-flag additives. Buy with confidence!")
            case .skincare:
                return ("配方温和克制，无高致痘酯与强刺激防腐，敏感肌安心用。", "Gentle, clean INCI profile without harsh preservatives or heavy pore-cloggers.")
            case .pet:
                return ("鲜肉基底清晰，无谷物分割法与诱食剂陷阱，主子安心干饭！", "Clean meat-first formula with zero attractants or sneaky grain splitting!")
            }
        }

        if let top = topDanger {
            return (
                "揪出 \(dangerCount) 处红灯雷区！首当其冲：\(top.nameZH)（\(top.categoryZH)）。",
                "Caught \(dangerCount) red flags! Top offender: \(top.nameEN) (\(top.categoryEN))."
            )
        }
        if let st = structuralTop {
            return (st.titleZH, st.titleEN)
        }
        return (
            "含轻度加工成分，偶尔解馋无妨，日常高频建议换更干净款。",
            "Contains mild processed ingredients—fine occasionally, cleaner swaps exist for daily use."
        )
    }

    /// Compare two ScanRecords side-by-side for Supermarket VS PK Showdown.
    static func compareWinner(left: ScanRecord, right: ScanRecord) -> Int {
        // Returns -1 if left wins, +1 if right wins, 0 if tie
        if left.score != right.score {
            return left.score > right.score ? -1 : 1
        }
        if left.dangerCount != right.dangerCount {
            return left.dangerCount < right.dangerCount ? -1 : 1
        }
        if left.normalizedTokens.count != right.normalizedTokens.count {
            return left.normalizedTokens.count < right.normalizedTokens.count ? -1 : 1
        }
        return 0
    }
}
