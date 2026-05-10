import Foundation

enum DoseIntensity {
    case low
    case medium
    case high

    var label: String {
        switch self {
        case .low: "Düşük doz"
        case .medium: "Orta doz"
        case .high: "Yüksek doz"
        }
    }
}
