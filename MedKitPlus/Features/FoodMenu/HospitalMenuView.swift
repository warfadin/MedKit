import SwiftUI

struct HospitalMenuView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var hospitalMenu: HospitalMonthlyMenu?
    @Binding var selectedDate: Date
    @Binding var selectedMode: HospitalMenuMode
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    @Binding var hasLoaded: Bool

    private let service: HospitalMenuService
    private let bottomContentPadding: CGFloat
    private let calendar = Calendar.current

    init(
        hospitalMenu: Binding<HospitalMonthlyMenu?>,
        selectedDate: Binding<Date>,
        selectedMode: Binding<HospitalMenuMode>,
        isLoading: Binding<Bool>,
        errorMessage: Binding<String?>,
        hasLoaded: Binding<Bool>,
        bottomContentPadding: CGFloat = 0,
        service: HospitalMenuService = HospitalMenuService()
    ) {
        self._hospitalMenu = hospitalMenu
        self._selectedDate = selectedDate
        self._selectedMode = selectedMode
        self._isLoading = isLoading
        self._errorMessage = errorMessage
        self._hasLoaded = hasLoaded
        self.bottomContentPadding = bottomContentPadding
        self.service = service
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var sortedDays: [HospitalDailyMenu] {
        hospitalMenu?.days.sorted { $0.date < $1.date } ?? []
    }

    var body: some View {
        ZStack {
            AppColors.background(isDarkMode).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    content
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, bottomContentPadding)
            }
        }
        .task {
            guard !hasLoaded else {
                return
            }

            hasLoaded = true
            await loadMenu()
        }
        .refreshable { await loadMenu(forceRemote: true) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                Text("Hastane")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 8)

                modePicker
            }

            Text("Yemek menüsü")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColors.primaryText(isDarkMode))
        }
    }

    private var modePicker: some View {
        Picker("Görünüm", selection: $selectedMode) {
            ForEach(HospitalMenuMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 150)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading, hospitalMenu == nil {
            statusPanel(
                systemImage: "fork.knife",
                title: "Menü yükleniyor",
                message: "Hastane yemek menüsü kontrol ediliyor."
            )
        } else if let errorMessage, hospitalMenu == nil {
            errorPanel(errorMessage)
        } else if sortedDays.isEmpty {
            statusPanel(
                systemImage: "calendar.badge.exclamationmark",
                title: "Menü bulunamadı",
                message: "Kayıtlı hastane menüsünde gösterilecek gün bulunamadı."
            )
        } else {
            switch selectedMode {
            case .day:
                dailyPager
            case .month:
                monthList
            }
        }
    }

    private var dailyPager: some View {
        TabView(selection: $selectedDate) {
            ForEach(sortedDays) { day in
                ScrollView {
                    dailyCard(day)
                        .padding(.bottom, 28 + bottomContentPadding)
                }
                .refreshable { await loadMenu(forceRemote: true) }
                .tag(day.date)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(minHeight: 600)
    }

    private var monthList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ay")
                .font(.headline.weight(.heavy))
                .foregroundStyle(AppColors.primaryText(isDarkMode))

            ForEach(sortedDays) { day in
                compactDayCard(day)
            }
        }
    }

    private func dailyCard(_ day: HospitalDailyMenu) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            dayHeader(day, titleFont: .title3.weight(.heavy))
            mealSection(title: "Öğle Yemeği", items: visibleMenuItems(day.lunch))
            mealSection(title: "Akşam Yemeği", items: visibleMenuItems(day.dinner))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppColors.panel(isDarkMode), in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topTrailing) {
            if isLoading {
                ProgressView()
                    .padding(14)
            }
        }
    }

    private func compactDayCard(_ day: HospitalDailyMenu) -> some View {
        Button {
            selectedDate = day.date
            selectedMode = .day
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                dayHeader(day, titleFont: .headline.weight(.heavy))
                compactMealPreview(title: "Öğle", items: visibleMenuItems(day.lunch))
                compactMealPreview(title: "Akşam", items: visibleMenuItems(day.dinner))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.panel(isDarkMode), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func dayHeader(_ day: HospitalDailyMenu, titleFont: Font) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(day.dayMonthText)
                .font(titleFont)
                .foregroundStyle(AppColors.primaryText(isDarkMode))

            Text(day.weekday)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)

            Spacer()

            if calendar.isDateInToday(day.date) {
                Text("Bugün")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func compactMealPreview(title: String, items: [String]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.red)
                .frame(width: 52, alignment: .leading)

            Text(items.joined(separator: ", "))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.primaryText(isDarkMode))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func mealSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(AppColors.primaryText(isDarkMode))

            if items.isEmpty {
                Text("Bugün için kayıt görünmüyor.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppColors.controlBackground(isDarkMode), in: RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        HStack(spacing: 10) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.red)

                            Text(item)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppColors.primaryText(isDarkMode))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                        .background(AppColors.controlBackground(isDarkMode), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func statusPanel(systemImage: String, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.red)

            Text(title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(AppColors.primaryText(isDarkMode))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColors.panel(isDarkMode), in: RoundedRectangle(cornerRadius: 8))
    }

    private func errorPanel(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            statusPanel(
                systemImage: "exclamationmark.triangle.fill",
                title: "Menü alınamadı",
                message: message
            )

            Button {
                Task {
                    await loadMenu(forceRemote: true)
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Tekrar dene")
                }
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.red, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func visibleMenuItems(_ items: [String]) -> [String] {
        items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    @MainActor
    private func loadMenu(forceRemote: Bool = false) async {
        let cachedMenu = service.loadCachedMonthlyHospitalMenu()
        if let cachedMenu {
            applyMenu(cachedMenu)
            errorMessage = nil
        }

        let shouldFetch = forceRemote
            || cachedMenu == nil
            || service.shouldRefreshMonthlyHospitalMenu()

        guard shouldFetch else {
            isLoading = false
            return
        }

        isLoading = hospitalMenu == nil
        if hospitalMenu == nil {
            errorMessage = nil
        }

        do {
            let menu = try await service.fetchMonthlyHospitalMenu(forceRemote: forceRemote)
            applyMenu(menu)
            errorMessage = nil
        } catch {
            if hospitalMenu == nil {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }

        isLoading = false
    }

    private func applyMenu(_ menu: HospitalMonthlyMenu) {
        hospitalMenu = menu
        selectedDate = menu.menu(for: selectedDate)?.date
            ?? menu.menu(for: Date())?.date
            ?? menu.days.first?.date
            ?? selectedDate
    }
}

#Preview {
    HospitalMenuView(
        hospitalMenu: .constant(nil),
        selectedDate: .constant(Date()),
        selectedMode: .constant(.day),
        isLoading: .constant(false),
        errorMessage: .constant(nil),
        hasLoaded: .constant(false)
    )
}

enum HospitalMenuMode: String, CaseIterable, Identifiable {
    case day
    case month

    var id: Self { self }

    var title: String {
        switch self {
        case .day:
            "Gün"
        case .month:
            "Ay"
        }
    }
}

private extension HospitalDailyMenu {
    var dayMonthText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
}
