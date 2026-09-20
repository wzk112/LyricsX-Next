import Foundation
import LyricsCore
import FoundationToolbox

extension LyricsProviders {
    @Loggable
    final class QQMusic {
        let httpClient: HTTPClient
        private var performer: NetworkPerformer { NetworkPerformer(httpClient: httpClient) }

        private static let searchHost1 = "c.y.qq.com"
        private static let searchPath1 = "/splcloud/fcgi-bin/smartbox_new.fcg"
        private static let searchHost2 = "u.y.qq.com"
        private static let searchPath2 = "/cgi-bin/musicu.fcg"
        private static let lyricsHost = "c.y.qq.com"
        private static let lyricsPath = "/qqmusic/fcgi-bin/lyric_download.fcg"

        init(httpClient: HTTPClient = .shared) {
            self.httpClient = httpClient
        }
    }
}

extension LyricsProviders.QQMusic: _LyricsProvider {
    struct LyricsToken {
        let value: QQMusicSongSearchResult
    }

    static let service: String = "QQMusic"

    func search(for request: LyricsSearchRequest) async throws -> [LyricsToken] {
        // Keep endpoint identity independent of task completion order. This
        // also avoids relying on integer-tagged existential tuple results in
        // optimized builds; each child has a distinct, structured binding.
        async let hints = searchResult(for: request, full: false)
        async let details = searchResult(for: request, full: true)
        var endpoints = await [hints, details]
        if endpoints.count == 2,
           case .success(let hints) = endpoints[0], !hints.isEmpty,
           case .success(let details) = endpoints[1], details.isEmpty {
            // An existing smartbox hit is evidence that an empty full search
            // may be transient. Retry once, rather than amplifying every
            // legitimate zero-result query into repeated requests.
            try await Task.sleep(nanoseconds: 350_000_000)
            do { endpoints[1] = .success(try await searchApi2(for: request)) }
            catch { endpoints[1] = .failure(error) }
        }
        var seen = Set<String>(), combined: [LyricsToken] = []
        var failure: Error?
        for endpoint in endpoints {
            switch endpoint {
            case .success(let values): combined += values.filter { seen.insert($0.value.id).inserted }
            case .failure(let error): failure = error
            }
        }
        if combined.isEmpty, let failure { throw failure }
        return combined
    }

    private func searchResult(for request: LyricsSearchRequest, full: Bool) async -> Result<[LyricsToken], Error> {
        do {
            return .success(try await full ? searchApi2(for: request) : searchApi1(for: request))
        } catch { return .failure(error) }
    }

    private func searchApi1(for request: LyricsSearchRequest) async throws -> [LyricsToken] {
        let endpoint = Endpoint(host: Self.searchHost1, path: Self.searchPath1,
                                queryItems: [URLQueryItem(name: "key", value: request.searchTerm.description)])
        let data = try await performer.performData(endpoint)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let code = object?["code"] as? Int, code != 0 { throw LyricsProviderError.serviceResponse(code: code) }
        if let body = object?["data"] as? [String: Any], body["song"] == nil { return [] }
        let result: QQResponseSearchResult = try performer.decode(data)
        return result.data.song.list.map { LyricsToken(value: $0) }
    }

    private func searchApi2(for request: LyricsSearchRequest) async throws -> [LyricsToken] {
        // This endpoint silently returns an empty list for oversized pages.
        // Grow the result set using its supported 20-record pagination.
        var values: [LyricsToken] = []
        var seen = Set<String>()
        for page in 1...max(1, (request.limit + 19) / 20) {
            try Task.checkCancellation()
            do {
                let batch = try await searchPage(for: request, page: page)
                let added = batch.filter { seen.insert($0.value.id).inserted }
                values += added
                if batch.count < 20 || added.isEmpty { break }
            } catch {
                if values.isEmpty { throw error }
                break // a later page cannot erase earlier successful pages
            }
        }
        return values
    }

