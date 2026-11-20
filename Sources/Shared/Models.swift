import Foundation
import SwiftUI

enum ScanDomain: String, CaseIterable, Identifiable, Codable {
    case food
    case skincare
    case pet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: return L10n.t("食品零食", "Food")
        case .skincare: return L10n.t("护肤美妆", "Skincare")
        case .pet: return L10n.t("猫粮狗粮", "Pet Food")
        }
    }

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .skincare: return "sparkles"
        case .pet: return "pawprint.fill"
        }
    }
}

enum RadarType: String, CaseIterable, Identifiable, Codable {
    case cleanFood     // 通用添加剂 & 科技与狠活（免费基础）
    case sugarDiet     // 控糖减脂（隐形糖 / 反式脂肪 / 高GI填充）
    case goutPurine    // 高尿酸 / 痛风（酵母抽提物 / 核苷酸 / 海鲜精 / 果糖）
    case momBaby       // 孕期 / 宝妈选零（人工色素 / 高危防腐剂 / 咖啡因）
    case acneSkincare  // 敏感肌 / 致痘 / 孕慎护肤（INCI）
    case petSafety     // 养猫 / 养狗避毒与谷物分割法

    var id: String { rawValue }

    var isFreeBase: Bool {
        self == .cleanFood
    }

    var title: String {
        switch self {
        case .cleanFood: return L10n.t("科技与狠活", "Additives")
        case .sugarDiet: return L10n.t("控糖减脂", "Low Sugar")
        case .goutPurine: return L10n.t("痛风高尿酸", "Gout / Purine")
        case .momBaby: return L10n.t("孕期与宝妈", "Mom & Kids")
        case .acneSkincare: return L10n.t("敏感致痘护肤", "Sensitive Skin")
        case .petSafety: return L10n.t("猫狗粮避毒", "Pet Safety")
        }
    }

    var shortTag: String {
        switch self {
        case .cleanFood: return L10n.t("通用添加剂", "Additives")
        case .sugarDiet: return L10n.t("控糖减脂", "Low Sugar")
        case .goutPurine: return L10n.t("痛风嘌呤", "Purine")
        case .momBaby: return L10n.t("孕妈宝宝", "Mom & Kids")
        case .acneSkincare: return L10n.t("护肤避雷", "Skincare")
        case .petSafety: return L10n.t("宠粮扫雷", "Pet Food")
        }
    }

    var subtitle: String {
        switch self {
        case .cleanFood:
            return L10n.t("国标高危防腐剂、反式脂肪、人工色素、超加工陷阱", "High-risk preservatives, trans fats, synthetic dyes, ultra-processed flags")
        case .sugarDiet:
            return L10n.t("揪出果葡糖浆、麦芽糊精、植脂末、代糖与前三位加糖", "Catches HFCS, maltodextrin, creamer, sweeteners & top-3 hidden sugars")
        case .goutPurine:
            return L10n.t("拦截酵母抽提物、呈味核苷酸二钠、海鲜浓缩粉与高果糖", "Flags yeast extract, I+G nucleotides, seafood powder & fructose")
        case .momBaby:
            return L10n.t("规避脱氢乙酸钠、亚硝酸盐、人工色素、咖啡因与酒精", "Avoids sodium dehydroacetate, nitrites, synthetic dyes, caffeine & alcohol")
        case .acneSkincare:
            return L10n.t("识别中英文 INCI 致痘脂、MIT/尼泊金防腐、高浓度酒精与孕慎 A 醇", "Spots comedogenic esters, MIT/parabens, drying alcohol & retinol cautions")
        case .petSafety:
            return L10n.t("拦住木糖醇/洋葱/BHA/诱食剂，自动识破猫狗粮谷物分割法", "Catches xylitol/onion/BHA/attractants & sneaky grain-splitting traps")
        }
    }

    var icon: String {
        switch self {
        case .cleanFood: return "shield.lefthalf.filled.badge.checkmark"
        case .sugarDiet: return "flame.fill"
        case .goutPurine: return "drop.triangle.fill"
        case .momBaby: return "heart.circle.fill"
        case .acneSkincare: return "face.smiling.inverse"
        case .petSafety: return "pawprint.circle.fill"
        }
    }

    var domainHint: ScanDomain {
        switch self {
        case .acneSkincare: return .skincare
        case .petSafety: return .pet
        default: return .food
        }
    }
}

enum RiskLevel: String, Codable, Comparable {
    case safe
    case caution
    case danger

    private var rank: Int {
        switch self {
        case .safe: return 0
        case .caution: return 1
        case .danger: return 2
        }
    }

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    var label: String {
        switch self {
        case .safe: return L10n.t("干净安心", "Clean")
        case .caution: return L10n.t("轻度留意", "Caution")
        case .danger: return L10n.t("高危红灯", "Red Flag")
        }
    }
}

enum VerdictGrade: String, Codable {
    case clean      // 85-100
    case mild       // 65-84
    case warning    // 40-64
    case danger     // 0-39

