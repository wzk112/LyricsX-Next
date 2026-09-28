import AppKit

/// A short information row uses the same user-selected width as timed lyrics.
/// Text and artwork grow gently, with room for a two-line title at every width.
@MainActor struct OverlaySongCardLayout {
    let width: Double
    let displayedTitle: String
    let displayedArtist: String
    private struct CacheKey: Hashable {
        let width: Double
        let title: String
        let artist: String
    }
    private static var heightCache: [CacheKey: Double] = [:]

    init(width: Double, title: String? = nil, artist: String? = nil) {
        self.width = width
        displayedTitle = title ?? "LyricsX Next"
        displayedArtist = artist ?? ""
    }

    private var scale: Double { min(1, max(0, (width - 320) / 400)) }
    var artwork: Double { 42 + 18 * scale }
    var title: Double { 17 + 4 * scale }
    var artist: Double { 12 + 2 * scale }
    var spacing: Double { 12 + 4 * scale }
    var textWidth: Double { max(1, width - 60 - artwork - spacing) }
    var height: Double {
        let key = CacheKey(width: width, title: displayedTitle, artist: displayedArtist)
        if let cached = Self.heightCache[key] { return cached }
        let value = ceil(rowHeight + 36)
        if Self.heightCache.count >= 64 { Self.heightCache.removeAll(keepingCapacity: true) }
        Self.heightCache[key] = value
        return value
    }
    // The audible line sits above the bottom of its 18pt surface. Shift the
    // row down without changing the sum of padding or the panel height.
    static let waveformTopPadding: CGFloat = 15.5
    static let waveformBottomPadding: CGFloat = 2.5
    /// Waveform spacing retains the original no-wave centering and height.
    func baseHeight(waveformEnabled: Bool) -> Double { height + (waveformEnabled ? 16 : 0) }
    var contentWidth: Double { max(260, width - 60) }

    private var rowHeight: Double {
        let titleFont = NSFont.systemFont(ofSize: title, weight: .semibold)
        let artistFont = NSFont.systemFont(ofSize: artist, weight: .medium)
        let titleLine = ceil(NSLayoutManager().defaultLineHeight(for: titleFont))
        let artistLine = ceil(NSLayoutManager().defaultLineHeight(for: artistFont))
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let titleBounds = (displayedTitle as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: titleFont, .paragraphStyle: paragraph])
        let titleHeight = min(titleLine * 2, max(titleLine, ceil(titleBounds.height)))
        let textHeight = titleHeight + (displayedArtist.isEmpty ? 0 : 4 + artistLine)
        return max(artwork, textHeight)
    }
}
