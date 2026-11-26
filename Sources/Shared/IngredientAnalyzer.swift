import Foundation

enum IngredientAnalyzer {

    /// Automatically detect whether raw OCR text looks like Food, Skincare, or Pet Food.
    static func detectDomain(from text: String, activeRadars: Set<RadarType>) -> ScanDomain {
        let lower = L10n.toSimplifiedForMatching(text).lowercased()
        let petSignals = [
            "原料组成", "猫粮", "狗粮", "宠物饲料", "全价", "牛磺酸", "丝兰提取物", "鲜鸡肉",
            "肉粉", "动物副产品", "冻干鸡肉", "鸡肉粉", "鱼粉", "猫罐头", "犬粮",
            "chicken meal", "meat by-products", "taurine", "kibble", "cat food", "dog food", "pet"
        ]
        let skinSignals = [
            "aqua", "glycerin", "parfum", "retinol", "ceramide", "niacinamide", "salicylic",
            "hyaluronate", "methylisothiazolinone", "isopropyl myristate", "phenoxyethanol",
            "dimethicone", "carbomer", "tocopherol", "butylene glycol",
            "神经酰胺", "积雪草", "透明质酸", "烟酰胺", "视黄醇", "水杨酸", "羟苯", "变性乙醇",
            "肉豆蔻酸", "苯氧乙醇", "卡波姆", "丁二醇", "聚二甲基硅氧烷", "洁面", "面霜", "精华"
        ]

        let petScore = petSignals.filter { lower.contains($0) }.count
        let skinScore = skinSignals.filter { lower.contains($0) }.count

        if petScore >= 2 { return .pet }
        if skinScore >= 2 { return .skincare }
        if activeRadars == [.acneSkincare] { return .skincare }
        if activeRadars == [.petSafety] { return .pet }
        return .food
    }

    /// Seamlessly stitch CJK characters broken across curved-bottle OCR newlines without spaces,
    /// while preserving single spaces between wrapped Latin/English words.
    static func joinCrossLineBreaks(_ raw: String) -> String {
        var s = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // 1. CJK character followed by newline and CJK character -> stitch with zero space (e.g. "脱氢\n乙酸钠" -> "脱氢乙酸钠")
        if let cjkRegex = try? NSRegularExpression(
            pattern: "(?<=[\\p{Han}\\p{Hiragana}\\p{Katakana}\\p{Hangul}])[ \\t]*\\n+[ \\t]*(?=[\\p{Han}\\p{Hiragana}\\p{Katakana}\\p{Hangul}])"
        ) {
            s = cjkRegex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }

        // 2. Chemical prefix hyphen/prime wrapped next to CJK (e.g. "5'-\n呈味核苷酸二钠", "D-\n异抗坏血酸钠") -> zero space
        if let chemPrefixRegex = try? NSRegularExpression(
            pattern: "(?<=[-'])[ \\t]*\\n+[ \\t]*(?=\\p{Han})|(?<=\\p{Han})[ \\t]*\\n+[ \\t]*(?=[-'])"
        ) {
            s = chemPrefixRegex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }

        // 3. CJK followed by short vitamin/code suffix across newline (e.g. "维生素\nC", "辅酶\nQ10") -> zero space
        if let shortCodeRegex = try? NSRegularExpression(
            pattern: "(?<=\\p{Han})[ \\t]*\\n+[ \\t]*(?=[A-Za-z0-9]{1,4}(?![A-Za-z]))"
        ) {
            s = shortCodeRegex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }

        // 4. Remaining newlines (e.g. English words across lines) -> single space
        if let remNewline = try? NSRegularExpression(pattern: "[ \\t]*\\n+[ \\t]*") {
            s = remNewline.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ")
        }

        return s
    }

