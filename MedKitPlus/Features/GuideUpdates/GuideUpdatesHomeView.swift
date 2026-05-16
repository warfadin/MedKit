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
                    content
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .navigationTitle("Guide Updates")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Search guideline changes")
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Guideline Diff")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text("What changed since the previous guide?")
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(AppColors.primaryText(isDarkMode))
                .fixedSize(horizontal: false, vertical: true)
            Text("Fast, clinical deltas from old recommendations to current recommendations.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var tabPicker: some View {
        Picker("Guide Updates Section", selection: $viewModel.selectedTab) {
            ForEach(GuideUpdatesTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    private var specialtyChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SpecialtyChip(
                    title: "All",
                    isSelected: viewModel.selectedSpecialty == nil,
                    action: { viewModel.selectedSpecialty = nil }
                )

                ForEach(viewModel.specialties) { specialty in
                    SpecialtyChip(
                        title: specialty.title,
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
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 180)
        } else if let errorMessage = viewModel.errorMessage {
            GuideStateView(
                systemImage: "exclamationmark.triangle.fill",
                title: "Unable to Load",
                message: errorMessage
            )
        } else if viewModel.selectedTab == .saved {
            GuideStateView(
                systemImage: "bookmark",
                title: "No Saved Updates",
                message: "Saved updates can be wired to persistence in a later pass."
            )
        } else if viewModel.visibleTopics.isEmpty {
            GuideStateView(
                systemImage: "magnifyingglass",
                title: "No Topics",
                message: "Try a different specialty or search term."
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.visibleTopics) { topic in
                    NavigationLink {
                        GuideTopicDetailView(summary: topic)
                    } label: {
                        GuideTopicCardView(topic: topic)
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

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(topic.title)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(AppColors.primaryText(isDarkMode))
                    Text(topic.specialty.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                ImportanceBadge(importance: topic.importance)
            }

            HStack(spacing: 8) {
                GuideVersionPill(title: "Previous", value: topic.previousGuide)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                GuideVersionPill(title: "Latest", value: topic.latestGuide)
            }

            HStack(spacing: 12) {
                Label(topic.lastUpdated, systemImage: "calendar")
                Label("\(topic.updateCount) updates", systemImage: "list.bullet.rectangle")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(14)
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
        .task {
            await viewModel.load()
        }
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.summary.specialty.title)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(viewModel.summary.title)
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(AppColors.primaryText(isDarkMode))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ImportanceBadge(importance: viewModel.summary.importance)
                Text("\(viewModel.summary.updateCount) updates")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 220)
        } else if let errorMessage = viewModel.errorMessage {
            GuideStateView(
                systemImage: "exclamationmark.triangle.fill",
                title: "Topic Unavailable",
                message: errorMessage
            )
        } else if let topic = viewModel.topic {
            GuideGlassSection(title: "Summary") {
                Text(topic.overview.isEmpty ? "No overview available yet." : topic.overview)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GuideGlassSection(title: "What Changed") {
                if topic.updates.isEmpty {
                    Text("No update items are available yet.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 12) {
                        ForEach(topic.updates) { update in
                            GuideUpdateItemCardView(update: update)
                        }
                    }
                }
            }

            if let firstUpdate = topic.updates.first {
                PreviousVsCurrentView(update: firstUpdate)
            }

            GuideGlassSection(title: "Clinical Impact") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(topic.updates) { update in
                        Text(update.clinicalImpact.isEmpty ? "No clinical impact available." : update.clinicalImpact)
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
            HStack(alignment: .top, spacing: 8) {
                Text(update.title)
                    .font(.headline.weight(.heavy))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                ImportanceBadge(importance: update.importance)
            }

            Text(update.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text(update.changeType.title)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.blue.opacity(0.12), in: Capsule())
                    .foregroundStyle(.blue)

                if update.examRelevant {
                    Label("Exam", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct PreviousVsCurrentView: View {
    let update: GuideUpdateItem

    var body: some View {
        GuideGlassSection(title: "Previous vs Current") {
            VStack(spacing: 10) {
                RecommendationBlock(
                    title: "Previous",
                    systemImage: "clock.arrow.circlepath",
                    text: update.oldRecommendation
                )
                RecommendationBlock(
                    title: "Current",
                    systemImage: "checkmark.circle.fill",
                    text: update.newRecommendation
                )
                RecommendationBlock(
                    title: "Delta",
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
        GuideGlassSection(title: "Sources") {
            if sources.isEmpty {
                Text("No sources are available yet.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(sources) { source in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.name)
                                .font(.subheadline.weight(.bold))
                            Text("\(source.organization) - \(source.year) - \(source.version)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let url = URL(string: source.url), !source.url.isEmpty {
                                Link("Open source", destination: url)
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
            Text(text.isEmpty ? "No recommendation text available." : text)
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

private struct GuideVersionPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "Pending" : value)
                .font(.caption.weight(.heavy))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ImportanceBadge: View {
    let importance: GuideImportance

    var body: some View {
        Text(importance.title)
            .font(.caption2.weight(.heavy))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var color: Color {
        switch importance {
        case .practiceChanging: .red
        case .important: .orange
        case .moderate: .blue
        case .minor: .secondary
        }
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
