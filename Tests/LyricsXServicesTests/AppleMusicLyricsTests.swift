import Foundation
import Testing
import LyricsXCore
@testable import LyricsXServices

private actor MusicReads {
    var calls = 0
    let values: [String?]
    init(_ values: [String?]) { self.values = values }
    func next() -> String? {
        let index = calls; calls += 1
        return index < values.count ? values[index] : nil
    }
}
private func musicTrack(_ lyrics: String? = nil) -> Track {
    .init(playerID: "com.apple.Music", playerName: "Apple Music", persistentID: "fixture",
        title: "Music field fixture", artist: "Test artist", album: "Test album", duration: 120, embeddedLyrics: lyrics)
}
private func musicStore(reader: @escaping LyricsStore.AppleMusicReader,
                        network: LyricsStore.SearchBackend? = nil, enabled: Bool = true) -> LyricsStore {
    LyricsStore(cache: .init(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
        configuration: {
            var config = SourceConfiguration(); config.enabled = ["LRCLIB"]
            if enabled { config.enabled.insert("Apple Music") }; return config
        }, aliasResolver: .init(fetch: { _ in Data(#"{"results":[]}"#.utf8) }), firstResultDelay: .milliseconds(1),
        appleMusicReader: reader,
        searchBackend: network ?? { _, _, _, _ in .init { $0.finish() } })
}

@Test func musicRetriesEmptyValuesButStopsAtAReadableDocument() async throws {
    let reads = MusicReads([nil, "  ", "[00:01.00]Late line"])
    let source = AppleMusicLyricsSource(retryDelays: [.zero, .zero, .zero]) { _ in await reads.next() }
    let doc = try #require(try await source.document(for: musicTrack()))
    #expect(await reads.calls == 3)
    #expect(doc.isSynced && doc.source == "Apple Music" && doc.title == musicTrack().title)
}
@Test func musicEmptyReadHasAFiniteBudgetAndNonMusicTracksNeverRead() async throws {
    let reads = MusicReads([])
    let source = AppleMusicLyricsSource(retryDelays: [.zero, .zero, .zero]) { _ in await reads.next() }
    #expect(try await source.document(for: musicTrack()) == nil)
    #expect(await reads.calls == 3)
    #expect(try await source.document(for: .init(playerID: "test", playerName: "", title: "Other")) == nil)
    #expect(await reads.calls == 3)
}
@Test func musicPermissionErrorDoesNotTriggerRepeatedAuthorizationAttempts() async {
    let reads = MusicReads([])
    let source = AppleMusicLyricsSource(retryDelays: [.zero, .zero, .zero]) { _ in
        _ = await reads.next(); throw AppleMusicLyricsSource.ReadError.permission
    }
    do { _ = try await source.document(for: musicTrack()); Issue.record("Permission failure must surface") }
    catch { #expect(error is AppleMusicLyricsSource.ReadError) }
    #expect(await reads.calls == 1)
}
@Test func musicCancellationDuringBackoffStopsFurtherReads() async throws {
    let reads = MusicReads([])
    let source = AppleMusicLyricsSource(retryDelays: [.zero, .seconds(10)]) { _ in await reads.next() }
    let task = Task { try await source.document(for: musicTrack()) }
    while await reads.calls == 0 { await Task.yield() }
    task.cancel()
    do { _ = try await task.value; Issue.record("Cancelled old-song read must stop") }
    catch { #expect(error is CancellationError) }
    #expect(await reads.calls == 1)
}
@Test func musicPlainTextIsPreviewableWhileOtherSourcesCanProvideSynchronization() async throws {
    let track = musicTrack("Plain first line\nPlain second line")
    let store = musicStore(reader: { AppleMusicLyricsSource.parse($0.embeddedLyrics, for: $0) }, network: { track, _, _, _ in
        .init { continuation in
            continuation.yield(.init(title: track.title, artist: track.artist, source: "LRCLIB",
                duration: track.duration, lines: [.init(id: 0, time: 1, text: "Synchronized line")]))
            continuation.finish()
        }
    })
    var manual: [LyricCandidate] = []
    for try await value in store.search(track: track, keyword: track.title + " " + track.artist) { manual.append(value) }
    #expect(manual.contains { $0.document.source == "Apple Music" && !$0.document.isSynced && $0.document.plainText != nil })
    #expect(manual.contains { $0.document.source == "LRCLIB" && $0.document.isSynced })
    var automatic: [LyricCandidate] = []
    for try await value in store.lyrics(for: track, forceRefresh: true) { automatic.append(value) }
    #expect(automatic.max(by: { $0.score < $1.score })?.document.source == "LRCLIB")
}
@Test func musicReadFailureDoesNotDiscardNetworkLyrics() async throws {
    let track = musicTrack()
    let store = musicStore(reader: { _ in throw AppleMusicLyricsSource.ReadError.unavailable }, network: { track, _, _, _ in
        .init { $0.yield(.init(title: track.title, artist: track.artist, source: "LRCLIB",
            lines: [.init(id: 0, time: 0, text: "Fallback") ])); $0.finish() }
    })
    var results: [LyricCandidate] = []
    for try await value in store.search(track: track, keyword: track.title) { results.append(value) }
    #expect(results.contains { $0.document.source == "LRCLIB" })
}
@Test func unrelatedManualQueriesAndDisabledMusicSourceDoNotReadThePlayingSong() async throws {
    let reads = MusicReads([])
    for (enabled, query) in [(true, "A completely different song"), (false, musicTrack().title)] {
        let store = musicStore(reader: { _ in _ = await reads.next(); return nil }, enabled: enabled)
        for try await _ in store.search(track: musicTrack(), keyword: query) {}
    }
    #expect(await reads.calls == 0)
}
@Test func savedManualMusicChoiceAndOffsetRemainAuthoritative() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = LyricsCache(directory: directory)
    let selected = LyricsDocument(title: musicTrack().title, artist: musicTrack().artist, source: "Manual",
        lines: [.init(id: 0, time: 0, text: "Keep my selection")], offsetMilliseconds: 700)
    try await cache.save(selected, for: musicTrack())
    let reads = MusicReads([])
    let store = LyricsStore(cache: cache, aliasResolver: .init(fetch: { _ in Data(#"{"results":[]}"#.utf8) }),
        appleMusicReader: { _ in _ = await reads.next(); return nil }, searchBackend: { _, _, _, _ in .init { $0.finish() } })
    var values: [LyricCandidate] = []
    for try await value in store.lyrics(for: musicTrack(), forceRefresh: false) { values.append(value) }
    #expect(values.count == 1 && values[0].document.offsetMilliseconds == 700)
    #expect(await reads.calls == 0)
}

@Test func standaloneMusicSourceHonorsPriorityEvenWhenItsFieldArrivesAfterNetworkLyrics() async throws {
    let track = musicTrack("[00:01.00]Native line")
    for first in ["Apple Music", "LRCLIB"] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LyricsStore(cache: .init(directory: directory), configuration: {
            var config = SourceConfiguration(); config.enabled = ["Apple Music", "LRCLIB"]
            config.sourceOrder = [first] + ["Apple Music", "LRCLIB"].filter { $0 != first }
            config.preferWordTiming = false; config.preferBilingual = false
            return config
        }, aliasResolver: .init(fetch: { _ in Data(#"{"results":[]}"#.utf8) }), firstResultDelay: .milliseconds(1),
        appleMusicReader: {
            try await Task.sleep(for: .milliseconds(60))
            return AppleMusicLyricsSource.parse($0.embeddedLyrics, for: $0)
        }, searchBackend: { track, _, _, _ in
            .init { $0.yield(.init(title: track.title, artist: track.artist, source: "LRCLIB", duration: track.duration,
                lines: [.init(id: 0, time: 1, text: "Network line")])); $0.finish() }
        })
        var values: [LyricCandidate] = []
        for try await value in store.lyrics(for: track, forceRefresh: true) { values.append(value) }
        let best = values.max(by: { $0.score < $1.score })
        #expect(best?.document.source == first)
        #expect(values.contains { $0.document.source == first && !$0.isProvisional })
    }
}

private actor MusicSourceStatuses {
    var values: [SourceSearchStatus] = []
    func append(_ value: SourceSearchStatus) { values.append(value) }
}
@Test func standaloneMusicStatusFinishesEmptyWithoutIssuingProviderQueriesForIt() async throws {
    let track = musicTrack()
    let providerReads = MusicReads([])
    let store = LyricsStore(cache: .init(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
        configuration: { var config = SourceConfiguration(); config.enabled = ["Apple Music"]; return config },
        aliasResolver: .init(fetch: { _ in Data(#"{"results":[]}"#.utf8) }), appleMusicReader: { _ in nil },
        searchBackend: { _, _, _, _ in .init { continuation in
            Task { _ = await providerReads.next(); continuation.finish() }
        } })
    let statuses = MusicSourceStatuses()
    for try await _ in store.search(track: track, keyword: track.title, onSourceUpdate: { value in
        Task { await statuses.append(value) }
    }) {}
    // Status callbacks enqueue actor messages; let those messages settle.
    for _ in 0..<50 {
        if await statuses.values.contains(where: { !$0.isSearching }) { break }
        try await Task.sleep(for: .milliseconds(1))
    }
    #expect(await providerReads.calls == 0)
    #expect(await statuses.values.contains { $0.source == "Apple Music" && !$0.isSearching && $0.count == 0 && $0.issue != nil })
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["LYRICSX_LIVE_MUSIC_FIELD"] == "1"))
@MainActor func liveMusicLyricsFieldReadIsReadOnly() async throws {
    let bridge = PlayerBridge()
    var snapshot: PlaybackSnapshot?
    bridge.onSnapshot = { snapshot = $0 }
    bridge.mode = .appleMusic
    bridge.start()
    defer { bridge.stop() }
    let deadline = ContinuousClock.now.advanced(by: .seconds(6))
    while snapshot?.track == nil && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(50)) }
    let track = try #require(snapshot?.track)
    let doc = try await AppleMusicLyricsSource().document(for: track)
    print("MUSIC_FIELD title=\(track.title) source=\(doc?.source ?? "none") synced=\(doc?.isSynced ?? false) chars=\(doc?.plainText?.count ?? 0) lines=\(doc?.lines.count ?? 0)")
}
