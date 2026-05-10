import SwiftUI

struct AppThemeControl: View {
    @AppStorage("appThemeMode") private var appThemeModeRawValue = AppThemeMode.system.rawValue

    private var appThemeMode: AppThemeMode {
        AppThemeMode.stored(appThemeModeRawValue)
    }

    var body: some View {
        Menu {
            ForEach(AppThemeMode.allCases) { mode in
                Button {
                    appThemeModeRawValue = mode.rawValue
                } label: {
                    Label(mode.title, systemImage: mode.systemImage)
                }
            }
        } label: {
            Image(systemName: appThemeMode.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 36, height: 36)
                .foregroundStyle(iconColor)
                .background(.thinMaterial, in: Circle())
        }
        .accessibilityLabel("Tema")
        .accessibilityValue(appThemeMode.title)
    }

    private var iconColor: Color {
        switch appThemeMode {
        case .system: .blue
        case .light: .orange
        case .dark: .yellow
        }
    }
}
