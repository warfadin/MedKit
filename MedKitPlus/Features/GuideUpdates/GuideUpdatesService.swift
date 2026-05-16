import Foundation

enum GuideUpdatesServiceError: LocalizedError {
    case noReadableIndex
    case noReadableTopic(String)

    var errorDescription: String? {
        switch self {
        case .noReadableIndex:
            "Guide Updates index could not be loaded."
        case .noReadableTopic(let id):
            "Guide topic could not be loaded: \(id)"
        }
    }
}

final class GuideUpdatesService {
    private let remoteBaseURL: URL?
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let fileManager: FileManager

    init(
        remoteBaseURL: URL? = nil,
        session: URLSession = .shared,
        fileManager: FileManager = .default
    ) {
        self.remoteBaseURL = remoteBaseURL
        self.session = session
        self.fileManager = fileManager
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadIndex() async -> Result<GuideUpdatesIndex, Error> {
        do {
            let index = try await refreshIndexIfNeeded()
            return .success(index)
        } catch {
            return .failure(error)
        }
    }

    func loadTopic(summary: GuideTopicSummary) async -> Result<GuideTopicDetail, Error> {
        do {
            let detail = try await refreshTopicIfNeeded(summary: summary)
            return .success(detail)
        } catch {
            return .failure(error)
        }
    }

    private func refreshIndexIfNeeded() async throws -> GuideUpdatesIndex {
        let localIndex = try? readCachedIndex()
        let fallbackIndex = localIndex ?? (try? readBundledIndex())

        guard let remoteBaseURL else {
            if let fallbackIndex { return fallbackIndex }
            throw GuideUpdatesServiceError.noReadableIndex
        }

        do {
            let remoteIndex: GuideUpdatesIndex = try await fetchJSON(from: remoteBaseURL.appendingPathComponent("index.json"))
            if remoteIndex.contentVersion != fallbackIndex?.contentVersion {
                try write(remoteIndex, to: cacheURL(for: "index.json"))
            }
            return remoteIndex
        } catch {
            if let fallbackIndex { return fallbackIndex }
            throw error
        }
    }

    private func refreshTopicIfNeeded(summary: GuideTopicSummary) async throws -> GuideTopicDetail {
        let cachedTopic = try? readCachedTopic(file: summary.file)

        guard let remoteBaseURL else {
            if let cachedTopic { return cachedTopic }
            if let bundledTopic = try? readBundledTopic(file: summary.file) { return bundledTopic }
            throw GuideUpdatesServiceError.noReadableTopic(summary.id)
        }

        do {
            let remoteTopic: GuideTopicDetail = try await fetchJSON(from: remoteBaseURL.appendingPathComponent(summary.file))
            try write(remoteTopic, to: cacheURL(for: summary.file))
            return remoteTopic
        } catch {
            if let cachedTopic { return cachedTopic }
            if let bundledTopic = try? readBundledTopic(file: summary.file) { return bundledTopic }
            throw error
        }
    }

    private func fetchJSON<T: Decodable>(from url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(T.self, from: data)
    }

    private func readCachedIndex() throws -> GuideUpdatesIndex {
        try read(GuideUpdatesIndex.self, from: cacheURL(for: "index.json"))
    }

    private func readCachedTopic(file: String) throws -> GuideTopicDetail {
        try read(GuideTopicDetail.self, from: cacheURL(for: file))
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

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }

    private func cacheURL(for file: String) throws -> URL {
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return root
            .appendingPathComponent("GuideUpdates", isDirectory: true)
            .appendingPathComponent(file)
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
}
