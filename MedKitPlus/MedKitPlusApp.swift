import SwiftUI

@main
struct MedKitPlusApp: App {
    @AppStorage("appThemeMode") private var appThemeModeRawValue = AppThemeMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(AppThemeMode.stored(appThemeModeRawValue).preferredColorScheme)
        }
    }
}
