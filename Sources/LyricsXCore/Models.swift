import Foundation

public struct Track: Codable, Hashable, Sendable, Identifiable {
    public var playerID: String
    public var playerName: String
    public var persistentID: String
    public var title: String
    public var artist: String
    public var album: String
    public var duration: Double
    public var artworkData: Data?
    public var artworkURL: URL?
    public var localFileURL: URL?
    public var embeddedLyrics: String?

    public init(playerID: String, playerName: String, persistentID: String = "", title: String,
                artist: String = "", album: String = "", duration: Double = 0,
                artworkData: Data? = nil, artworkURL: URL? = nil, localFileURL: URL? = nil, embeddedLyrics: String? = nil) {
        self.playerID = playerID; self.playerName = playerName; self.persistentID = persistentID
        self.title = title; self.artist = artist; self.album = album
        self.duration = duration.isFinite ? max(0, duration) : 0
        self.artworkData = artworkData; self.artworkURL = artworkURL
        self.localFileURL = localFileURL; self.embeddedLyrics = embeddedLyrics
    }

    // Length prefixes prevent ambiguous identities when metadata contains separators.
    public var id: String { [playerID, persistentID, title, artist, album].map { "\($0.utf8.count):\($0)" }.joined() }
    public var cacheIdentity: String { [title, artist, album, String(Int(duration.rounded()))].map { "\($0.utf8.count):\($0)" }.joined() }

    /// Player APIs commonly publish a song in stages: title first, then artist,
    /// album, artwork, or a persistent identifier. Those refinements must not
    /// be presented as another track change.
    public func representsSamePlaybackItem(as other: Track) -> Bool {
        guard playerID == other.playerID else { return false }
        if !persistentID.isEmpty, !other.persistentID.isEmpty {
            return persistentID == other.persistentID
        }
        guard !title.isEmpty, title == other.title else { return false }
        func compatible(_ lhs: String, _ rhs: String) -> Bool {
            lhs.isEmpty || rhs.isEmpty || lhs == rhs
        }
        return compatible(artist, other.artist) && compatible(album, other.album)
    }
}

public struct PlaybackSnapshot: Sendable {
    public var track: Track?
    public var position: Double
    public var isPlaying: Bool
    public var sampledAt: Double
    public var positionIsReliable: Bool
    public var playbackStateIsReliable: Bool
    public init(
        track: Track?,
        position: Double,
        isPlaying: Bool,
        sampledAt: Double = ProcessInfo.processInfo.systemUptime,
        positionIsReliable: Bool = true,
        playbackStateIsReliable: Bool = true
    ) {
        self.track = track; self.position = position; self.isPlaying = isPlaying; self.sampledAt = sampledAt
        self.positionIsReliable = positionIsReliable
        self.playbackStateIsReliable = playbackStateIsReliable
    }
}

public struct WordCue: Codable, Hashable, Sendable {
    public var text: String
    public var start: Double
    public var end: Double
    public init(text: String, start: Double, end: Double) { self.text = text; self.start = start; self.end = end }
    public func progress(at time: Double) -> Double {
        guard time.isFinite else { return 0 }
        if end == start { return time >= start ? 1 : 0 }
        return min(1, max(0, (time - start) / max(0.001, end - start)))
    }
}

public struct LyricLine: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var time: Double
    public var text: String
    public var translation: String?
    public var words: [WordCue]
    public var attachments: [String: String]
    /// Real tags may omit punctuation, have instantaneous characters or
    /// overlapping durations. Keep every usable cue instead of rejecting the
    /// whole line. Unmatched text remains visible without fabricated timing.
    public var wordTimingRanges: [(range: Range<String.Index>, cue: WordCue)] {
        var cursor = text.startIndex
        var result: [(Range<String.Index>, WordCue)] = []
        for cue in words {
            guard !cue.text.isEmpty, cue.start.isFinite, cue.end.isFinite,
                  cue.start >= 0, cue.end >= cue.start,
                  let range = text.range(of: cue.text, range: cursor..<text.endIndex) else { continue }
            result.append((range, cue)); cursor = range.upperBound
        }
        return result
    }
    public var hasWordTiming: Bool {
        wordTimingRanges.contains { !$0.cue.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.cue.end > $0.cue.start }
    }
    public var hasTranslation: Bool {
        guard let translation else { return false }
        let original = CandidateRanker.normalized(text)
        return translation.components(separatedBy: .newlines).contains {
            let value = CandidateRanker.normalized($0)
            return !value.isEmpty && value != original
        }
    }
    public init(id: Int, time: Double, text: String, translation: String? = nil,
                words: [WordCue] = [], attachments: [String: String] = [:]) {
        self.id = id; self.time = time; self.text = text; self.translation = translation
        self.words = words; self.attachments = attachments
    }
}

