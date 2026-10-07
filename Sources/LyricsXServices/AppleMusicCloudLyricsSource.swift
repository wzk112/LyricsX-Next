import Foundation
import LyricsXCore

/// Cloud reader, separate from Music's editable song lyrics field.
public struct AppleMusicCloudLyricsSource: Sendable {
    public static let name = "Apple Music 云端"
    public static func isCloudSource(_ value: String) -> Bool {
        value == name || value == "Apple Music 云端（实验）"
    }
    static func normalizedName(_ value: String) -> String { isCloudSource(value) ? name : value }
    typealias Request = @Sendable (String) async throws -> Data
    private let request: Request
    public init() { request = { try await AppleMusicCloudSession.shared.request($0) } }
    init(request: @escaping Request) { self.request = request }

    public func document(for track: Track) async throws -> LyricsDocument? {
        guard track.playerID == "com.apple.Music" else { return nil }
        try Task.checkCancellation()
        let storefront = try JSONDecoder().decode(StorefrontResponse.self, from: await request("/v1/me/storefront")).data.first?.id ?? ""
        guard storefront.count == 2, storefront.allSatisfy({ $0.isASCII && $0.isLetter }) else { throw AppleMusicCloudError.response }
        var matched: Song?
        for term in Self.searchTerms(for: track) {
            try Task.checkCancellation()
            var query = URLComponents()
            query.queryItems = [.init(name: "term", value: term), .init(name: "types", value: "songs"),
                                .init(name: "limit", value: "25")]
            let data = try await request("/v1/catalog/\(storefront)/search?\(query.percentEncodedQuery ?? "")")
            let songs = try JSONDecoder().decode(SearchResponse.self, from: data).results.songs?.data ?? []
            if let song = Self.match(songs, to: track) { matched = song; break }
        }
        guard let song = matched else { throw AppleMusicCloudError.catalogMismatch }
        try Task.checkCancellation()
        // Native Music can show timed lines even when there is no syllable resource.
        for resource in ["syllable-lyrics", "lyrics"] {
            try Task.checkCancellation()
            let lyrics: Data
            do {
                lyrics = try await request("/v1/catalog/\(storefront)/songs/\(song.id)/\(resource)?extend=ttmlLocalizations&l%5Blyrics%5D=zh-Hans-CN")
            } catch AppleMusicCloudError.noLyrics { continue }
            guard let text = try Self.ttml(in: lyrics) else { continue }
            var document = try TTMLLyricsParser.parse(text, source: Self.name)
            document.title = song.attributes.name
            document.artist = song.attributes.artistName
            document.album = song.attributes.albumName ?? ""
            document.duration = Double(song.attributes.durationInMillis ?? 0) / 1000
            document.providerID = "apple-cloud:\(storefront):\(song.id)"
            return document
        }
        throw AppleMusicCloudError.noLyrics
    }

    static func searchTerms(for track: Track) -> [String] {
        // Complete cast/CV credit lists often overconstrain Apple's catalog search.
        // Short queries locate candidates; the unchanged full metadata verifies them.
        let credits = TrackSearchText.catalogArtists(track.artist).filter { CandidateRanker.normalized($0).count >= 3 }
        var seen: Set<String> = []
        return (credits.prefix(2).map { track.title + " " + $0 } + [track.title])
            .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(400)) }
            .filter { !$0.isEmpty && seen.insert(CandidateRanker.normalized($0)).inserted }
    }

    struct Song: Decodable, Sendable {
        let id: String
        let attributes: Attributes
        struct Attributes: Decodable, Sendable {
            let name: String; let artistName: String; let albumName: String?; let durationInMillis: Int?
        }
    }
    static func match(_ songs: [Song], to track: Track) -> Song? {
        songs.filter { song in
            guard !song.id.isEmpty, song.id.allSatisfy({ $0.isASCII && $0.isNumber }),
                  CandidateRanker.equivalentTitle(song.attributes.name, track.title),
                  CandidateRanker.compatibleArtists(song.attributes.artistName, for: track) else { return false }
            if !track.album.isEmpty, let album = song.attributes.albumName, !album.isEmpty,
               CandidateRanker.normalized(album) != CandidateRanker.normalized(track.album) { return false }
            if track.duration > 0, let milliseconds = song.attributes.durationInMillis {
                return abs(Double(milliseconds) / 1000 - track.duration) <= max(5, track.duration * 0.025)
            }
            return true
        }.sorted { left, right in
            abs(Double(left.attributes.durationInMillis ?? 0) / 1000 - track.duration)
                < abs(Double(right.attributes.durationInMillis ?? 0) / 1000 - track.duration)
        }.first
    }
    static func ttml(in data: Data) throws -> String? {
        guard data.count <= 4_000_000 else { throw LyricsCodec.CodecError.tooLarge }
        guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = response["data"] as? [[String: Any]] else { throw AppleMusicCloudError.response }
        for row in rows {
            guard let attributes = row["attributes"] as? [String: Any] else { continue }
            if let text = attributes["ttmlLocalizations"] as? String, !text.isEmpty { return text }
            if let localizations = attributes["ttmlLocalizations"] as? [String: String],
               let text = localizations["zh-Hans-CN"] ?? localizations["zh-Hans"] ?? localizations.sorted(by: { $0.key < $1.key }).first?.value { return text }
            if let text = attributes["ttml"] as? String, !text.isEmpty { return text }
        }
        return nil
    }
    private struct StorefrontResponse: Decodable { let data: [Storefront]; struct Storefront: Decodable { let id: String } }
    private struct SearchResponse: Decodable { let results: Results; struct Results: Decodable { let songs: Songs? }; struct Songs: Decodable { let data: [Song] } }
}

public enum AppleMusicCloudError: LocalizedError {
    case signInRequired, pageNotReady, timeout, forbidden, catalogMismatch, noLyrics, response, network
    public var errorDescription: String? {
        switch self {
        case .signInRequired: "请在设置 → 搜索 → Apple Music 云端歌词中登录。"
        case .pageNotReady: "Apple Music 网页未就绪，请打开登录窗口重试。"
        case .timeout: "Apple Music 云端读取超时，其他歌词源仍会搜索。"
        case .forbidden: "云端歌词访问被拒绝，请检查订阅或重新登录；服务也可能暂不可用。"
        case .catalogMismatch: "Apple Music 目录未匹配到这首歌，不代表没有在线歌词。"
        case .noLyrics: "已匹配到歌曲，但云端接口没有返回可读取的歌词。"
        case .response: "Apple Music 返回的歌词数据暂不支持。"
        case .network: "Apple Music 网页连接失败，请稍后重试。"
        }
    }
}
