import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    private let tools = ToolDefinition.availableTools

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background(isDarkMode).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        toolList
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MedKit+")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.blue)
                Text("Araçlar")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.primaryText(isDarkMode))
            }

            Spacer()

            AppThemeControl()
        }
    }

    private var toolList: some View {
        VStack(spacing: 10) {
            ForEach(tools) { tool in
                NavigationLink {
                    destination(for: tool)
                } label: {
                    ToolCard(tool: tool, isDarkMode: isDarkMode)
                }
                .buttonStyle(.plain)
                .disabled(!tool.isEnabled)
            }
        }
    }

    @ViewBuilder
    private func destination(for tool: ToolDefinition) -> some View {
        switch tool.id {
        case .vasoactiveCalculator:
            VasoactiveCalculatorView()
        case .foodMenu:
            FoodMenuView()
        case .guideUpdates:
            GuideUpdatesHomeView()
        }
    }
}

private struct ToolCard: View {
    let tool: ToolDefinition
    let isDarkMode: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tool.systemImage)
                .font(.system(size: 18, weight: .bold))
                .frame(width: 44, height: 44)
                .foregroundStyle(.white)
                .background(.blue, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(tool.title)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(AppColors.primaryText(isDarkMode))
                Text(tool.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.panel(isDarkMode), in: RoundedRectangle(cornerRadius: 8))
        .opacity(tool.isEnabled ? 1 : 0.55)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
