import Foundation

enum VasoactiveDoseCalculator {
    static let focusRate: Double = 30
    static let focusProgress: Double = 0.72

    static func concentrationMcgPerMl(drugMg: Double, volumeMl: Double) -> Double {
        guard volumeMl > 0 else { return 0 }
        return drugMg * 1000 / volumeMl
    }

    static func infusionRate(dose: Double, weightKg: Int, concentrationMcgPerMl: Double) -> Double {
        guard concentrationMcgPerMl > 0 else { return 0 }
        return dose * Double(weightKg) * 60 / concentrationMcgPerMl
    }

    static func maxSliderDose(for agent: VasoactiveAgent, preset: InfusionPreset, weightKg: Int) -> Double {
        let practicalDoseAt30cc = 30 * preset.concentrationMcgPerMl / (Double(weightKg) * 60)

        switch agent {
        case .norepinephrine:
            return max(0.8, min(1.5, practicalDoseAt30cc * 2.1))
        case .adrenaline:
            return max(0.6, min(1.2, practicalDoseAt30cc * 2.0))
        case .dobutamine:
            return 25
        case .dopamine:
            return 25
        }
    }

    static func intensity(for agent: VasoactiveAgent, dose: Double) -> DoseIntensity {
        switch agent {
        case .norepinephrine:
            if dose < 0.1 { return .low }
            if dose < 0.3 { return .medium }
            return .high
        case .adrenaline:
            if dose < 0.05 { return .low }
            if dose < 0.2 { return .medium }
            return .high
        case .dobutamine:
            if dose < 5 { return .low }
            if dose <= 10 { return .medium }
            return .high
        case .dopamine:
            if dose < 5 { return .low }
            if dose < 10 { return .medium }
            return .high
        }
    }

    static func manualPreset(drugMgText: String, volumeMlText: String) -> InfusionPreset? {
        guard
            let mg = normalizedDouble(from: drugMgText),
            let ml = normalizedDouble(from: volumeMlText),
            mg > 0,
            ml > 0
        else { return nil }

        return InfusionPreset(name: "Manuel", drugMg: mg, volumeMl: ml)
    }

    static func dose(
        forProgress progress: Double,
        range: ClosedRange<Double>,
        concentrationMcgPerMl: Double,
        weightKg: Int
    ) -> Double {
        let maxRate = infusionRate(dose: range.upperBound, weightKg: weightKg, concentrationMcgPerMl: concentrationMcgPerMl)
        guard maxRate > 0 else { return range.lowerBound }

        let clampedProgress = min(max(progress, 0), 1)
        let targetRate: Double

        if maxRate <= focusRate {
            targetRate = clampedProgress * maxRate
        } else if clampedProgress <= focusProgress {
            targetRate = (clampedProgress / focusProgress) * focusRate
        } else {
            let tailProgress = (clampedProgress - focusProgress) / (1 - focusProgress)
            targetRate = focusRate + tailProgress * (maxRate - focusRate)
        }

        let targetDose = targetRate * concentrationMcgPerMl / (Double(weightKg) * 60)
        return min(max(targetDose, range.lowerBound), range.upperBound)
    }

    static func progress(
        forDose dose: Double,
        range: ClosedRange<Double>,
        concentrationMcgPerMl: Double,
        weightKg: Int
    ) -> Double {
        let maxRate = infusionRate(dose: range.upperBound, weightKg: weightKg, concentrationMcgPerMl: concentrationMcgPerMl)
        guard maxRate > 0 else { return 0 }

        let rate = infusionRate(dose: dose, weightKg: weightKg, concentrationMcgPerMl: concentrationMcgPerMl)
        let clampedRate = min(max(rate, 0), maxRate)

        if maxRate <= focusRate {
            return clampedRate / maxRate
        }

        if clampedRate <= focusRate {
            return (clampedRate / focusRate) * focusProgress
        }

        let tailProgress = (clampedRate - focusRate) / (maxRate - focusRate)
        return focusProgress + tailProgress * (1 - focusProgress)
    }

    static func effectText(for agent: VasoactiveAgent, dose: Double) -> String {
        switch agent {
        case .norepinephrine:
            if dose < 0.1 { return "Düşük doz: baskın alfa vazokonstriksiyon, MAP desteği." }
            if dose < 0.3 { return "Orta doz: güçlü vazopressör etki, perfüzyon ve laktat yakın izlenmeli." }
            return "Yüksek doz: belirgin vazopressör gereksinimi, ek ajan ve şok nedeni yeniden değerlendirilmeli."
        case .adrenaline:
            if dose < 0.05 { return "Düşük doz: beta-1 inotrop/kronotrop etki belirginleşir." }
            if dose < 0.2 { return "Orta doz: inotropi ile birlikte alfa vazopressör etki artar." }
            return "Yüksek doz: alfa vazokonstriksiyon, taşiaritmi ve laktat artışı açısından dikkat."
        case .dobutamine:
            if dose < 3 { return "Düşük doz: hafif beta-1 inotrop etki." }
            if dose <= 10 { return "3-10 mcg/kg/dk: baskın inotrop etki, kardiyak debi desteği." }
            if dose <= 20 { return "15-20 mcg/kg/dk: inotrop etkiye ek vazopressör/taşikardik yanıt görülebilir." }
            return "Çok yüksek doz: aritmi, iskemi ve hipotansiyon açısından dikkat."
        case .dopamine:
            if dose < 3 { return "Düşük doz: dopaminerjik etki; renal koruma amacıyla kullanımı önerilmez." }
            if dose < 10 { return "Orta doz: beta-1 inotrop/kronotrop etki baskın." }
            return "Yüksek doz: alfa vazopressör etki, taşiaritmi riski artar."
        }
    }

    static func recommendation(for agent: VasoactiveAgent, dose: Double, rate: Double) -> String {
        switch agent {
        case .norepinephrine:
            if dose >= 0.25 {
                return "MAP yetersizse norepinefrini sürekli artırmak yerine vazopressin eklenmesi klinik olarak değerlendirilebilir."
            }
            if rate > 30 {
                return "Bu karışım ve kiloda hız 30 cc/h üstüne çıktı; daha konsantre karışım veya ek ajan ihtiyacı değerlendirilebilir."
            }
            return "Ekstravazasyon, periferik dolaşım ve hedef MAP düzenli izlenmeli."
        case .adrenaline:
            if dose >= 0.2 {
                return "Taşikardi, aritmi, laktat yükselmesi ve miyokardiyal iskemi açısından yakın izlem gerekir."
            }
            return "Şok tipine göre inotrop/vazopressör hedef yeniden değerlendirilmelidir."
        case .dobutamine:
            if dose >= 10 {
                return "Yüksek dozlarda taşikardi, aritmi ve hipotansiyon gelişebilir; volüm durumu ve vazopressör ihtiyacı kontrol edilmeli."
            }
            return "Kardiyak debi, kan basıncı ve ritim yanıtına göre titre edilir."
        case .dopamine:
            return "Sepsiste ilk seçenek değildir; aritmi riski ve norepinefrin erişimi özellikle değerlendirilmelidir."
        }
    }

    private static func normalizedDouble(from text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }
}
