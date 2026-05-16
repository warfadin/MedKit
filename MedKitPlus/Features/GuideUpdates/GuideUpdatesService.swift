import Foundation
import OSLog

enum GuideUpdatesServiceError: LocalizedError {
    case noReadableIndex
    case noReadableTopic(String)
    case invalidJSON(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .noReadableIndex:
            "Kılavuz güncellemeleri listesi yüklenemedi."
        case .noReadableTopic(let id):
            "Kılavuz konusu yüklenemedi: \(id)"
        case .invalidJSON(let context):
            "Kılavuz güncellemeleri verisi geçersiz: \(context)"
        case .network(let context):
            "Kılavuz güncellemeleri ağ isteği başarısız oldu: \(context)"
        }
    }
}

final class GuideDataService {
    private let remoteRootURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let fileManager: FileManager
    private let logger = Logger(subsystem: "de.mehmetataman.medkit", category: "GuideDataService")

    init(
        remoteRootURL: URL = URL(string: "https://raw.githubusercontent.com/warfadin/medkit-data/main")!,
        session: URLSession = .shared,
        fileManager: FileManager = .default
    ) {
        self.remoteRootURL = remoteRootURL
        self.session = session
        self.fileManager = fileManager
    }

    func loadIndex() async -> Result<GuideUpdatesIndex, Error> {
        do {
            let index = try readBundledIndex()
            log("fallback source used: bundled index")
            return .success(index)
        } catch {
            log("fallback bundled index failed: \(error.localizedDescription)")
            return .failure(GuideUpdatesServiceError.noReadableIndex)
        }
    }

    func loadTopic(summary: GuideTopicSummary) async -> Result<GuideTopicDetail, Error> {
        do {
            let detail = try await loadRemoteTopic(summary: summary)
            return .success(detail)
        } catch {
            log("remote topic failed for \(summary.id): \(error.localizedDescription)")

            if let cachedTopic = try? readCachedTopic(summary: summary) {
                log("fallback source used: cache for \(summary.remoteTopicPath)")
                return .success(cachedTopic)
            }

            if let bundledTopic = try? readBundledTopic(file: summary.file) {
                log("fallback source used: bundled topic for \(summary.file)")
                return .success(bundledTopic)
            }

            return .failure(error)
        }
    }

    func refreshCachedTopics(_ topics: [GuideTopicSummary]) async -> Bool {
        log("refresh started: \(topics.count) topics")
        var didCompleteEveryTopic = true
        for topic in topics {
            let didCompleteTopic = await refreshCachedTopic(topic)
            didCompleteEveryTopic = didCompleteEveryTopic && didCompleteTopic
        }
        return didCompleteEveryTopic
    }

    func remoteURL(for summary: GuideTopicSummary) -> URL {
        remoteRootURL.appendingPathComponent(summary.remoteTopicPath)
    }

    private func refreshCachedTopic(_ summary: GuideTopicSummary) async -> Bool {
        clearLegacySepsisCacheIfNeeded(for: summary)
        let url = remoteURL(for: summary)
        log("URL checked: \(url.absoluteString)")

        let data: Data
        do {
            data = try await fetchRemoteData(from: url)
        } catch {
            log("refresh failed but cache retained: \(summary.remoteTopicPath) - \(error.localizedDescription)")
            return false
        }

        do {
            _ = try decoder.decode(GuideTopicDetail.self, from: data)
            log("decode success: \(summary.remoteTopicPath)")
        } catch {
            log("refresh failed but cache retained: \(summary.remoteTopicPath) - decode failure: \(error.localizedDescription)")
            return false
        }

        do {
            let cacheURL = try cacheURL(for: summary.remoteTopicPath)
            if let cachedData = try? Data(contentsOf: cacheURL), cachedData == data {
                log("content unchanged: \(summary.remoteTopicPath)")
                log("cache updated or skipped: skipped")
                return true
            }

            log("content changed: \(summary.remoteTopicPath)")
            try write(data: data, to: cacheURL)
            log("cache updated or skipped: updated")
            return true
        } catch {
            log("refresh failed but cache retained: \(summary.remoteTopicPath) - cache write failure: \(error.localizedDescription)")
            return false
        }
    }

