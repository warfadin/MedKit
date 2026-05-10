import Foundation

struct MealItem: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let kcal: String?

    init(id: UUID = UUID(), name: String, kcal: String? = nil) {
        self.id = id
        self.name = name
        self.kcal = kcal
    }
}

struct DailyCanteenMenu: Identifiable, Codable, Equatable {
    var id: Date { date }

    let date: Date
    let weekday: String
    let lunch: [MealItem]
    let ordovr: [MealItem]
    let isClosed: Bool
}

struct CanteenMenu: Codable, Equatable {
    let title: String
    let days: [DailyCanteenMenu]

    func menu(for date: Date, calendar: Calendar = .current) -> DailyCanteenMenu? {
        days.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

enum FoodMenuServiceError: LocalizedError, Equatable {
    case invalidResponse
    case requestFailed(statusCode: Int)
    case transportFailed(String)
    case unreadablePage
    case camlikSectionNotFound
    case mealSectionNotFound(String)
    case emptyMenu
    case cacheUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Yemek menüsü sunucusundan beklenmeyen bir yanıt alındı."
        case .requestFailed(let statusCode):
            "Yemek menüsü alınamadı. Sunucu \(statusCode) durum kodu döndürdü."
        case .transportFailed(let reason):
            "Yemek menüsü sayfasına ulaşılamadı: \(reason)"
        case .unreadablePage:
            "Yemek menüsü sayfası okunabilir metne dönüştürülemedi."
        case .camlikSectionNotFound:
            "Aylık Çamlık Yemek Menüsü bölümü sayfada bulunamadı."
        case .mealSectionNotFound(let section):
            "\(section) bölümü aylık Çamlık menüsünde bulunamadı."
        case .emptyMenu:
            "Aylık Çamlık menüsü bulundu ancak yemek listesi boş görünüyor."
        case .cacheUnavailable(let reason):
            "Yemek menüsü alınamadı ve kayıtlı son aylık menü bulunamadı: \(reason)"
        }
    }
}

struct FoodMenuService {
    private let menuURL: URL
    private let session: URLSession
    private let cache: FoodMenuCache
    private var calendar: Calendar

    init(
        menuURL: URL = URL(string: "https://uludag.edu.tr/yemek")!,
        session: URLSession = .shared,
        cache: FoodMenuCache = FoodMenuCache(),
        calendar: Calendar = .current
    ) {
        self.menuURL = menuURL
        self.session = session
        self.cache = cache
        self.calendar = calendar
    }

    func loadCachedMonthlyCamlikMenu() -> CanteenMenu? {
        cache.load()
    }

    func shouldRefreshMonthlyCamlikMenu(now: Date = Date()) -> Bool {
        cache.shouldRefreshToday(calendar: calendar, now: now)
    }

    func fetchMonthlyCamlikMenu(forceRemote: Bool = false) async throws -> CanteenMenu {
        let cachedMenu = cache.load()

        if !forceRemote,
           let cachedMenu,
           !cache.shouldRefreshToday(calendar: calendar) {
            return cachedMenu
        }

        do {
            return try await fetchAndCacheRemoteMonthlyCamlikMenu()
        } catch {
            if let cachedMenu {
                return cachedMenu
            }

            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            let reason = forceRemote ? "Güncel menü yenilenemedi. \(message)" : message
            throw FoodMenuServiceError.cacheUnavailable(reason)
        }
    }

    private func fetchAndCacheRemoteMonthlyCamlikMenu() async throws -> CanteenMenu {
        let menu = try await fetchRemoteMonthlyCamlikMenu()
        try cache.save(menu)
        return menu
    }

    func fetchRemoteMonthlyCamlikMenu() async throws -> CanteenMenu {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(from: menuURL)
        } catch {
            throw FoodMenuServiceError.transportFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodMenuServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw FoodMenuServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }

        guard let html = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else {
            throw FoodMenuServiceError.unreadablePage
        }

