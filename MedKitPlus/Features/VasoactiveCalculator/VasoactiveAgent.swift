import Foundation

enum VasoactiveAgent: String, CaseIterable, Identifiable {
    case norepinephrine
    case adrenaline
    case dobutamine
    case dopamine

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .norepinephrine: "NA"
        case .adrenaline: "A"
        case .dobutamine: "Dob"
        case .dopamine: "Dop"
        }
    }

    var displayName: String {
        switch self {
        case .norepinephrine: "Nöradrenalin"
        case .adrenaline: "Adrenalin"
        case .dobutamine: "Dobutamin"
        case .dopamine: "Dopamin"
        }
    }

    var startingDose: Double {
        switch self {
        case .norepinephrine: 0.08
        case .adrenaline: 0.04
        case .dobutamine: 5
        case .dopamine: 5
        }
    }

    var lowDoseUpperBound: Double {
        switch self {
        case .norepinephrine: 0.1
        case .adrenaline: 0.05
        case .dobutamine: 5
        case .dopamine: 5
        }
    }

    var mediumDoseUpperBound: Double {
        switch self {
        case .norepinephrine: 0.3
        case .adrenaline: 0.2
        case .dobutamine: 10
        case .dopamine: 10
        }
    }

    var presets: [InfusionPreset] {
        switch self {
        case .norepinephrine:
            [
                InfusionPreset(name: "8 mg / 100 mL SF", drugMg: 8, volumeMl: 100),
                InfusionPreset(name: "16 mg / 100 mL SF", drugMg: 16, volumeMl: 100),
                InfusionPreset(name: "4 mg / 50 mL SF", drugMg: 4, volumeMl: 50),
                InfusionPreset(name: "32 mg / 250 mL SF", drugMg: 32, volumeMl: 250)
            ]
        case .adrenaline:
            [
                InfusionPreset(name: "4 mg / 100 mL SF", drugMg: 4, volumeMl: 100),
                InfusionPreset(name: "8 mg / 100 mL SF", drugMg: 8, volumeMl: 100),
                InfusionPreset(name: "4 mg / 50 mL SF", drugMg: 4, volumeMl: 50),
                InfusionPreset(name: "10 mg / 250 mL SF", drugMg: 10, volumeMl: 250)
            ]
        case .dobutamine:
            [
                InfusionPreset(name: "250 mg / 250 mL %5Dex", drugMg: 250, volumeMl: 250),
                InfusionPreset(name: "500 mg / 250 mL %5Dex", drugMg: 500, volumeMl: 250),
                InfusionPreset(name: "250 mg / 50 mL %5Dex", drugMg: 250, volumeMl: 50),
                InfusionPreset(name: "500 mg / 500 mL %5Dex", drugMg: 500, volumeMl: 500)
            ]
        case .dopamine:
            [
                InfusionPreset(name: "400 mg / 250 mL %5Dex", drugMg: 400, volumeMl: 250),
                InfusionPreset(name: "800 mg / 250 mL %5Dex", drugMg: 800, volumeMl: 250),
                InfusionPreset(name: "200 mg / 100 mL %5Dex", drugMg: 200, volumeMl: 100),
                InfusionPreset(name: "400 mg / 500 mL %5Dex", drugMg: 400, volumeMl: 500)
            ]
        }
    }

    var clinicalNote: String {
        switch self {
        case .norepinephrine:
            "Sepsiste ilk basamak vazopressör olarak norepinefrin önerilir. Preset ve limitler kurum protokolüyle doğrulanmalıdır."
        case .adrenaline:
            "Norepinefrin ve vazopressin sonrası yetersiz MAP durumunda ek ajan olarak değerlendirilebilir."
        case .dobutamine:
            "Düşük kardiyak debi veya miyokard disfonksiyonu düşünüldüğünde, kan basıncı ve ritim izlemiyle titre edilir."
        case .dopamine:
            "Dopaminin vazoaktif olarak kullanımı güncel sepsis kılavuzlarında rutin olarak önerilmez. Bkz: Surviving Sepsis Campaign Guidelines, 2021."
        }
    }
}
