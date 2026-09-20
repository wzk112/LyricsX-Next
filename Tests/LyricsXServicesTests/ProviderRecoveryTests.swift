import Foundation
import Testing
import LyricsXCore
@preconcurrency import LyricsKit
@testable import LyricsService
@testable import LyricsXServices

private actor DownloadCounts {
    var active = 0, maximum = 0
    func start() { active += 1; maximum = max(maximum, active) }
    func finish() { active -= 1 }
}
private struct SlowFirstProvider: _LyricsProvider {
    static let service = "fixture"
    let counts: DownloadCounts
    var allSlow = false
    func search(for request: LyricsSearchRequest) async throws -> [Int] { Array(0..<36) }
    func fetch(with token: Int) async throws -> Lyrics {
        await counts.start()
        do {
            try await Task.sleep(for: token == 0 || allSlow ? .milliseconds(220) : .milliseconds(3))
            await counts.finish()
            return Lyrics("[ti:Version \(token)]\n[00:01]Fixture \(token)")!
        } catch { await counts.finish(); throw error }
    }
}

@Test func completedDownloadsAreDeliveredBeforeSlowFirstAndKeepVersionsBeyondTen() async throws {
    let counts = DownloadCounts()
    let provider = SlowFirstProvider(counts: counts)
    var titles: [String] = []
    for try await result in provider.lyrics(for: .init(searchTerm: .keyword("Fixture"), duration: 0, limit: 36)) {
        titles.append(result.idTags[.title] ?? "")
    }
    #expect(titles.count == 36)
    #expect(titles.first != "Version 0")
    #expect(await counts.maximum <= 4)
    #expect(await counts.active == 0)
}

@Test func cancellingSearchCancelsEveryPendingDownload() async throws {
    let counts = DownloadCounts()
    let task = Task {
        for try await _ in SlowFirstProvider(counts: counts, allSlow: true).lyrics(for: .init(searchTerm: .keyword("Fixture"), duration: 0, limit: 36)) { }
    }
    while await counts.active < 4 { try await Task.sleep(for: .milliseconds(1)) }
    task.cancel()
    _ = await task.result
    let deadline = ContinuousClock.now.advanced(by: .seconds(1))
    while await counts.active != 0, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(2)) }
    #expect(await counts.active == 0)
}

