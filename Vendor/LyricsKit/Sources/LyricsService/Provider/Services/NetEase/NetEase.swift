import Foundation
import LyricsCore
import Regex

extension LyricsProviders {
    final class NetEase {
        let httpClient: HTTPClient
        private let eapiClient: NetEaseEapiClient
        private var performer: NetworkPerformer { NetworkPerformer(httpClient: httpClient) }

        private static let lyricsEapiURL = "https://interface3.music.163.com/eapi/song/lyric/v1"

        init(httpClient: HTTPClient = .shared) {
            self.httpClient = httpClient
            self.eapiClient = NetEaseEapiClient(httpClient: httpClient)
        }
    }
}

extension LyricsProviders.NetEase: _LyricsProvider {
    struct LyricsToken {
        let value: NetEaseResponseSearchResult.Result.Song
    }

    static let service: String = "NetEase"

    func search(for request: LyricsSearchRequest) async throws -> [LyricsToken] {
        // The old PC endpoint can return code 405 instead of a result.
        // Use the current app endpoint first; fall back once, without a
        // redundant cookie-probe search or repeated rate-limit retries.
        do {
            let data = try await eapiClient.post(url: "https://interface3.music.163.com/eapi/search/get", payload: [
                "s": request.searchTerm.description, "type": "1",
                "limit": String(request.limit), "offset": "0"
            ])
            return try decodeSearch(data)
        } catch {
            try Task.checkCancellation()
            let endpoint = Endpoint(
                host: "music.163.com", path: "/api/search/pc",
                queryItems: [URLQueryItem(name: "s", value: request.searchTerm.description),
                             URLQueryItem(name: "offset", value: "0"),
                             URLQueryItem(name: "limit", value: String(request.limit)),
                             URLQueryItem(name: "type", value: "1")],
                method: .post, headers: ["Referer": "https://music.163.com/", "User-Agent": "Mozilla/5.0"])
            return try decodeSearch(await performer.performData(endpoint))
        }
    }

    private func decodeSearch(_ data: Data) throws -> [LyricsToken] {
        if let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = envelope["code"] as? Int, code != 200 {
            throw LyricsProviderError.serviceResponse(code: code)
        }
        let result: NetEaseResponseSearchResult = try performer.decode(data)
        return result.result.songs.map(LyricsToken.init)
    }

    func fetch(with token: LyricsToken) async throws -> Lyrics {
        let payload: [String: String] = [
            "id": token.value.id.description,
            "cp": "false",
            "lv": "0",
            "kv": "0",
            "tv": "0",
            "rv": "0",
            "yv": "0",
            "ytv": "0",
            "yrv": "0",
            "csrf_token": "",
        ]

        let raw = try await eapiClient.post(url: Self.lyricsEapiURL, payload: payload)
        let singleLyricsResponse: NetEaseResponseSingleLyrics =
            try performer.decode(raw, as: NetEaseResponseSingleLyrics.self)

        let lyrics: Lyrics
        let transLrc = (singleLyricsResponse.tlyric?.fixedLyric).flatMap(Lyrics.init(_:))
        if let yrc = singleLyricsResponse.yrc?.fixedLyric, let parsed = Lyrics(netEaseYrcContent: yrc) {
            if let translation = (singleLyricsResponse.ytlrc?.fixedLyric).flatMap(Lyrics.init(_:)) ?? transLrc {
                parsed.merge(translation: translation)
            }
            lyrics = parsed
        } else if let kLrc = (singleLyricsResponse.klyric?.fixedLyric).flatMap(Lyrics.init(netEaseKLyricContent:)) {
            transLrc.map(kLrc.merge)
            lyrics = kLrc
        } else if let lrc = (singleLyricsResponse.lrc?.fixedLyric).flatMap(Lyrics.init(_:)) {
            transLrc.map(lrc.merge)
            lyrics = lrc
        } else {
            throw LyricsProviderError.processingFailed(reason: "No valid lyric content found in NetEase response.")
        }

        lyrics.applyMetadata(
            title: token.value.name,
            artist: token.value.artists.first?.name,
            album: token.value.album.name,
            lrcBy: singleLyricsResponse.lyricUser?.nickname,
            length: Double(token.value.duration) / 1000,
            artworkURL: token.value.album.picUrl,
            serviceToken: "\(token.value.id)"
        )
        return lyrics
    }
}

private let netEaseTimeTagFixer = Regex(#"(\[\d+:\d+):(\d+\])"#)

extension NetEaseResponseSingleLyrics.Lyric {
    fileprivate var fixedLyric: String? {
        lyric?.replacingMatches(of: netEaseTimeTagFixer, with: "$1.$2")
    }
}
