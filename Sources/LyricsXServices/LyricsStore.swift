import Foundation
@preconcurrency import LyricsKit
import LyricsXCore

public final class LyricsStore: LyricsRepository, Sendable {
    /// Download budgets per source/query. Manual search retains more versions;
    /// both paths use the same matching, aliases, and completion-order delivery.
    static let automaticCandidateLimit = 40
    static let compactManualCandidateLimit = 12
    static let completeManualCandidateLimit = 80
    static let compactManualResultsPerSource = 12
    public let cache: LyricsCache
    private let configuration: @Sendable () -> SourceConfiguration
    private let aliasResolver: TrackAliasResolver
    typealias SearchBackend = @Sendable (Track, String?, SourceConfiguration, SecureLyricsHTTPClient) -> AsyncThrowingStream<LyricsDocument, Error>
    private let searchBackend: SearchBackend
    private let searchBudget: Duration
    private let firstResultDelay: Duration
    private let fallbackGrace: Duration
    public init(cache: LyricsCache = LyricsCache(), configuration: @escaping @Sendable () -> SourceConfiguration = { .init() }) {
        self.cache = cache; self.configuration = configuration
        self.aliasResolver = TrackAliasResolver(); self.searchBackend = Self.providerSearch; self.searchBudget = .seconds(24); self.firstResultDelay = .seconds(1); self.fallbackGrace = .seconds(8)
    }
    init(cache: LyricsCache, configuration: @escaping @Sendable () -> SourceConfiguration = { .init() },
         aliasResolver: TrackAliasResolver, searchBudget: Duration = .seconds(24), firstResultDelay: Duration = .seconds(1),
         fallbackGrace: Duration = .seconds(8), searchBackend: @escaping SearchBackend) {
        self.cache = cache; self.configuration = configuration; self.aliasResolver = aliasResolver
        self.searchBackend = searchBackend; self.searchBudget = searchBudget; self.firstResultDelay = firstResultDelay; self.fallbackGrace = fallbackGrace
    }
    public func save(_ document: LyricsDocument, for track: Track) async throws { if track.playerID != "lyricsx.demo" { try await cache.save(document, for: track) } }
    public func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                if track.playerID == "lyricsx.demo" { continuation.finish(); return }
                let selectionKey = configuration().selectionKey
                var checkpoint: LyricCandidate?
                if !forceRefresh {
                    if let cached = await cache.automaticCandidate(for: track, configuration: selectionKey) {
                        if !cached.isProvisional { continuation.yield(cached); continuation.finish(); return }
                        checkpoint = cached
                    }
                    if checkpoint == nil, let embedded = track.embeddedLyrics, let doc = try? LyricsCodec.parse(embedded), doc.isSynced || doc.plainText?.isEmpty == false {
                        continuation.yield(LyricCandidate(document: doc, score: 999)); continuation.finish(); return
                    }
                    if checkpoint == nil, let local = Self.localLyrics(track: track, directory: configuration().legacyDirectory) {
                        continuation.yield(LyricCandidate(document: local, score: 999)); continuation.finish(); return
                    }
                }
                guard !Task.isCancelled else { continuation.finish(); return }
                let searchID = await cache.beginSearch(for: track)
                defer { Task { await cache.endSearch(for: track, id: searchID) } }
                let results = AutomaticSearchResults(continuation) { [cache] candidate in
                    try? await cache.saveCheckpoint(candidate, for: track, searchID: searchID, configuration: selectionKey)
                }
                if let checkpoint { await results.restore(checkpoint) }
                let firstDisplay = Task {
                    do { try await Task.sleep(for: firstResultDelay) } catch { return }
                    await results.allowEarlyDisplay()
                }
                defer { firstDisplay.cancel() }
                var failure: Error?
                do {
                    for try await candidate in search(track: track) {
                        try Task.checkCancellation()
                        await results.add(candidate)
                    }
                } catch { failure = error }
                guard !Task.isCancelled else { continuation.finish(); return }
                await results.finish(error: failure)

            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    public func search(track: Track, keyword: String? = nil, complete: Bool = false,
                       onSourceUpdate: @escaping @Sendable (SourceSearchStatus) -> Void = { _ in }) -> AsyncThrowingStream<LyricCandidate, Error> {
        var config = configuration()
        config.candidateLimit = keyword == nil ? Self.automaticCandidateLimit
            : (complete ? Self.completeManualCandidateLimit : Self.compactManualCandidateLimit)
        let configuration = config
        return AsyncThrowingStream { continuation in
            let collector = SearchCollector(track: track, keyword: keyword, complete: complete, configuration: configuration, fallbackGrace: fallbackGrace,
                                            continuation: continuation, onSourceUpdate: onSourceUpdate)
            let task = Task {
                let sessionConfig = URLSessionConfiguration.ephemeral
                sessionConfig.timeoutIntervalForRequest = 6
                sessionConfig.timeoutIntervalForResource = 9
                sessionConfig.httpMaximumConnectionsPerHost = 4
                let session = URLSession(configuration: sessionConfig)
                defer { session.invalidateAndCancel() }
                let client = SecureLyricsHTTPClient(session: session)
                await collector.begin()
                let budget = keyword == nil ? searchBudget
                    : (complete ? max(searchBudget, .seconds(40)) : min(searchBudget, .seconds(18)))
                let deadline = Task {
                    do { try await Task.sleep(for: budget) } catch { return }
                    await collector.finish(timedOut: true)
                    continuation.finish(throwing: StoreError.timeout)
                    session.invalidateAndCancel()
                }
                defer { deadline.cancel() }
                // One worker per source. Newly discovered native names enter
                // each source's queue immediately, ahead of broad title-only
                // queries; no slow source can block alias expansion elsewhere.
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        if Self.usesTrackHints(track: track, keyword: keyword) {
                            let aliases = await self.aliasResolver.aliases(for: track, client: client)
                            if !Task.isCancelled { await collector.addAliases(aliases) }
                        }
                        await collector.catalogFinished()
                    }
                    for source in configuration.availableSources {
                        var single = configuration; single.enabled = [source]
                        let sourceConfig = single
                        group.addTask {
                            while let query = await collector.nextQuery(source: source) {
                                guard !Task.isCancelled else { return }
                                do {
                                    for try await document in self.searchBackend(query.track, query.keyword, sourceConfig, client) {
                                        guard !Task.isCancelled else { return }
                                        _ = await collector.add(document)
                                        if await collector.sourceShouldStop(source) { break }
                                    }
                                    await collector.completed(source: source, error: nil)
                                } catch {
                                    if Task.isCancelled { return }
                                    await collector.completed(source: source, error: SourceSearchStatus.describe(error))
                                }
                            }
                        }
                    }
                }
                guard !Task.isCancelled else { return }
                await collector.finish(timedOut: false)
                if await collector.allFailed { continuation.finish(throwing: StoreError.unavailable) }
                else { continuation.finish() }
            }
            continuation.onTermination = { _ in task.cancel(); Task { await collector.cancel() } }
        }
    }

    static func usesTrackHints(track: Track, keyword: String?) -> Bool {
        guard let keyword else { return true }
        let value = CandidateRanker.normalized(keyword)
        return value == CandidateRanker.normalized(track.title)
            || value == CandidateRanker.normalized(track.title + " " + track.artist)
    }

    static func queryKeywords(track: Track, keyword: String?, complete: Bool = true) -> [String?] {
        if let keyword, !usesTrackHints(track: track, keyword: keyword) { return [keyword] }
        let titles = TrackSearchText.titles(track.title)
        if complete { return [nil] + titles.map { Optional($0) } }
        // The info query already carries the original title and artist. Compact
        // search adds only the first useful cleaned title instead of multiplying
        // every source by every subtitle and alias spelling.
        return [nil] + titles.prefix(2).map { Optional($0) }
    }

    private static func providerSearch(track: Track, keyword: String?, config: SourceConfiguration,
                                       client: SecureLyricsHTTPClient) -> AsyncThrowingStream<LyricsDocument, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let services: [LyricsProviders.Service<LyricsProviders.EmptyOptions>] = [.netease, .qq, .kugou]
                var providers: [any LyricsProvider] = services.filter { config.enabled.contains($0.displayName) }.map { $0.create(httpClient: client) }
                if let token = config.musixmatchToken, !token.isEmpty, config.enabled.contains("Musixmatch") {
                    providers.append(LyricsProviders.Service.musixmatch.create(.init(usertoken: token), httpClient: client))
                }
                let limit = config.candidateLimit
                let request = LyricsSearchRequest(searchTerm: keyword.map { .keyword($0) } ?? .info(title: track.title, artist: track.artist), duration: track.duration, limit: limit)
                let failures = await withTaskGroup(of: String?.self, returning: [String].self) { group in
                    for provider in providers {
                        group.addTask {
                            do {
                                for try await lyrics in provider.lyrics(for: request) {
                                    try Task.checkCancellation()
                                    let doc = LyricsCodec.convert(lyrics)
                                    continuation.yield(doc)
                                }
                                return nil
                            } catch is CancellationError { return nil }
                            catch {
                                if ProcessInfo.processInfo.environment["LYRICSX_SEARCH_DIAGNOSTICS"] == "1" { print("PROVIDER_ERROR \(SourceSearchStatus.describe(error))") }
                                return SourceSearchStatus.describe(error)
                            }
                        }
                    }
                    if config.enabled.contains("LRCLIB") {
                        group.addTask {
                            do {
                                for doc in try await LRCLIBSearch.documents(track: track, keyword: keyword, client: client) {
                                    try Task.checkCancellation()
                                    continuation.yield(doc)
                                }
                                return nil
                            } catch { return SourceSearchStatus.describe(error) }
                        }
                    }
                    var errors: [String] = []
                    for await failure in group { if let failure { errors.append(failure) } }
                    return errors
                }
                if Task.isCancelled { continuation.finish(throwing: CancellationError()) }
                else if !failures.isEmpty { continuation.finish(throwing: StoreError.sourceFailure(failures.joined(separator: "；"))) }
                else { continuation.finish() }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    private static func localLyrics(track: Track, directory: URL?) -> LyricsDocument? {
        var bases: [URL] = []
        if let file = track.localFileURL { bases.append(file.deletingPathExtension()) }
        if let directory {
            let name = "\(track.title) - \(track.artist)".replacingOccurrences(of: "/", with: ":")
            bases.append(directory.appendingPathComponent(name))
        }
        for base in bases { for ext in ["lrcx", "lrc"] { if let doc = try? LyricsCodec.read(base.appendingPathExtension(ext)) { return doc } } }
        return nil
    }
    enum StoreError: LocalizedError {
        case unavailable, timeout
        case sourceFailure(String)
        var errorDescription: String? {
            switch self {
            case .unavailable: "歌词源未能完成搜索，请查看各来源状态后重试。"
            case .sourceFailure(let message): message
            case .timeout: "部分歌词源响应超时，已保留可用结果；可以重新搜索。"
            }
        }
    }
}

