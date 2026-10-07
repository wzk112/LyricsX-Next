import Foundation

/// Search-only names; never rewrite the player title or cached lyric contents.
public enum TrackSearchText {
    /// Search hints only. Keep full player metadata for identity/ranking.
    public static func catalogArtists(_ artist: String) -> [String] {
        let all = artists(artist)
        let full = CandidateRanker.normalized(artist)
        let components = all.filter { CandidateRanker.normalized($0) != full }
        var seen: Set<String> = []
        return (components.isEmpty ? all : components).map {
            $0.replacingOccurrences(of: #"(?i)[(（]\s*(?:cv|voice)\s*[:：].*?[)）]"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !CandidateRanker.normalized($0).isEmpty && seen.insert(CandidateRanker.normalized($0)).inserted }
    }

    public static func searchArtist(_ artist: String) -> String {
        let names = catalogArtists(artist)
        // Long cast lists make catalog APIs reject or overconstrain the query.
        // Preserve ordinary solo/duet names and explicit free-text searches.
        return names.count > 2 || artist.range(of: #"(?i)[(（]\s*(?:cv|voice)\s*[:：]"#, options: .regularExpression) != nil
            ? names.prefix(2).joined(separator: " ") : artist
    }

    public static func titles(_ title: String) -> [String] {
        let withoutCredit = title.replacingOccurrences(of: #"(?i)[(（\[]\s*(?:feat(?:uring)?\.?|ft\.?|prod\.?(?:\s+by)?)\s+[^)）\]]+[)）\]]"#, with: "", options: .regularExpression)
        let cleaned = withoutCredit.replacingOccurrences(of: #"(?i)[(（\[]\s*(?:full(?:\s+ver(?:sion)?\.?)?|完整版|フル(?:バージョン|ver\.?)?)\s*[)）\]]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var names = [title, cleaned]
        // Tildes conventionally delimit an alternate title/subtitle. Do not
        // strip arbitrary parentheses: Live, Remix and Cover identify versions.
        let subtitles = cleaned.components(separatedBy: CharacterSet(charactersIn: "~～〜"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if subtitles.count == 2 { names.append(contentsOf: subtitles) }
        let bilingual = cleaned.components(separatedBy: " - ")
        if bilingual.count == 2, CandidateRanker.equivalent(bilingual[0], bilingual[1]) { names.append(contentsOf: bilingual) }
        var seen: Set<String> = []
        return names.filter { !CandidateRanker.normalized($0).isEmpty && seen.insert(CandidateRanker.normalized($0)).inserted }
    }
    public static func artists(_ artist: String, title: String = "") -> [String] {
        var names = [artist]
        if let regex = try? NSRegularExpression(pattern: #"(?i)[(（\[]\s*(?:feat(?:uring)?\.?|ft\.?)\s+([^)）\]]+)[)）\]]"#) {
            let range = NSRange(title.startIndex..., in: title)
            for match in regex.matches(in: title, range: range) {
                if let range = Range(match.range(at: 1), in: title) { names.append(String(title[range])) }
            }
        }
        let components = names.flatMap { $0.replacingOccurrences(of: #"(?i)\s+(?:and|feat\.?|featuring|ft\.?)\s+"#, with: "/", options: .regularExpression)
            .components(separatedBy: CharacterSet(charactersIn: "/&,、;+×")) }
        var seen: Set<String> = []
        return (names + components).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !CandidateRanker.normalized($0).isEmpty && seen.insert(CandidateRanker.normalized($0)).inserted }
    }
}
