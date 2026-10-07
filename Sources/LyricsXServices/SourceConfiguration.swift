import Foundation
import LyricsXCore

public struct SourceConfiguration: Sendable {
    public static let defaultOrder = ["LRCLIB", "NetEase", "QQMusic", "Kugou", "Musixmatch", "Apple Music"]
    var candidateLimit = 40
    public var enabled: Set<String> = ["LRCLIB", "NetEase", "QQMusic", "Kugou", "Apple Music"]
    public var sourceOrder: [String] = defaultOrder
    public var appleMusicCloudEnabled = false
    public var preferBilingual = true
    public var preferWordTiming = true
    /// Keep the automatic result conservative by default. When disabled, a
    /// synchronized result with an exact title can still be used when a player
    /// or provider omits or formats artist and duration metadata differently.
    public var strictMatching = true
    public var musixmatchToken: String?
    public var legacyDirectory: URL?
    public init() {}

    public var selectionKey: String {
        (["ranking-v4"] + Self.normalizedOrder(sourceOrder) + enabled.sorted() + [String(appleMusicCloudEnabled), String(preferBilingual), String(preferWordTiming), String(strictMatching)]).joined(separator: "|")
    }

    func satisfiesAutomaticPreferences(_ document: LyricsDocument, for track: Track, aliases: [Track]) -> Bool {
        guard document.isSynced, !document.isLikelyInstrumentalPlaceholder,
              !(preferWordTiming || preferBilingual) || (document.hasWordTiming && document.hasTranslation) else { return false }
        return ([track] + aliases).contains {
            (!strictMatching || CandidateRanker.equivalentTitle(document.title, $0.title))
                && selectionScore(document, for: $0) >= 60
        }
    }

    public static func normalizedOrder(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return (values + defaultOrder).map(sourceKey).filter { defaultOrder.contains($0) && seen.insert($0).inserted }
    }

    /// Existing cloud documents retain their provenance; both readers share
    /// one source control, ranking position, result budget and status.
    public static func sourceKey(_ value: String) -> String {
        AppleMusicCloudLyricsSource.isCloudSource(value) ? AppleMusicLyricsSource.name : value
    }

    public func selectionScore(_ document: LyricsDocument, for track: Track) -> Double {
        let match = CandidateRanker.score(document, for: track)
        // Preferences cannot promote a rejected title, artist, or duration match.
        let trustedVariant = !strictMatching && match >= 53
            && min(CandidateRanker.normalized(document.title).count, CandidateRanker.normalized(track.title).count) >= 3
        guard match >= 60 || trustedVariant else { return match }
        let exactTitle = CandidateRanker.equivalentTitle(document.title, track.title)
        let order = Self.normalizedOrder(sourceOrder)
        let sourceBonus = order.firstIndex(of: Self.sourceKey(document.source)).map { Double(order.count - $0) * 10 } ?? 0
        // Identity is a gate, not an unconditional 400-point preference. Only
        // strict mode gives exact titles their own tier. In relaxed mode valid
        // title variants compete on features/source before tiny match differences.
        return 60 + (strictMatching && exactTitle ? 400 : 0) + (document.isSynced ? 200 : 0)
            + preferenceBonus(document) * 25 + sourceBonus + match / 100
    }

    /// Providers occasionally publish a stale duration for an otherwise exact
    /// title/artist match. This is only a fallback after every strict candidate
    /// has failed; it prevents automatic search from showing an empty state while
    /// preserving strict candidates as the normal path.
    public func fallbackSelectionScore(_ document: LyricsDocument, for track: Track) -> Double? {
        guard document.isSynced else { return nil }
        let title = CandidateRanker.normalized(track.title)
        let candidateTitle = CandidateRanker.normalized(document.title)
        let artist = CandidateRanker.normalized(track.artist)
        let candidateArtist = CandidateRanker.normalized(document.artist)
        guard !title.isEmpty, title == candidateTitle,
              artist.isEmpty || (!candidateArtist.isEmpty && (artist == candidateArtist || artist.contains(candidateArtist) || candidateArtist.contains(artist)))
        else { return nil }
        let order = Self.normalizedOrder(sourceOrder)
        let sourceBonus = order.firstIndex(of: Self.sourceKey(document.source)).map { Double(order.count - $0) } ?? 0
        return 50 + preferenceBonus(document) / 2 + sourceBonus / 100
    }

