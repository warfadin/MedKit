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
}

struct GuidelineSource: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let organization: String
    let year: Int
    let url: String
    let version: String
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

    var title: String {
        switch self {
        case .newRecommendation: "New"
        case .removedRecommendation: "Removed"
        case .modifiedThreshold: "Threshold"
        case .expandedIndication: "Expanded"
        case .narrowedIndication: "Narrowed"
        case .changedDrugOrDose: "Drug / Dose"
        case .changedTerminology: "Terminology"
        case .changedEvidenceLevel: "Evidence"
        case .noMajorChange: "No Major Change"
        case .practicePoint: "Practice Point"
        }
    }
}

enum GuideImportance: String, Codable, CaseIterable, Identifiable, Comparable {
    case practiceChanging
    case important
    case moderate
    case minor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .practiceChanging: "Practice Changing"
        case .important: "Important"
        case .moderate: "Moderate"
        case .minor: "Minor"
        }
    }

    private var rank: Int {
        switch self {
        case .practiceChanging: 0
        case .important: 1
        case .moderate: 2
        case .minor: 3
        }
    }

    static func < (lhs: GuideImportance, rhs: GuideImportance) -> Bool {
        lhs.rank < rhs.rank
    }
}

enum GuideSpecialty: String, Codable, CaseIterable, Identifiable {
    case gastroenterologyHepatology = "Gastroenterology / Hepatology"
    case nephrology = "Nephrology"
    case cardiology = "Cardiology"
    case criticalCare = "Critical Care"
    case infectiousDiseases = "Infectious Diseases"
    case endocrinology = "Endocrinology"
    case pulmonology = "Pulmonology"
    case hematology = "Hematology"
    case oncology = "Oncology"
    case generalInternalMedicine = "General Internal Medicine"

    var id: String { rawValue }
    var title: String { rawValue }
}
