import Foundation
@preconcurrency import LyricsKit
import LyricsXCore

public enum LyricsCodec {
    public static func parse(_ text: String, source: String = "本地") throws -> LyricsDocument {
        let clean = text.replacingOccurrences(of: "\u{FEFF}", with: "").replacingOccurrences(of: "\r\n", with: "\n")
        guard clean.utf8.count <= 4_000_000 else { throw CodecError.tooLarge }
        if clean.contains("[lxinstrumental:1]") { return LyricsDocument(source: source, isInstrumental: true, originalLRC: clean) }
        if let lyrics = Lyrics(clean) { return convert(lyrics, source: source) }
        let plain = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plain.isEmpty, !plain.contains("\u{0000}") else { throw CodecError.empty }
        // Plain lyrics are intentionally never assigned fabricated timestamps.
        return LyricsDocument(source: source, plainText: plain, originalLRC: clean)
    }
    static func convert(_ lyrics: Lyrics, source: String? = nil) -> LyricsDocument {
        var rows: [LyricLine] = []
        for line in lyrics.lines where line.enabled && line.position.isFinite && line.position >= 0 {
            var words: [WordCue] = []
            if let timing = line.attachments.timetag {
                let chars = Array(line.content)
                let tags = timing.tags.filter { $0.index >= 0 && $0.index <= chars.count && $0.time.isFinite }
                    .sorted { $0.index < $1.index }
                for (index, tag) in tags.enumerated() {
                    let endIndex = index + 1 < tags.count ? tags[index + 1].index : chars.count
                    let endTime = index + 1 < tags.count ? tags[index + 1].time : timing.duration ?? tag.time + 0.4
                    guard endIndex > tag.index, endTime >= tag.time else { continue }
                    words.append(WordCue(text: String(chars[tag.index..<endIndex]), start: line.position + tag.time, end: line.position + endTime))
                }
            }
            var attachments: [String: String] = [:]
            for tag in lyrics.metadata.attachmentTags { attachments[tag.rawValue] = line.attachments[tag] }
            let translation = line.attachments.translation()
            if let last = rows.last, abs(last.time - line.position) < 0.001 {
                // Some providers encode bilingual lyrics as two lines at the same timestamp.
                if last.text != line.content, !line.content.isEmpty {
                    if last.text.isEmpty { rows[rows.count - 1].text = line.content }
                    else { rows[rows.count - 1].translation = [last.translation, line.content].compactMap { $0 }.joined(separator: "\n") }
                }
                continue
            }
            rows.append(LyricLine(id: rows.count, time: line.position, text: line.content, translation: translation, words: words, attachments: attachments))
        }
        return LyricsDocument(title: lyrics.idTags[.title] ?? "", artist: lyrics.idTags[.artist] ?? "",
                              album: lyrics.idTags[.album] ?? "", source: source ?? lyrics.metadata.service ?? "未知来源",
                              duration: lyrics.length ?? 0, lines: rows, offsetMilliseconds: lyrics.offset,
                              originalLRC: lyrics.description, artworkURL: lyrics.metadata.artworkURL, providerID: lyrics.metadata.serviceToken)
    }
    public static func read(_ url: URL) throws -> LyricsDocument {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? 0 <= 4_000_000 else { throw CodecError.tooLarge }
        return try parse(readText(url))
    }
    static func readText(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        guard data.count <= 4_000_000 else { throw CodecError.tooLarge }
        let gb18030 = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        guard let value = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) ?? String(data: data, encoding: String.Encoding(rawValue: gb18030)) else { throw CodecError.encoding }
        return value
    }
    public static func export(_ doc: LyricsDocument, plain: Bool = false) -> String {
        if doc.isInstrumental { return "[ti:\(doc.title)]\n[ar:\(doc.artist)]\n[lxinstrumental:1]" }
        if plain { return doc.plainText ?? doc.lines.map { [$0.text, $0.translation].compactMap { $0 }.joined(separator: "\n") }.joined(separator: "\n") }
        if !doc.isSynced { return doc.plainText ?? "" }
        if let source = Lyrics(doc.originalLRC) {
            source.offset = doc.offsetMilliseconds
            if !doc.title.isEmpty { source.idTags[.title] = doc.title.replacingOccurrences(of: "\n", with: " ") }
            if !doc.artist.isEmpty { source.idTags[.artist] = doc.artist.replacingOccurrences(of: "\n", with: " ") }
            return source.description
        }
        var lines = ["[ti:\(doc.title)]", "[ar:\(doc.artist)]", "[offset:\(doc.offsetMilliseconds)]"]
        for line in doc.lines {
            let tag = String(format: "[%02d:%06.3f]", Int(line.time) / 60, line.time.truncatingRemainder(dividingBy: 60))
            lines.append(tag + line.text)
            if let translation = line.translation { lines.append(tag + "[tr]" + translation) }
        }
        return lines.joined(separator: "\n")
    }
    public enum CodecError: LocalizedError {
        case tooLarge, empty, encoding
        public var errorDescription: String? {
            switch self {
            case .tooLarge: "歌词文件不能超过 4 MB。"
            case .empty: "文件没有可用的歌词。"
            case .encoding: "无法读取文件编码，请使用 UTF-8、UTF-16 或 GB18030。"
            }
        }
    }
}
