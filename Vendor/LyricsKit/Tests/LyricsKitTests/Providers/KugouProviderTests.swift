import Testing
import Foundation
@testable import LyricsService

struct KugouProviderTests {
    private let infoRequest = LyricsSearchRequest(
        searchTerm: .info(title: "Test Song", artist: "Test Artist"),
        duration: 200,
        limit: 3
    )

    @Test func searchBuildsCorrectURL() async throws {
        let mock = MockHTTPClient()
        mock.stub(host: "mobiles.kugou.com",
                  response: .data(try FixtureLoader.data(named: "Kugou/search.json")))
        mock.stub(host: "krcs.kugou.com",
                  response: .data(try FixtureLoader.data(named: "Kugou/candidates_empty.json")))
        let provider = LyricsProviders.Kugou(httpClient: mock)

        await #expect(throws: LyricsProviderError.self) {
            _ = try await collect(provider.lyrics(for: infoRequest))
        }

        let searchRequest = try #require(mock.recorded.first(where: { $0.url?.host == "mobiles.kugou.com" }))
        #expect(searchRequest.url?.scheme == "https")
        #expect(searchRequest.url?.path == "/api/v3/search/song")
        let query = searchRequest.url?.query ?? ""
        #expect(query.contains("format=json"))
        #expect(query.contains("keyword=Test%20Song%20Test%20Artist"))
        #expect(query.contains("pagesize=3"))
    }

    @Test func processingFailsWhenNoCandidates() async throws {
        let mock = MockHTTPClient()
        mock.stub(host: "mobiles.kugou.com",
                  response: .data(try FixtureLoader.data(named: "Kugou/search.json")))
        mock.stub(host: "krcs.kugou.com",
                  response: .data(try FixtureLoader.data(named: "Kugou/candidates_empty.json")))
        let provider = LyricsProviders.Kugou(httpClient: mock)

        // Every candidate failed; surface the failure so the UI can distinguish
        // an unavailable source from a successful search with no matches.
        await #expect(throws: LyricsProviderError.self) {
            _ = try await collect(provider.lyrics(for: infoRequest))
        }
    }

    @Test func candidatesEndpointHitsKrcsHost() async throws {
        let mock = MockHTTPClient()
        mock.stub(host: "mobiles.kugou.com",
                  response: .data(try FixtureLoader.data(named: "Kugou/search.json")))
        mock.stub(host: "krcs.kugou.com",
                  response: .data(try FixtureLoader.data(named: "Kugou/candidates_empty.json")))
        let provider = LyricsProviders.Kugou(httpClient: mock)

        await #expect(throws: LyricsProviderError.self) {
            _ = try await collect(provider.lyrics(for: infoRequest))
        }

        let candidatesRequest = try #require(mock.recorded.first(where: { $0.url?.host == "krcs.kugou.com" }))
        let query = candidatesRequest.url?.query ?? ""
        #expect(query.contains("hash=abcdef123456"))
        #expect(query.contains("album_audio_id=222"))
        #expect(query.contains("ver=1"))
        #expect(query.contains("client=mobi"))
    }

    @Test func networkErrorOnSearchPropagates() async throws {
        let mock = MockHTTPClient()
        mock.stubAny(.error(URLError(.notConnectedToInternet)))
        let provider = LyricsProviders.Kugou(httpClient: mock)

        await #expect(throws: LyricsProviderError.self) {
            _ = try await collect(provider.lyrics(for: infoRequest))
        }
    }

    @Test func decodingErrorOnSearchPropagates() async throws {
        let mock = MockHTTPClient()
        mock.stub(host: "mobiles.kugou.com", response: .data(Data("garbage".utf8)))
        let provider = LyricsProviders.Kugou(httpClient: mock)

        await #expect(throws: LyricsProviderError.self) {
            _ = try await collect(provider.lyrics(for: infoRequest))
        }
    }
}
