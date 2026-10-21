import Foundation

/// Positive offsets advance lyrics. The global value belongs to the device's
/// settings; only the song value is stored in a lyric document.
public enum LyricsOffset {
    public static let limit = 300_000
    public static func normalized(_ milliseconds: Int) -> Int {
        min(limit, max(-limit, milliseconds))
    }
    public static func combined(song: Int, global: Int) -> Int {
        let extra = normalized(global)
        let (value, overflow) = song.addingReportingOverflow(extra)
        return overflow ? (extra >= 0 ? Int.max : Int.min) : value
    }
}
