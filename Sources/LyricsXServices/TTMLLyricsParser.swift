import Foundation
import LyricsXCore

/// Parses Apple-style absolute lyric clocks. Never invents word timing for
/// line-only or untimed text, and keeps the original XML for auxiliary vocals.
enum TTMLLyricsParser {
    static func parse(_ text: String, source: String) throws -> LyricsDocument {
        guard text.utf8.count <= 2_000_000 else { throw LyricsCodec.CodecError.tooLarge }
        guard !text.localizedCaseInsensitiveContains("<!DOCTYPE") else { throw ParseError.invalid }
        let builder = Builder()
        let parser = XMLParser(data: Data(text.utf8))
        parser.shouldResolveExternalEntities = false
        parser.delegate = builder
        guard parser.parse(), let root = builder.root, root.name == "tt" else { throw ParseError.invalid }
        let wordTiming = root.attribute("timing")?.lowercased()
        var rows: [LyricLine] = [], plain: [String] = []
        let translations = root.descendants("translation").filter { $0.attribute("type") != "replacement" }
        var translated: [String: String] = [:]
        for translation in translations {
            for node in translation.descendants("text") {
                if let key = node.attribute("for"), !node.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    translated[key, default: ""] += (translated[key] == nil ? "" : "\n") + node.text
                }
            }
        }
        guard let body = root.descendants("body").first else { throw ParseError.invalid }
        for paragraph in body.descendants("p") {
            if paragraph.attribute("role") == "x-bg" { continue }
            var words: [WordCue] = []
            let content = render(paragraph, words: &words, allowWords: wordTiming != "line" && wordTiming != "none")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { continue }
            plain.append(content)
            let start = paragraph.attribute("begin").flatMap(time) ?? words.map(\.start).min()
            guard wordTiming != "none", let start, start.isFinite, start >= 0 else { continue }
            var attachments: [String: String] = [:]
            for attribute in ["agent", "key", "end"] {
                if let value = paragraph.attribute(attribute) { attachments["ttml-" + attribute] = value }
            }
            let inlineTranslation = paragraph.descendants("span").filter { $0.attribute("role") == "x-translation" }.map(\.text).joined(separator: "\n")
            let romanization = paragraph.descendants("span").filter { $0.attribute("role") == "x-roman" || $0.attribute("role") == "x-romanization" }.map(\.text).joined()
            if !romanization.isEmpty { attachments["ttml-romanization"] = romanization }
            let translation = paragraph.attribute("key").flatMap { translated[$0] }
                ?? (inlineTranslation.isEmpty ? nil : inlineTranslation)
            rows.append(.init(id: rows.count, time: start, text: content, translation: translation,
                              words: words, attachments: attachments))
        }
        guard !plain.isEmpty else { throw ParseError.empty }
        return .init(source: source, lines: rows, plainText: rows.isEmpty ? plain.joined(separator: "\n") : nil,
                     originalTTML: text)
    }

    private static func render(_ node: Node, words: inout [WordCue], allowWords: Bool) -> String {
        if ["x-bg", "x-translation", "x-roman", "x-romanization"].contains(node.attribute("role") ?? "") { return "" }
        var value = ""
        let timedChildren = node.descendants("span").contains { $0.attribute("begin") != nil }
        let start = node.attribute("begin").flatMap(time)
        let end = node.attribute("end").flatMap(time) ?? start.flatMap { start in node.attribute("dur").flatMap(time).map { start + $0 } }
        for piece in node.pieces {
            switch piece {
            case .text(let text):
                // Preserve literal word separators, discard XML indentation.
                if text.allSatisfy(\.isWhitespace) && text.contains(where: { $0 == "\n" || $0 == "\r" }) { continue }
                value += text
            case .node(let child): value += render(child, words: &words, allowWords: allowWords)
            }
        }
        if allowWords, node.name == "span", !timedChildren, let start, let end,
           start.isFinite, end.isFinite, start >= 0, end >= start,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            words.append(.init(text: value, start: start, end: end))
        }
        return value
    }

    static func time(_ value: String) -> Double? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.contains(":") {
            let parts = text.split(separator: ":", omittingEmptySubsequences: false)
            guard (2...3).contains(parts.count) else { return nil }
            var result = 0.0
            for part in parts { guard let number = Double(part), number.isFinite, number >= 0 else { return nil }; result = result * 60 + number }
            return result.isFinite ? result : nil
        }
        for (suffix, multiplier) in [("ms", 0.001), ("h", 3600.0), ("m", 60.0), ("s", 1.0)] where text.hasSuffix(suffix) {
            guard let number = Double(text.dropLast(suffix.count)), number.isFinite, number >= 0 else { return nil }
            let result = number * multiplier
            return result.isFinite ? result : nil
        }
        guard let number = Double(text), number.isFinite, number >= 0 else { return nil }
        return number
    }

    enum ParseError: LocalizedError {
        case invalid, empty
        var errorDescription: String? { self == .invalid ? "云端歌词格式暂不支持或已损坏。" : "这首歌没有可读取的歌词。" }
    }
    private final class Node {
        enum Piece { case text(String), node(Node) }
        let name: String
        let attributes: [String: String]
        var pieces: [Piece] = []
        init(name: String, attributes: [String: String]) { self.name = name; self.attributes = attributes }
        func attribute(_ key: String) -> String? { attributes[key] ?? attributes.first { $0.key.split(separator: ":").last.map(String.init) == key }?.value }
        var text: String { pieces.map { switch $0 { case .text(let text): text; case .node(let node): node.text } }.joined() }
        func descendants(_ name: String) -> [Node] {
            pieces.flatMap { piece -> [Node] in
                guard case .node(let child) = piece else { return [] }
                return (child.name == name ? [child] : []) + child.descendants(name)
            }
        }
    }
    private final class Builder: NSObject, XMLParserDelegate {
        var root: Node?
        var stack: [Node] = []
        var count = 0
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
            count += 1
            guard count <= 50_000, stack.count < 64 else { parser.abortParsing(); return }
            let node = Node(name: String(elementName.split(separator: ":").last ?? Substring(elementName)), attributes: attributes)
            if let parent = stack.last { parent.pieces.append(.node(node)) } else { root = node }
            stack.append(node)
        }
        func parser(_ parser: XMLParser, foundCharacters string: String) { stack.last?.pieces.append(.text(string)) }
        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            if let text = String(data: CDATABlock, encoding: .utf8) { stack.last?.pieces.append(.text(text)) }
        }
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) { if !stack.isEmpty { stack.removeLast() } }
    }
}
