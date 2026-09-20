import Foundation
import Testing
import LyricsXCore
@testable import LyricsXServices

private let songA = Track(playerID: "com.apple.Music", playerName: "Apple Music", persistentID: "A", title: "First", artist: "Artist", duration: 180, artworkData: Data([1, 2]))
private let songB = Track(playerID: "com.apple.Music", playerName: "Apple Music", persistentID: "B", title: "Second", artist: "Artist", duration: 200)
private struct NoSearch: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws { }
}
@MainActor private final class ReadState {
    var now = 100.0
    var fail = false
}
@MainActor private func eventually(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(2)) }
    #expect(condition())
}

@Test func continuityKeepsTransportIdentityAndArtworkButAcceptsRealTrackChanges() throws {
    var continuity = PlaybackContinuity()
    let originalSample = continuity.accept(.init(track: songA, position: 40, isPlaying: true), now: 0)
    let original = try #require(originalSample)
    var partial = songA; partial.persistentID = ""; partial.artworkData = nil; partial.album = ""
    let recoveredSample = continuity.accept(.init(track: partial, position: 41, isPlaying: false), now: 1)
    let recovered = try #require(recoveredSample)
    #expect(recovered.track?.id == original.track?.id && recovered.track?.artworkData == songA.artworkData)
    let changedSample = continuity.accept(.init(track: songB, position: 0, isPlaying: true), now: 2)
    let changed = try #require(changedSample)
    #expect(changed.track?.id == songB.id && changed.track?.artworkData == nil)
    var duplicateTitle = songB; duplicateTitle.persistentID = "Other recording"
    #expect(continuity.accept(.init(track: duplicateTitle, position: 0, isPlaying: true), now: 3)?.track?.persistentID == "Other recording")
}

@Test func lateMetadataAndPersistentIDCompleteTheCurrentPlaybackItem() throws {
    var continuity = PlaybackContinuity()
    let early = Track(playerID: "com.apple.Music", playerName: "Apple Music", title: "Song")
    _ = continuity.accept(.init(track: early, position: 0, isPlaying: true), now: 0)
    var complete = early
    complete.persistentID = "library-id"
    complete.artist = "Artist"
    complete.album = "Album"
    complete.artworkData = Data([4, 2])
    let reconciled = try #require(continuity.accept(.init(track: complete, position: 1, isPlaying: true), now: 1)?.track)
    #expect(reconciled.persistentID == "library-id")
    #expect(reconciled.artist == "Artist" && reconciled.album == "Album")
    #expect(early.representsSamePlaybackItem(as: reconciled))
}

@Test func confirmedEmptyStateEventuallyClearsButOneGapCannot() throws {
    var continuity = PlaybackContinuity()
    _ = continuity.accept(.init(track: songA, position: 40, isPlaying: true), now: 0)
    let gap = PlaybackSnapshot(track: nil, position: 0, isPlaying: false, positionIsReliable: false, playbackStateIsReliable: false)
    #expect(continuity.accept(gap, now: 1) == nil)
    #expect(continuity.accept(gap, now: 1.8) == nil)
    let confirmedSample = continuity.accept(gap, now: 3.1)
    let confirmed = try #require(confirmedSample)
    #expect(confirmed.track == nil && confirmed.playbackStateIsReliable)
}

@Test @MainActor func bridgeRetriesGapAndAppliesPauseWithoutClearingLyricsOrProgress() async throws {
    let session = LyricsSession(repository: NoSearch())
    var reads = 0, emissions = 0
    var errors: [String] = []
    let state = ReadState()
    let bridge = PlayerBridge(snapshotReader: {
        reads += 1
        switch reads {
        case 1: return .init(track: songA, position: 40, isPlaying: true, sampledAt: state.now)
        case 2: return .init(track: nil, position: 0, isPlaying: false, sampledAt: state.now, positionIsReliable: false, playbackStateIsReliable: false)
        default: return .init(track: songA, position: 0, isPlaying: false, sampledAt: state.now, positionIsReliable: false)
        }
    }, now: { state.now })
    bridge.onSnapshot = { snapshot in emissions += 1; session.accept(snapshot, now: state.now) }
    bridge.onError = { if let error = $0 { errors.append(error) } }
    defer { bridge.stop(); session.stop() }
    bridge.refresh()
    try await eventually { emissions == 1 }
    session.use(.init(title: "First", lines: [.init(id: 0, time: 0, text: "Still here")]), persist: false)
    let generation = session.searchGeneration
    state.now = 101
    bridge.refresh()
    try await eventually { emissions == 2 }
    #expect(reads == 3 && errors.isEmpty)
    #expect(session.track == songA && !session.isPlaying && session.position == 41)
    #expect(session.document?.lines.first?.text == "Still here" && session.searchGeneration == generation)
    session.tick(now: 300)
    #expect(session.position == 41)
}

