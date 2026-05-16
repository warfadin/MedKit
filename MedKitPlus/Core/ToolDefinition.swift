import Foundation

struct ToolDefinition: Identifiable, Equatable {
    enum ToolID: String {
        case vasoactiveCalculator
        case foodMenu
        case guideUpdates
    }

    let id: ToolID
    let title: String
    let subtitle: String
    let systemImage: String
    let isEnabled: Bool
}

extension ToolDefinition {
    static let availableTools: [ToolDefinition] = [
        ToolDefinition(
            id: .guideUpdates,
            title: "Guide Updates",
            subtitle: "Kılavuz versiyonları arasındaki klinik farklar",
            systemImage: "doc.text.magnifyingglass",
            isEnabled: true
        ),
        ToolDefinition(
            id: .foodMenu,
            title: "Yemek Menüsü",
            subtitle: "Çamlık ve hastane yemek listeleri",
            systemImage: "fork.knife",
            isEnabled: true
        ),
        ToolDefinition(
            id: .vasoactiveCalculator,
            title: "Vazoaktif Ajan Hesaplayıcı",
            subtitle: "Doz, infüzyon hızı ve karışım hesaplama",
            systemImage: "cross.case.fill",
            isEnabled: true
        )
    ]
}
