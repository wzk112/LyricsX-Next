import Foundation
import Synchronization
import Testing
import LyricsXCore
import LyricsXServices
@testable import LyricsXApp

private final class SearchProbe: Sendable {
    struct Request: Sendable {
        let query: String
        let updates: LyricsSearchController.Updates
        let continuation: AsyncThrowingStream<LyricCandidate, Error>.Continuation
    }
    private let requests = Mutex<[Request]>([])
    func read(_ track: Track, _ query: String, _ complete: Bool, _ updates: @escaping LyricsSearchController.Updates) -> AsyncThrowingStream<LyricCandidate, Error> {
        let pair = AsyncThrowingStream<LyricCandidate, Error>.makeStream()
        requests.withLock { $0.append(.init(query: query, updates: updates, continuation: pair.continuation)) }
        return pair.stream
    }
    var count: Int { requests.withLock { $0.count } }
    func request(_ index: Int) -> Request { requests.withLock { $0[index] } }
}
private actor PreviewRepository: LyricsRepository {
    var saved: [LyricsDocument] = []
    nonisolated func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) { saved.append(document) }
}
@MainActor private final class PreviewFixture {
    let suite = "LyricsXPreviewAudit-" + UUID().uuidString
    let defaults: UserDefaults
    let repository = PreviewRepository()
    let probe = SearchProbe()
    let model: AppModel
    let controller: LyricsSearchController
    init(timeout: Duration = .seconds(2)) {
        defaults = UserDefaults(suiteName: suite)!
        model = AppModel(repository: repository, preferences: Preferences(defaults: defaults))
        model.session.accept(.init(track: .init(playerID: "fixture", playerName: "Fixture", title: "Current", artist: "Artist"), position: 12, isPlaying: false), shouldSearch: false)
        let source = probe
        controller = .init(model: model, read: { source.read($0, $1, $2, $3) }, compactTimeout: timeout)
    }
    isolated deinit { controller.cancel(); model.stop(); defaults.removePersistentDomain(forName: suite) }
    func request(_ index: Int) async throws -> SearchProbe.Request {
        for _ in 0..<200 where probe.count <= index { try await Task.sleep(for: .milliseconds(5)) }
        #expect(probe.count > index)
        return probe.request(index)
    }
    func finished() async throws {
        for _ in 0..<200 where controller.searching { try await Task.sleep(for: .milliseconds(5)) }
        #expect(!controller.searching)
    }
    var candidate: LyricCandidate { .init(document: .init(title: "Current", artist: "Artist", source: "LRCLIB", lines: [.init(id: 20, time: 1, text: "Fixture")], providerID: "song:1"), score: 80) }
}