    var stampTitle: String {
        switch self {
        case .clean: return L10n.t("干净配料 · 闭眼入", "CLEAN · BUY WITH CONFIDENCE")
        case .mild: return L10n.t("轻度科技 · 偶尔解馋", "MILD · OCCASIONAL TREAT")
        case .warning: return L10n.t("科技与狠活 · 建议三思", "PROCESSED · THINK TWICE")
        case .danger: return L10n.t("高危雷区 · 放下快跑", "RED ALERT · PUT IT BACK")
        }
    }

    var shortStamp: String {
        switch self {
        case .clean: return L10n.t("干净闭眼入", "CLEAN PASS")
        case .mild: return L10n.t("轻度留意", "MILD")
        case .warning: return L10n.t("科技与狠活", "PROCESSED")
        case .danger: return L10n.t("高危劝退", "RED ALERT")
        }
    }
}

enum CabinetBucket: String, Codable, CaseIterable, Identifiable {
    case none
    case greenList
    case redList

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return L10n.t("仅记录", "Saved")
        case .greenList: return L10n.t("安心回购", "Buy Again")
        case .redList: return L10n.t("永久拉黑", "Never Buy")
        }
    }
}

struct IngredientEntry: Identifiable, Hashable {
    let id: String
    let nameZH: String
    let nameEN: String
    let aliases: [String]
    let domain: ScanDomain
    let risk: RiskLevel
    let penalty: Int
    let radars: [RadarType]
    let categoryZH: String
    let categoryEN: String
    let reasonZH: String
    let reasonEN: String
    let standardRef: String

    var displayName: String { L10n.t(nameZH, nameEN) }
    var displayCategory: String { L10n.t(categoryZH, categoryEN) }
    var displayReason: String { L10n.t(reasonZH, reasonEN) }
}

struct IngredientHit: Identifiable, Codable, Hashable {
    let id: String
    let matchedToken: String
    let nameZH: String
    let nameEN: String
    let risk: RiskLevel
    let penalty: Int
    let triggeredRadars: [RadarType]
    let categoryZH: String
    let categoryEN: String
    let reasonZH: String
    let reasonEN: String
    let standardRef: String
    let positionIndex: Int // 1-based rank in ingredient list
    let isCustomBlacklist: Bool

    var displayName: String { L10n.t(nameZH, nameEN) }
    var displayCategory: String { L10n.t(categoryZH, categoryEN) }
    var displayReason: String { L10n.t(reasonZH, reasonEN) }
}

struct StructuralAlert: Identifiable, Codable, Hashable {
    let id: String
    let titleZH: String
    let titleEN: String
    let detailZH: String
    let detailEN: String
    let risk: RiskLevel
    let penalty: Int

    var displayTitle: String { L10n.t(titleZH, titleEN) }
    var displayDetail: String { L10n.t(detailZH, detailEN) }
}

struct ScanRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var productName: String
    let rawText: String
    let normalizedTokens: [String]
    let domain: ScanDomain
    let activeRadars: [RadarType]
    let score: Int
    let grade: VerdictGrade
    let dangerCount: Int
    let cautionCount: Int
    let cleanCount: Int
    let hits: [IngredientHit]
    let structuralAlerts: [StructuralAlert]
    let headlineZH: String
    let headlineEN: String
    let createdAt: Date
    var cabinet: CabinetBucket

    var displayHeadline: String { L10n.t(headlineZH, headlineEN) }
}

struct SampleProduct: Identifiable {
    let id: String
    let nameZH: String
    let nameEN: String
    let badgeZH: String
    let badgeEN: String
    let domain: ScanDomain
    let rawTextZH: String
    let rawTextEN: String

    var displayName: String { L10n.t(nameZH, nameEN) }
    var displayBadge: String { L10n.t(badgeZH, badgeEN) }
    var rawText: String { L10n.t(rawTextZH, rawTextEN) }
}