public struct LyricsDocument: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var artist: String
    public var album: String
    public var source: String
    public var duration: Double
    public var lines: [LyricLine]
    public var plainText: String?
    public var offsetMilliseconds: Int
    public var isInstrumental: Bool
    public var originalLRC: String
    public var artworkURL: URL?
    public var providerID: String?
    public init(id: UUID = UUID(), title: String = "", artist: String = "", album: String = "", source: String = "本地",
                duration: Double = 0, lines: [LyricLine] = [], plainText: String? = nil,
                offsetMilliseconds: Int = 0, isInstrumental: Bool = false, originalLRC: String = "", artworkURL: URL? = nil, providerID: String? = nil) {
        self.id = id; self.title = title; self.artist = artist; self.album = album; self.source = source
        self.duration = duration; self.lines = lines.filter { $0.time.isFinite && $0.time >= 0 }.sorted { $0.time < $1.time }
        for index in self.lines.indices { self.lines[index].id = index }
        self.plainText = plainText; self.offsetMilliseconds = offsetMilliseconds
        self.isInstrumental = isInstrumental; self.originalLRC = originalLRC; self.artworkURL = artworkURL
        self.providerID = providerID
    }
    public var hasWordTiming: Bool { lines.contains(where: { $0.hasWordTiming }) }
    public var hasTranslation: Bool { lines.contains(where: { $0.hasTranslation }) }
    public var isSynced: Bool { !lines.isEmpty }
    /// Some providers return a short status sentence as a timed lyric instead
    /// of setting their instrumental flag. Only classify it as non-lyrical
    /// when there are at most three non-empty lines, so normal songs cannot be
    /// hidden merely because one lyric happens to contain a matching word.
    public var isLikelyInstrumentalPlaceholder: Bool {
        guard !isInstrumental else { return true }
        let originalLines = lines.isEmpty ? (plainText ?? "").components(separatedBy: .newlines) : lines.map(\.text)
        let textLines = originalLines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard textLines.count <= 3 else { return false }
        guard !textLines.isEmpty else { return true }
        // Every substantive line must be a recognized status phrase. A lyric
        // containing "instrumental" or "纯音乐" is not itself a placeholder.
        return Self.matchesPlaceholder(textLines.joined()) || textLines.allSatisfy {
            Self.matchesPlaceholder($0) || Self.isOnlyMusicNotation($0)
        }
    }

    // The list covers wording returned by the providers we support and common
    // variants in Simplified/Traditional Chinese, English, Japanese and Korean.
    // Punctuation and whitespace are discarded before matching, so forms such
    // as "♪ 纯音乐，请欣赏 ♪" and "No lyrics available" are equivalent.
    private static let instrumentalPlaceholderPhrases: Set<String> = [
        "纯音乐", "純音樂", "纯音樂", "无歌词", "無歌詞", "没有歌词", "沒有歌詞", "暂无歌词", "暫無歌詞",
        "未填词", "未填詞", "无填词", "無填詞", "没有填词", "沒有填詞", "间奏", "間奏",
        "instrumental", "instrumentalmusic", "instrumentalonly", "instrumentalversion", "interlude",
        "nolyric", "nolyrics", "nolyricsavailable", "lyricsunavailable", "lyricsnotavailable", "musiconly",
        "instrumentalpleaseenjoy", "instrumentalmusicpleaseenjoy", "thissongisinstrumental", "thissonghasnolyrics",
        "インスト", "インストゥルメンタル", "歌詞なし", "歌詞無し", "歌詞はありません", "歌詞がありません", "間奏",
        "연주곡", "가사없음", "가사가없습니다", "가사가없어요",
        "musiqueinstrumentale", "sansparoles", "sinletra", "sinletras", "keintext", "ohnegesang",
        "semletra", "semletras", "strumentale", "senzatesto", "безслов", "инструментал", "инструментальнаямузыка"
    ]

    private static let chinesePlaceholderPattern = "^(此歌曲为|此歌曲為|本歌曲为|本歌曲為|本歌曲|此歌曲|该歌曲为|該歌曲為|这首歌是|這首歌是|本曲为|本曲為|本曲|此曲为|此曲為|此曲)?((没有|沒有|未|无|無)(填词|填詞|歌词|歌詞)的)?(纯音乐|純音樂|纯音樂|无歌词|無歌詞|暂无歌词|暫無歌詞|没有歌词|沒有歌詞|没有填词|沒有填詞|未填词|未填詞|纯伴奏|純伴奏|伴奏)(请欣赏|請欣賞|请您欣赏|請您欣賞|请欣赏音乐|請欣賞音樂|敬请欣赏|敬請欣賞|请聆听|請聆聽)?$"

    private static func matchesPlaceholder(_ text: String) -> Bool {
        let normalized = normalizedPlaceholderText(text)
        return instrumentalPlaceholderPhrases.contains(normalized)
            || normalized.range(of: chinesePlaceholderPattern, options: .regularExpression) != nil
    }

    private static func normalizedPlaceholderText(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }

    private static func isOnlyMusicNotation(_ text: String) -> Bool {
        let allowed = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).union(.symbols)
        return !text.unicodeScalars.isEmpty && text.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
    public func lyricTime(for position: Double) -> Double { position + Double(offsetMilliseconds) / 1000 }
    public func index(at position: Double) -> Int? {
        let time = lyricTime(for: position)
        guard time.isFinite, let first = lines.first, time >= first.time else { return nil }
        var low = 0; var high = lines.count
        while low < high {
            let mid = (low + high) / 2
            if lines[mid].time <= time { low = mid + 1 } else { high = mid }
        }
        return low - 1
    }
    public func seekPosition(for line: LyricLine) -> Double { max(0, line.time - Double(offsetMilliseconds) / 1000) }
}

public struct LyricCandidate: Sendable, Identifiable {
    public var document: LyricsDocument
    public var score: Double
    public var isProvisional: Bool
    public var id: UUID { document.id }
    public init(document: LyricsDocument, score: Double, isProvisional: Bool = false) {
        self.document = document; self.score = score; self.isProvisional = isProvisional
    }
}

public enum LyricsPhase: Equatable, Sendable {
    case idle, loading, ready, notFound, failed(String)
}

public protocol LyricsRepository: Sendable {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error>
    func save(_ document: LyricsDocument, for track: Track) async throws
}
