import Foundation

struct GuideUpdatesIndex: Codable, Equatable {
    let schemaVersion: Int
    let contentVersion: String
    let lastUpdated: String
    let topics: [GuideTopicSummary]
}

struct GuideTopicSummary: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let specialty: GuideSpecialty
    let file: String
    let lastUpdated: String
    let latestGuide: String
    let previousGuide: String
    let importance: GuideImportance
    let updateCount: Int
    let tags: [String]

    var remoteTopicPath: String {
        "guides/\(specialtyPath)/\(id).json"
    }

    var specialtyPath: String {
        if id == "sepsis" {
            return "intensive_care"
        }
        return specialty.remotePathComponent
    }
}

struct GuideTopicDetail: Codable, Identifiable, Hashable {
    let schemaVersion: Int
    let id: String
    let title: String
    let specialty: GuideSpecialty
    let lastUpdated: String
    let overview: String
    let sources: [GuidelineSource]
    let updates: [GuideUpdateItem]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case title
        case specialty
        case lastUpdated
        case overview
        case sources
        case updates
    }

    init(
        schemaVersion: Int,
        id: String,
        title: String,
        specialty: GuideSpecialty,
        lastUpdated: String,
        overview: String,
        sources: [GuidelineSource],
        updates: [GuideUpdateItem]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.specialty = specialty
        self.lastUpdated = lastUpdated
        self.overview = overview
        self.sources = sources
        self.updates = updates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        specialty = try container.decodeIfPresent(GuideSpecialty.self, forKey: .specialty) ?? .generalInternalMedicine
        lastUpdated = try container.decodeIfPresent(String.self, forKey: .lastUpdated) ?? ""
        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        sources = try container.decodeIfPresent([GuidelineSource].self, forKey: .sources) ?? []
        updates = try container.decodeIfPresent([GuideUpdateItem].self, forKey: .updates) ?? []
    }

    var guidelineComparisonText: String? {
        let sortedSources = sources
            .filter { $0.year > 0 }
            .sorted { $0.year < $1.year }
        guard
            let oldest = sortedSources.first?.comparisonLabel,
            let newest = sortedSources.last?.comparisonLabel,
            oldest != newest
        else {
            return sortedSources.first?.comparisonLabel
        }
        return "\(oldest) -> \(newest)"
    }

    var yearComparisonText: String? {
        let years = sources
            .map(\.year)
            .filter { $0 > 0 }
            .sorted()
        guard let oldest = years.first else { return nil }
        guard let newest = years.last, newest != oldest else { return String(oldest) }
        return "\(String(oldest)) > \(String(newest))"
    }

    var latestGuideYear: Int? {
        sources
            .map(\.year)
            .filter { $0 > 0 }
            .max()
    }

    var highestUpdateImportance: GuideImportance {
        updates.map(\.importance).min() ?? .important
    }
}

struct GuidelineSource: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let organization: String
    let year: Int
    let url: String
    let version: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case organization
        case year
        case url
        case version
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        organization = try container.decodeIfPresent(String.self, forKey: .organization) ?? ""
        year = try container.decodeIfPresent(Int.self, forKey: .year) ?? 0
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? ""
    }

    var metadataText: String {
        [
            organization,
            year > 0 ? String(year) : nil,
            version
        ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " - ")
    }

    var comparisonLabel: String? {
        guard year > 0 else { return nil }
        let base = Self.guidelineBaseLabel(version: version, organization: organization, name: name)
        guard !base.isEmpty else { return String(year) }
        return "\(base)-\(String(year))"
    }

    private static func guidelineBaseLabel(version: String, organization: String, name: String) -> String {
        let trimmedVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedVersion.isEmpty,
           !trimmedVersion.isYearOnly,
           !trimmedVersion.localizedCaseInsensitiveContains("draft") {
            return abbreviation(for: trimmedVersion)
        }

        let source = organization.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? name : organization
        return abbreviation(for: source)
    }

    private static func abbreviation(for text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "–", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return "" }

        let words = cleaned
            .split { $0.isWhitespace }
            .map(String.init)
            .filter { !ignoredAbbreviationWords.contains($0.localizedLowercase) }

        guard !words.isEmpty else { return cleaned.uppercased(with: Locale(identifier: "tr_TR")) }

        if words.count <= 3 {
            return words
                .map { $0.uppercased(with: Locale(identifier: "tr_TR")) }
                .joined(separator: " ")
        }

        return words
            .compactMap { $0.first }
            .map { String($0).uppercased(with: Locale(identifier: "tr_TR")) }
            .joined()
    }

    private static let ignoredAbbreviationWords: Set<String> = [
        "ve",
        "and",
        "of",
        "the",
        "for"
    ]
}