        return try parseMonthlyCamlikMenu(from: html)
    }

    func parseMonthlyCamlikMenu(from html: String) throws -> CanteenMenu {
        let lines = normalizedLines(from: html)
        let camlikBlocks = menuBlocks(named: "Çamlık Yemek Menüsü", in: lines)
        guard let monthlyBlock = camlikBlocks.max(by: { dateCount(in: $0) < dateCount(in: $1) }) else {
            throw FoodMenuServiceError.camlikSectionNotFound
        }

        guard dateCount(in: monthlyBlock) > 1 else {
            throw FoodMenuServiceError.camlikSectionNotFound
        }

        guard let lunchStart = monthlyBlock.firstIndex(of: "Öğle Yemeği") else {
            throw FoodMenuServiceError.mealSectionNotFound("Öğle Yemeği")
        }

        guard let ordovrStart = monthlyBlock.firstIndex(of: "Ordövr") else {
            throw FoodMenuServiceError.mealSectionNotFound("Ordövr")
        }

        let lunchLines = Array(monthlyBlock[(lunchStart + 1)..<ordovrStart])
        let ordovrLines = Array(monthlyBlock[(ordovrStart + 1)...])
        let lunchByDay = parsedMealsByDate(from: lunchLines)
        let ordovrByDay = parsedMealsByDate(from: ordovrLines)
        let allParsedDates = Set(lunchByDay.keys).union(ordovrByDay.keys).sorted()

        guard let firstDate = allParsedDates.first else {
            throw FoodMenuServiceError.emptyMenu
        }

        let completedDates = monthDates(containing: firstDate, plus: allParsedDates)
        let days = completedDates.map { date in
            let lunch = lunchByDay[date]?.items ?? []
            let ordovr = ordovrByDay[date]?.items ?? []
            let weekday = lunchByDay[date]?.weekday
                ?? ordovrByDay[date]?.weekday
                ?? weekdayName(for: date)
            let isClosed = lunch.isEmpty && ordovr.isEmpty
                || isHolidayOnly(lunch) && ordovr.isEmpty

            return DailyCanteenMenu(
                date: date,
                weekday: weekday,
                lunch: lunch,
                ordovr: ordovr,
                isClosed: isClosed
            )
        }

        guard days.contains(where: { !$0.isClosed }) else {
            throw FoodMenuServiceError.emptyMenu
        }

        return CanteenMenu(title: "Çamlık Yemek Menüsü", days: days)
    }

    private func menuBlocks(named title: String, in lines: [String]) -> [[String]] {
        lines.indices.compactMap { index -> [String]? in
            guard lines[index] == title else {
                return nil
            }

            let followingLines = Array(lines[(index + 1)...])
            let nextMenuIndex = followingLines.firstIndex { line in
                line.hasSuffix("Yemek Menüsü") && line != title
            } ?? followingLines.count

            return Array(followingLines[..<nextMenuIndex])
        }
    }

    private func parsedMealsByDate(from lines: [String]) -> [Date: ParsedDailyMeals] {
        var result: [Date: ParsedDailyMeals] = [:]
        var index = 0

        while index < lines.count {
            guard let date = parseDate(lines[index]) else {
                index += 1
                continue
            }

            let weekday = index + 1 < lines.count && isWeekday(lines[index + 1])
                ? lines[index + 1]
                : weekdayName(for: date)
            let hasExplicitWeekday = index + 1 < lines.count && isWeekday(lines[index + 1])
            index += hasExplicitWeekday ? 2 : 1

            var items: [MealItem] = []
            while index < lines.count, parseDate(lines[index]) == nil {
                let line = lines[index]
                if isMenuItemLine(line) {
                    items.append(MealItem(name: cleanedMealName(line)))
                }
                index += 1
            }

            result[date] = ParsedDailyMeals(weekday: weekday, items: items)
        }

        return result
    }

    private func monthDates(containing firstDate: Date, plus parsedDates: [Date]) -> [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: firstDate) else {
            return parsedDates
        }

        var dates: [Date] = []
        var currentDate = calendar.startOfDay(for: interval.start)
        while currentDate < interval.end {
            dates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return dates
    }

    private func normalizedLines(from html: String) -> [String] {
        html
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</div>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</li>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</h1>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</h2>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</h3>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</h4>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</h5>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</h6>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(
                of: "<[^>]+>",
                with: "\n",
                options: .regularExpression
            )
            .components(separatedBy: .newlines)
            .map { decodeHTMLEntities($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression) }
            .filter { !$0.isEmpty }
    }

    private func dateCount(in lines: [String]) -> Int {
        lines.filter { parseDate($0) != nil }.count
    }

    private func parseDate(_ text: String) -> Date? {
        let parts = text.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 3 else {
            return nil
        }

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.day = parts[0]
        components.month = parts[1]
        components.year = parts[2]
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }

    private func isMenuItemLine(_ line: String) -> Bool {
        let skippedLines: Set<String> = [
            "-",
            "* * *",
            "Öğle Yemeği",
            "Akşam Yemeği",
            "Ordövr"
        ]

        guard !skippedLines.contains(line) else {
            return false
        }

        if line.hasPrefix("Alerjen içeriği:") || line.hasSuffix("Yemek Menüsü") {
            return false
        }

        if line.range(of: #"^\(?\s*\d+(\s*,\s*\d+)*\s*\)?$"#, options: .regularExpression) != nil {
            return false
        }

        return !isWeekday(line)
    }

    private func cleanedMealName(_ line: String) -> String {
        decodeHTMLEntities(line)
            .replacingOccurrences(of: #"^Image:\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*-\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*\(\s*\d+(\s*,\s*\d+)*\s*\)\s*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+-\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isHolidayOnly(_ items: [MealItem]) -> Bool {
        items.count == 1 && items[0].name.localizedCaseInsensitiveContains("RESMİ TATİL")
    }

    private func isWeekday(_ text: String) -> Bool {
        [
            "Pazartesi",
            "Salı",
            "Çarşamba",
            "Perşembe",
            "Cuma",
            "Cumartesi",
            "Pazar"
        ].contains(text)
    }

    private func weekdayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.calendar = calendar
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date).capitalized(with: Locale(identifier: "tr_TR"))
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        let entities = [
            "&amp;": "&",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " ",
            "&ccedil;": "ç",
            "&Ccedil;": "Ç",
            "&ouml;": "ö",
            "&Ouml;": "Ö",
            "&uuml;": "ü",
            "&Uuml;": "Ü",
            "&scedil;": "ş",
            "&Scedil;": "Ş",
            "&gbreve;": "ğ",
            "&Gbreve;": "Ğ",
            "&imath;": "ı",
            "&Idot;": "İ"
        ]

        let namedDecoded = entities.reduce(text) { result, entity in
            result.replacingOccurrences(of: entity.key, with: entity.value)
        }

        return decodeNumericHTMLEntities(namedDecoded)
    }

    private func decodeNumericHTMLEntities(_ text: String) -> String {
        let pattern = #"&#(x[0-9A-Fa-f]+|\d+);"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        var decoded = text
        let fullRange = NSRange(decoded.startIndex..<decoded.endIndex, in: decoded)
        let matches = regex.matches(in: decoded, range: fullRange)

        for match in matches.reversed() {
            guard match.numberOfRanges == 2,
                  let entityRange = Range(match.range(at: 0), in: decoded),
                  let valueRange = Range(match.range(at: 1), in: decoded) else {
                continue
            }

            let value = String(decoded[valueRange])
            let scalarValue: UInt32?
            if value.lowercased().hasPrefix("x") {
                scalarValue = UInt32(value.dropFirst(), radix: 16)
            } else {
                scalarValue = UInt32(value, radix: 10)
            }

            guard let scalarValue,
                  let scalar = UnicodeScalar(scalarValue) else {
                continue
            }

            decoded.replaceSubrange(entityRange, with: String(Character(scalar)))
        }

        return decoded
    }
}