enum SampleCatalog {
    static let all: [SampleProduct] = [
        SampleProduct(
            id: "toast_bread",
            nameZH: "网红奶香手撕吐司",
            nameEN: "Store-Bought Milk Toast",
            badgeZH: "热门面包测雷",
            badgeEN: "Bakery Trap",
            domain: .food,
            rawTextZH: "配料：小麦粉、饮用水、白砂糖、人造奶油（精炼植物油、氢化植物油、食用香精）、果葡糖浆、鸡蛋、食品添加剂（脱氢乙酸钠、丙酸钙、单双甘油脂肪酸酯、三氯蔗糖、柠檬黄、食用香精）。",
            rawTextEN: "Ingredients: Wheat Flour, Water, White Sugar, Margarine (Refined Vegetable Oil, Partially Hydrogenated Vegetable Oil, Artificial Flavor), High Fructose Corn Syrup, Eggs, Sodium Dehydroacetate, Calcium Propionate, Sucralose, Yellow 5."
        ),
        SampleProduct(
            id: "clean_yogurt",
            nameZH: "极简原味低温酸奶",
            nameEN: "Minimalist Plain Greek Yogurt",
            badgeZH: "干净模范",
            badgeEN: "Clean Benchmark",
            domain: .food,
            rawTextZH: "配料：生牛乳（≥99%）、嗜热链球菌、保加利亚乳杆菌、动物双歧杆菌。",
            rawTextEN: "Ingredients: Raw Milk (99%), Live Probiotics (Streptococcus thermophilus, Lactobacillus bulgaricus)."
        ),
        SampleProduct(
            id: "instant_noodle_soup",
            nameZH: "网红浓汤方便面/火锅丸子",
            nameEN: "Rich Broth Instant Ramen",
            badgeZH: "痛风隐形雷区",
            badgeEN: "Gout / Purine Bomb",
            domain: .food,
            rawTextZH: "配料：小麦粉、棕榈油、麦芽糊精、食用盐、白砂糖、酵母抽提物、呈味核苷酸二钠、谷氨酸钠、虾粉、浓缩海鲜粉、焦糖色、三聚磷酸钠、六偏磷酸钠、TBHQ（叔丁基对苯二酚）、食用香精。",
            rawTextEN: "Ingredients: Wheat Flour, Palm Oil, Maltodextrin, Salt, Sugar, Yeast Extract, Disodium 5'-Ribonucleotide (E635), MSG, Seafood Extract, Caramel Color (E150d), Sodium Tripolyphosphate, TBHQ (E319), Artificial Flavor."
        ),
        SampleProduct(
            id: "zero_soda",
            nameZH: "某网红「0糖0卡」气泡水",
            nameEN: "Zero-Sugar Sparkling Soda",
            badgeZH: "控糖代糖实测",
            badgeEN: "Diet Soda Check",
            domain: .food,
            rawTextZH: "配料：水、二氧化碳、赤藓糖醇、三氯蔗糖、安赛蜜、阿斯巴甜（含苯丙氨酸）、柠檬酸、苯甲酸钠、诱惑红、食用香精。",
            rawTextEN: "Ingredients: Carbonated Water, Erythritol, Sucralose, Acesulfame K, Aspartame, Citric Acid, Sodium Benzoate (E211), Red 40 (Allura Red), Artificial Flavor."
        ),
        SampleProduct(
            id: "trap_cat_food",
            nameZH: "某爆款平价「全价无谷」猫粮",
            nameEN: "Budget 'Natural' Dry Cat Food",
            badgeZH: "猫粮谷物分割法",
            badgeEN: "Pet Food Trap",
            domain: .pet,
            rawTextZH: "原料组成：鸡肉粉、玉米、大米、小麦粉、豆粕、不明动物副产品粉、鸡油、宠物饲料复合调味料、卡拉胶、BHA、BHT、焦糖色、牛磺酸。",
            rawTextEN: "Ingredients: Chicken Meal, Corn, Rice, Wheat Flour, Soy Meal, Meat By-Products, Poultry Fat, Flavor Enhancers, Carrageenan, BHA, BHT, Caramel Color, Taurine."
        ),
        SampleProduct(
            id: "clean_cat_food",
            nameZH: "高肉烘焙鲜肉全价猫粮",
            nameEN: "Baked Fresh Meat Cat Food",
            badgeZH: "干净宠粮对比",
            badgeEN: "Clean Pet Food",
            domain: .pet,
            rawTextZH: "原料组成：鲜鸡肉（52%）、鲜鸭肉（24%）、三文鱼（10%）、鸡肝、鱼油、南瓜粉、丝兰提取物、牛磺酸、维生素C。",
            rawTextEN: "Ingredients: Fresh Chicken (52%), Fresh Duck (24%), Salmon (10%), Fish Oil, Pumpkin, Yucca Extract, Taurine, Vitamin C."
        ),
        SampleProduct(
            id: "acne_cream",
            nameZH: "网红大牌抗老美白面霜",
            nameEN: "Viral Anti-Aging Glow Cream",
            badgeZH: "护肤致痘+孕慎",
            badgeEN: "Skincare Red Flag",
            domain: .skincare,
            rawTextZH: "成分：水、甘油、变性乙醇、肉豆蔻酸异丙酯、棕榈酸异丙酯、视黄醇、水杨酸、香精、羟苯丙酯、甲基异噻唑啉酮、DMDM 乙内酰脲。",
            rawTextEN: "Ingredients: Aqua, Glycerin, Alcohol Denat., Isopropyl Myristate, Isopropyl Palmitate, Retinol, Salicylic Acid, Fragrance (Parfum), Propylparaben, Methylisothiazolinone, DMDM Hydantoin."
        ),
        SampleProduct(
            id: "gentle_lotion",
            nameZH: "敏感肌修护屏障精华乳",
            nameEN: "Barrier Repair Gentle Lotion",
            badgeZH: "敏感肌安心榜",
            badgeEN: "Clean Skincare",
            domain: .skincare,
            rawTextZH: "成分：水、甘油、角鲨烷、神经酰胺 NP、泛醇、积雪草提取物、透明质酸钠、烟酰胺。",
            rawTextEN: "Ingredients: Aqua, Glycerin, Squalane, Ceramide NP, Panthenol, Centella Asiatica Extract, Sodium Hyaluronate, Niacinamide."
        )
    ]
}
