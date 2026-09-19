import Foundation
import Testing
import LyricsXCore
@testable import LyricsXServices

@Test func multiTimestampBOMAndTranslationParse() throws {
    let doc = try LyricsCodec.parse("\u{FEFF}[ti:歌]\r\n[ar:人]\r\n[00:01.00][00:03.00]第一句\r\n[00:01.00][tr:en]First line\r\n[00:05.00]")
    #expect(doc.lines.count == 3)
    #expect(doc.lines[0].translation == "First line")
    #expect(doc.lines[1].time == 3)
    #expect(doc.lines[2].text.isEmpty)
}
@Test func duplicateTimestampTranslationIsPreserved() throws {
    let doc = try LyricsCodec.parse("[00:01]Hello\n[00:01]你好\n[00:05]Bye")
    #expect(doc.lines.count == 2); #expect(doc.lines[0].translation == "你好")
}
@Test func wordTimingAndAttachmentsRoundTrip() throws {
    let raw = "[00:01.000]你😀好\n[00:01.000][tt]<0,0><300,1><600,2><900>\n[00:01.000][tr:en]Hello\n[00:01.000][ro]<ni,0,1>\n[00:05.000]结束"
    var doc = try LyricsCodec.parse(raw)
    #expect(doc.hasWordTiming); #expect(doc.lines[0].words.map(\.text).joined() == "你😀好")
    doc.offsetMilliseconds = -600
    let roundTrip = try LyricsCodec.parse(LyricsCodec.export(doc))
    #expect(roundTrip.offsetMilliseconds == -600)
    #expect(roundTrip.lines[0].translation == "Hello")
    #expect(roundTrip.lines[0].attachments["ro"] != nil)
}
@Test func plainLyricsNeverInventSynchronization() throws {
    let doc = try LyricsCodec.parse("First line\nSecond line")
    #expect(!doc.isSynced); #expect(doc.plainText == "First line\nSecond line")
}
@Test func emptyAndOversizeLyricsAreRejected() {
    #expect(throws: (any Error).self) { try LyricsCodec.parse("  \n ") }
    #expect(throws: (any Error).self) { try LyricsCodec.parse(String(repeating: "x", count: 4_000_001)) }
}
@Test func instrumentalSurvivesSaving() throws {
    let doc = LyricsDocument(title: "Music", isInstrumental: true)
    #expect(try LyricsCodec.parse(LyricsCodec.export(doc)).isInstrumental)
}
@Test func legacyFilenameEscapesSlashWithoutTraversal() {
    let track = Track(playerID: "test", playerName: "", title: "../../A/B", artist: "C/D")
    #expect(LyricsCache.filename(for: track) == "..:..:A:B - C:D")
    #expect(!LyricsCache.filename(for: track).contains("/"))
}
@Test func longUnicodeFilenamesFitFilesystemLimit() {
    let track = Track(playerID: "test", playerName: "", title: String(repeating: "歌", count: 300))
    #expect(LyricsCache.filename(for: track).utf8.count < 240)
}
@Test func reusesExistingLRCAndWritesOffsetToSameFile() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let track = Track(playerID: "test", playerName: "", title: "歌", artist: "人")
    let path = directory.appendingPathComponent("歌 - 人.lrc")
    try "[00:01.00]原来的歌词".write(to: path, atomically: true, encoding: .utf8)
    let cache = LyricsCache(directory: directory)
    var doc = try #require(await cache.load(for: track))
    #expect(doc.lines[0].text == "原来的歌词")
    doc.offsetMilliseconds = 400
    try await cache.save(doc, for: track)
    #expect(try LyricsCodec.read(path).offsetMilliseconds == 400)
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["歌 - 人.lrc"])
}
@Test func existingCachePreventsNetworkLookup() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = LyricsCache(directory: directory)
    let track = Track(playerID: "test", playerName: "", title: "Cache", artist: "Artist")
    try await cache.save(LyricsCodec.parse("[00:01]Cached"), for: track)
    let store = LyricsStore(cache: cache, configuration: { var c = SourceConfiguration(); c.enabled = []; return c })
    var results: [LyricCandidate] = []
    for try await result in store.lyrics(for: track, forceRefresh: false) { results.append(result) }
    #expect(results.count == 1); #expect(results.first?.score == 1000)
    #expect(results.first?.document.lines.first?.text == "Cached")
}
@Test func newSavesUseLRCXExtension() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let track = Track(playerID: "test", playerName: "", title: "New", artist: "Artist")
    try await LyricsCache(directory: directory).save(LyricsCodec.parse("[00:01]New lyric"), for: track)
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["New - Artist.lrcx"])
}
@Test func unreadableCacheDoesNotBlockNewSearch() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let track = Track(playerID: "test", playerName: "", title: "Bad", artist: "Artist")
    try Data().write(to: directory.appendingPathComponent("Bad - Artist.lrcx"))
    #expect(await LyricsCache(directory: directory).load(for: track) == nil)
}
@Test func changingDirectoryReadsNewLocation() async throws {
    let first = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let second = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: first); try? FileManager.default.removeItem(at: second) }
    let cache = LyricsCache(directory: first), track = Track(playerID: "test", playerName: "", title: "Song")
    try await cache.save(LyricsCodec.parse("[00:00]A"), for: track)
    await cache.setDirectory(second)
    #expect(await cache.load(for: track) == nil)
    try await cache.save(LyricsCodec.parse("[00:00]B"), for: track)
    #expect(await cache.load(for: track)?.lines.first?.text == "B")
}
@Test func fileWriteFailureIsSurfaced() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try Data().write(to: file); defer { try? FileManager.default.removeItem(at: file) }
    do { try await LyricsCache(directory: file).save(.init(), for: .init(playerID: "test", playerName: "", title: "Song")); Issue.record("Expected write failure") }
    catch { }
}
@Test func processTimeoutAndCancellationDoNotHang() async throws {
    let start = Date()
    await #expect(throws: (any Error).self) { try await ProcessRunner.run("/bin/sleep", arguments: ["30"], timeout: 0.05) }
    #expect(Date().timeIntervalSince(start) < 2)
    let task = Task { try await ProcessRunner.run("/bin/sleep", arguments: ["30"]) }
    task.cancel()
    await #expect(throws: (any Error).self) { try await task.value }
}
@Test func processSeparatesOutputAndHandlesSpaces() async throws {
    let result = try await ProcessRunner.run("/usr/bin/printf", arguments: ["%s", "hello space"])
    #expect(String(decoding: result.data, as: UTF8.self) == "hello space")
}
@Test func invalidAndOptionalQQArtworkRequestsNeverReachURLSession() async {
    let client = SecureLyricsHTTPClient(session: URLSession(configuration: .ephemeral))
    var invalid = URLRequest(url: URL(string: "https://example.invalid")!)
    invalid.url = nil
    await #expect(throws: URLError.self) { try await client.data(for: invalid) }
    var request = URLRequest(url: URL(string: "https://u.y.qq.com/cgi-bin/musicu.fcg")!)
    request.httpBody = Data(#"{"module":"music.pf_song_detail_svr"}"#.utf8)
    await #expect(throws: URLError.self) { try await client.data(for: request) }
}
@Test func systemPayloadHandlesMicrosAndIgnoresArtworkInIdentity() throws {
    let json = #"{"title":"Song","artist":"Artist","album":"Album","isPlaying":true,"durationMicros":180000000,"elapsedTimeMicros":10000000,"timestampEpochMicros":1000000000,"bundleIdentifier":"test"}"#
    let payload = try JSONDecoder().decode(SystemMediaPayload.self, from: Data(json.utf8))
    let snapshot = payload.snapshot(now: 50, wallTime: 1001)
    #expect(snapshot.position == 11); #expect(snapshot.track?.duration == 180)
}
@Test func systemPayloadDecodesDataURIArtwork() throws {
    let json = #"{"title":"Song","artist":"Artist","artworkDataBase64":"data:image/jpeg;base64,aGVsbG8="}"#
    let payload = try JSONDecoder().decode(SystemMediaPayload.self, from: Data(json.utf8))
    #expect(payload.snapshot(now: 0).track?.artworkData == Data("hello".utf8))
}
@Test func oldValidMediaTimestampAdvancesBeyondThreeSeconds() throws {
    let json = #"{"title":"Song","artist":"Artist","isPlaying":true,"durationMicros":180000000,"elapsedTimeMicros":10000000,"timestampEpochMicros":980000000}"#
    let payload = try JSONDecoder().decode(SystemMediaPayload.self, from: Data(json.utf8))
    let snapshot = payload.snapshot(now: 50, wallTime: 1000)
    #expect(snapshot.position == 30)
}

@Test func oldMediaTimestampClampsAtTrackEnd() throws {
    let json = #"{"title":"Song","isPlaying":true,"durationMicros":100000000,"elapsedTimeMicros":95000000,"timestampEpochMicros":900000000}"#
    let payload = try JSONDecoder().decode(SystemMediaPayload.self, from: Data(json.utf8))
    #expect(payload.snapshot(now: 50, wallTime: 1000).position == 100)
}
@Test func iosLyricTickerRecoveryIsRestrictedToIOSApps() throws {
    let json = #"{"title":"Some lyric","artist":"Song — Singer","bundleIdentifier":"test"}"#
    let payload = try JSONDecoder().decode(SystemMediaPayload.self, from: Data(json.utf8))
    #expect(payload.snapshot(now: 0, isIOSApp: true).track?.title == "Song")
    #expect(payload.snapshot(now: 0).track?.title == "Some lyric")
}

@Test func deletedCachePathIsNotReturnedAndReplacementCanBeFound() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = LyricsCache(directory: directory)
    let track = Track(playerID: "test", playerName: "", title: "Deleted")
    try await cache.save(LyricsCodec.parse("[00:01]Original"), for: track)
    let original = try #require(await cache.existingURL(for: track))
    try FileManager.default.removeItem(at: original)
    #expect(await cache.existingURL(for: track) == nil)
    let replacement = directory.appendingPathComponent(LyricsCache.filename(for: track) + ".lrc")
    try "[00:01]Replacement".write(to: replacement, atomically: true, encoding: .utf16)
    #expect(await cache.load(for: track)?.lines.first?.text == "Replacement")
    #expect(await cache.existingURL(for: track) == replacement)
}
