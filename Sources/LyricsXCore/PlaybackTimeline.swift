import Foundation

/// Only the monotonic clock drives animation. Wall-clock changes cannot advance lyrics.
public struct PlaybackTimeline: Sendable {
    private var anchor = 0.0
    private var sampledAt = 0.0
    public private(set) var isPlaying = false
    private var duration = 0.0
    private var displayCorrection = 0.0
    private static let correctionDuration = 0.3
    public var maximumExtrapolation = 3.0
    public init() {}
    public mutating func accept(_ snapshot: PlaybackSnapshot) {
        guard snapshot.sampledAt.isFinite else { return }
        if snapshot.positionIsReliable, !snapshot.position.isFinite { return }
        guard snapshot.positionIsReliable || snapshot.playbackStateIsReliable else { return }
        let displayed = presentationPosition(at: snapshot.sampledAt)
        let continuous = isPlaying && (!snapshot.playbackStateIsReliable || snapshot.isPlaying)
            && snapshot.sampledAt >= sampledAt && snapshot.sampledAt - sampledAt < maximumExtrapolation
        let current = position(at: snapshot.sampledAt)
        anchor = snapshot.positionIsReliable ? max(0, snapshot.position) : current
        let correction = displayed - anchor
        // Player IPC has small timestamp jitter even with a steady display
        // link. Keep only the visual clock continuous and converge promptly;
        // real seeks, pauses, stale sources and line selection stay exact.
        displayCorrection = continuous && abs(correction) <= 0.12 ? correction : 0
        sampledAt = snapshot.sampledAt
        if snapshot.playbackStateIsReliable { isPlaying = snapshot.isPlaying }
        if let track = snapshot.track, track.duration > 0 { duration = track.duration }
    }
    public func position(at now: Double) -> Double {
        guard now.isFinite else { return anchor }
        let elapsed = isPlaying ? min(maximumExtrapolation, max(0, now - sampledAt)) : 0
        let result = anchor + elapsed
        return duration > 0 ? min(duration, result) : result
    }
    public func presentationPosition(at now: Double) -> Double {
        let exact = position(at: now)
        guard isPlaying, now.isFinite, displayCorrection != 0 else { return exact }
        let t = min(1, max(0, (now - sampledAt) / Self.correctionDuration))
        let ease = t * t * t * (t * (t * 6 - 15) + 10)
        let result = max(0, exact + displayCorrection * (1 - ease))
        return duration > 0 ? min(duration, result) : result
    }
    public mutating func seek(to position: Double, at now: Double) {
        guard position.isFinite, now.isFinite else { return }
        displayCorrection = 0
        anchor = max(0, duration > 0 ? min(position, duration) : position); sampledAt = now
    }
    public mutating func freeze(at now: Double) { anchor = position(at: now); sampledAt = now; isPlaying = false; displayCorrection = 0 }
}

public enum CandidateRanker {
    public static func equivalentTitle(_ lhs: String, _ rhs: String) -> Bool {
        TrackSearchText.titles(lhs).contains { a in TrackSearchText.titles(rhs).contains { equivalent(a, $0) } }
    }
    public static func compatibleArtists(_ candidate: String, for track: Track) -> Bool {
        let expected = TrackSearchText.artists(track.artist, title: track.title)
        if expected.isEmpty { return true }
        return TrackSearchText.artists(candidate).contains { name in
            expected.contains { other in
                let a = normalized(name), b = normalized(other)
                return equivalent(name, other) || (min(a.count, b.count) >= 3 && (a.contains(b) || b.contains(a)))
            }
        }
    }
    public static func equivalent(_ lhs: String, _ rhs: String) -> Bool {
        let left = normalized(lhs), right = normalized(rhs)
        guard !left.isEmpty, !right.isEmpty else { return false }
        if left == right { return true }
        if left.unicodeScalars.allSatisfy({ $0.value < 128 }), right.unicodeScalars.allSatisfy({ $0.value < 128 }) { return false }
        // Handles kana, Hangul, Cyrillic and diacritics without interpreting a
        // translated title as equivalent. Catalog IDs provide translated aliases.
        guard let latinLeft = lhs.applyingTransform(.toLatin, reverse: false),
              let latinRight = rhs.applyingTransform(.toLatin, reverse: false) else { return false }
        let a = normalized(latinLeft), b = normalized(latinRight)
        return a.count >= 3 && a == b
    }
    public static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }
    public static func score(_ doc: LyricsDocument, for track: Track) -> Double {
        let title = normalized(track.title), candidateTitle = normalized(doc.title)
        guard !title.isEmpty, !candidateTitle.isEmpty,
              equivalentTitle(doc.title, track.title) || candidateTitle.contains(title) || title.contains(candidateTitle) else { return 0 }
        let exactTitle = equivalentTitle(doc.title, track.title)
        var result = exactTitle ? 60.0 : 38.0
        let artist = normalized(track.artist), candidateArtist = normalized(doc.artist)
        if !artist.isEmpty {
            guard !candidateArtist.isEmpty, compatibleArtists(doc.artist, for: track) else { return 0 }
            result += equivalent(doc.artist, track.artist) ? 25 : 15
        }
        if track.duration > 0, doc.duration > 0 {
            let delta = abs(track.duration - doc.duration)
            // Many sources report the last lyric's timestamp as their length;
            // the instrumental outro may be much longer. Duration may reject
            // an ambiguous title, but cannot veto a verified title/artist pair.
            if !exactTitle, delta >= max(15, track.duration * 0.08) { return 0 }
            result += max(0, 10 - delta)
        }
        if doc.hasWordTiming { result += 3 }
        if doc.hasTranslation { result += 2 }
        return result
    }
}
