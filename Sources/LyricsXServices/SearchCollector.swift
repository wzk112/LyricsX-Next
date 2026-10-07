import Foundation
import LyricsXCore

actor SearchCollector {
    struct Key: Hashable {
        var title: String; var artist: String; var source: String
        var lines: [LyricLine]; var plain: String?; var instrumental: Bool
        var providerID: String?; var album: String
        init(_ document: LyricsDocument, preserveProviderID: Bool) {
            title = document.title; artist = document.artist; source = document.source
            providerID = preserveProviderID ? document.providerID : nil; album = document.album
            lines = document.lines; plain = document.plainText; instrumental = document.isInstrumental
        }
    }
    let track: Track
    let configuration: SourceConfiguration
    let continuation: AsyncThrowingStream<LyricCandidate, Error>.Continuation
    var aliases: [Track] = []
    var candidates: [Key: LyricCandidate] = [:]
    var visibleKeys: Set<Key> = []
    let onSourceUpdate: @Sendable (SourceSearchStatus) -> Void
    var sourceErrors: [String: String] = [:]
    var activeSources: Set<String> = []
    struct Query: Sendable {
        let track: Track
        let keyword: String?
        var key: String {
            keyword.map { "q:" + CandidateRanker.normalized($0) }
                ?? "i:" + CandidateRanker.normalized(track.title) + "|" + CandidateRanker.normalized(track.artist)
        }
    }
    var queues: [String: [Query]] = [:]
    var queryKeys: [String: Set<String>] = [:]
    var waiters: [String: CheckedContinuation<Query?, Never>] = [:]
    var catalogDone = false
    let useTrackHints: Bool
    let isAutomatic: Bool
    let completeManualSearch: Bool
    var satisfiedSources: Set<String> = []
    var completedQueries: [String: Int] = [:]
    var successfulAutomaticQueries: [String: Int] = [:]
    var hasReliableAutomaticResult = false
    let fallbackGrace: Duration
    var fallbackDeadline: Task<Void, Never>?
    var fallbackExpired = false
    var finished = false
    var successes = 0
    var failures = 0
    var allFailed: Bool { candidates.isEmpty && successes == 0 && failures > 0 }
    init(track: Track, keyword: String?, complete: Bool, configuration: SourceConfiguration, fallbackGrace: Duration,
         continuation: AsyncThrowingStream<LyricCandidate, Error>.Continuation, onSourceUpdate: @escaping @Sendable (SourceSearchStatus) -> Void) {
        self.fallbackGrace = fallbackGrace
        self.onSourceUpdate = onSourceUpdate
        self.useTrackHints = LyricsStore.usesTrackHints(track: track, keyword: keyword)
        self.isAutomatic = keyword == nil
        self.completeManualSearch = complete
        var effectiveConfiguration = configuration
        if track.playerID != "com.apple.Music" || !LyricsStore.usesTrackHints(track: track, keyword: keyword) {
            effectiveConfiguration.enabled.remove(AppleMusicLyricsSource.name)
            effectiveConfiguration.appleMusicCloudEnabled = false
        }
        self.track = track; self.configuration = effectiveConfiguration; self.continuation = continuation
        let queries = LyricsStore.queryKeywords(track: track, keyword: keyword, complete: complete || keyword == nil).map { Query(track: track, keyword: $0) }
        for source in effectiveConfiguration.availableSources {
            if source == AppleMusicLyricsSource.name { queues[source] = []; continue }
            queues[source] = queries
            queryKeys[source] = Set(queries.map(\.key))
        }
    }
    func add(_ document: LyricsDocument) -> [Track] {
        guard !finished else { return [] }
        guard document.isSynced || document.isInstrumental || document.plainText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return [] }
        var discovered: [Track] = []
        if useTrackHints {
            discovered = addAliases(ArtistAliasEvidence.aliases(in: document, for: track))
            discovered += addAliases(ArtistAliasEvidence.searchTitles(in: document, for: track, aliases: aliases))
        }
        guard !finished else { return discovered }
        let key = Key(document, preserveProviderID: isAutomatic || completeManualSearch)
        guard candidates[key] == nil else { return discovered }
        let candidate = LyricCandidate(document: document, score: configuration.bestScore(document, for: track, aliases: aliases))
        candidates[key] = candidate
        publish(candidate, key: key)
        considerAutomaticCandidate(candidate)
        finishSatisfiedAutomaticSearch()
        let source = SourceConfiguration.sourceKey(document.source)
        updateCompactLimit(for: source)
        if !finished { report(source) }
        return discovered
    }
    @discardableResult func addAliases(_ values: [Track]) -> [Track] {
        guard !finished else { return [] }
        var added: [Track] = []
        let aliasLimit = isAutomatic || completeManualSearch ? 4 : 2
        for value in values where aliases.count < aliasLimit {
            guard !aliases.contains(where: { CandidateRanker.normalized($0.title) == CandidateRanker.normalized(value.title)
                && CandidateRanker.normalized($0.artist) == CandidateRanker.normalized(value.artist) }) else { continue }
            aliases.append(value); added.append(value)
            for source in configuration.availableSources {
                if source == AppleMusicLyricsSource.name { continue }
                if satisfiedSources.contains(source) { continue }
                let queries = LyricsStore.queryKeywords(track: value, keyword: nil, complete: isAutomatic || completeManualSearch).map { Query(track: value, keyword: $0) }
                    .filter { queryKeys[source, default: []].insert($0.key).inserted }
                queues[source, default: []].insert(contentsOf: queries, at: 0)
                if !queries.isEmpty, let waiter = waiters.removeValue(forKey: source) {
                    activeSources.insert(source)
                    waiter.resume(returning: queues[source]!.removeFirst())
                }
            }
        }
        guard !added.isEmpty else { return [] }
        // A newly verified name must get its own search round. Do not let the
        // original spelling's completed queries suppress a native-title lookup.
        successfulAutomaticQueries = [:]
        if fallbackDeadline != nil { armFallbackDeadline() }
        for (key, var candidate) in candidates {
            let score = configuration.bestScore(candidate.document, for: track, aliases: aliases)
            if score > candidate.score {
                candidate.score = score; candidates[key] = candidate; publish(candidate, key: key)
            }
            considerAutomaticCandidate(candidate)
        }
        finishSatisfiedAutomaticSearch()
        for source in configuration.availableSources { updateCompactLimit(for: source) }
        return added
    }
    private func considerAutomaticCandidate(_ candidate: LyricCandidate) {
        guard isAutomatic, candidate.score >= 60, candidate.document.isSynced,
              !candidate.document.isLikelyInstrumentalPlaceholder else { return }
        hasReliableAutomaticResult = true
        if fallbackDeadline == nil, candidate.document.hasWordTiming || candidate.document.hasTranslation
            || !(configuration.preferWordTiming || configuration.preferBilingual) {
            armFallbackDeadline()
        }
        let source = SourceConfiguration.sourceKey(candidate.document.source)
        if !satisfiedSources.contains(source),
           configuration.satisfiesAutomaticPreferences(candidate.document, for: track, aliases: aliases) {
            satisfiedSources.insert(source)
            queues[source] = []
        }
    }
    private func finishSatisfiedAutomaticSearch() {
        guard isAutomatic else { return }
        // No other enabled source can outrank an exact, fully preferred result
        // from the first source. Do not spend the rest of the budget on it.
        if let first = configuration.availableSources.first, satisfiedSources.contains(first) {
            finish(timedOut: false)
            continuation.finish()
        }
        finishAutomaticRoundIfReady()
    }
    private func automaticRoundComplete(for source: String) -> Bool {
        satisfiedSources.contains(source) || successfulAutomaticQueries[source, default: 0] >= 2
            || (queues[source, default: []].isEmpty && !activeSources.contains(source))
    }
    private func finishAutomaticRoundIfReady() {
        // Once every enabled provider had a fair info/title round (and catalog
        // aliases were checked), use the best available feature combination.
        // No language heuristic: Chinese word-only and foreign bilingual-only
        // results both settle without waiting for an impossible second feature.
        guard isAutomatic, !finished, catalogDone, hasReliableAutomaticResult,
              fallbackExpired || configuration.availableSources.allSatisfy({ automaticRoundComplete(for: $0) }) else { return }
        finish(timedOut: false)
        continuation.finish()
    }
    private func expireFallback() {
        guard !finished else { return }
        fallbackExpired = true
        finishAutomaticRoundIfReady()
    }
    private func armFallbackDeadline() {
        fallbackDeadline?.cancel()
        fallbackExpired = false
        fallbackDeadline = Task { [weak self, fallbackGrace] in
            do { try await Task.sleep(for: fallbackGrace) } catch { return }
            await self?.expireFallback()
        }
    }
    private func updateCompactLimit(for source: String) {
        guard !isAutomatic, !completeManualSearch else { return }
        let visibleCount = visibleKeys.lazy.filter({ self.candidates[$0].map { SourceConfiguration.sourceKey($0.document.source) == source } == true }).count
        if visibleCount >= LyricsStore.compactManualResultsPerSource || (catalogDone && completedQueries[source, default: 0] >= 2) {
            satisfiedSources.insert(source)
            queues[source] = []
        }
    }
    private func publish(_ candidate: LyricCandidate, key: Key) {
        // For the current track, compact search keeps off-target same-name songs
        // available for later alias rescoring without flooding the visible list.
        let visible = isAutomatic || completeManualSearch || !useTrackHints || candidate.score >= 60
        guard visible else { return }
        visibleKeys.insert(key)
        continuation.yield(candidate)
    }
    func sourceShouldStop(_ source: String) -> Bool { satisfiedSources.contains(source) }
    func begin() {
        if configuration.enabled.contains(AppleMusicLyricsSource.name) { activeSources.insert(AppleMusicLyricsSource.name) }
        for source in configuration.availableSources { report(source) }
    }
    func completed(source: String, error: String?, emptyIssue: String? = nil) {
        guard !finished else { return }
        activeSources.remove(source)
        completedQueries[source, default: 0] += 1
        if let error { failures += 1; sourceErrors[source] = error }
        else {
            successes += 1; successfulAutomaticQueries[source, default: 0] += 1
            // A later successful query supersedes an earlier request failure.
            // Otherwise a recovered provider remains labelled unavailable.
            sourceErrors[source] = emptyIssue
        }
        updateCompactLimit(for: source)
        finishAutomaticRoundIfReady()
        finishWaitingIfDrained()
        if !finished { report(source) }
    }
    func catalogFinished() {
        catalogDone = true
        for source in configuration.availableSources { updateCompactLimit(for: source) }
        finishAutomaticRoundIfReady()
        finishWaitingIfDrained()
    }
    func nextQuery(source: String) async -> Query? {
        guard !finished, !Task.isCancelled else { return nil }
        if satisfiedSources.contains(source) { finishWaitingIfDrained(); return nil }
        // Park a provider after its fair round instead of issuing more broad
        // searches while another source is still resolving. A new alias wakes it.
        let park = isAutomatic && hasReliableAutomaticResult && successfulAutomaticQueries[source, default: 0] >= 2
        if !park, queues[source]?.isEmpty == false {
            activeSources.insert(source)
            return queues[source]!.removeFirst()
        }
        return await withCheckedContinuation { waiter in
            waiters[source] = waiter
            finishWaitingIfDrained()
        }
    }
    private func finishWaitingIfDrained() {
        guard catalogDone, activeSources.isEmpty, queues.values.allSatisfy(\.isEmpty) else { return }
        let pending = waiters.values; waiters = [:]
        for waiter in pending { waiter.resume(returning: nil) }
    }
    func cancel() {
        finished = true
        fallbackDeadline?.cancel(); fallbackDeadline = nil
        let pending = waiters.values; waiters = [:]
        for waiter in pending { waiter.resume(returning: nil) }
    }
    func finish(timedOut: Bool) {
        guard !finished else { return }
        for source in configuration.availableSources { report(source, finished: true, timedOut: timedOut && activeSources.contains(source)) }
        cancel()
    }
    private func report(_ source: String, finished: Bool = false, timedOut: Bool = false) {
        let count = visibleKeys.lazy.filter { self.candidates[$0].map { SourceConfiguration.sourceKey($0.document.source) == source } == true }.count
        onSourceUpdate(.init(source: source, count: count,
                             isSearching: !finished && (source != AppleMusicLyricsSource.name || activeSources.contains(source)),
                             issue: sourceErrors[source] ?? (timedOut ? "搜索超时，已保留结果" : nil)))
    }
}
