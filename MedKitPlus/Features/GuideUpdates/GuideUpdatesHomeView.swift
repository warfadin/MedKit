import SwiftUI

struct GuideUpdatesHomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = GuideUpdatesViewModel()

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        ZStack {
            AppColors.background(isDarkMode).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    tabPicker
                    specialtyChips
                    refreshBanner
                    content
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .navigationTitle("Kılavuz Güncellemeleri")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Ara")
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private var refreshBanner: some View {
        if let refreshMessage = viewModel.refreshMessage {
            Text(refreshMessage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Önceki kılavuzdan bu yana ne değişti?")
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(AppColors.primaryText(isDarkMode))
                .fixedSize(horizontal: false, vertical: true)
            Text("Kılavuz sürümleri arasındaki klinik açıdan önemli değişiklikleri karşılaştır.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var tabPicker: some View {
        Picker("Kılavuz güncellemeleri bölümü", selection: $viewModel.selectedTab) {
            ForEach(GuideUpdatesTab.allCases) { tab in
                Text(tab.displayTitle).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    private var specialtyChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SpecialtyChip(
                    title: "Tümü",
                    isSelected: viewModel.selectedSpecialty == nil,
                    action: { viewModel.selectedSpecialty = nil }
                )

                ForEach(viewModel.specialties) { specialty in
                    SpecialtyChip(
                        title: specialty.displayTitle,
                        isSelected: viewModel.selectedSpecialty == specialty,
                        action: { viewModel.selectedSpecialty = specialty }
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Yükleniyor")
                .frame(maxWidth: .infinity, minHeight: 180)
        } else if let errorMessage = viewModel.errorMessage {
            GuideStateView(
                systemImage: "exclamationmark.triangle.fill",
                title: "Yüklenemedi",
                message: errorMessage
            )
        } else if viewModel.selectedTab == .saved && viewModel.visibleTopics.isEmpty {
            GuideStateView(
                systemImage: "bookmark",
                title: "Henüz kaydedilen konu yok",
                message: "Konulara daha sonra hızlı erişmek için kaydedin."
            )
        } else if viewModel.visibleTopics.isEmpty {
            GuideStateView(
                systemImage: "magnifyingglass",
                title: "Güncelleme bulunamadı",
                message: "Farklı bir branş veya arama terimi deneyin."
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.visibleTopics) { topic in
                    NavigationLink {
                        GuideTopicDetailView(summary: topic)
                    } label: {
                        GuideTopicCardView(
                            topic: topic,
                            metadata: viewModel.cardMetadata[topic.id],
                            isSaved: viewModel.isSaved(topic)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct GuideTopicCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let topic: GuideTopicSummary
    let metadata: GuideTopicCardMetadata?
    let isSaved: Bool

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(topic.title)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(AppColors.primaryText(isDarkMode))
                        .fixedSize(horizontal: false, vertical: true)

                    if let yearComparisonText = metadata?.yearComparisonText {
                        Text(yearComparisonText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                }

                Spacer(minLength: 8)

                ImportanceBadge(importance: metadata?.importance ?? topic.importance, compact: true)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            if isSaved {
                HStack {
                    Spacer()
                    Image(systemName: "bookmark.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.blue)
                        .accessibilityLabel("Kaydedildi")
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(isDarkMode ? 0.08 : 0.35), lineWidth: 1)
        )
    }
}

struct GuideTopicDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: TopicDetailViewModel

    init(summary: GuideTopicSummary) {
        _viewModel = StateObject(wrappedValue: TopicDetailViewModel(summary: summary))
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        ZStack {
            AppColors.background(isDarkMode).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    detailHeader
                    detailContent
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .navigationTitle(viewModel.summary.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.toggleSaved()
                } label: {
                    Image(systemName: viewModel.isSaved ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(viewModel.isSaved ? "Kaydı kaldır" : "Kaydet")
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.summary.title)
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(AppColors.primaryText(isDarkMode))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 7) {
                if let guidelineComparisonText = viewModel.guidelineComparisonText {
                    Text(guidelineComparisonText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text("•")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Text(viewModel.changeCountText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Text("Güncelliğin kontrol edildiği tarih: \(viewModel.reviewDate)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if viewModel.isLoading {
            ProgressView("Yükleniyor")
                .frame(maxWidth: .infinity, minHeight: 220)
        } else if let errorMessage = viewModel.errorMessage {
            GuideStateView(
                systemImage: "exclamationmark.triangle.fill",
                title: "Konu kullanılamıyor",
                message: errorMessage
            )
        } else if let topic = viewModel.topic {
            GuideGlassSection(title: "Özet") {
                Text(topic.overview.isEmpty ? "Henüz özet yok." : topic.overview)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let firstUpdate = topic.updates.first {
                PreviousVsCurrentView(update: firstUpdate)
            }

            GuideGlassSection(title: "Ne Değişti?") {
                if topic.updates.isEmpty {
                    Text("Güncelleme bulunamadı.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 12) {
                        ForEach(topic.updates) { update in
                            GuideUpdateItemCardView(update: update)
                        }
                    }
                }
            }

            GuideGlassSection(title: "Klinik Etki") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(topic.updates) { update in
                        Text(update.clinicalImpact.isEmpty ? "Klinik etki bilgisi yok." : update.clinicalImpact)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            GuidelineSourcesView(sources: topic.sources)
        }
    }
}

struct GuideUpdateItemCardView: View {
    let update: GuideUpdateItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(update.title)
                .font(.headline.weight(.heavy))
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ImportanceBadge(importance: update.importance)
                    ChangeTypeBadge(changeType: update.changeType)
                }
            }

            Text(update.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct PreviousVsCurrentView: View {
    let update: GuideUpdateItem

    var body: some View {
        GuideGlassSection(title: "Önceki / Güncel") {
            VStack(spacing: 10) {
                RecommendationBlock(
                    title: "Önceki",
                    systemImage: "clock.arrow.circlepath",
                    text: update.oldRecommendation
                )
                RecommendationBlock(
                    title: "Güncel",
                    systemImage: "checkmark.circle.fill",
                    text: update.newRecommendation
                )
                RecommendationBlock(
                    title: "Fark",
                    systemImage: "arrow.triangle.2.circlepath",
                    text: update.whatChanged
                )
            }
        }
    }
}

struct GuidelineSourcesView: View {
    let sources: [GuidelineSource]

    var body: some View {
        GuideGlassSection(title: "Kaynaklar") {
            if sources.isEmpty {
                Text("Kaynaklar kullanılamıyor.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(sources) { source in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.name)
                                .font(.subheadline.weight(.bold))
                            Text(source.metadataText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let url = URL(string: source.url), !source.url.isEmpty {
                                Link("Kaynağı aç", destination: url)
                                    .font(.caption.weight(.bold))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct GuideGlassSection<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.heavy))
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(colorScheme == .dark ? 0.08 : 0.35), lineWidth: 1)
        )
    }
}

private struct RecommendationBlock: View {
    let title: String
    let systemImage: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(text.isEmpty ? "Öneri metni yok." : text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SpecialtyChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct ImportanceBadge: View {
    let importance: GuideImportance
    var compact = false

    var body: some View {
        Text(compact ? importance.compactTitle : importance.title)
            .font(.caption2.weight(.heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var color: Color {
        switch importance {
        case .practiceChanging: .red
        case .high, .important: .orange
        case .moderate: .blue
        case .minor, .low, .editorial: .secondary
        }
    }
}

private struct ChangeTypeBadge: View {
    let changeType: GuideChangeType

    var body: some View {
        Text(changeType.title)
            .font(.caption2.weight(.heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.blue.opacity(0.12), in: Capsule())
            .foregroundStyle(.blue)
    }
}

private struct GuideStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline.weight(.heavy))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        GuideUpdatesHomeView()
    }
}
