import Foundation
import Testing
import LyricsXCore
@testable import LyricsXServices

private let castCredits = "DENONBU,KOTONOHOUSE,Karin Houou (CV: Kana Sukoya), Mitsuki Seto (CV: Sister Claire), Lucia Taiga (CV: Sara Hoshikawa)"
private let castTrack = Track(playerID: "com.apple.Music", playerName: "Apple Music", title: "In My World",
                              artist: castCredits, album: "In My World - Single", duration: 251.24)
private let wordFixture = "<tt><body><p begin=\"1\" end=\"3\"><span begin=\"1.1\" end=\"2\">Word</span></p></body></tt>"
private let lineFixture = "<tt xmlns:itunes=\"http://music.apple.com/lyric-ttml-internal\" itunes:timing=\"Line\"><body><p begin=\"1.2\" end=\"3\">Timed line</p></body></tt>"

private actor CatalogFixtureRoutes {
    enum Words: Sendable { case available, missing, empty, forbidden }
    let words: Words
    let lines: Bool
    let matchingCatalog: Bool
    let matchOnlyLastQuery: Bool
    var paths: [String] = []
    init(words: Words = .available, lines: Bool = true, matchingCatalog: Bool = true, matchOnlyLastQuery: Bool = false) {
        self.words = words; self.lines = lines; self.matchingCatalog = matchingCatalog; self.matchOnlyLastQuery = matchOnlyLastQuery
    }
    func read(_ path: String) throws -> Data {
        paths.append(path)
        if path == "/v1/me/storefront" { return Data(#"{"data":[{"id":"au"}]}"#.utf8) }
        if path.contains("/search?") {
            let url = URLComponents(string: "https://amp-api.music.apple.com" + path)
            let term = url?.queryItems?.first { $0.name == "term" }?.value
            let match = matchingCatalog && (!matchOnlyLastQuery || term == castTrack.title)
            let attributes: [String: Any] = ["name": "In My World", "artistName": match ? castCredits : "Unrelated performer",
                                            "albumName": castTrack.album, "durationInMillis": 251240]
            return try JSONSerialization.data(withJSONObject: ["results": ["songs": ["data": [["id": "1573750923", "attributes": attributes]]]]])
        }
        if path.contains("/syllable-lyrics?") {
            switch words {
            case .available: return try resource(wordFixture)
            case .missing: throw AppleMusicCloudError.noLyrics
            case .empty: return Data(#"{"data":[]}"#.utf8)
            case .forbidden: throw AppleMusicCloudError.forbidden
            }
        }
        #expect(path.contains("/lyrics?"))
        if lines { return try resource(lineFixture) }
        throw AppleMusicCloudError.noLyrics
    }
    private func resource(_ text: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["data": [["attributes": ["ttml": text]]]])
    }
}

@Test func cloudCastCreditsUseShortQueriesWhileTheFullMetadataStillVerifiesTheRecording() async throws {
    #expect(AppleMusicCloudLyricsSource.searchTerms(for: castTrack) == ["In My World DENONBU", "In My World KOTONOHOUSE", "In My World"])
    let routes = CatalogFixtureRoutes()
    let document = try #require(await AppleMusicCloudLyricsSource(request: { try await routes.read($0) }).document(for: castTrack))
    #expect(document.hasWordTiming && document.artist == castCredits && document.providerID == "apple-cloud:au:1573750923")
    let paths = await routes.paths
    #expect(paths.count == 3 && !paths[1].contains("Kana"))
    #expect(paths[2].contains("/1573750923/syllable-lyrics?"))
    var solo = castTrack; solo.artist = "Karin Houou (CV: Kana Sukoya)"
    #expect(AppleMusicCloudLyricsSource.searchTerms(for: solo).first == "In My World Karin Houou")
}

@Test func cloudCatalogRetriesShortArtistAndTitleQueriesWithoutAcceptingOtherPerformers() async throws {
    let routes = CatalogFixtureRoutes(matchOnlyLastQuery: true)
    let document = try #require(await AppleMusicCloudLyricsSource(request: { try await routes.read($0) }).document(for: castTrack))
    #expect(document.artist == castCredits)
    let paths = await routes.paths
    #expect(paths.count == 5 && paths.filter { $0.contains("/search?") }.count == 3)
    #expect(paths.filter { $0.contains("-lyrics?") }.count == 1)
}

@Test(arguments: [true, false]) func cloudUsesActualTimedLinesWhenSyllableLyricsAreMissingOrEmpty(_ missing: Bool) async throws {
    let routes = CatalogFixtureRoutes(words: missing ? .missing : .empty)
    let document = try #require(await AppleMusicCloudLyricsSource(request: { try await routes.read($0) }).document(for: castTrack))
    #expect(document.isSynced && !document.hasWordTiming && document.lines[0].time == 1.2)
    #expect(document.originalTTML == lineFixture && document.source == AppleMusicCloudLyricsSource.name)
    let paths = await routes.paths
    #expect(paths.count == 4 && paths[2].contains("/syllable-lyrics?") && paths[3].contains("/lyrics?"))
    let allowed = await AppleMusicCloudSession.validPath(paths[3])
    #expect(allowed)
}

@Test func cloudCatalogMismatchIsDistinctFromMatchedSongWithoutReadableLyrics() async throws {
    let unmatched = CatalogFixtureRoutes(matchingCatalog: false)
    do {
        _ = try await AppleMusicCloudLyricsSource(request: { try await unmatched.read($0) }).document(for: castTrack)
        Issue.record("An unrelated performer should not match")
    } catch AppleMusicCloudError.catalogMismatch { }
    #expect(await unmatched.paths.allSatisfy { !$0.contains("/songs/") })
    let unavailable = CatalogFixtureRoutes(words: .missing, lines: false)
    do {
        _ = try await AppleMusicCloudLyricsSource(request: { try await unavailable.read($0) }).document(for: castTrack)
        Issue.record("Missing resources should report unreadable lyrics")
    } catch AppleMusicCloudError.noLyrics { }
    #expect(await unavailable.paths.count == 4)
    #expect(AppleMusicCloudError.catalogMismatch.localizedDescription.contains("不代表没有在线歌词"))
    #expect(AppleMusicCloudError.noLyrics.localizedDescription.contains("已匹配到歌曲"))
}

@Test func cloudDoesNotHideAuthorizationFailureByRequestingMoreLyricResources() async throws {
    let routes = CatalogFixtureRoutes(words: .forbidden)
    do {
        _ = try await AppleMusicCloudLyricsSource(request: { try await routes.read($0) }).document(for: castTrack)
        Issue.record("A rejected account unexpectedly returned lyrics")
    } catch AppleMusicCloudError.forbidden { }
    #expect(await routes.paths.count == 3)
}
