import Foundation
import Testing
import LyricsXCore
@testable import LyricsXServices

@MainActor private func waitForArtworkTest(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(2)) }
    #expect(condition())
}
@MainActor private final class ArtworkClock { var time = 100.0 }
private struct ArtworkNoSearch: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws { }
}

@Test @MainActor func slowArtworkDoesNotDelayTransportOrDuplicateRequests() async throws {
    let song = Track(playerID: "com.apple.Music", playerName: "Apple Music", persistentID: "A", title: "First", artist: "Artist")
    var reads = 0, artReads = 0
    var pending: CheckedContinuation<Data?, Never>?
    var emitted: [PlaybackSnapshot] = []
    let session = LyricsSession(repository: ArtworkNoSearch())
    let bridge = PlayerBridge(snapshotReader: {
        reads += 1
        return .init(track: song, position: Double(39 + reads), isPlaying: true, sampledAt: Double(99 + reads))
    }, artworkReader: { _ in
        artReads += 1
        return await withCheckedContinuation { pending = $0 }
    })
    bridge.onSnapshot = { emitted.append($0); session.accept($0, now: $0.sampledAt) }
    defer { bridge.stop(); session.stop(); pending?.resume(returning: nil) }
    bridge.refresh()
    try await waitForArtworkTest { emitted.count == 1 && pending != nil }
    #expect(emitted[0].position == 40 && emitted[0].track?.artworkData == nil)
    session.use(.init(title: "Chosen"), persist: false)
    let trackRevision = session.trackRevision, searchGeneration = session.searchGeneration
    bridge.refresh()
    try await waitForArtworkTest { emitted.count == 2 }
    #expect(emitted[1].position == 41 && artReads == 1)
    pending?.resume(returning: Data([1, 2, 3])); pending = nil
    try await waitForArtworkTest { emitted.count == 3 }
    #expect(emitted[2].position == 41 && emitted[2].sampledAt == 101)
    #expect(!emitted[2].positionIsReliable && !emitted[2].playbackStateIsReliable)
    #expect(emitted[2].track?.artworkData == Data([1, 2, 3]))
    #expect(session.position == 41 && session.isPlaying && session.document?.title == "Chosen")
    #expect(session.trackRevision == trackRevision && session.searchGeneration == searchGeneration)
}

@Test @MainActor func lateArtworkCannotReachChangedTrackOrPlayer() async throws {
    let first = Track(playerID: "com.apple.Music", playerName: "Apple Music", persistentID: "shared", title: "First")
    let next = Track(playerID: "com.apple.Music", playerName: "Apple Music", persistentID: "next", title: "Next")
    let spotify = Track(playerID: "com.spotify.client", playerName: "Spotify", persistentID: "shared", title: "First")
    var reads = 0
    var pending: CheckedContinuation<Data?, Never>?
    var emitted: [PlaybackSnapshot] = []
    let bridge = PlayerBridge(snapshotReader: {
        reads += 1
        let track = reads == 1 ? first : reads == 2 ? next : spotify
        return .init(track: track, position: 1, isPlaying: true)
    }, artworkReader: { track in
        if track.id == first.id { return await withCheckedContinuation { pending = $0 } }
        return nil
    })
    bridge.onSnapshot = { emitted.append($0) }
    defer { bridge.stop(); pending?.resume(returning: nil) }
    bridge.refresh()
    try await waitForArtworkTest { emitted.count == 1 && pending != nil }
    bridge.refresh()
    try await waitForArtworkTest { emitted.count == 2 }
    bridge.refresh()
    try await waitForArtworkTest { emitted.count == 3 }
    pending?.resume(returning: Data([9])); pending = nil
    try await Task.sleep(for: .milliseconds(20))
    #expect(emitted.count == 3)
    #expect(emitted[1].track?.id == next.id && emitted[1].track?.artworkData == nil)
    #expect(emitted[2].track?.id == spotify.id && emitted[2].track?.artworkData == nil)
}

@Test @MainActor func stoppedBridgeDropsLateArtwork() async throws {
    let song = Track(playerID: "com.apple.Music", playerName: "Apple Music", persistentID: "A", title: "First")
    var pending: CheckedContinuation<Data?, Never>?
    var emitted: [PlaybackSnapshot] = []
    let bridge = PlayerBridge(snapshotReader: { .init(track: song, position: 2, isPlaying: true) },
                              artworkReader: { _ in await withCheckedContinuation { pending = $0 } })
    bridge.onSnapshot = { emitted.append($0) }
    bridge.refresh()
    try await waitForArtworkTest { emitted.count == 1 && pending != nil }
    bridge.stop()
    pending?.resume(returning: Data([9])); pending = nil
    try await Task.sleep(for: .milliseconds(20))
    #expect(emitted.count == 1 && emitted[0].track?.artworkData == nil)
}

@Test @MainActor func missingArtworkKeepsRetryPacing() async throws {
    let song = Track(playerID: "com.apple.Music", playerName: "Apple Music", persistentID: "A", title: "First")
    let clock = ArtworkClock()
    var requests = 0, snapshots = 0
    let bridge = PlayerBridge(snapshotReader: { .init(track: song, position: 1, isPlaying: true) },
                              artworkReader: { _ in requests += 1; return nil }, now: { clock.time })
    bridge.onSnapshot = { _ in snapshots += 1 }
    defer { bridge.stop() }
    bridge.refresh()
    try await waitForArtworkTest { snapshots == 1 && requests == 1 }
    bridge.refresh()
    try await waitForArtworkTest { snapshots == 2 }
    #expect(requests == 1)
    clock.time = 104
    bridge.refresh()
    try await waitForArtworkTest { snapshots == 3 && requests == 2 }
}

@Test @MainActor func partialMetadataAndAlbumCompletionKeepMatchingArtwork() async throws {
    let full = Track(playerID: "com.apple.Music", playerName: "Apple Music", persistentID: "A",
                     title: "Song", artist: "Artist", artworkData: Data([7]))
    let partial = Track(playerID: "com.apple.Music", playerName: "Apple Music", title: "Song")
    var album = full; album.album = "Album"; album.artworkData = nil
    var next = album; next.title = "Other"; next.artworkData = nil
    let samples = [full, partial, partial, album, album, next]
    var index = 0, artReads = 0
    var emitted: [PlaybackSnapshot] = []
    let bridge = PlayerBridge(snapshotReader: {
        let track = samples[index]; index += 1
        return .init(track: track, position: Double(index), isPlaying: true)
    }, artworkReader: { _ in artReads += 1; return nil })
    bridge.onSnapshot = { emitted.append($0) }
    defer { bridge.stop() }
    for count in 1...samples.count {
        bridge.refresh()
        try await waitForArtworkTest { emitted.count == count }
        if count <= 5 {
            #expect(emitted[count - 1].track?.artworkData == Data([7]))
            #expect(artReads == 0)
        }
    }
    #expect(emitted[1].track?.id == full.id)
    #expect(emitted[3].track?.album == "Album")
    #expect(emitted[5].track?.title == "Other" && emitted[5].track?.artworkData == nil)
}
