import Foundation
import LyricsXCore

/// Reads Music's song lyrics field, not the subscription service's private
/// syllable endpoint. It never writes lyrics or blocks playback sampling.
public struct AppleMusicLyricsSource: Sendable {
    public static let name = "Apple Music"
    typealias Reader = @Sendable (Track) async throws -> String?
    private let reader: Reader
    private let retryDelays: [Duration]
    public init() { reader = Self.readSongField; retryDelays = [.zero, .seconds(1), .seconds(3)] }
    init(retryDelays: [Duration] = [.zero, .seconds(1), .seconds(3)], reader: @escaping Reader) {
        self.reader = reader; self.retryDelays = retryDelays
    }
    public func document(for track: Track) async throws -> LyricsDocument? {
        guard track.playerID == "com.apple.Music" else { return nil }
        if let document = Self.parse(track.embeddedLyrics, for: track) { return document }
        for delay in retryDelays {
            try Task.checkCancellation()
            if delay > .zero { try await Task.sleep(for: delay) }
            if let document = Self.parse(try await reader(track), for: track) { return document }
        }
        return nil
    }
    static func parse(_ text: String?, for track: Track) -> LyricsDocument? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              var document = try? LyricsCodec.parse(text, source: name) else { return nil }
        // The player identity, not tags embedded by a previous editor, owns
        // association with the currently playing recording.
        document.title = track.title; document.artist = track.artist
        document.album = track.album; document.duration = track.duration
        document.providerID = "music-field:" + track.id
        return document
    }
    static func readSongField(_ track: Track) async throws -> String? {
        let script = """
          if (!app.running()) return JSON.stringify({state:'changed'});
          function text(f) { try { return String(f() || ''); } catch (_) { return ''; } }
          function matches(t) {
            const id = text(() => t.persistentID());
            if (argv[0] && id) return id === argv[0];
            return text(() => t.name()) === argv[1] && text(() => t.artist()) === argv[2]
              && text(() => t.album()) === argv[3];
          }
          const t = app.currentTrack();
          if (!matches(t)) return JSON.stringify({state:'changed'});
          let lyrics;
          try { lyrics = t.lyrics(); }
          catch (e) { return JSON.stringify({state:e.number === -1743 ? 'permission' : 'unavailable'}); }
          if (!matches(app.currentTrack())) return JSON.stringify({state:'changed'});
          return JSON.stringify({state:'ok', lyrics: lyrics || ''});
        """
        let result: ProcessRunner.Output
        do {
            guard let output = try await RunningPlayerScript.runJavaScript(bundleID: track.playerID, body: script,
                arguments: [track.persistentID, track.title, track.artist, track.album], timeout: 2) else {
                throw ReadError.changed
            }
            result = output
        } catch is CancellationError {
            if Task.isCancelled { throw CancellationError() }
            throw ReadError.timeout
        }
        guard result.status == 0 else {
            if result.error.contains("-1743") { throw ReadError.permission }
            throw ReadError.unavailable
        }
        struct Response: Decodable { let state: String; let lyrics: String? }
        let response = try JSONDecoder().decode(Response.self, from: result.data)
        switch response.state {
        case "ok": return response.lyrics
        case "changed": throw ReadError.changed
        case "permission": throw ReadError.permission
        default: throw ReadError.unavailable
        }
    }
    enum ReadError: LocalizedError {
        case permission, unavailable, changed, timeout
        var errorDescription: String? {
            switch self {
            case .permission: "未获准读取 Music；请在系统设置的自动化权限中允许访问。其他歌词源仍会搜索。"
            case .unavailable: "Music 暂未提供歌曲歌词字段；其他歌词源仍会搜索。"
            case .changed: "歌曲已切换，已停止读取旧歌。"
            case .timeout: "读取 Music 歌词超时；其他歌词源仍会搜索，可以重新尝试。"
            }
        }
    }
}