private extension String {
    var isYearOnly: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).allSatisfy(\.isNumber)
    }
}

struct GuideUpdateItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let oldRecommendation: String
    let newRecommendation: String
    let whatChanged: String
    let clinicalImpact: String
    let changeType: GuideChangeType
    let importance: GuideImportance
    let evidenceLevel: String
    let tags: [String]
    let sourceIds: [String]
    let relevantSetting: [String]
    let examRelevant: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case oldRecommendation
        case newRecommendation
        case whatChanged
        case clinicalImpact
        case changeType
        case importance
        case evidenceLevel
        case tags
        case sourceIds
        case relevantSetting
        case examRelevant
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        oldRecommendation = try container.decodeIfPresent(String.self, forKey: .oldRecommendation) ?? ""
        newRecommendation = try container.decodeIfPresent(String.self, forKey: .newRecommendation) ?? ""
        whatChanged = try container.decodeIfPresent(String.self, forKey: .whatChanged) ?? ""
        clinicalImpact = try container.decodeIfPresent(String.self, forKey: .clinicalImpact) ?? ""
        changeType = try container.decodeIfPresent(GuideChangeType.self, forKey: .changeType) ?? .practicePoint
        importance = try container.decodeIfPresent(GuideImportance.self, forKey: .importance) ?? .important
        evidenceLevel = try container.decodeIfPresent(String.self, forKey: .evidenceLevel) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        sourceIds = try container.decodeIfPresent([String].self, forKey: .sourceIds) ?? []
        relevantSetting = try container.decodeIfPresent([String].self, forKey: .relevantSetting) ?? []
        examRelevant = try container.decodeIfPresent(Bool.self, forKey: .examRelevant) ?? false
    }
}

enum GuideChangeType: String, Codable, CaseIterable, Identifiable {
    case newRecommendation
    case removedRecommendation
    case modifiedThreshold
    case expandedIndication
    case narrowedIndication
    case changedDrugOrDose
    case changedTerminology
    case changedEvidenceLevel
    case noMajorChange
    case practicePoint

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = GuideChangeType(rawValue: value) ?? .practicePoint
    }

    var title: String {
        switch self {
        case .newRecommendation: "Yeni Öneri"
        case .removedRecommendation: "Kaldırılan Öneri"
        case .modifiedThreshold: "Değişen Eşik"
        case .expandedIndication: "Genişletilmiş Endikasyon"
        case .narrowedIndication: "Daraltılmış Endikasyon"
        case .changedDrugOrDose: "Değişen İlaç veya Doz"
        case .changedTerminology: "Terminoloji"
        case .changedEvidenceLevel: "Değişen Kanıt Düzeyi"
        case .noMajorChange: "Büyük Değişiklik Yok"
        case .practicePoint: "Pratik Nokta"
        }
    }
}

