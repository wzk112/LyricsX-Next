import Foundation
import Testing
@testable import LyricsXCore

private final class ControlledRepository: LyricsRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var streams: [AsyncThrowingStream<LyricCandidate, Error>.Continuation] = []
    private var saves: [LyricsDocument] = []
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> {
        AsyncThrowingStream { continuation in lock.withLock { streams.append(continuation) } }
    }
    func save(_ document: LyricsDocument, for track: Track) async throws { lock.withLock { saves.append(document) } }
    func yield(_ document: LyricsDocument, at index: Int, score: Double = 80) {
        let continuation = lock.withLock { streams[index] }
        continuation.yield(.init(document: document, score: score))
    }
    func finish(_ index: Int) { lock.withLock { streams[index] }.finish() }
    func fail(_ index: Int) { lock.withLock { streams[index] }.finish(throwing: URLError(.networkConnectionLost)) }
    var count: Int { lock.withLock { streams.count } }
    var savedTitles: [String] { lock.withLock { saves.map(\.title) } }
}

@Suite @MainActor struct SessionTests {
    @Test func displayFramesAdvanceBetweenTicksAndFollowPauseAndSeek() {
        let session = LyricsSession(repository: ControlledRepository())
        session.accept(.init(track: first, position: 10, isPlaying: true, sampledAt: 100), now: 100, shouldSearch: false)
        #expect(session.position == 10)
        #expect(abs(session.presentationPosition(at: 100 + 1.0 / 60) - (10 + 1.0 / 60)) < 0.00001)
        #expect(session.position == 10) // Drawing never mutates the session.
        session.accept(.init(track: first, position: 10.1, isPlaying: false, sampledAt: 100.1), now: 100.1, shouldSearch: false)
        #expect(session.presentationPosition(at: 102) == 10.1)
        session.seek(to: 30, now: 102)
        #expect(session.presentationPosition(at: 103) == 30)
        session.stop()
    }
    @Test func shortInstrumentalPlaceholderPhrasesAreDetectedWithoutHidingRealLyrics() {
        let chinese = LyricsDocument(lines: [.init(id: 0, time: 0, text: "♪ 纯音乐，请欣赏 ♪")])
        let english = LyricsDocument(lines: [.init(id: 0, time: 0, text: "No lyrics available")])
        let japanese = LyricsDocument(lines: [.init(id: 0, time: 0, text: "インストゥルメンタル")])
        let symbols = LyricsDocument(lines: [.init(id: 0, time: 0, text: "♫ ♪ ♬")])
        let realShortSong = LyricsDocument(lines: [
            .init(id: 0, time: 0, text: "Please enjoy the sunshine"),
            .init(id: 1, time: 2, text: "We will sing again"),
            .init(id: 2, time: 4, text: "Tonight")
        ])
        let longerSong = LyricsDocument(lines: (0..<4).map { .init(id: $0, time: Double($0), text: "纯音乐") })
        #expect(chinese.isLikelyInstrumentalPlaceholder)
        #expect(english.isLikelyInstrumentalPlaceholder)
        #expect(japanese.isLikelyInstrumentalPlaceholder)
        #expect(symbols.isLikelyInstrumentalPlaceholder)
        #expect(!realShortSong.isLikelyInstrumentalPlaceholder)
        #expect(!longerSong.isLikelyInstrumentalPlaceholder)
    }

