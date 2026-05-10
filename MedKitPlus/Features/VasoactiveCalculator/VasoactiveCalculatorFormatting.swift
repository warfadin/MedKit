import Foundation

enum VasoactiveCalculatorFormatting {
    static func cleanNumber(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }
}