enum GuideImportance: String, Codable, CaseIterable, Identifiable, Comparable {
    case practiceChanging
    case high
    case important
    case moderate
    case minor
    case low
    case editorial

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "low":
            self = .low
        case "editorial":
            self = .editorial
        default:
            self = GuideImportance(rawValue: value) ?? .important
        }
    }

    var title: String {
        switch self {
        case .practiceChanging: "Klinik pratiği değiştirebilir"
        case .high, .important: "Çok önemli"
        case .moderate: "Nispeten önemli"
        case .minor, .low: "Önemsiz"
        case .editorial: "Editoryal"
        }
    }

    var compactTitle: String {
        switch self {
        case .practiceChanging: "Pratik değiştirir"
        default: title
        }
    }

    private var rank: Int {
        switch self {
        case .practiceChanging: 0
        case .high, .important: 1
        case .moderate: 2
        case .minor, .low: 3
        case .editorial: 4
        }
    }

    static func < (lhs: GuideImportance, rhs: GuideImportance) -> Bool {
        lhs.rank < rhs.rank
    }
}

enum GuideSpecialty: String, Codable, CaseIterable, Identifiable {
    case gastroenterologyHepatology = "Gastroenterology / Hepatology"
    case gastroenterology = "Gastroenterology"
    case hepatology = "Hepatology"
    case nephrology = "Nephrology"
    case cardiology = "Cardiology"
    case criticalCare = "Critical Care"
    case intensiveCare = "Intensive Care"
    case emergencyMedicine = "Emergency Medicine"
    case infectiousDiseases = "Infectious Diseases"
    case endocrinology = "Endocrinology"
    case pulmonology = "Pulmonology"
    case rheumatology = "Rheumatology"
    case hematology = "Hematology"
    case oncology = "Oncology"
    case generalInternalMedicine = "General Internal Medicine"

    var id: String { rawValue }
    var title: String { rawValue }

    var displayTitle: String {
        switch self {
        case .gastroenterologyHepatology: "Gastroenteroloji / Hepatoloji"
        case .gastroenterology: "Gastroenteroloji"
        case .hepatology: "Hepatoloji"
        case .nephrology: "Nefroloji"
        case .cardiology: "Kardiyoloji"
        case .criticalCare, .intensiveCare: "Yoğun Bakım"
        case .emergencyMedicine: "Acil Tıp"
        case .infectiousDiseases: "Enfeksiyon Hastalıkları"
        case .endocrinology: "Endokrinoloji"
        case .pulmonology: "Göğüs Hastalıkları"
        case .rheumatology: "Romatoloji"
        case .hematology: "Hematoloji"
        case .oncology: "Onkoloji"
        case .generalInternalMedicine: "İç Hastalıkları"
        }
    }

    var remotePathComponent: String {
        switch self {
        case .gastroenterologyHepatology: "gastroenterology"
        case .gastroenterology: "gastroenterology"
        case .hepatology: "hepatology"
        case .nephrology: "nephrology"
        case .cardiology: "cardiology"
        case .criticalCare: "critical_care"
        case .intensiveCare: "intensive_care"
        case .emergencyMedicine: "emergency_medicine"
        case .infectiousDiseases: "infectious_diseases"
        case .endocrinology: "endocrinology"
        case .pulmonology: "pulmonology"
        case .rheumatology: "rheumatology"
        case .hematology: "hematology"
        case .oncology: "oncology"
        case .generalInternalMedicine: "general_internal_medicine"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "Nefroloji":
            self = .nephrology
        case "Gastroenteroloji / Hepatoloji":
            self = .gastroenterologyHepatology
        case "Gastroenteroloji":
            self = .gastroenterology
        case "Hepatoloji":
            self = .hepatology
        case "Endokrinoloji":
            self = .endocrinology
        case "Kardiyoloji":
            self = .cardiology
        case "Göğüs Hastalıkları":
            self = .pulmonology
        case "Romatoloji":
            self = .rheumatology
        case "Enfeksiyon Hastalıkları":
            self = .infectiousDiseases
        case "Hematoloji":
            self = .hematology
        case "Onkoloji":
            self = .oncology
        case "Yoğun Bakım":
            self = .intensiveCare
        case "Acil Tıp":
            self = .emergencyMedicine
        default:
            self = GuideSpecialty(rawValue: value) ?? .generalInternalMedicine
        }
    }
}
