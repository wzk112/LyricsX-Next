import Foundation
import Synchronization
import Testing
import LyricsXCore
@testable import LyricsXServices

@Test(arguments: [true, false]) func combinedMusicSourcePublishesBothReadersAndSettlesOneStatus(_ readableCloud: Bool) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let track = Track(playerID: "com.apple.Music", playerName: "Music", title: "Fixture", artist: "Artist", duration: 120,
                      embeddedLyrics: "[00:01.00]Embedded fixture")
    let statuses = Mutex<[SourceSearchStatus]>([])
    let providerCalls = Mutex(0)
    let store = LyricsStore(cache: .init(directory: directory), configuration: {
        var config = SourceConfiguration(); config.enabled = ["Apple Music"]; config.appleMusicCloudEnabled = true; return config
    }, aliasResolver: .init(fetch: { _ in Data(#"{"results":[]}"#.utf8) }),
    appleMusicCloudReader: {
        try await Task.sleep(for: .milliseconds(40))
        guard readableCloud else { throw AppleMusicCloudError.forbidden }
        return .init(title: $0.title, artist: $0.artist, source: AppleMusicCloudLyricsSource.name, duration: $0.duration,
                     lines: [.init(id: 0, time: 1, text: "Cloud fixture")], providerID: "apple-cloud:au:1")
    }, searchBackend: { _, _, _, _ in providerCalls.withLock { $0 += 1 }; return .init { $0.finish() } })
    var candidates: [LyricCandidate] = []
    for try await candidate in store.search(track: track, keyword: track.title, onSourceUpdate: { value in statuses.withLock { $0.append(value) } }) {
        candidates.append(candidate)
    }
    #expect(candidates.count == (readableCloud ? 2 : 1))
    let updates = statuses.withLock { $0 }
    #expect(Set(updates.map(\.source)) == ["Apple Music"])
    #expect(updates.last?.count == candidates.count && updates.last?.isSearching == false && updates.last?.issue == nil)
    #expect(updates.contains { $0.count == 1 && $0.isSearching })
    #expect(providerCalls.withLock { $0 } == 0)
}
@Test func combinedMusicSourceOffOrUnrelatedQueryNeverCallsEitherReader() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let calls = Mutex(0)
    let track = Track(playerID: "com.apple.Music", playerName: "Music", title: "Current")
    for disabled in [true, false] {
        let store = LyricsStore(cache: .init(directory: directory), configuration: {
            var config = SourceConfiguration(); config.enabled = disabled ? [] : ["Apple Music"]; config.appleMusicCloudEnabled = true; return config
        }, aliasResolver: .init(fetch: { _ in Data(#"{"results":[]}"#.utf8) }),
        appleMusicReader: { _ in calls.withLock { $0 += 1 }; return nil },
        appleMusicCloudReader: { _ in calls.withLock { $0 += 1 }; return nil },
        searchBackend: { _, _, _, _ in .init { $0.finish() } })
        for try await _ in store.search(track: track, keyword: disabled ? "Current" : "Other") { }
    }
    #expect(calls.withLock { $0 } == 0)
}
@Test func existingCloudDocumentsShareMusicRankingAndCompactBudget() {
    let track = Track(playerID: "com.apple.Music", playerName: "Music", title: "Fixture", artist: "Artist")
    var config = SourceConfiguration(); config.preferBilingual = false; config.preferWordTiming = false
    config.sourceOrder = [AppleMusicCloudLyricsSource.name, "LRCLIB", "Apple Music"]
    let field = LyricsDocument(title: track.title, artist: track.artist, source: "Apple Music", lines: [.init(id: 0, time: 1, text: "Fixture")])
    var cloud = field; cloud.source = AppleMusicCloudLyricsSource.name
    #expect(config.selectionScore(field, for: track) == config.selectionScore(cloud, for: track))
    #expect(SourceConfiguration.normalizedOrder(config.sourceOrder).first == "Apple Music")
    let values = (0..<14).map { n in LyricCandidate(document: n % 2 == 0 ? field : cloud, score: Double(n)) }
    #expect(config.orderedManualResults(values, complete: false).count == 12)
    let before = config.selectionKey; config.appleMusicCloudEnabled = true
    #expect(before != config.selectionKey)
}

@Test func legacyCloudCacheKeepsTimingAndIdentityUnderTheStableName() throws {
    let old = "Apple Music 云端（实验）"
    let xml = "<tt><body><div><p begin=\"1s\" end=\"3s\"><span begin=\"1s\" end=\"2s\">Fixture</span></p></div></body></tt>"
    var document = try TTMLLyricsParser.parse(xml, source: old)
    document.providerID = "apple-cloud:au:123"; document.offsetMilliseconds = 125
    let restored = try LyricsCodec.parse(LyricsCodec.export(document))
    #expect(restored.source == "Apple Music 云端")
    #expect(restored.lines == document.lines && restored.originalTTML == xml)
    #expect(restored.providerID == document.providerID && restored.offsetMilliseconds == 125)
    #expect(SourceConfiguration.sourceKey(old) == "Apple Music")
    #expect(SourceConfiguration.normalizedOrder([old, "LRCLIB", "Apple Music 云端"]).prefix(2) == ["Apple Music", "LRCLIB"])
}
