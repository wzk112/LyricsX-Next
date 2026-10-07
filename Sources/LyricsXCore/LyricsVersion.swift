import Foundation

extension LyricsDocument {
    public func lineID(at position: Double) -> Int? {
        index(at: position).map { lines[$0].id }
    }
    /// Provider IDs identify songs, not an immutable lyric revision. Compare
    /// the actual text, translations and timed words before marking Applied.
    /// A user-adjusted offset does not turn the chosen version into another one.
    public func representsSameVersion(as other: LyricsDocument) -> Bool {
        guard lines == other.lines, plainText == other.plainText,
              isInstrumental == other.isInstrumental else { return false }
        if let providerID, let otherID = other.providerID { return providerID == otherID }
        return source == other.source && title == other.title && artist == other.artist && album == other.album
    }
}
