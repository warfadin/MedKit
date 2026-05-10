import Foundation

struct HospitalDailyMenu: Identifiable, Codable, Equatable {
    var id: Date { date }

    let date: Date
    let weekday: String
    let lunch: [String]
    let dinner: [String]
}

struct HospitalMonthlyMenu: Codable, Equatable {
    let title: String
    let month: Int
    let year: Int
    let days: [HospitalDailyMenu]

    func menu(for date: Date, calendar: Calendar = .current) -> HospitalDailyMenu? {
        days.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

enum HospitalMenuServiceError: LocalizedError, Equatable {
    case invalidResponse
    case requestFailed(statusCode: Int)
    case transportFailed(String)
    case decodingFailed(String)
    case emptyMenu
    case cacheUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Hastane yemek menüsü sunucusundan beklenmeyen bir yanıt alındı."
        case .requestFailed(let statusCode):
            "Hastane yemek menüsü alınamadı. Sunucu \(statusCode) durum kodu döndürdü."
        case .transportFailed(let reason):
            "Hastane yemek menüsüne ulaşılamadı: \(reason)"
        case .decodingFailed(let reason):
            "Hastane yemek menüsü okunamadı: \(reason)"
        case .emptyMenu:
            "Hastane yemek menüsü bulundu ancak gün listesi boş görünüyor."
        case .cacheUnavailable(let reason):
            "Hastane yemek menüsü alınamadı ve kayıtlı son menü bulunamadı: \(reason)"
        }
    }
}

struct HospitalMenuService {
    private let menuURL: URL
    private let session: URLSession
    private let cache: HospitalMenuCache
    private let calendar: Calendar

    init(
        menuURL: URL = URL(string: "https://raw.githubusercontent.com/warfadin/medkit-data/refs/heads/main/menus/hospital-menu-current.json")!,
        session: URLSession = .shared,
        cache: HospitalMenuCache = HospitalMenuCache(),
        calendar: Calendar = .current
    ) {
        self.menuURL = menuURL
        self.session = session
        self.cache = cache
        self.calendar = calendar
    }

    func loadCachedMonthlyHospitalMenu() -> HospitalMonthlyMenu? {
        cache.load()
    }

    func shouldRefreshMonthlyHospitalMenu(now: Date = Date()) -> Bool {
        cache.shouldRefreshToday(calendar: calendar, now: now)
    }

    func fetchMonthlyHospitalMenu(forceRemote: Bool = false) async throws -> HospitalMonthlyMenu {
        let cachedMenu = cache.load()

        if !forceRemote,
           let cachedMenu,
           !cache.shouldRefreshToday(calendar: calendar) {
            return cachedMenu
        }

        do {
            return try await fetchAndCacheRemoteMonthlyHospitalMenu()
        } catch {
            if let cachedMenu {
                return cachedMenu
            }

            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            let reason = forceRemote ? "Güncel menü yenilenemedi. \(message)" : message
            throw HospitalMenuServiceError.cacheUnavailable(reason)
        }
    }

    private func fetchAndCacheRemoteMonthlyHospitalMenu() async throws -> HospitalMonthlyMenu {
        let menu = try await fetchRemoteMonthlyHospitalMenu()
        try cache.save(menu)
        return menu
    }

    func fetchRemoteMonthlyHospitalMenu() async throws -> HospitalMonthlyMenu {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(from: menuURL)
        } catch {
            throw HospitalMenuServiceError.transportFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HospitalMenuServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw HospitalMenuServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }

        do {
            let menu = try HospitalMenuCoding.makeDecoder().decode(HospitalMonthlyMenu.self, from: data)
            guard !menu.days.isEmpty else {
                throw HospitalMenuServiceError.emptyMenu
            }
            return menu
        } catch let serviceError as HospitalMenuServiceError {
            throw serviceError
        } catch {
            throw HospitalMenuServiceError.decodingFailed(error.localizedDescription)
        }
    }
}

struct HospitalMenuCache {
    private let key: String
    private let lastSuccessfulFetchDateKey: String
    private let defaults: UserDefaults

    init(
        key: String = "hospitalMonthlyMenuCache",
        lastSuccessfulFetchDateKey: String? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.key = key
        self.lastSuccessfulFetchDateKey = lastSuccessfulFetchDateKey ?? "\(key)LastSuccessfulFetchDate"
        self.defaults = defaults
    }

    func save(_ menu: HospitalMonthlyMenu, fetchedAt: Date = Date()) throws {
        let data = try HospitalMenuCoding.makeEncoder().encode(menu)
        defaults.set(data, forKey: key)
        defaults.set(fetchedAt, forKey: lastSuccessfulFetchDateKey)
    }

    func load() -> HospitalMonthlyMenu? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        return try? HospitalMenuCoding.makeDecoder().decode(HospitalMonthlyMenu.self, from: data)
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

private enum HospitalMenuCoding {
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter())
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(dateFormatter())
        return encoder
    }

    private static func dateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
