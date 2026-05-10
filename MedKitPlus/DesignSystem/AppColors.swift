import SwiftUI

enum AppColors {
    static func background(_ dark: Bool) -> Color {
        dark ? Color(red: 0.06, green: 0.07, blue: 0.09) : Color(red: 0.95, green: 0.97, blue: 0.98)
    }

    static func panel(_ dark: Bool) -> Color {
        dark ? Color(red: 0.11, green: 0.12, blue: 0.15) : .white
    }

    static func controlBackground(_ dark: Bool) -> Color {
        dark ? Color(red: 0.16, green: 0.17, blue: 0.21) : Color(red: 0.91, green: 0.94, blue: 0.96)
    }

    static func fieldBackground(_ dark: Bool) -> Color {
        dark ? Color(red: 0.08, green: 0.09, blue: 0.12) : .white
    }

    static func primaryText(_ dark: Bool) -> Color {
        dark ? .white : Color(red: 0.08, green: 0.10, blue: 0.13)
    }
}