struct FoodMenuCache {
    private let key: String
    private let lastSuccessfulFetchDateKey: String
    private let defaults: UserDefaults

    init(
        key: String = "camlikMonthlyMenuCache",
        lastSuccessfulFetchDateKey: String? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.key = key
        self.lastSuccessfulFetchDateKey = lastSuccessfulFetchDateKey ?? "\(key)LastSuccessfulFetchDate"
        self.defaults = defaults
    }

    func save(_ menu: CanteenMenu, fetchedAt: Date = Date()) throws {
        let data = try JSONEncoder().encode(menu)
        defaults.set(data, forKey: key)
        defaults.set(fetchedAt, forKey: lastSuccessfulFetchDateKey)
    }

    func load() -> CanteenMenu? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode(CanteenMenu.self, from: data)
    }

    func lastSuccessfulFetchDate() -> Date? {
        defaults.object(forKey: lastSuccessfulFetchDateKey) as? Date
    }

    func shouldRefreshToday(calendar: Calendar = .current, now: Date = Date()) -> Bool {
        guard let lastSuccessfulFetchDate = lastSuccessfulFetchDate() else {
            return true
        }

        return !calendar.isDate(lastSuccessfulFetchDate, inSameDayAs: now)
    }
}

private struct ParsedDailyMeals {
    let weekday: String
    let items: [MealItem]
}