    /// A deliberately lower-priority fallback for sources with incomplete
    /// metadata. Strict candidates and exact title/artist candidates above
    /// always win; this path is only used after they have all failed.
    public func relaxedSelectionScore(_ document: LyricsDocument, for track: Track) -> Double? {
        guard !strictMatching, document.isSynced else { return nil }
        let title = CandidateRanker.normalized(track.title)
        let candidateTitle = CandidateRanker.normalized(document.title)
        guard title.count >= 3, candidateTitle.count >= 3 else { return nil }
        let exactTitle = CandidateRanker.equivalentTitle(document.title, track.title)
        let compatibleTitle = exactTitle || title.contains(candidateTitle) || candidateTitle.contains(title)
        guard compatibleTitle else { return nil }

        let compatibleArtist = CandidateRanker.compatibleArtists(document.artist, for: track)
        // A partial title must retain an artist match; an exact title is useful
        // even when a provider has omitted the artist or reports a variant.
        guard exactTitle || compatibleArtist else { return nil }
        let order = Self.normalizedOrder(sourceOrder)
        let sourceBonus = order.firstIndex(of: Self.sourceKey(document.source)).map { Double(order.count - $0) } ?? 0
        return (exactTitle ? 40 : 30) + preferenceBonus(document) + (compatibleArtist ? 0.1 : 0) + sourceBonus / 100
    }

    private func preferenceBonus(_ document: LyricsDocument) -> Double {
        guard preferWordTiming || preferBilingual else { return 0 }
        // The other feature is a fallback, including when only one preference
        // is enabled. With both enabled, word timing remains the first priority.
        let wordWeight = preferWordTiming ? 6.0 : 4.0
        let bilingualWeight = preferWordTiming ? 4.0 : 6.0
        return (document.hasWordTiming ? wordWeight : 0) + (document.hasTranslation ? bilingualWeight : 0)
    }

    func bestScore(_ document: LyricsDocument, for track: Track, aliases: [Track] = []) -> Double {
        ([track] + aliases).map { query in
            let strict = selectionScore(document, for: query)
            if strict >= 60 { return strict }
            return max(fallbackSelectionScore(document, for: query) ?? 0, relaxedSelectionScore(document, for: query) ?? 0)
        }.max() ?? 0
    }

    /// Even a free-text query unrelated to the playing track must honor source
    /// and feature preferences, rather than using network arrival order.
    public func manualPrecedes(_ lhs: LyricCandidate, _ rhs: LyricCandidate) -> Bool {
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        let left = preferenceBonus(lhs.document), right = preferenceBonus(rhs.document)
        if left != right { return left > right }
        let order = Self.normalizedOrder(sourceOrder)
        let leftSource = order.firstIndex(of: Self.sourceKey(lhs.document.source)) ?? order.count
        let rightSource = order.firstIndex(of: Self.sourceKey(rhs.document.source)) ?? order.count
        if leftSource != rightSource { return leftSource < rightSource }
        func key(_ doc: LyricsDocument) -> String { doc.title + "|" + doc.artist + "|" + doc.album + "|" + (doc.providerID ?? "") }
        return key(lhs.document) < key(rhs.document)
    }

    /// Retry results may include previously downloaded versions. Enforce the
    /// same compact budget after merging, keeping the best versions per source.
    public func orderedManualResults(_ values: [LyricCandidate], complete: Bool) -> [LyricCandidate] {
        let sorted = values.sorted(by: manualPrecedes)
        guard !complete else { return sorted }
        var counts: [String: Int] = [:]
        return sorted.filter {
            let source = Self.sourceKey($0.document.source)
            counts[source, default: 0] += 1
            return counts[source, default: 0] <= LyricsStore.compactManualResultsPerSource
        }
    }
}