    private func loadRemoteTopic(summary: GuideTopicSummary) async throws -> GuideTopicDetail {
        clearLegacySepsisCacheIfNeeded(for: summary)
        let url = remoteURL(for: summary)
        log("final requested URL: \(url.absoluteString)")
        log("requested URL: \(url.absoluteString)")
        log("fetch started: \(summary.remoteTopicPath)")

        let data = try await fetchRemoteData(from: url)
        log("remote fetch success: \(summary.remoteTopicPath)")

        do {
            let topic = try decoder.decode(GuideTopicDetail.self, from: data)
            log("decode success: \(summary.remoteTopicPath)")
            do {
                try write(data: data, to: cacheURL(for: summary.remoteTopicPath))
                log("cache write success: \(summary.remoteTopicPath)")
            } catch {
                log("cache write failure: \(error.localizedDescription)")
            }
            return topic
        } catch {
            log("decode failure: \(error.localizedDescription)")
            throw GuideUpdatesServiceError.invalidJSON(error.localizedDescription)
        }
    }

    private func fetchRemoteData(from url: URL) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            log("network error: \(error.localizedDescription)")
            throw GuideUpdatesServiceError.network(error.localizedDescription)
        }

        if let httpResponse = response as? HTTPURLResponse {
            log("HTTP status code: \(httpResponse.statusCode)")
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw GuideUpdatesServiceError.network("HTTP \(httpResponse.statusCode)")
            }
        }

        return data
    }

    private func readCachedTopic(summary: GuideTopicSummary) throws -> GuideTopicDetail {
        let url = try cacheURL(for: summary.remoteTopicPath)
        log("cache read attempt: \(summary.remoteTopicPath)")
        let topic = try read(GuideTopicDetail.self, from: url)
        log("cache read success: \(summary.remoteTopicPath)")
        return topic
    }

    private func readBundledIndex() throws -> GuideUpdatesIndex {
        let url = try bundledURL(file: "index.json")
        return try read(GuideUpdatesIndex.self, from: url)
    }

    private func readBundledTopic(file: String) throws -> GuideTopicDetail {
        let url = try bundledURL(file: file)
        return try read(GuideTopicDetail.self, from: url)
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }

    private func write(data: Data, to url: URL) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic])
    }

    private func cacheURL(for path: String) throws -> URL {
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return root
            .appendingPathComponent("GuideUpdates", isDirectory: true)
            .appendingPathComponent(path)
    }

    private func clearLegacySepsisCacheIfNeeded(for summary: GuideTopicSummary) {
        guard summary.id == "sepsis" else { return }
        do {
            let legacyURL = try cacheURL(for: "guides/critical_care/sepsis.json")
            if fileManager.fileExists(atPath: legacyURL.path) {
                try fileManager.removeItem(at: legacyURL)
                log("cleared stale cache path: guides/critical_care/sepsis.json")
            }
        } catch {
            log("stale sepsis cache cleanup skipped: \(error.localizedDescription)")
        }
    }

    private func bundledURL(file: String) throws -> URL {
        let candidates = [
            "guide-updates",
            "Features/GuideUpdates/Resources/guide-updates",
            nil
        ]

        let filename = (file as NSString).lastPathComponent
        let resource = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        let subdirectory = (file as NSString).deletingLastPathComponent

        for root in candidates {
            let fullSubdirectory: String?
            if subdirectory == "." || subdirectory.isEmpty {
                fullSubdirectory = root
            } else if let root {
                fullSubdirectory = "\(root)/\(subdirectory)"
            } else {
                fullSubdirectory = subdirectory
            }

            if let url = Bundle.main.url(forResource: resource, withExtension: ext, subdirectory: fullSubdirectory) {
                return url
            }
        }

        throw CocoaError(.fileNoSuchFile)
    }

    private func log(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        #if DEBUG
        print("[GuideDataService] \(message)")
        #endif
    }
}

typealias GuideUpdatesService = GuideDataService
