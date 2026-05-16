import Foundation
import Combine

struct GuideTopicCardMetadata: Equatable {
    let yearComparisonText: String?
    let latestGuideYear: Int?
    let importance: GuideImportance
}

final class GuideSavedTopicsStore {
    static let didChangeNotification = Notification.Name("GuideSavedTopicsStore.didChange")

    private let defaults: UserDefaults
    private let key = "guideUpdates.savedTopicIDs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var savedIDs: Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    func isSaved(_ id: String) -> Bool {
        savedIDs.contains(id)
    }

    func toggle(_ id: String) -> Bool {
        var ids = savedIDs
        let isSaved: Bool
        if ids.contains(id) {
            ids.remove(id)
            isSaved = false
        } else {
            ids.insert(id)
            isSaved = true
        }
        defaults.set(Array(ids).sorted(), forKey: key)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        return isSaved
    }
}

enum GuideUpdatesTab: String, CaseIterable, Identifiable {
    case recent = "Recent"
    case specialties = "Specialties"
    case topics = "Topics"
    case saved = "Saved"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .recent: "Güncel"
        case .specialties: "Branşlar"
        case .topics: "Konular"
        case .saved: "Kaydedilenler"
        }
    }
}

@MainActor
final class GuideUpdatesViewModel: ObservableObject {
    @Published private(set) var topics: [GuideTopicSummary] = []
    @Published private(set) var cardMetadata: [String: GuideTopicCardMetadata] = [:]
    @Published private(set) var savedTopicIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published var errorMessage: String?
    @Published var refreshMessage: String?
    @Published var searchText = ""
    @Published var selectedSpecialty: GuideSpecialty?
    @Published var selectedTab: GuideUpdatesTab = .recent

    private let service: GuideUpdatesService
    private let savedStore: GuideSavedTopicsStore
    private var cancellables = Set<AnyCancellable>()

    init(service: GuideUpdatesService? = nil, savedStore: GuideSavedTopicsStore? = nil) {
        self.service = service ?? GuideUpdatesService()
        let resolvedSavedStore = savedStore ?? GuideSavedTopicsStore()
        self.savedStore = resolvedSavedStore
        savedTopicIDs = resolvedSavedStore.savedIDs

        NotificationCenter.default.publisher(for: GuideSavedTopicsStore.didChangeNotification)
            .sink { [weak self] _ in
                self?.savedTopicIDs = resolvedSavedStore.savedIDs
            }
            .store(in: &cancellables)
    }

    var specialties: [GuideSpecialty] {
        Array(Set(topics.map(\.specialty))).sorted { $0.displayTitle < $1.displayTitle }
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
                    || topic.specialty.displayTitle.localizedLowercase.contains(query)
                    || topic.tags.contains { $0.localizedLowercase.contains(query) }
            }
        }

        if selectedTab == .saved {
            items = items.filter { savedTopicIDs.contains($0.id) }
        }

        switch selectedTab {
        case .recent:
            return items.sorted(by: sortByLatestGuideYear)
        case .specialties:
            return items.sorted(by: sortByLatestGuideYear)
        case .topics:
            return items.sorted(by: sortByLatestGuideYear)
        case .saved:
            return items.sorted(by: sortByLatestGuideYear)
        }
    }

    func load() async {
        guard topics.isEmpty else { return }
        await refresh(showLoading: true)
    }

    func refresh() async {
        await refresh(showLoading: topics.isEmpty)
    }

    func isSaved(_ topic: GuideTopicSummary) -> Bool {
        savedTopicIDs.contains(topic.id)
    }

    private func refresh(showLoading: Bool) async {
        if showLoading {
            isLoading = true
        } else {
            isRefreshing = true
        }
        errorMessage = nil
        refreshMessage = nil
        let result = await service.loadIndex()

        switch result {
        case .success(let index):
            topics = index.topics
            let didRefreshAllTopics = await service.refreshCachedTopics(index.topics)
            await loadCardMetadata(for: index.topics)
            if !didRefreshAllTopics {
                refreshMessage = "Bazı konular yenilenemedi. Mevcut içerik korundu."
            }
        case .failure(let error):
            if topics.isEmpty {
                errorMessage = error.localizedDescription
            } else {
                refreshMessage = "Yenileme başarısız oldu. Mevcut içerik korundu."
            }
        }

        if showLoading {
            isLoading = false
        } else {
            isRefreshing = false
        }
    }

    private func loadCardMetadata(for topics: [GuideTopicSummary]) async {
        var loadedMetadata: [String: GuideTopicCardMetadata] = [:]
        for topic in topics {
            let result = await service.loadTopic(summary: topic)
            guard case .success(let detail) = result else { continue }
            loadedMetadata[topic.id] = GuideTopicCardMetadata(
                yearComparisonText: detail.yearComparisonText,
                latestGuideYear: detail.latestGuideYear,
                importance: detail.highestUpdateImportance
            )
        }
        cardMetadata = loadedMetadata
    }

    private func sortByLatestGuideYear(_ lhs: GuideTopicSummary, _ rhs: GuideTopicSummary) -> Bool {
        let lhsYear = cardMetadata[lhs.id]?.latestGuideYear
        let rhsYear = cardMetadata[rhs.id]?.latestGuideYear

        if let lhsYear, let rhsYear, lhsYear != rhsYear {
            return lhsYear > rhsYear
        }

        if lhsYear != nil, rhsYear == nil {
            return true
        }

        if lhsYear == nil, rhsYear != nil {
            return false
        }

        if lhs.lastUpdated != rhs.lastUpdated {
            return lhs.lastUpdated > rhs.lastUpdated
        }

        return lhs.title < rhs.title
    }
}

@MainActor
final class TopicDetailViewModel: ObservableObject {
    @Published private(set) var topic: GuideTopicDetail?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaved = false
    @Published var errorMessage: String?

    let summary: GuideTopicSummary
    private let service: GuideUpdatesService
    private let savedStore: GuideSavedTopicsStore

    init(
        summary: GuideTopicSummary,
        service: GuideUpdatesService? = nil,
        savedStore: GuideSavedTopicsStore? = nil
    ) {
        self.summary = summary
        self.service = service ?? GuideUpdatesService()
        let resolvedSavedStore = savedStore ?? GuideSavedTopicsStore()
        self.savedStore = resolvedSavedStore
        isSaved = resolvedSavedStore.isSaved(summary.id)
    }

    var reviewDate: String {
        topic?.lastUpdated ?? summary.lastUpdated
    }

    var guidelineComparisonText: String? {
        topic?.guidelineComparisonText
    }

    var changeCountText: String {
        let count = topic?.updates.count ?? summary.updateCount
        return "\(count) değişiklik"
    }

    func toggleSaved() {
        isSaved = savedStore.toggle(summary.id)
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