    @Test func acceptedResultIsSavedEvenIfTheSearchLaterFails() async {
        let repo = ControlledRepository(); let session = LyricsSession(repository: repo)
        session.accept(snapshot(first))
        repo.yield(.init(title: "Accepted"), at: 0, score: 800)
        await waitFor { session.document?.title == "Accepted" }
        repo.fail(0)
        await waitFor { repo.savedTitles.contains("Accepted") }
        #expect(session.phase == .ready)
        session.stop()
    }
    @Test func positiveAndNegativeOffsetsCrossTheSameBoundaryAndReset() {
        let repo = ControlledRepository(); let session = LyricsSession(repository: repo)
        let now = ProcessInfo.processInfo.systemUptime
        session.accept(.init(track: first, position: 10, isPlaying: false, sampledAt: now), now: now)
        session.use(.init(title: "A", lines: [
            .init(id: 0, time: 0, text: "Before"), .init(id: 1, time: 10.1, text: "After")
        ]), persist: false)
        #expect(session.currentLineIndex == 0)
        session.adjustOffset(by: 200)
        #expect(session.document?.offsetMilliseconds == 200 && session.currentLineIndex == 1)
        session.adjustOffset(by: -400)
        #expect(session.document?.offsetMilliseconds == -200 && session.currentLineIndex == 0)
        session.resetOffset()
        #expect(session.document?.offsetMilliseconds == 0 && session.position == 10)
        session.stop()
    }
    @Test func suppressedTrackKeepsTimeWithoutStartingSearch() {
        let repo = ControlledRepository(); let session = LyricsSession(repository: repo)
        session.accept(snapshot(first, position: 10), shouldSearch: false)
        #expect(repo.count == 0)
        #expect(session.position >= 10 && session.isPlaying && session.document == nil)
        session.accept(snapshot(second, position: 1))
        #expect(repo.count == 1)
        session.suppressLyrics()
        repo.yield(.init(title: "Late"), at: 0)
        #expect(session.document == nil)
        session.stop()
    }
    private let first = Track(playerID: "test", playerName: "", title: "A")
    private let second = Track(playerID: "test", playerName: "", title: "B")
    private func snapshot(_ track: Track?, position: Double = 0, playing: Bool = true) -> PlaybackSnapshot {
        .init(track: track, position: position, isPlaying: playing)
    }
    private func waitFor(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<1000 { if condition() { return }; await Task.yield() }
        #expect(condition())
    }
    @Test func lateResultFromPreviousSongCannotOverwriteCurrentSong() async {
        let repo = ControlledRepository(); let session = LyricsSession(repository: repo)
        session.accept(snapshot(first)); session.accept(snapshot(second))
        repo.yield(.init(title: "B"), at: 1)
        await waitFor { session.document?.title == "B" }
        repo.yield(.init(title: "A"), at: 0, score: 100)
        await Task.yield()
        #expect(session.document?.title == "B"); session.stop()
    }
    @Test func returningToSameTrackDoesNotAcceptOldSearch() async {
        let repo = ControlledRepository(); let session = LyricsSession(repository: repo)
        session.accept(snapshot(first)); session.accept(snapshot(second)); session.accept(snapshot(first))
        repo.yield(.init(title: "fresh A"), at: 2)
        await waitFor { session.document?.title == "fresh A" }
        repo.yield(.init(title: "stale A"), at: 0, score: 500)
        await Task.yield()
        #expect(session.document?.title == "fresh A"); session.stop()
    }
    @Test func manualImportWinsAgainstPendingNetworkResults() async {
        let repo = ControlledRepository(); let session = LyricsSession(repository: repo)
        session.accept(snapshot(first)); session.use(.init(title: "import"))
        repo.yield(.init(title: "remote"), at: 0, score: 500)
        await Task.yield()
        #expect(session.document?.title == "import"); session.stop()
    }
    @Test func artworkOnlyUpdateDoesNotRestartSearch() {
        let repo = ControlledRepository(); let session = LyricsSession(repository: repo)
        session.accept(snapshot(first))
        var updated = first; updated.artworkData = Data([9])
        session.accept(snapshot(updated))
        #expect(repo.count == 1); #expect(session.track?.artworkData == Data([9])); session.stop()
    }
    @Test func metadataOnlyUpdateDoesNotResetReliablePlaybackTime() {
        let repo = ControlledRepository(); let session = LyricsSession(repository: repo)
        let now = ProcessInfo.processInfo.systemUptime
        session.accept(.init(track: first, position: 20, isPlaying: true, sampledAt: now), now: now)
        var updated = first; updated.artworkData = Data([8])
        session.accept(.init(
            track: updated,
            position: 0,
            isPlaying: false,
            sampledAt: now + 0.2,
            positionIsReliable: false,
            playbackStateIsReliable: false
        ), now: now + 0.2)
        #expect(session.position > 20)
        #expect(session.isPlaying)
        session.stop()
    }
    @Test func clearingTrackImmediatelyClearsLyricsAndLine() {
        let repo = ControlledRepository(); let session = LyricsSession(repository: repo)
        session.accept(snapshot(first, position: 5)); session.use(.init(lines: [.init(id: 0, time: 1, text: "A")]))
        #expect(session.currentLineIndex == 0)
        session.accept(snapshot(nil, playing: false))
        #expect(session.document == nil); #expect(session.currentLineIndex == nil); #expect(session.phase == .idle)
    }
    @Test func unreliableEmptySnapshotDoesNotClearTrackDuringSeek() {
        let repo = ControlledRepository(); let session = LyricsSession(repository: repo)
        let now = ProcessInfo.processInfo.systemUptime
        session.accept(.init(track: first, position: 12, isPlaying: true, sampledAt: now), now: now, shouldSearch: false)
        session.seek(to: 30, now: now + 1)
        session.accept(.init(track: nil, position: 0, isPlaying: false, sampledAt: now + 1.1,
                             positionIsReliable: false, playbackStateIsReliable: false), now: now + 1.1)
        #expect(session.track == first)
        #expect(session.position >= 30 && session.position < 31)
        session.stop()
    }
    @Test func seekCannotBeUndoneByOneOldPoll() {
        let repo = ControlledRepository(); let session = LyricsSession(repository: repo)
        let now = ProcessInfo.processInfo.systemUptime
        session.accept(.init(track: first, position: 30, isPlaying: false, sampledAt: now), now: now)
        session.seek(to: 5, now: now)
        session.accept(.init(track: first, position: 30, isPlaying: false, sampledAt: now + 0.1), now: now + 0.1)
        #expect(session.position == 5)
        session.accept(.init(track: first, position: 5, isPlaying: false, sampledAt: now + 1), now: now + 1)
        #expect(session.position == 5); session.stop()
    }
    @Test func seekConfirmationAcceptsFreshPlayerPosition() {
        let repo = ControlledRepository(); let session = LyricsSession(repository: repo)
        let now = ProcessInfo.processInfo.systemUptime
        session.accept(.init(track: first, position: 30, isPlaying: false, sampledAt: now), now: now)
        session.seek(to: 5, now: now)
        session.accept(.init(track: first, position: 5.4, isPlaying: false, sampledAt: now + 0.2), now: now + 0.2)
        #expect(session.position == 5.4)
        session.stop()
    }
    @Test func failedSeekCanReleaseProtectionImmediately() {
        let repo = ControlledRepository(); let session = LyricsSession(repository: repo)
        let now = ProcessInfo.processInfo.systemUptime
        session.accept(.init(track: first, position: 30, isPlaying: false, sampledAt: now), now: now)
        session.seek(to: 5, now: now)
        session.rejectPendingSeek()
        session.accept(.init(track: first, position: 30, isPlaying: false, sampledAt: now + 0.2), now: now + 0.2)
        #expect(session.position == 30)
        session.stop()
    }
    @Test func retryOfSameTrackRejectsEarlierRequest() async {
        let repo = ControlledRepository(); let session = LyricsSession(repository: repo)
        session.accept(snapshot(first)); session.reload(forceRefresh: true)
        repo.yield(.init(title: "new"), at: 1)
        await waitFor { session.document?.title == "new" }
        repo.yield(.init(title: "old"), at: 0, score: 500)
        await Task.yield()
        #expect(session.document?.title == "new"); session.stop()
    }
    @Test func offsetEditStopsPriorityReplacement() async {
        let repo = ControlledRepository(); let session = LyricsSession(repository: repo)
        session.accept(snapshot(first)); repo.yield(.init(title: "selected"), at: 0)
        await waitFor { session.document != nil }
        session.adjustOffset(by: 200); repo.yield(.init(title: "other"), at: 0, score: 100)
        await Task.yield()
        #expect(session.document?.title == "selected"); #expect(session.document?.offsetMilliseconds == 200); session.stop()
    }
    @Test func silentProviderTimesOutInsteadOfLoadingForever() async throws {
        let repo = ControlledRepository(); let session = LyricsSession(repository: repo, searchTimeout: .milliseconds(20))
        session.accept(snapshot(first))
        // The 20 ms production deadline is unchanged. Allow the shared
        // MainActor to finish concurrent native rendering before inspecting it.
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while session.phase == .loading, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        if case .failed = session.phase { } else { Issue.record("Expected timeout failure") }
        session.stop()
    }
    @Test func searchWithoutResultsHasExplicitEmptyState() async {
        let repo = ControlledRepository(); let session = LyricsSession(repository: repo)
        session.accept(snapshot(first)); repo.finish(0)
        await waitFor { session.phase == .notFound }; session.stop()
    }
}

