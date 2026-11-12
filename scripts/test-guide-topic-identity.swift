import Foundation

private final class TopicURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let body: String
        switch host {
        case "match.example": body = #"{"id":"fixture","title":"Uzak içerik"}"#
        case "wrong.example": body = #"{"id":"other","title":"Başka konu"}"#
        case "missing.example": body = #"{"title":"Kimliksiz konu"}"#
        case "aliases.example" where url.lastPathComponent == "aki.json":
            body = #"{"id":"acute_kidney_injury"}"#
        case "aliases.example" where url.lastPathComponent == "ckd.json":
            body = #"{"id":"chronic_kidney_disease"}"#
        case "aliases.example": body = #"{"id":"acute_kidney_injury"}"#
        default:
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }

        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@main
@MainActor
struct GuideTopicIdentityTests {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TopicURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        func service(_ host: String) -> GuideDataService {
            GuideDataService(remoteRootURL: URL(string: "https://\(host).example")!, session: session, cacheDirectory: directory)
        }

        let summary = makeSummary(id: "fixture")
        let cacheFile = directory.appendingPathComponent(summary.remoteTopicPath)

        let loaded = try await service("match").loadTopic(summary: summary).get()
        try expect(loaded.id == summary.id && loaded.title == "Uzak içerik", "Matching remote topic must load")
        let originalCache = try Data(contentsOf: cacheFile)

        let fallback = try await service("wrong").loadTopic(summary: summary).get()
        try expect(fallback == loaded, "Wrong remote topic must fall back to the valid cache")
        let cacheAfterLoad = try Data(contentsOf: cacheFile)
        try expect(cacheAfterLoad == originalCache, "Wrong remote topic must leave the cache intact")

        for host in ["wrong", "missing"] {
            let refreshed = await service(host).refreshCachedTopics([summary])
            try expect(!refreshed, "Refresh must reject a wrong or missing topic ID")
            let cacheAfterRefresh = try Data(contentsOf: cacheFile)
            try expect(cacheAfterRefresh == originalCache, "Rejected refresh must leave the cache intact")
        }

        try Data(#"{"id":"other"}"#.utf8).write(to: cacheFile, options: .atomic)
        let offlineResult = await service("offline").loadTopic(summary: summary)
        if case .success = offlineResult {
            throw Failure(message: "Offline load must reject a cached topic with the wrong ID")
        }

        for (id, alias) in [("aki", "acute_kidney_injury"), ("ckd", "chronic_kidney_disease")] {
            let summary = makeSummary(id: id)
            let refreshed = await service("aliases").refreshCachedTopics([summary])
            try expect(refreshed, "The existing remote alias must be accepted for \(id)")
            let cached = try await service("offline").loadTopic(summary: summary).get()
            try expect(cached.id == alias, "The cached remote alias must load offline for \(id)")
        }

        let unrelatedRefresh = await service("aliases").refreshCachedTopics([summary])
        try expect(!unrelatedRefresh, "A known alias must be rejected for an unrelated topic")

        print("Guide topic identity tests passed.")
    }

    private static func makeSummary(id: String) -> GuideTopicSummary {
        GuideTopicSummary(
            id: id, title: "Test konusu", specialty: .nephrology,
            file: "no-bundled-test-topic.json", lastUpdated: "", latestGuide: "", previousGuide: "",
            importance: .moderate, updateCount: 0, tags: []
        )
    }

    private struct Failure: Error {
        let message: String
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure(message: message) }
    }
}
