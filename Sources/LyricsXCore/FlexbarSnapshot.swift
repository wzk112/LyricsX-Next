import Foundation

/// A small display projection with an occasional clock anchor, never artwork or file paths.
public struct FlexbarSnapshot: Codable, Equatable, Sendable {
    public struct Clock: Codable, Equatable, Sendable {
        public let hostUptime: Double
        public let position: Double
        public let rate: Double
        public init(hostUptime: Double, position: Double, rate: Double) {
            self.hostUptime = hostUptime; self.position = position; self.rate = rate
        }
    }
    public struct TimedRange: Codable, Equatable, Sendable {
        public let location: Int
        public let length: Int
        public let start: Double
        public let end: Double
        public init(location: Int, length: Int, start: Double, end: Double) {
            self.location = location; self.length = length; self.start = start; self.end = end
        }
    }
    public struct LineTiming: Codable, Equatable, Sendable {
        public let start: Double
        public let end: Double
        public let offsetMilliseconds: Int
        /// Ranges count extended grapheme clusters, not UTF-16 code units.
        public let words: [TimedRange]
        public init(start: Double, end: Double, offsetMilliseconds: Int, words: [TimedRange]) {
            self.start = start; self.end = end; self.offsetMilliseconds = offsetMilliseconds
            self.words = Array(words.prefix(128))
        }
    }
    public enum State: String, Codable, Sendable { case idle, loading, lyrics, song, instrumental, notFound }
    public let version: Int
    public let kind: String
    public var sessionID: UUID
    public var revision: UInt64
    public let state: State
    public let trackRevision: UInt64
    public let documentRevision: UInt64
    public let title: String
    public let artist: String
    public let primary: String
    public let translation: String?
    public let nextLine: String?
    public let isPlaying: Bool
    public var suspended: Bool
    public var clock: Clock?
    public var timing: LineTiming?

    public init(sessionID: UUID, revision: UInt64 = 0, state: State, trackRevision: UInt64,
                documentRevision: UInt64, title: String, artist: String, primary: String,
                translation: String? = nil, nextLine: String? = nil, isPlaying: Bool, suspended: Bool = false) {
        version = 1; kind = "snapshot"; self.sessionID = sessionID; self.revision = revision
        self.state = state; self.trackRevision = trackRevision; self.documentRevision = documentRevision
        self.title = Self.bounded(title); self.artist = Self.bounded(artist); self.primary = Self.bounded(primary)
        self.translation = translation.map(Self.bounded); self.nextLine = nextLine.map(Self.bounded)
        self.isPlaying = isPlaying; self.suspended = suspended
    }

    /// Grapheme and byte limits also bound pathological combining-character input.
    private static func bounded(_ text: String) -> String {
        var value = "", bytes = 0
        for character in text.prefix(4096) {
            let part = String(character)
            let count = part.unicodeScalars.reduce(0) { total, scalar in
                total + (scalar.value < 0x20 ? 6 : scalar.value == 0x22 || scalar.value == 0x5c ? 2 : String(scalar).utf8.count)
            }
            guard bytes + count <= 8192 else { break }
            value += part; bytes += count
        }
        return value
    }

    public static func isDisplayableLyric(_ text: String) -> Bool {
        let gap = CharacterSet(charactersIn: ".·•…⋯・。 \t\n")
        return !text.isEmpty && !text.unicodeScalars.allSatisfy(gap.contains)
    }

    public func hasSamePresentation(as other: Self) -> Bool {
        trackRevision == other.trackRevision && documentRevision == other.documentRevision
            && state == other.state && title == other.title && artist == other.artist && primary == other.primary
            && translation == other.translation && nextLine == other.nextLine
            && isPlaying == other.isPlaying && suspended == other.suspended
            && timing == other.timing
    }

    public static func project(sessionID: UUID, trackRevision: UInt64, documentRevision: UInt64,
                               title: String?, artist: String?, phase: LyricsPhase, isSearching: Bool,
                               isPlaying: Bool, instrumental: Bool, synced: Bool,
                               current: LyricLine?, next: LyricLine?, showTranslation: Bool,
                               transform: (String) -> String = { $0 }) -> Self {
        let state: State
        let primary: String
        let text = current.map { transform($0.text) } ?? ""
        if title == nil { state = .idle; primary = "LyricsX Next" }
        else if instrumental { state = .instrumental; primary = title ?? "" }
        else if synced, isDisplayableLyric(text) { state = .lyrics; primary = text }
        else if isSearching { state = .loading; primary = title ?? "" }
        else if case .notFound = phase { state = .notFound; primary = title ?? "" }
        else if case .failed = phase { state = .notFound; primary = title ?? "" }
        else { state = .song; primary = title ?? "" }
        return .init(sessionID: sessionID, state: state, trackRevision: trackRevision,
                     documentRevision: documentRevision, title: title ?? "", artist: artist ?? "", primary: primary,
                     translation: state == .lyrics && showTranslation ? current?.translation.map(transform) : nil,
                     nextLine: next.map { transform($0.text) }, isPlaying: isPlaying)
    }
}