private final class TerminationRepository: LyricsRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var ended = false
    let pair = AsyncThrowingStream<LyricCandidate, Error>.makeStream()
    var terminated: Bool { lock.withLock { ended } }
    init() { pair.continuation.onTermination = { [weak self] _ in self?.lock.withLock { self?.ended = true } } }
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { pair.stream }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

@Test @MainActor func discardedSessionCancelsSuspendedSearchWithoutWaitingForDeadline() async throws {
    let repository = TerminationRepository()
    var session: LyricsSession? = LyricsSession(repository: repository)
    weak var reference = session
    session?.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Lifetime"), position: 0, isPlaying: true))
    try await Task.sleep(for: .milliseconds(10))
    session = nil
    for _ in 0..<100 where !repository.terminated { try await Task.sleep(for: .milliseconds(2)) }
    #expect(reference == nil)
    #expect(repository.terminated)
    repository.pair.continuation.finish()
}

@Test @MainActor func malformedExtremeOffsetCanBeAdjustedAndResetWithoutOverflow() {
    let session = LyricsSession(repository: ControlledRepository())
    defer { session.stop() }
    session.use(.init(lines: [.init(id: 0, time: 0, text: "Test")], offsetMilliseconds: .max), persist: false)
    session.adjustOffset(by: 100)
    #expect(session.document?.offsetMilliseconds == 300_000)
    session.use(.init(lines: [.init(id: 0, time: 0, text: "Test")], offsetMilliseconds: .min), persist: false)
    session.adjustOffset(by: -100)
    #expect(session.document?.offsetMilliseconds == -300_000)
    session.use(.init(lines: [.init(id: 0, time: 0, text: "Test")], offsetMilliseconds: .min), persist: false)
    session.resetOffset()
    #expect(session.document?.offsetMilliseconds == 0)
}
