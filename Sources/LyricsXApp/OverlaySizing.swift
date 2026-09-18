import AppKit
import Observation
import LyricsXCore

@Observable @MainActor
final class OverlayViewport {
    var width: Double
    var rendering = true
    @ObservationIgnored var contentSizeChanged: (@MainActor (NSSize) -> Void)?
    init(width: Double) { self.width = width }
}

/// Measure full lines once, never individual reveal frames. The rendering canvas
/// keeps its fixed width while only the native glass/window height animates.
@MainActor enum OverlayTextMeasure {
    private struct LineKey: Hashable { let document: UUID; let index: Int; let conversion: String; let text: String }
    private static var lineCache: [LineKey: String] = [:]
    static func invalidateLayoutText(for document: UUID) {
        // A replacement can change a future incremental suffix while keeping
        // both the document ID and the currently visible text.
        lineCache = lineCache.filter { $0.key.document != document }
    }
    static func layoutText(document: LyricsDocument, index: Int, preferences: Preferences) -> String {
        guard document.lines.indices.contains(index) else { return "" }
        let key = LineKey(document: document.id, index: index, conversion: preferences.conversion, text: document.lines[index].text)
        if let value = lineCache[key] { return value }
        let text = preferences.text(document.lines[index].text)
        let value = text + (LyricLinePresentation.make(lines: document.lines, index: index, transform: preferences.text)?.layoutTail ?? "")
        if lineCache.count >= 256 { lineCache.removeAll(keepingCapacity: true) }
        lineCache[key] = value
        return value
    }
    struct TextLayout {
        let fontSize: Double
        let height: Double
        let rows: Int
    }
    private struct LayoutKey: Hashable {
        let text: String
        let font: Double
        let width: Double
        let tracking: Double
        let weight: Double
        let minimumScale: Double
        let fontName: String
    }
    private static var layoutCache: [LayoutKey: TextLayout] = [:]

    /// Choose wrapping and (only when needed) a two-row font reduction once.
    /// SwiftUI then draws at this explicit size, instead of independently
    /// shrinking a measured two-row string back into one bottom-aligned row.
    static func layout(_ text: String, font: Double, canvasWidth: Double, tracking: Double = -0.4,
                       weight: NSFont.Weight = .semibold, minimumScale: Double = 0.6,
                       typography: LyricTypography = .init()) -> TextLayout {
        // Use the same content width as SwiftUI. A conservative inset here
        // reserves a second row even when the rendered line fits on one.
        let available = max(1, canvasWidth)
        let key = LayoutKey(text: text, font: font, width: available, tracking: tracking, weight: weight.rawValue, minimumScale: minimumScale, fontName: typography.fontName)
        if let value = layoutCache[key] { return value }
        var measuredHeight = 0.0
        func rows(at size: Double) -> Int {
            let storage = NSTextStorage(string: text.isEmpty ? " " : text, attributes: [
                .font: typography.nativeFont(size: size, weight: weight), .kern: tracking
            ])
            let manager = NSLayoutManager()
            let container = NSTextContainer(size: .init(width: available, height: .greatestFiniteMagnitude))
            container.lineFragmentPadding = 0
            storage.addLayoutManager(manager); manager.addTextContainer(container)
            manager.ensureLayout(for: container)
            measuredHeight = manager.usedRect(for: container).height
            var count = 0
            manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: container)) { _, _, _, _, stop in
                count += 1
                if count > 2 { stop.pointee = true }
            }
            return max(1, count)
        }
        var size = font
        var count = rows(at: size)
        if count > 2 {
            var low = font * minimumScale, high = font
            for _ in 0..<6 {
                let mid = (low + high) / 2
                if rows(at: mid) > 2 { high = mid } else { low = mid }
            }
            size = low; count = rows(at: size)
        }
        let nominalHeight = typography.lineHeight(size: size, weight: weight) * Double(min(2, count))
        // NSTextStorage also measures fallback glyphs (e.g. Chinese text in a
        // Latin font). The selected font's ascender alone cannot contain them.
        let height = typography.fontName.isEmpty || count > 2 ? nominalHeight : max(nominalHeight, ceil(measuredHeight))
        let value = TextLayout(fontSize: size, height: height, rows: min(2, count))
        if layoutCache.count >= 256 { layoutCache.removeAll(keepingCapacity: true) }
        layoutCache[key] = value
        return value
    }
    static func primaryLayout(document: LyricsDocument, index: Int, preferences: Preferences, canvasWidth: Double) -> TextLayout {
        layout(layoutText(document: document, index: index, preferences: preferences), font: preferences.fontSize, canvasWidth: canvasWidth, typography: preferences.typography)
    }
    static func primaryHeight(document: LyricsDocument, index: Int, preferences: Preferences, canvasWidth: Double) -> Double {
        primaryLayout(document: document, index: index, preferences: preferences, canvasWidth: canvasWidth).height
    }
    static func translationHeight(_ text: String?, font: Double, canvasWidth: Double, typography: LyricTypography = .init()) -> Double {
        guard let text else { return 0 }
        return layout(text, font: font, canvasWidth: canvasWidth, tracking: 0, weight: .medium, minimumScale: 0.75, typography: typography).height
    }
    static func desiredSize(document: LyricsDocument, index: Int, preferences p: Preferences, maximumWidth: Double) -> NSSize {
        .init(width: maximumWidth, height: height(document: document, index: index, preferences: p, maximumWidth: maximumWidth))
    }
    static func secondary(document: LyricsDocument, index: Int, preferences p: Preferences) -> OverlaySecondaryMode.Content {
        guard document.lines.indices.contains(index) else { return .init() }
        let line = document.lines[index]
        return p.overlaySecondaryMode.content(
            translation: p.showTranslation && line.hasTranslation ? line.translation.map(p.text) : nil,
            next: document.lines.indices.contains(index + 1) ? p.text(document.lines[index + 1].text) : nil)
    }
    static func height(document: LyricsDocument, index: Int, preferences p: Preferences, maximumWidth: Double) -> Double {
        let primary = primaryHeight(document: document, index: index, preferences: p, canvasWidth: maximumWidth - 60)
        let next = primaryHeight(document: document, index: index + 1, preferences: p, canvasWidth: maximumWidth - 60) * p.nextLineFontSize / p.fontSize
        let auxiliary = secondary(document: document, index: index, preferences: p)
        return OverlayLayoutMetrics.chromeHeight + primary + auxiliary.height(
            translationHeight: translationHeight(auxiliary.translation, font: p.translationFontSize, canvasWidth: maximumWidth - 60, typography: p.typography), nextHeight: next,
            primarySpacing: p.overlayPrimarySpacing, secondarySpacing: p.overlaySecondarySpacing)
    }

}

struct OverlayAnchor {
    var topCenter: NSPoint
    func frame(size: NSSize, in screen: NSRect) -> NSRect {
        let width = min(size.width, screen.width)
        let height = min(size.height, screen.height)
        return .init(x: max(screen.minX, min(topCenter.x - width / 2, screen.maxX - width)),
                     y: max(screen.minY, min(topCenter.y - height, screen.maxY - height)),
                     width: width, height: height)
    }
}
