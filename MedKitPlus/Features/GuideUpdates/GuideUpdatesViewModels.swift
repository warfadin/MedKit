import Foundation
import Combine

enum GuideUpdatesTab: String, CaseIterable, Identifiable {
    case recent = "Recent"
    case specialties = "Specialties"
    case topics = "Topics"
    case saved = "Saved"

    var id: String { rawValue }
}

@MainActor
final class GuideUpdatesViewModel: ObservableObject {
    @Published private(set) var topics: [GuideTopicSummary] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedSpecialty: GuideSpecialty?
    @Published var selectedTab: GuideUpdatesTab = .recent

    private let service: GuideUpdatesService

    init(service: GuideUpdatesService? = nil) {
        self.service = service ?? GuideUpdatesService()
    }

    var specialties: [GuideSpecialty] {
        Array(Set(topics.map(\.specialty))).sorted { $0.title < $1.title }
    }

    var visibleTopics: [GuideTopicSummary] {
        var items = topics

        if let selectedSpecialty {
            items = items.filter { $0.specialty == selectedSpecialty }
        }

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchText.localizedLowercase
            items = items.filter { topic in
                topic.title.localizedLowercase.contains(query)
                    || topic.specialty.title.localizedLowercase.contains(query)
                    || topic.tags.contains { $0.localizedLowercase.contains(query) }
            }
        }

        switch selectedTab {
        case .recent:
            return items.sorted { $0.lastUpdated > $1.lastUpdated }
        case .specialties:
            return items.sorted { $0.specialty.title == $1.specialty.title ? $0.title < $1.title : $0.specialty.title < $1.specialty.title }
        case .topics:
            return items.sorted { $0.title < $1.title }
        case .saved:
            return []
        }
    }

    func load() async {
        guard topics.isEmpty else { return }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        let result = await service.loadIndex()
        isLoading = false

        switch result {
        case .success(let index):
            topics = index.topics
        case .failure(let error):
            topics = []
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class TopicDetailViewModel: ObservableObject {
    @Published private(set) var topic: GuideTopicDetail?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    let summary: GuideTopicSummary
    private let service: GuideUpdatesService

    init(summary: GuideTopicSummary, service: GuideUpdatesService? = nil) {
        self.summary = summary
        self.service = service ?? GuideUpdatesService()
    }

    func load() async {
        guard topic == nil else { return }
        isLoading = true
        errorMessage = nil
        let result = await service.loadTopic(summary: summary)
        isLoading = false

        switch result {
        case .success(let detail):
            topic = detail
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