struct SecureLyricsHTTPClient: HTTPClient {
    let session: URLSession
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var request = request
        guard let original = request.url,
              let scheme = original.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = original.host, !host.isEmpty else { throw URLError(.badURL) }
        // QQ Music makes this optional request only to decorate a lyric result
        // with its own album art. Playback artwork is owned by the active player
        // (for example Apple Music), so avoid an unrelated request on macOS 27.
        if host == "u.y.qq.com", let body = request.httpBody,
           String(decoding: body, as: UTF8.self).contains("music.pf_song_detail_svr") {
            throw URLError(.resourceUnavailable)
        }
        if scheme == "http", var components = URLComponents(url: original, resolvingAgainstBaseURL: false) {
            components.scheme = "https"; request.url = components.url
        }
        request.setValue("LyricsX-Next/2.0 (https://github.com/wzk112/LyricsX-Next)", forHTTPHeaderField: "X-Client")
        for attempt in 0..<2 {
            do {
                try Task.checkCancellation()
                let result = try await perform(request, host: host, path: original.path)
                guard (200..<300).contains(result.1.statusCode) else { throw HTTPResponseError(status: result.1.statusCode) }
                return result
            } catch {
                let retryable: Bool
                if let status = error as? HTTPResponseError { retryable = [408, 500, 502, 503, 504].contains(status.status) }
                else {
                    let value = error as NSError
                    retryable = value.domain == NSURLErrorDomain && [NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost].contains(value.code)
                }
                guard attempt == 0, retryable, !Task.isCancelled else { throw error }
                try await Task.sleep(for: .milliseconds(350))
            }
        }
        throw URLError(.unknown)
    }
    private func perform(_ request: URLRequest, host: String, path: String) async throws -> (Data, HTTPURLResponse) {
        // macOS 27.0 can abort the process from URLSession.data(for:) while QQ
        // Music performs its optional cover request. The data-task API keeps the
        // same timeout and cancellation behavior without that async bridge.
        let cancellation = HTTPTaskCancellation()
        return try await withTaskCancellationHandler {
          try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if ProcessInfo.processInfo.environment["LYRICSX_SEARCH_DIAGNOSTICS"] == "1" {
                    print("HTTP_RESULT host=\(host) path=\(path) status=\((response as? HTTPURLResponse)?.statusCode ?? 0) bytes=\(data?.count ?? 0) error=\((error as NSError?)?.code ?? 0)")
                }
                if let error { continuation.resume(throwing: error); return }
                guard let data, data.count < 8_000_000, let response = response as? HTTPURLResponse else {
                    continuation.resume(throwing: URLError(.badServerResponse)); return
                }
                continuation.resume(returning: (data, response))
            }
            cancellation.install(task)
            task.resume()
          }
        } onCancel: {
            cancellation.cancel()
        }
    }
}

private final class HTTPTaskCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var cancelled = false
    func install(_ value: URLSessionDataTask) {
        lock.withLock { task = value; if cancelled { value.cancel() } }
    }
    func cancel() { lock.withLock { cancelled = true; task?.cancel() } }
}