@Suite(.serialized) @MainActor struct LyricsSearchControllerTests {
    @Test func previewAndRetryDoNotWriteOrSeekUntilExplicitApply() async throws {
        let f = PreviewFixture(); let c = f.controller
        let original = LyricsDocument(lines: [.init(id: 0, time: 0, text: "Original")])
        f.model.session.use(original, persist: false)
        c.open(); let first = try await f.request(0)
        first.continuation.yield(f.candidate); first.continuation.finish()
        try await f.finished(); c.preview(try #require(c.results.first))
        #expect(c.canApplyPreview && f.model.session.document?.id == original.id)
        #expect(f.model.session.position == 12 && !f.model.session.isPlaying)
        #expect(await f.repository.saved.isEmpty)
        c.search(); let retry = try await f.request(1)
        retry.continuation.finish(throwing: URLError(.networkConnectionLost))
        try await f.finished()
        #expect(c.results.count == 1 && c.previewCandidate != nil && c.canApplyPreview)
        c.applyPreview()
        for _ in 0..<100 { if await !f.repository.saved.isEmpty { break }; try await Task.sleep(for: .milliseconds(5)) }
        #expect(await f.repository.saved.count == 1)
        #expect(c.previewIsApplied && f.model.session.position == 12 && !f.model.session.isPlaying)
    }
    @Test func emptyReplacementRemovesOldResultsInsteadOfOfferingThemForAnotherQuery() async throws {
        let f = PreviewFixture(); let c = f.controller
        c.open(); let first = try await f.request(0)
        first.continuation.yield(f.candidate); first.continuation.finish(); try await f.finished()
        c.query = "Another song"; c.search(); let next = try await f.request(1)
        #expect(c.retainedPreviousResults && !c.canApplyPreview)
        c.preview(f.candidate); #expect(c.previewCandidate == nil)
        next.continuation.finish(); try await f.finished()
        #expect(c.results.isEmpty && !c.retainedPreviousResults)
    }
    @Test func correctedLyricsReplaceThePreviewButAreNotMistakenForTheAppliedRevision() async throws {
        let f = PreviewFixture(); let c = f.controller
        let old = f.candidate; f.model.session.use(old.document, persist: false)
        c.open(); let first = try await f.request(0)
        first.continuation.yield(old); first.continuation.finish(); try await f.finished(); c.preview(old)
        #expect(c.previewIsApplied)
        c.search(); let retry = try await f.request(1)
        var updated = old; updated.document.lines[0].text = "Corrected" // Same song and UUID, different revision.
        retry.continuation.yield(updated); retry.continuation.finish(); try await f.finished()
        #expect(c.results.count == 1 && c.previewCandidate?.document.lines[0].text == "Corrected")
        #expect(!c.previewIsApplied && c.canApplyPreview)
        #expect(f.model.session.document?.lines[0].text == "Fixture")
    }
    @Test func timeoutAndCloseRejectLateResultsAndLateSearchingStatuses() async throws {
        let f = PreviewFixture(timeout: .milliseconds(40)); let c = f.controller
        c.open(); let pending = try await f.request(0)
        pending.updates(.init(source: "LRCLIB", count: 0, isSearching: true))
        try await f.finished()
        pending.continuation.yield(f.candidate)
        pending.updates(.init(source: "LRCLIB", count: 99, isSearching: true))
        try await Task.sleep(for: .milliseconds(10))
        #expect(c.results.isEmpty && c.error?.contains("超时") == true)
        #expect(c.sourceStatuses.allSatisfy { !$0.isSearching && $0.count == 0 })
        c.search(); let closing = try await f.request(1); c.cancel()
        closing.updates(.init(source: "LRCLIB", count: 77, isSearching: true))
        closing.continuation.yield(f.candidate)
        try await Task.sleep(for: .milliseconds(10))
        #expect(!c.searching && c.results.isEmpty && c.sourceStatuses.allSatisfy { !$0.isSearching })
    }
    @Test func switchingSongsResetsQuerySelectionAndRejectsOldRequestCallbacks() async throws {
        let f = PreviewFixture(); let c = f.controller
        c.open(); let old = try await f.request(0)
        f.model.session.accept(.init(track: .init(playerID: "fixture", playerName: "Fixture", title: "Next", artist: "New artist"), position: 0, isPlaying: false), shouldSearch: false)
        c.trackChanged()
        old.continuation.yield(f.candidate); old.updates(.init(source: "LRCLIB", count: 10, isSearching: true))
        try await Task.sleep(for: .milliseconds(10))
        #expect(c.query == "Next New artist" && c.results.isEmpty && c.previewCandidate == nil && !c.canApplyPreview)
        c.search(); let next = try await f.request(1)
        #expect(next.query == "Next New artist")
        next.continuation.finish(); try await f.finished()
        #expect(await f.repository.saved.isEmpty)
    }
    @Test func browsingPreviewStopsFollowingAndReturningRealignsWithoutChangingPlayback() {
        var follow = SearchLyricFollowState()
        let doc = LyricsDocument(lines: [.init(id: 20, time: 0, text: "First"), .init(id: 80, time: 2, text: "Next")])
        #expect(follow.request(document: doc, index: 0, reduced: false) != nil)
        #expect(follow.request(document: doc, index: 1, reduced: false, browsing: true) == nil)
        #expect(follow.request(document: doc, index: 1, reduced: false, force: true)?.index == 1)
    }
}