    /// Normalize noisy OCR output into clean ordered ingredient tokens.
    static func normalizeAndTokenize(_ raw: String) -> (cleanedText: String, tokens: [String]) {
        var text = joinCrossLineBreaks(raw)

        // Apply OCR typo corrections on both original & simplified forms while keeping readable display text
        let simplifiedProbe = L10n.toSimplifiedForMatching(text)
        var textForCorrection = text
        for pair in IngredientDatabase.ocrCorrections {
            if textForCorrection.contains(pair.wrong) {
                textForCorrection = textForCorrection.replacingOccurrences(of: pair.wrong, with: pair.right)
            } else if simplifiedProbe.contains(pair.wrong) {
                let tradWrong = L10n.toTraditionalChinese(pair.wrong)
                if textForCorrection.contains(tradWrong) {
                    textForCorrection = textForCorrection.replacingOccurrences(of: tradWrong, with: pair.right)
                }
            }
        }
        text = textForCorrection

        // Strip common leading prefixes like "配料表：", "配料:", "Ingredients:", "原料组成：", "全成分："
        let prefixPatterns = [
            "^(?:产品|產品)?配料表?\\s*[:：]",
            "^原料[组組]成\\s*[:：]",
            "^添加[剂劑][组組]成\\s*[:：]",
            "^全?主要成分\\s*[:：]",
            "^全?成分表?\\s*[:：]",
            "^ingredients?\\s*[:：]"
        ]
        var working = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for pattern in prefixPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(working.startIndex..., in: working)
                working = regex.stringByReplacingMatches(in: working, options: [], range: range, withTemplate: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Strip pure concentration/percentage annotations like "(≥99%)", "（52%）" so they don't become bogus tokens
        if let pctParenRegex = try? NSRegularExpression(
            pattern: "[（(]\\s*[≥≤><~≈]?\\s*\\d+(?:\\.\\d+)?\\s*%\\s*[）)]"
        ) {
            working = pctParenRegex.stringByReplacingMatches(
                in: working,
                range: NSRange(working.startIndex..., in: working),
                withTemplate: ""
            )
        }

        // Split by Chinese/English delimiters while flattening nested additive parentheses
        let flattened = working
            .replacingOccurrences(of: "食品添加剂", with: "")
            .replacingOccurrences(of: "食品添加劑", with: "")
            .replacingOccurrences(of: "添加剂组成", with: "、")
            .replacingOccurrences(of: "其他微量成分", with: "、")
            .replacingOccurrences(of: "（", with: "、")
            .replacingOccurrences(of: "）", with: "、")
            .replacingOccurrences(of: "(", with: ",")
            .replacingOccurrences(of: ")", with: ",")
            .replacingOccurrences(of: "【", with: "、")
            .replacingOccurrences(of: "】", with: "、")
            .replacingOccurrences(of: "[", with: ",")
            .replacingOccurrences(of: "]", with: ",")
            .replacingOccurrences(of: "。", with: "、")
            .replacingOccurrences(of: ";", with: ",")
            .replacingOccurrences(of: "；", with: "、")

        let separators = CharacterSet(charactersIn: "、,，/\\|")
        let purePctRegex = try? NSRegularExpression(pattern: "^[≥≤><~≈]?\\s*\\d+(?:\\.\\d+)?\\s*%?$")
        let rawTokens = flattened
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { tok in
                guard !tok.isEmpty && tok.count <= 64 else { return false }
                if let r = purePctRegex,
                   r.firstMatch(in: tok, range: NSRange(tok.startIndex..., in: tok)) != nil {
                    return false
                }
                return true
            }

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
        var verifiedTokenIndices = Set<Int>()

        // 1. Custom User Allergen / Blacklist check (ALWAYS Danger!)
        let cleanBlacklist = customBlacklist
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for (index, token) in tokens.enumerated() {
            let lowerToken = L10n.toSimplifiedForMatching(token).lowercased()
            for blocked in cleanBlacklist {
                let normalizedBlocked = L10n.toSimplifiedForMatching(blocked).lowercased()
                if lowerToken.contains(normalizedBlocked) {
                    verifiedTokenIndices.insert(index)
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

        // 2. Match curated database entries relevant to domain + cross-domain triggers
        let candidateEntries = IngredientDatabase.entries.filter { entry in
            if entry.domain == domain { return true }
            if domain == .pet && entry.radars.contains(.petSafety) { return true }
            if domain == .skincare && entry.radars.contains(.acneSkincare) { return true }
            if domain == .food && entry.domain == .food { return true }
            return false
        }

        for (index, token) in tokens.enumerated() {
            let lowerToken = L10n.toSimplifiedForMatching(token).lowercased()
            for entry in candidateEntries {
                let matched = matchesEntry(lowerToken: lowerToken, entry: entry)
                if matched {
                    verifiedTokenIndices.insert(index)
                    if matchedEntryIds.contains(entry.id) { continue }
                    matchedEntryIds.insert(entry.id)
                    let relevantRadars = entry.radars.filter { effectiveRadars.contains($0) }
                    let radarTriggered = !relevantRadars.isEmpty

                    let adjustedPenalty: Int
                    let adjustedRisk: RiskLevel
                    if entry.risk == .safe {
                        adjustedPenalty = 0
                        adjustedRisk = .safe
                    } else if radarTriggered {
                        adjustedPenalty = entry.penalty
                        adjustedRisk = entry.risk
                    } else {
                        adjustedPenalty = max(3, entry.penalty / 3)
                        adjustedRisk = .caution
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

            if !verifiedTokenIndices.contains(index) && isKnownBasicBaseIngredient(lowerToken, domain: domain) {
                verifiedTokenIndices.insert(index)
            }
        }

        // 3. Structural Intelligence Alerts (Top-3 Sugar, Grain-Splitting Trap, Ultra-Processed Length, Unlisted Complex Terms)
        var structuralAlerts: [StructuralAlert] = []

        if domain == .food {
            let top3 = tokens.prefix(3).map { L10n.toSimplifiedForMatching($0).lowercased() }
            let sugarTerms = ["白砂糖", "绵白糖", "蔗糖", "果葡糖浆", "葡萄糖浆", "麦芽糊精", "冰糖", "红糖", "黑糖", "麦芽糖浆", "sugar", "corn syrup", "hfcs", "glucose syrup"]
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
            let top6 = tokens.prefix(6).map { L10n.toSimplifiedForMatching($0).lowercased() }
            let grainTerms = ["玉米", "小麦", "大米", "碎米", "豆粕", "谷蛋白", "豌豆淀粉", "马铃薯粉", "corn", "wheat", "rice", "soy"]
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

        // Unlisted complex/chemical ingredient guard: NEVER blindly award 100 points when multiple chemical terms aren't in the DB!
        let unverifiedTokens: [String] = tokens.enumerated().compactMap { idx, tok in
            verifiedTokenIndices.contains(idx) ? nil : tok
        }
        let complexUnverifiedTokens = unverifiedTokens.filter { isComplexOrChemicalToken($0) }
        let verifiedCount = verifiedTokenIndices.count
        let shouldWarnUnlisted = complexUnverifiedTokens.count >= 2
            || (complexUnverifiedTokens.count >= 1 && hits.isEmpty && verifiedCount == 0)
            || (unverifiedTokens.count >= 3 && unverifiedTokens.count > verifiedCount)

        var unlistedNoticeCount = 0
        if shouldWarnUnlisted {
            let highlighted = complexUnverifiedTokens.isEmpty ? unverifiedTokens : complexUnverifiedTokens
            unlistedNoticeCount = highlighted.count
            let preview = highlighted.prefix(3).joined(separator: "、")
            let previewEN = highlighted.prefix(3).joined(separator: ", ")
            let unlistedPenalty = max(16, min(28, 12 + complexUnverifiedTokens.count * 4 + unverifiedTokens.count))
            structuralAlerts.append(
                StructuralAlert(
                    id: "unlisted_complex_ingredients",
                    titleZH: "含 \(unlistedNoticeCount) 项未收录复杂成分（已核验 \(verifiedCount)/\(tokens.count) 项）",
                    titleEN: "\(unlistedNoticeCount) Unlisted Complex Terms (\(verifiedCount)/\(tokens.count) Verified)",
                    detailZH: "已核验 \(verifiedCount) 项暂未见高危红灯，但「\(preview)」等 \(unlistedNoticeCount) 项化学/复杂名称暂未收录于离线库，请结合包装复核，不盲目视为满分干净配料。",
                    detailEN: "Verified \(verifiedCount) items with zero red flags, but \(unlistedNoticeCount) complex terms (\(previewEN)) are not yet in the offline catalog—review manually rather than assuming 100% clean.",
                    risk: .caution,
                    penalty: unlistedPenalty
                )
            )
        }

        // 4. Score Computation (0 - 100)
        let hitPenalty = hits.reduce(0) { $0 + $1.penalty }
        let structPenalty = structuralAlerts.reduce(0) { $0 + $1.penalty }
        let singleUnlistedCap = (!shouldWarnUnlisted && !complexUnverifiedTokens.isEmpty) ? 8 : 0
        let cleanBonus = (hitPenalty == 0 && complexUnverifiedTokens.isEmpty && !shouldWarnUnlisted)
            ? min(6, hits.filter { $0.risk == .safe }.count * 2)
            : 0
        let rawScore = max(8, min(100 - singleUnlistedCap, 100 - hitPenalty - structPenalty + cleanBonus))

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
            structuralTop: structuralAlerts.first(where: { $0.risk == .danger }),
            verifiedCount: verifiedCount,
            totalCount: tokens.count,
            unlistedComplexCount: unlistedNoticeCount
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

    private static func matchesEntry(lowerToken: String, entry: IngredientEntry) -> Bool {
        entry.aliases.contains { alias in
            let a = alias.lowercased()
            if a.count <= 3 && a.allSatisfy({ $0.isASCII }) {
                let pattern = "(?<![a-z0-9])\(NSRegularExpression.escapedPattern(for: a))(?![a-z0-9])"
                return lowerToken.range(of: pattern, options: .regularExpression) != nil
            }
            return lowerToken.contains(a)
        }
    }

    private static func isKnownBasicBaseIngredient(_ simplifiedLower: String, domain: ScanDomain) -> Bool {
        let commonStaples = [
            "水", "饮用水", "纯净水", "矿泉水", "去离子水", "碳酸水", "二氧化碳",
            "小麦粉", "全麦粉", "高筋小麦粉", "低筋小麦粉", "面粉", "大米", "糯米", "黑米", "糙米", "燕麦", "燕麦片", "荞麦", "藜麦", "青稞", "小米",
            "黄豆", "大豆", "黑豆", "红豆", "绿豆", "鹰嘴豆", "豌豆", "扁豆",
            "鸡蛋", "鲜鸡蛋", "全蛋液", "蛋黄液", "巴氏杀菌全蛋液", "蛋白液", "鹌鹑蛋",
            "生牛乳", "鲜牛奶", "纯牛奶", "全脂乳粉", "脱脂乳粉", "乳清粉", "干酪", "芝士", "稀奶油", "黄油", "无盐黄油", "发酵黄油",
            "猪肉", "牛肉", "鸡肉", "鸡胸肉", "鸭肉", "羊肉", "鱼肉", "三文鱼", "鳕鱼", "虾仁",
            "食用盐", "食盐", "海盐", "加碘食盐", "酿造酱油", "生抽", "老抽", "酿造食醋", "陈醋", "米醋", "苹果醋",
            "植物油", "菜籽油", "花生油", "葵花籽油", "玉米油", "大豆油", "橄榄油", "特级初榨橄榄油", "芝麻油", "亚麻籽油", "山茶油", "椰子油",
            "玉米淀粉", "马铃薯淀粉", "木薯淀粉", "红薯淀粉", "豌豆淀粉", "食用淀粉", "淀粉",
            "番茄", "西红柿", "土豆", "马铃薯", "红薯", "紫薯", "山药", "南瓜", "胡萝卜", "白菜", "菠菜", "西兰花", "香菇", "木耳", "海带", "紫菜",
            "苹果", "香蕉", "草莓", "蓝莓", "蔓越莓", "树莓", "葡萄", "柠檬", "西柚", "百香果", "水蜜桃", "黄桃", "芒果", "菠萝", "奇异果", "红枣", "枸杞", "桑葚",
            "芝麻", "黑芝麻", "白芝麻", "花生", "核桃", "巴旦木", "扁桃仁", "腰果", "开心果", "榛子", "松子", "夏威夷果", "板栗", "葵花籽", "南瓜籽",
            "可可脂", "可可粉", "可可液块", "黑巧克力", "咖啡豆", "咖啡粉", "浓缩咖啡", "茶叶", "红茶", "绿茶", "乌龙茶", "茉莉花茶", "普洱茶", "抹茶粉",
            "蜂蜜", "桂花", "玫瑰花", "菊花", "陈皮", "生姜", "干姜", "辣椒", "花椒", "八角", "桂皮", "香叶", "小茴香", "黑胡椒", "白胡椒", "孜然", "酵母", "干酵母",
            "water", "purified water", "carbonated water", "aqua", "eau",
            "wheat flour", "whole wheat flour", "flour", "rice", "oats", "rolled oats",
            "eggs", "whole eggs", "egg yolk", "salt", "sea salt", "milk", "whole milk", "skim milk", "cream", "butter",
            "olive oil", "extra virgin olive oil", "sunflower oil", "canola oil", "rapeseed oil", "soybean oil", "sesame oil",
            "cocoa butter", "cocoa mass", "cocoa powder", "coffee", "tea", "green tea", "black tea", "matcha",
            "apple", "banana", "strawberry", "blueberry", "cranberry", "lemon", "orange", "mango", "pumpkin", "tomato", "carrot", "potato", "yeast", "honey"
        ]
        if domain != .pet {
            let humanAromatics = ["洋葱", "大蒜", "蒜", "葱", "香葱", "onion", "garlic"]
            if humanAromatics.contains(where: { simplifiedLower == $0 }) {
                return true
            }
        }
        return commonStaples.contains { simplifiedLower == $0 }
    }

    private static func isComplexOrChemicalToken(_ rawToken: String) -> Bool {
        let lower = L10n.toSimplifiedForMatching(rawToken).lowercased()
        let zhChemSignals = [
            "酸", "钠", "钾", "钙", "镁", "铵", "铝", "铁", "锌", "铜",
            "酯", "醇", "醛", "酮", "醚", "酚", "胺", "酰胺", "酰", "烷", "烯", "苯", "氯", "硫", "磷", "硅",
            "聚", "羟", "甲基", "乙基", "丙基", "丁基", "异", "氢化", "氧化", "过氧", "焦", "偏",
            "季铵", "吡啶", "噻唑", "咪唑", "吗啉", "磺", "苷", "肽", "酶", "胶", "素", "剂", "改性", "交联", "共聚物"
        ]
        if zhChemSignals.contains(where: { lower.contains($0) }) {
            return true
        }
        let enChemPatterns = [
            "ate\\b", "ite\\b", "ide\\b", "ine\\b", "one\\b", "ene\\b", "ol\\b", "yl\\b",
            "poly", "peg-", "ppg-", "copolymer", "crosspolymer", "siloxane", "ethicone",
            "paraben", "glycol", "steareth", "laureth", "ceteareth", "quaternium",
            "disodium", "trisodium", "edta", "\\be\\d{3}[a-z]?\\b", "\\bins\\s*\\d{3}\\b", "\\bci\\s*\\d{4,6}\\b"
        ]
        for pat in enChemPatterns {
            if lower.range(of: pat, options: .regularExpression) != nil {
                return true
            }
        }
        return lower.count >= 14
    }

    private static func buildHeadline(
        grade: VerdictGrade,
        domain: ScanDomain,
        dangerCount: Int,
        topDanger: IngredientHit?,
        structuralTop: StructuralAlert?,
        verifiedCount: Int,
        totalCount: Int,
        unlistedComplexCount: Int
    ) -> (String, String) {
        if let top = topDanger {
            return (
                "揪出 \(dangerCount) 处红灯雷区！首当其冲：\(top.nameZH)（\(top.categoryZH)）。",
                "Caught \(dangerCount) red flags! Top offender: \(top.nameEN) (\(top.categoryEN))."
            )
        }
        if let st = structuralTop {
            return (st.titleZH, st.titleEN)
        }
        if unlistedComplexCount > 0 {
            return (
                "已核验 \(verifiedCount)/\(totalCount) 项未见高危红灯，另有 \(unlistedComplexCount) 项未收录复杂成分请留意核对。",
                "Verified \(verifiedCount)/\(totalCount) items with zero red flags; \(unlistedComplexCount) unlisted complex ingredients need manual check."
            )
        }
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
        return (
            "含轻度加工成分，偶尔解馋无妨，日常高频建议换更干净款。",
            "Contains mild processed ingredients—fine occasionally, cleaner swaps exist for daily use."
        )
    }

    /// Compare two ScanRecords side-by-side for Supermarket VS PK Showdown.
    static func compareWinner(left: ScanRecord, right: ScanRecord) -> Int {
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
