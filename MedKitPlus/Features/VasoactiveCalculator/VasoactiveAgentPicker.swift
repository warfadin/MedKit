import SwiftUI

struct VasoactiveAgentPicker: View {
    @Binding var selectedAgent: VasoactiveAgent
    let isDarkMode: Bool

    private let agents = VasoactiveAgent.allCases

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 8) {
                ForEach(agents) { agent in
                    Button {
                        selectedAgent = agent
                    } label: {
                        Text(agent.shortName)
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .foregroundStyle(selectedAgent == agent ? .white : AppColors.primaryText(isDarkMode))
                            .background(selectedAgent == agent ? VasoactiveAgentTheme.color(for: agent) : AppColors.controlBackground(isDarkMode))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(agent.displayName)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        selectAgent(at: gesture.location.x, totalWidth: proxy.size.width)
                    }
            )
        }
        .frame(height: 44)
    }

    private func selectAgent(at xPosition: CGFloat, totalWidth: CGFloat) {
        guard totalWidth > 0 else { return }
        let clampedX = min(max(xPosition, 0), totalWidth - 0.1)
        let rawIndex = Int((clampedX / totalWidth) * CGFloat(agents.count))
        let index = min(max(rawIndex, 0), agents.count - 1)
        selectedAgent = agents[index]
    }
}