    private func searchPage(for request: LyricsSearchRequest, page: Int) async throws -> [LyricsToken] {
        let requestBody: [String: Any] = ["req_1": [
            "method": "DoSearchForQQMusicDesktop", "module": "music.search.SearchCgiService",
            "param": ["num_per_page": 20, "page_num": page,
                      "query": request.searchTerm.description, "search_type": 0]]]
        let endpoint = Endpoint(host: Self.searchHost2, path: Self.searchPath2, method: .post,
                                headers: ["Content-Type": "application/json"],
                                body: try JSONSerialization.data(withJSONObject: requestBody))
        let data = try await performer.performData(endpoint)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let code = (object?["req_1"] as? [String: Any])?["code"] as? Int, code != 0 {
            throw LyricsProviderError.serviceResponse(code: code)
        }
        let result: QQResponseSearchResult2 = try performer.decode(data)
        return result.request.data.body.song.list.map { LyricsToken(value: $0) }
    }

    func fetch(with token: LyricsToken) async throws -> Lyrics {
        let songToken = token.value
        let formBody = "musicid=\(songToken.id)&version=15&miniversion=82&lrctype=4"
        guard let bodyData = formBody.data(using: .utf8) else {
            throw LyricsProviderError.processingFailed(reason: "Could not encode QQMusic form body.")
        }
        let endpoint = Endpoint(
            host: Self.lyricsHost,
            path: Self.lyricsPath,
            method: .post,
            headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Referer": "https://c.y.qq.com/",
            ],
            body: bodyData
        )

        let data = try await performer.performData(endpoint)
        guard var dataString = String(data: data, encoding: .utf8) else {
            throw LyricsProviderError.processingFailed(reason: "Could not convert data to string.")
        }
        dataString = dataString
            .replacingOccurrences(of: "<!--", with: "")
            .replacingOccurrences(of: "-->", with: "")

        guard let xmlDocument = try? XMLUtils.create(content: dataString) else {
            throw LyricsProviderError.processingFailed(reason: "Failed to parse QQMusic XML response.")
        }

        let decodedContents = QQMusicXMLDecoder.decodeLyricContents(from: xmlDocument)
        guard let origContent = decodedContents["orig"] else {
            throw LyricsProviderError.processingFailed(reason: "Failed to parse or decrypt QQMusic QRC lyrics.")
        }

        let normalizedOrigContent = QQMusicXMLDecoder.normalizeExtendedLrcTimestamps(origContent)
        guard let lrc = Lyrics(qqmusicQrcContent: origContent)
            ?? Lyrics(normalizedOrigContent)
            ?? Lyrics(origContent) else {
            throw LyricsProviderError.processingFailed(reason: "Failed to parse or decrypt QQMusic QRC lyrics.")
        }
        lrc.applyQQMusicKanaFurigana()

        if let transContent = decodedContents["ts"], let transLrc = Lyrics(transContent) {
            lrc.merge(translation: transLrc)
        }

        lrc.applyMetadata(
            title: songToken.name,
            artist: songToken.singers.joined(separator: ","),
            artworkURL: await fetchAlbumCoverURL(songMid: songToken.mid),
            serviceToken: "\(songToken.mid)"
        )
        return lrc
    }

    private func fetchAlbumCoverURL(songMid: String) async -> URL? {
        let requestBody: [String: Any] = [
            "comm": ["ct": 24, "cv": 0],
            "songinfo": [
                "module": "music.pf_song_detail_svr",
                "method": "get_song_detail_yqq",
                "param": ["song_mid": songMid],
            ],
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else { return nil }
        let endpoint = Endpoint(
            host: Self.searchHost2,
            path: Self.searchPath2,
            method: .post,
            headers: ["Content-Type": "application/json"],
            body: bodyData
        )
        guard let response: QQResponseSongDetail = try? await performer.performJSON(endpoint),
              !response.songinfo.data.trackInfo.album.mid.isEmpty else {
            return nil
        }
        let albumMid = response.songinfo.data.trackInfo.album.mid
        return URL(string: "https://y.gtimg.cn/music/photo_new/T002R800x800M000\(albumMid).jpg")
    }
}
