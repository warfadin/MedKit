import Foundation

struct InfusionPreset: Identifiable, Equatable {
    let name: String
    let drugMg: Double
    let volumeMl: Double

    var id: String { "\(name)-\(drugMg)-\(volumeMl)" }
    var concentrationMcgPerMl: Double {
        VasoactiveDoseCalculator.concentrationMcgPerMl(drugMg: drugMg, volumeMl: volumeMl)
    }
}
