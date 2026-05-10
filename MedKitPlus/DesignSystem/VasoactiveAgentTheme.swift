import SwiftUI

enum VasoactiveAgentTheme {
    static func color(for agent: VasoactiveAgent) -> Color {
        switch agent {
        case .norepinephrine: .blue
        case .adrenaline: .pink
        case .dobutamine: .purple
        case .dopamine: .orange
        }
    }

    static func color(for intensity: DoseIntensity) -> Color {
        switch intensity {
        case .low: .green
        case .medium: Color(red: 0.78, green: 0.48, blue: 0.02)
        case .high: .red
        }
    }
}
