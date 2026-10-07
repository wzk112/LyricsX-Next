import Foundation
import Testing
import LyricsXCore
@testable import LyricsXServices

private let cloudTTML = """
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:itunes="http://music.apple.com/lyric-ttml-internal" xmlns:ttm="http://www.w3.org/ns/ttml#metadata" itunes:timing="Word">
<head><metadata><itunes:translations><itunes:translation type="subtitle" xml:lang="zh-Hans"><itunes:text for="L1">测试翻译</itunes:text></itunes:translation></itunes:translations></metadata></head>
<body><div begin="1" end="8"><p begin="1" end="4" itunes:key="L1" ttm:agent="v1"><span begin="1.1" end="1.3">We</span> <span begin="2" end="3">sing</span><span ttm:role="x-bg"><span begin="2.2" end="2.7">Backing</span></span></p><p begin="5" end="8"><span begin="5.1" end="5.5">测</span><span begin="6" end="7.7">试</span></p></div></body></tt>
"""
private let cloudTrack = Track(playerID: "com.apple.Music", playerName: "Apple Music", title: "Song", artist: "Artist", album: "Album", duration: 120)
private let cloudCatalog = Data(#"{"results":{"songs":{"data":[{"id":"123","attributes":{"name":"Song","artistName":"Artist","albumName":"Album","durationInMillis":120000}}]}}}"#.utf8)
private actor CloudRoutes {
    var paths: [String] = []
    func read(_ path: String) throws -> Data {
        paths.append(path)
        if path == "/v1/me/storefront" { return Data(#"{"data":[{"id":"au"}]}"#.utf8) }
        if path.contains("/search?") { return cloudCatalog }
        return try JSONSerialization.data(withJSONObject: ["data": [["attributes": ["ttmlLocalizations": cloudTTML]]]])
    }
}

@Test func appleTTMLKeepsWordGapsWhitespaceTranslationAndOriginalDocument() throws {
    let doc = try LyricsCodec.parse(cloudTTML)
    #expect(doc.isSynced && doc.hasWordTiming && doc.hasTranslation)
    #expect(doc.lines.count == 2 && doc.lines[0].time == 1)
    #expect(doc.lines[0].text == "We sing" && doc.lines[0].translation == "测试翻译")
    #expect(doc.lines[0].words.map(\.text) == ["We", "sing"])
    #expect(doc.lines[0].words[0].end == 1.3 && doc.lines[0].words[1].start == 2)
    #expect(doc.lines[0].wordTimingRanges.map { String(doc.lines[0].text[$0.range]) } == ["We", "sing"])
    #expect(doc.lines[1].text == "测试" && doc.lines[1].words[1].end == 7.7)
    #expect(doc.originalTTML == cloudTTML)
}

@Test func appleTTMLDoesNotFabricateTimingForLineOrPlainLyrics() throws {
    let line = try LyricsCodec.parse("<tt xmlns:itunes=\"http://music.apple.com/lyric-ttml-internal\" itunes:timing=\"Line\"><body><div><p begin=\"1:02.500\" end=\"1:05\">Line only</p></div></body></tt>")
    #expect(line.isSynced && !line.hasWordTiming && line.lines[0].time == 62.5)
    let plain = try LyricsCodec.parse("<tt><body><div><p>Untimed words</p></div></body></tt>")
    #expect(!plain.isSynced && !plain.hasWordTiming && plain.plainText == "Untimed words")
    #expect(throws: (any Error).self) { try LyricsCodec.parse("<tt><body><p>Broken") }
    #expect(throws: (any Error).self) { try LyricsCodec.parse("<!DOCTYPE tt [<!ENTITY text 'expanded'>]><tt><body><p>&text;</p></body></tt>") }
    #expect(TTMLLyricsParser.time("1250ms") == 1.25)
    #expect(TTMLLyricsParser.time("NaN") == nil)
    #expect(TTMLLyricsParser.time("1e308h") == nil)
    #expect(try LyricsCodec.parse("<tt><body><p begin=\"1\"><![CDATA[A & B]]></p></body></tt>").lines[0].text == "A & B")
}

@Test func cloudCacheRoundTripRetainsExactEndsRawTTMLSourceAndSavedOffset() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = LyricsCache(directory: directory)
    var doc = try LyricsCodec.parse(cloudTTML, source: AppleMusicCloudLyricsSource.name)
    doc.offsetMilliseconds = 230; doc.providerID = "apple-cloud:au:123"; doc.duration = 120
    try await cache.save(doc, for: cloudTrack)
    let restored = try #require(await cache.load(for: cloudTrack))
    #expect(restored.lines == doc.lines && restored.originalTTML == cloudTTML)
    #expect(restored.offsetMilliseconds == 230 && restored.providerID == doc.providerID)
    #expect(restored.source == doc.source && restored.duration == 120)
    #expect(!LyricsCodec.export(restored, plain: true).contains("<tt"))
}

@Test func cloudSourceUsesAccountRegionAndLocalizedWordLyrics() async throws {
    let routes = CloudRoutes()
    let source = AppleMusicCloudLyricsSource(request: { try await routes.read($0) })
    let doc = try #require(await source.document(for: cloudTrack))
    #expect(doc.hasWordTiming && doc.providerID == "apple-cloud:au:123")
    #expect(doc.source == AppleMusicCloudLyricsSource.name && doc.title == cloudTrack.title)
    let paths = await routes.paths
    #expect(paths.count == 3 && paths[2].contains("/catalog/au/songs/123/syllable-lyrics"))
    var other = cloudTrack; other.playerID = "com.spotify.client"
    #expect(try await source.document(for: other) == nil)
    #expect(await routes.paths.count == 3)
}

@Test func cloudMatchingRejectsWrongArtistAlbumRecordingAndUntrustedIDs() throws {
    let songs = try JSONDecoder().decode(Catalog.self, from: cloudCatalog).results.songs.data
    #expect(AppleMusicCloudLyricsSource.match(songs, to: cloudTrack)?.id == "123")
    for changed in ["artist", "album", "duration", "title"] {
        var track = cloudTrack
        switch changed { case "artist": track.artist = "Unrelated"; case "album": track.album = "Live Album"; case "duration": track.duration = 200; default: track.title = "Another Song" }
        #expect(AppleMusicCloudLyricsSource.match(songs, to: track) == nil)
    }
    #expect(try AppleMusicCloudLyricsSource.ttml(in: Data(#"{"data":[]}"#.utf8)) == nil)
    for badID in ["../123", "１２３"] {
        let invalid = try JSONDecoder().decode(Catalog.self, from: Data(String(decoding: cloudCatalog, as: UTF8.self).replacingOccurrences(of: "123", with: badID).utf8)).results.songs.data
        #expect(AppleMusicCloudLyricsSource.match(invalid, to: cloudTrack) == nil)
    }
    for attributes: [String: Any] in [["ttml": cloudTTML], ["ttmlLocalizations": ["zh-Hans-CN": cloudTTML]]] {
        let data = try JSONSerialization.data(withJSONObject: ["data": [["attributes": attributes]]])
        #expect(try AppleMusicCloudLyricsSource.ttml(in: data) == cloudTTML)
    }
}
private struct Catalog: Decodable { let results: Results; struct Results: Decodable { let songs: Songs }; struct Songs: Decodable { let data: [AppleMusicCloudLyricsSource.Song] } }

private actor CloudCalls {
    var count = 0
    func record() { count += 1 }
}

@Test func cloudIsOptInAndFailureDoesNotDiscardOtherSources() async throws {
    #expect(!SourceConfiguration().appleMusicCloudEnabled)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let calls = CloudCalls()
    let store = LyricsStore(cache: .init(directory: directory), configuration: {
        var config = SourceConfiguration(); config.enabled = [AppleMusicLyricsSource.name, "LRCLIB"]; config.appleMusicCloudEnabled = true; return config
    }, aliasResolver: .init(fetch: { _ in Data(#"{"results":[]}"#.utf8) }), firstResultDelay: .milliseconds(1),
    appleMusicCloudReader: { _ in await calls.record(); throw AppleMusicCloudError.forbidden }, searchBackend: { track, _, _, _ in
        .init { continuation in
            continuation.yield(.init(title: track.title, artist: track.artist, source: "LRCLIB", lines: [.init(id: 0, time: 0, text: "Fallback")]))
            continuation.finish()
        }
    })
    var values: [LyricCandidate] = []
    for try await candidate in store.search(track: cloudTrack, keyword: "Another Song") { values.append(candidate) }
    #expect(values.contains { $0.document.source == "LRCLIB" })
    #expect(await calls.count == 0)
    values = []
    for try await candidate in store.search(track: cloudTrack) { values.append(candidate) }
    #expect(values.contains { $0.document.source == "LRCLIB" })
    #expect(await calls.count == 1)
}

@Test func cloudOnlySearchWaitsForItsResultAndPreservesWords() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let document = try LyricsCodec.parse(cloudTTML, source: AppleMusicCloudLyricsSource.name)
    let store = LyricsStore(cache: .init(directory: directory), configuration: {
        var config = SourceConfiguration(); config.enabled = [AppleMusicLyricsSource.name]; config.appleMusicCloudEnabled = true; return config
    }, aliasResolver: .init(fetch: { _ in Data(#"{"results":[]}"#.utf8) }),
    appleMusicCloudReader: { _ in try await Task.sleep(for: .milliseconds(30)); return document },
    searchBackend: { _, _, _, _ in .init { $0.finish() } })
    var results: [LyricCandidate] = []
    for try await result in store.search(track: cloudTrack) { results.append(result) }
    #expect(results.count == 1 && results[0].document.lines == document.lines)
}

@Test @MainActor func cloudSessionDoesNoWorkUntilUsedAndOnlyAllowsReadEndpoints() {
    let session = AppleMusicCloudSession()
    #expect(!session.hasLoadedPage)
    #expect(AppleMusicCloudSession.validPath("/v1/me/storefront"))
    #expect(AppleMusicCloudSession.validPath("/v1/catalog/au/songs/123/syllable-lyrics?extend=ttmlLocalizations"))
    for path in ["https://example.com", "//example.com", "/v1/me/library/playlists", "/v1/catalog/us/../songs/1/syllable-lyrics", "/v1/catalog/us/songs/abc/syllable-lyrics"] {
        #expect(!AppleMusicCloudSession.validPath(path))
    }
    session.suspend()
    #expect(!session.hasLoadedPage)
}

@Test @MainActor func cancelledCloudRequestDoesNotRecreateTheLoginPage() async throws {
    let session = AppleMusicCloudSession()
    let request = Task { try await session.request("/v1/me/storefront") }
    request.cancel()
    do { _ = try await request.value; Issue.record("A cancelled request unexpectedly completed") }
    catch is CancellationError { }
    #expect(!session.hasLoadedPage)
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["LYRICSX_APPLE_CLOUD_WEB_QA"] == "1"))
@MainActor func officialWebPlayerCanInitializeTheExperimentalSession() async throws {
    let session = AppleMusicCloudSession()
    defer { session.suspend() }
    do { try await session.checkConnection() }
    catch AppleMusicCloudError.signInRequired { return } // The real page and SDK are ready; human sign-in is still required.
}