@Test @MainActor func notificationDuringReadQueuesAFreshRead() async throws {
    var pending: CheckedContinuation<PlaybackSnapshot, Error>?
    var reads = 0
    var titles: [String] = []
    let bridge = PlayerBridge(snapshotReader: {
        reads += 1
        if reads == 1 { return try await withCheckedThrowingContinuation { pending = $0 } }
        return .init(track: songB, position: 0, isPlaying: true)
    })
    bridge.onSnapshot = { if let title = $0.track?.title { titles.append(title) } }
    defer { bridge.stop() }
    bridge.refresh()
    try await eventually { pending != nil }
    bridge.refresh() // notification while the first JXA read is still running
    pending?.resume(returning: .init(track: songA, position: 40, isPlaying: true)); pending = nil
    try await eventually { reads == 2 && titles.last == "Second" }
}

@Test @MainActor func trackCommandRejectsLateReadFromBeforeTheCommand() async throws {
    var pending: CheckedContinuation<PlaybackSnapshot, Error>?
    var reads = 0
    var titles: [String] = [], commands: [PlayerCommand] = []
    let bridge = PlayerBridge(snapshotReader: {
        reads += 1
        if reads == 1 { return try await withCheckedThrowingContinuation { pending = $0 } }
        return .init(track: songB, position: 0, isPlaying: true)
    }, commandExecutor: { commands.append($0) })
    bridge.onSnapshot = { if let title = $0.track?.title { titles.append(title) } }
    defer { bridge.stop() }
    bridge.refresh()
    try await eventually { pending != nil }
    bridge.send(.next)
    try await eventually { titles == ["Second"] }
    pending?.resume(returning: .init(track: songA, position: 40, isPlaying: true)); pending = nil
    try await Task.sleep(for: .milliseconds(20))
    #expect(titles == ["Second"] && commands == [.next])
}

@Test @MainActor func transientReadFailuresStayQuietAndPersistentFailureRecovers() async throws {
    var reads = 0
    let state = ReadState()
    var recovered = false
    var error: String?
    let bridge = PlayerBridge(snapshotReader: {
        reads += 1
        state.now += 1
        if state.fail { throw URLError(.cannotConnectToHost) }
        if reads == 1 { throw URLError(.networkConnectionLost) }
        return .init(track: songA, position: 40, isPlaying: false)
    }, now: { state.now })
    bridge.onError = { error = $0 }
    bridge.onSnapshot = { _ in recovered = true }
    defer { bridge.stop() }
    bridge.refresh()
    try await eventually { recovered }
    #expect(error == nil)
    state.fail = true
    bridge.refresh()
    try await eventually { error != nil }
    state.fail = false; recovered = false
    bridge.refresh()
    try await eventually { recovered && error == nil }
}

@Test func missingScriptFieldsStayUnknownInsteadOfBecomingPauseAtZero() throws {
    let record = try JSONDecoder().decode(PlayerBridge.ScriptRecord.self, from: Data(#"{"title":"Song","position":null,"playing":null}"#.utf8))
    #expect(record.position == nil && record.playing == nil)
    let payload = try JSONDecoder().decode(SystemMediaPayload.self, from: Data(#"{"isPlaying":false}"#.utf8))
    let sample = payload.snapshot(now: 10)
    #expect(!sample.positionIsReliable && sample.playbackStateIsReliable && !sample.isPlaying)
}