@Test func nullableLRCLIBDurationAndOneBadRecordDoNotEraseOtherVersions() throws {
    let data = Data(#"[{"id":1,"trackName":"Song","artistName":"Singer","duration":null,"syncedLyrics":"[00:01]Hello"},{"id":2,"trackName":"Song","artistName":null,"albumName":null,"syncedLyrics":"[00:01]Hello"},{"id":3,"trackName":"Song","duration":185,"plainLyrics":"Untimed text"},{"id":4,"trackName":"Song","instrumental":true},{"id":5,"trackName":42,"duration":"broken"}]"#.utf8)
    let documents = try LRCLIBSearch.decode(data)
    #expect(documents.count == 4)
    #expect(documents[0].duration == 0 && documents[0].isSynced)
    #expect(documents[0].providerID != documents[1].providerID)
    #expect(documents[2].plainText == "Untimed text" && !documents[2].isSynced)
    #expect(documents[3].isInstrumental)
}

@Test func partialWordTimingsPreservePunctuationInstantaneousCuesAndOriginalLRCX() throws {
    let raw = "[00:01]（Hello world!）\n[00:01][tt]<0,1><600,6><600,7><1200,12><1200>\n[00:01][tr]你好世界"
    let document = try LyricsCodec.parse(raw)
    let line = try #require(document.lines.first)
    #expect(document.hasWordTiming && document.hasTranslation)
    #expect(line.words.contains { $0.start == $0.end })
    #expect(line.wordTimingRanges.count == line.words.count)
    let exported = try LyricsCodec.parse(LyricsCodec.export(document))
    #expect(exported.lines[0].words == line.words)
    #expect(exported.lines[0].text == line.text)
    let overlapping = LyricLine(id: 0, time: 1, text: "Hi there!", words: [
        .init(text: "Hi", start: 1, end: 1.6), .init(text: "there", start: 1.55, end: 2)
    ])
    #expect(overlapping.hasWordTiming && overlapping.wordTimingRanges.count == 2)
}

private struct NetEaseFixtureClient: HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        let body: String
        if url.path.contains("search") {
            body = #"{"code":200,"result":{"songCount":1,"songs":[{"name":"Song","id":123,"duration":180000,"artists":[{"id":1,"name":"Singer"}],"album":{"id":1,"name":"Album"}}]}}"#
        } else {
            body = #"{"yrc":{"lyric":"[1000,1000](1000,500,0)He(1500,500,0)llo"},"ytlrc":{"lyric":"[00:01.12]你好"},"tlyric":{"lyric":"[00:01.12]旧翻译"}}"#
        }
        return (Data(body.utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

@Test func neteaseWordBranchMergesNearbyWordTranslationWithoutChangingTiming() async throws {
    let provider = LyricsProviders.Service.netease.create(httpClient: NetEaseFixtureClient())
    var values: [LyricsDocument] = []
    for try await value in provider.lyrics(for: .init(searchTerm: .keyword("Song"), duration: 180)) { values.append(LyricsCodec.convert(value)) }
    let document = try #require(values.first)
    #expect(document.hasWordTiming && document.hasTranslation)
    #expect(document.lines[0].translation == "你好")
    #expect(document.lines[0].time == 1 && document.lines[0].words[0].start == 1)
}

@Test func nearbyTranslationDoesNotJumpToAdjacentFastLine() throws {
    let lyrics = try #require(Lyrics("[00:01]A\n[00:01.10]B\n[00:02]C"))
    let translated = try #require(Lyrics("[00:01.09]乙\n[00:02.20]丙"))
    lyrics.merge(translation: translated)
    #expect(lyrics.lines[0].attachments.translation() == nil)
    #expect(lyrics.lines[1].attachments.translation() == "乙")
    #expect(lyrics.lines[2].attachments.translation() == "丙")
}

private final class StatusRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [SourceSearchStatus] = []
    func add(_ value: SourceSearchStatus) { lock.withLock { entries.append(value) } }
    var values: [SourceSearchStatus] { lock.withLock { entries } }
}

@Test func sourceFailuresAreReportedSeparatelyAndEqualLyricsFromDifferentVersionsSurvive() async throws {
    let track = Track(playerID: "test", playerName: "", title: "Song", artist: "Singer")
    let statuses = StatusRecorder()
    let store = LyricsStore(cache: .init(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
                            aliasResolver: TrackAliasResolver { _ in Data(#"{"results":[]}"#.utf8) }) { _, _, config, _ in
        .init { stream in
            let source = config.enabled.first!
            if source == "NetEase" { stream.finish(throwing: LyricsProviderError.serviceResponse(code: 405)); return }
            if source == "LRCLIB" {
                for index in 0..<25 {
                    stream.yield(.init(title: "Song", artist: "Singer", source: source, lines: [.init(id: 0, time: 0, text: "Same lyrics")], providerID: String(index)))
                }
            }
            stream.finish()
        }
    }
    var values: [LyricCandidate] = []
    for try await value in store.search(track: track, keyword: "Song Singer", complete: true, onSourceUpdate: { statuses.add($0) }) { values.append(value) }
    #expect(values.count == 25)
    #expect(statuses.values.last(where: { $0.source == "LRCLIB" })?.count == 25)
    #expect(statuses.values.last(where: { $0.source == "NetEase" })?.issue?.contains("限流") == true)
    #expect(statuses.values.last(where: { $0.source == "QQMusic" })?.issue == nil)
    #expect(statuses.values.last?.isSearching == false)
}

@Test func aSlowSourceCannotBlockCatalogAliasQueriesInOtherSources() async throws {
    let track = Track(playerID: "test", playerName: "", title: "Roman Song", artist: "Singer", duration: 180)
    let resolver = TrackAliasResolver { request in
        let native = request.url?.path == "/lookup"
        return Data((native
            ? #"{"results":[{"trackId":123,"artistId":456,"trackName":"歌曲","artistName":"歌手","trackTimeMillis":180000}]}"#
            : #"{"results":[{"trackId":123,"artistId":456,"trackName":"Roman Song","artistName":"Singer","trackTimeMillis":180000}]}"#).utf8)
    }
    let store = LyricsStore(cache: .init(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
                            aliasResolver: resolver, searchBudget: .milliseconds(160)) { query, _, config, _ in
        .init { stream in
            if config.enabled.contains("Kugou") { return } // never finishes
            if query.title == "歌曲" { stream.yield(.init(title: "歌曲", artist: "歌手", source: "NetEase", lines: [.init(id: 0, time: 0, text: "歌詞", translation: "歌词")])) }
            stream.finish()
        }
    }
    var results: [LyricCandidate] = []
    for try await value in store.lyrics(for: track, forceRefresh: true) { results.append(value) }
    #expect(results.contains { $0.document.title == "歌曲" && $0.score >= 60 })
}

@Test func freeTextSearchHonorsPreferencesEvenWhenPlayingTrackDoesNotMatch() {
    var config = SourceConfiguration()
    config.sourceOrder = ["Kugou", "NetEase", "QQMusic", "LRCLIB"]
    let lrclib = LyricCandidate(document: .init(title: "Other song", source: "LRCLIB"), score: 0)
    let qq = LyricCandidate(document: .init(title: "Other song", source: "QQMusic"), score: 0)
    let kugou = LyricCandidate(document: .init(title: "Other song", source: "Kugou"), score: 0)
    #expect([lrclib, qq, kugou].sorted(by: config.manualPrecedes).map(\.document.source) == ["Kugou", "QQMusic", "LRCLIB"])
    let word = LyricCandidate(document: .init(title: "Other song", source: "QQMusic", lines: [.init(id: 0, time: 0, text: "Hi", words: [.init(text: "Hi", start: 0, end: 1)])]), score: 0)
    #expect(config.manualPrecedes(word, kugou))
    config.preferWordTiming = false
    #expect(config.manualPrecedes(word, kugou)) // Word timing is the bilingual preference's fallback.
}

private actor QQPageClient: HTTPClient {
    var pages: [Int] = []
    var sizes: [Int] = []
    var failLaterPages = false
    let flakyFirstPage: Bool
    let slowSmartbox: Bool
    init(failLaterPages: Bool = false, flakyFirstPage: Bool = false, slowSmartbox: Bool = false) { self.failLaterPages = failLaterPages; self.flakyFirstPage = flakyFirstPage; self.slowSmartbox = slowSmartbox }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        let response: Data
        if url.path.contains("smartbox") {
            if slowSmartbox { try await Task.sleep(for: .milliseconds(30)) }
            response = flakyFirstPage
                ? Data(#"{"code":0,"data":{"song":{"itemlist":[{"id":"0","mid":"id0","name":"Version 0","singer":"Singer"}]}}}"#.utf8)
                : Data(#"{"code":0,"data":{}}"#.utf8)
        } else if url.path.contains("musicu") {
            let json = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            if json["songinfo"] != nil { throw URLError(.resourceUnavailable) }
            let param = (json["req_1"] as! [String: Any])["param"] as! [String: Any]
            let page = param["page_num"] as! Int, size = param["num_per_page"] as! Int
            pages.append(page); sizes.append(size)
            if failLaterPages, page > 1 { throw URLError(.timedOut) }
            // Reproduce the real endpoint's empty-success response above 20.
            let songs: [[String: Any]] = size > 20 || (flakyFirstPage && pages.count == 1) ? [] : (0..<20).map { index in
                let id = (page - 1) * 20 + index
                return ["id": id, "mid": "id\(id)", "name": "Version \(id)", "singer": [["name": "Singer"]]]
            }
            response = try JSONSerialization.data(withJSONObject: ["req_1": ["code": 0, "data": ["body": ["song": ["list": songs]]]]])
        } else {
            response = Data("<root><content><![CDATA[[00:01]Hello]]></content></root>".utf8)
        }
        return (response, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

@Test func qqFetchesEightyVersionsUsingSupportedPageSize() async throws {
    let client = QQPageClient()
    let provider = LyricsProviders.Service.qq.create(httpClient: client)
    var values: [String] = []
    for try await value in provider.lyrics(for: .init(searchTerm: .keyword("Song"), duration: 0, limit: 80)) { values.append(value.idTags[.title] ?? "") }
    #expect(values.count == 80 && Set(values).count == 80)
    #expect(await client.pages == [1, 2, 3, 4])
    #expect(await client.sizes.allSatisfy { $0 == 20 })
}

@Test func qqLaterPageFailureKeepsEarlierVersions() async throws {
    let client = QQPageClient(failLaterPages: true)
    let provider = LyricsProviders.Service.qq.create(httpClient: client)
    var count = 0
    for try await _ in provider.lyrics(for: .init(searchTerm: .keyword("Song"), duration: 0, limit: 80)) { count += 1 }
    #expect(count == 20)
}

private actor FinalVersionGate {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if opened { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func release() {
        opened = true
        let pending = waiters; waiters = []
        for waiter in pending { waiter.resume() }
    }
}

@Test @MainActor func automaticLyricsCheckpointEarlyAndFinalizeTheBetterVersion() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = LyricsCache(directory: directory)
    let track = Track(playerID: "test", playerName: "", title: "Song", artist: "Singer")
    var plain = try LyricsCodec.parse("[00:01]Hello world", source: "NetEase")
    plain.title = track.title; plain.artist = track.artist
    var word = try LyricsCodec.parse("[00:01]Hello world\n[00:01][tt]<0,0><500,6><1000,11><1000>", source: "NetEase")
    word.title = track.title; word.artist = track.artist
    let first = plain, final = word
    let gate = FinalVersionGate()
    defer { Task { await gate.release() } }
    let store = LyricsStore(cache: cache, configuration: { var c = SourceConfiguration(); c.enabled = ["NetEase"]; return c },
                            aliasResolver: TrackAliasResolver { _ in Data(#"{"results":[]}"#.utf8) }, firstResultDelay: .milliseconds(10)) { _, _, _, _ in
        .init { stream in
            let task = Task {
                stream.yield(first)
                await gate.wait()
                guard !Task.isCancelled else { stream.finish(); return }
                stream.yield(final); stream.finish()
            }
            stream.onTermination = { _ in task.cancel() }
        }
    }
    let session = LyricsSession(repository: store)
    session.accept(.init(track: track, position: 1, isPlaying: false))
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while session.document == nil, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(2)) }
    #expect(session.document?.hasWordTiming == false)
    #expect(session.isSearching && session.phase == .ready)
    #expect(await cache.load(for: track)?.hasWordTiming == false)
    #expect(await cache.automaticCandidate(for: track, configuration: "test")?.isProvisional == true)
    await gate.release()
    while session.isSearching, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(2)) }
    #expect(session.document?.hasWordTiming == true)
    #expect(session.candidates.count == 2)
    while await cache.automaticCandidate(for: track, configuration: "test")?.isProvisional != false, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(2)) }
    #expect(await cache.load(for: track)?.hasWordTiming == true)
    session.reload(forceRefresh: true)
    #expect(session.isSearching)
    session.use(final, persist: false)
    #expect(!session.isSearching)
}

@Test(arguments: [false, true]) func qqRetriesTransientEmptyFullSearchWhenSmartboxHasEvidence(slowSmartbox: Bool) async throws {
    let client = QQPageClient(flakyFirstPage: true, slowSmartbox: slowSmartbox)
    let provider = LyricsProviders.Service.qq.create(httpClient: client)
    var count = 0
    for try await _ in provider.lyrics(for: .init(searchTerm: .keyword("Song"), duration: 0, limit: 40)) { count += 1 }
    #expect(count == 40)
    #expect(await client.pages == [1, 1, 2])
}
