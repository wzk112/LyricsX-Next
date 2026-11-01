import AppKit
import CoreText
import LyricsXCore

/// A visual segment of a real word cue. A cue can cross native font or bidi
/// runs, so its reveal is shared across their combined width.
struct TouchBarTimedSpan: Equatable {
    let cue: WordCue
    let x: Double
    let width: Double
    let rightToLeft: Bool
    let cueOffset: Double
    let cueWidth: Double
}

struct TouchBarLyricFrame: Equatable {
    struct Highlight: Equatable {
        let x: Double
        let width: Double
    }
    let translation: Double
    let highlights: [Highlight]
    private(set) var hasPendingScroll = false

    init(spans: [TouchBarTimedSpan], contentWidth: Double, viewportWidth: Double,
         time: Double, lineStart: Double?, untimedTailEndX: Double? = nil,
         plainRightToLeft: Bool = false) {
        let viewport = max(0, viewportWidth)
        let overflow = max(0, contentWidth - viewport)
        let clock = time.isFinite ? time : 0
        highlights = spans.compactMap { span in
            let progress = LyricEmphasisFrame.reveal(progress: span.cue.progress(at: clock),
                offset: span.cueOffset, width: span.width, total: span.cueWidth)
            let width = span.width * progress
            guard width > 0 else { return nil }
            return .init(x: span.x + (span.rightToLeft ? span.width - width : 0), width: width)
        }
        guard overflow > 0 else {
            translation = max(0, (viewport - contentWidth) / 2)
            return
        }
        if let first = spans.first {
            // The first upcoming / active cue determines the reading position.
            // Between cues keep the previous word in view. Absolute cue time
            // makes pausing and backward seeks deterministic.
            let cue = spans.last(where: { $0.cue.start <= clock })?.cue ?? first.cue
            let group = spans.filter { $0.cue == cue }
            let progress = cue.progress(at: clock)
            let travelled = progress * (group.first?.cueWidth ?? 0)
            let segment = group.first(where: { travelled <= $0.cueOffset + $0.width }) ?? group.last ?? first
            let within = min(segment.width, max(0, travelled - segment.cueOffset))
            let focus = segment.x + (segment.rightToLeft ? segment.width - within : within)
            let cueTranslation = -min(overflow, max(0, focus - viewport * 0.45))
            if let tailEnd = untimedTailEndX, tailEnd.isFinite,
               let lastCueEnd = spans.map(\.cue.end).max(), clock >= lastCueEnd {
                // Partial word tags must not strand an untagged suffix offscreen.
                // Scroll only the viewport after the real tags end; its text
                // remains white and receives no invented word timestamps.
                let target = -min(overflow, max(0, tailEnd - viewport * 0.45))
                let difference = target - cueTranslation
                let travel = max(0, clock - lastCueEnd - 1.5) * 28
                translation = cueTranslation + (difference < 0 ? -1 : 1) * min(abs(difference), travel)
                hasPendingScroll = abs(translation - target) > 0.01
            } else {
                translation = cueTranslation
            }
        } else if let lineStart, lineStart.isFinite {
            // Line-synced text can scroll without inventing word timestamps or
            // highlighting. Its movement follows playback, including pause/seek.
            let travel = min(overflow, max(0, clock - lineStart - 1.5) * 28)
            translation = plainRightToLeft ? -overflow + travel : -travel
            hasPendingScroll = travel < overflow - 0.01
        } else {
            translation = 0
        }
    }
}

/// Native, SDR-only rendering for the black 30-point Touch Bar surface. The
/// controller owns visibility and refresh scheduling; this view owns no timer.
@MainActor final class TouchBarLyricsView: NSView {
    private(set) var renderedText = ""
    private(set) var timedSpans: [TouchBarTimedSpan] = []
    private(set) var shapingCount = 0
    private(set) var contentWidth = 0.0
    private var sourceLine: LyricLine?
    private var shapedLine: CTLine?
    private var ascent: CGFloat = 0
    private var descent: CGFloat = 0
    private var time = 0.0
    private var playing = false
    private let horizontalInset = 5.0
    private var untimedTailEndX: Double?
    private var plainRightToLeft = false

    var requiresAnimation: Bool {
        guard playing else { return false }
        if !timedSpans.isEmpty {
            // Keep a live clock before/between cues, but stop frame updates once
            // the last real word has finished (including a song's static tail).
            return timedSpans.contains { time < $0.cue.end } || currentFrame().hasPendingScroll
        }
        guard sourceLine != nil else { return false }
        return currentFrame().hasPendingScroll
    }

    override var intrinsicContentSize: NSSize { .init(width: 360, height: 30) }
    override var isOpaque: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    required init?(coder: NSCoder) { nil }

    func update(line: LyricLine?, text: String, position: TimeInterval,
                effectiveOffsetMilliseconds: Int, isPlaying: Bool) {
        if sourceLine != line || renderedText != text {
            sourceLine = line
            renderedText = text
            rebuildText()
            setAccessibilityLabel(text)
        }
        let clock = position + Double(effectiveOffsetMilliseconds) / 1000
        time = clock.isFinite ? clock : 0
        playing = isPlaying
        needsDisplay = true
    }

    func currentFrame(viewportWidth: Double? = nil) -> TouchBarLyricFrame {
        TouchBarLyricFrame(spans: timedSpans, contentWidth: contentWidth,
            viewportWidth: viewportWidth ?? max(0, bounds.width - horizontalInset * 2),
            time: time, lineStart: sourceLine?.time, untimedTailEndX: untimedTailEndX,
            plainRightToLeft: plainRightToLeft)
    }

    private func rebuildText() {
        shapingCount += 1
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byClipping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .paragraphStyle: paragraph,
            NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true,
        ]
        let textLine = CTLineCreateWithAttributedString(NSAttributedString(string: renderedText, attributes: attributes))
        shapedLine = textLine
        contentWidth = max(0, CTLineGetTypographicBounds(textLine, &ascent, &descent, nil))
        timedSpans = []
        untimedTailEndX = nil
        plainRightToLeft = visualSegments(in: textLine,
            range: NSRange(location: 0, length: renderedText.utf16.count)).first?.rtl ?? false
        guard let sourceLine else { return }
        var location = 0
        var lastTimedEnd: Int?
        for fragment in TimedLyricFragment.make(line: sourceLine, text: renderedText) {
            let length = fragment.text.utf16.count
            defer { location += length }
            guard let cue = fragment.cue else { continue }
            let segments = visualSegments(in: textLine, range: NSRange(location: location, length: length))
                .filter { $0.x.isFinite && $0.width.isFinite && $0.width > 0 }
            if !segments.isEmpty { lastTimedEnd = location + length }
            let total = segments.reduce(0) { $0 + $1.width }
            var offset = 0.0
            for segment in segments {
                timedSpans.append(.init(cue: cue, x: segment.x, width: segment.width,
                    rightToLeft: segment.rtl, cueOffset: offset, cueWidth: total))
                offset += segment.width
            }
        }
        if let lastTimedEnd, lastTimedEnd < renderedText.utf16.count {
            let range = NSRange(location: lastTimedEnd, length: renderedText.utf16.count - lastTimedEnd)
            let tailText = (renderedText as NSString).substring(with: range)
            if !tailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let tail = visualSegments(in: textLine, range: range).last,
               tail.x.isFinite, tail.width.isFinite {
                untimedTailEndX = tail.x + (tail.rtl ? 0 : tail.width)
            }
        }
    }

    private func visualSegments(in line: CTLine, range: NSRange) -> [(x: Double, width: Double, rtl: Bool)] {
        var segments: [(index: CFIndex, x: Double, width: Double, rtl: Bool)] = []
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            var indices = [CFIndex](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            var advances = [CGSize](repeating: .zero, count: count)
            CTRunGetStringIndices(run, CFRange(location: 0, length: 0), &indices)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            CTRunGetAdvances(run, CFRange(location: 0, length: 0), &advances)
            let matching = (0..<count).filter { NSLocationInRange(indices[$0], range) }
            guard !matching.isEmpty else { continue }
            let left = matching.map { Double(positions[$0].x) }.min() ?? 0
            let right = matching.map { Double(positions[$0].x + advances[$0].width) }.max() ?? left
            let logicalStart = matching.map { indices[$0] }.min() ?? range.location
            segments.append((logicalStart, left, max(0, right - left), CTRunGetStatus(run).contains(.rightToLeft)))
        }
        // Runs are returned in visual order. Reveal should follow the cue's
        // logical string order even when a lyric mixes Arabic and Latin text.
        return segments.sorted { $0.index < $1.index }.map { ($0.x, $0.width, $0.rtl) }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setFillColor(NSColor.black.cgColor)
        context.fill(bounds)
        guard let shapedLine, bounds.width > horizontalInset * 2 else { return }
        let frame = currentFrame()
        let originX = horizontalInset + frame.translation
        let baseline = (bounds.height - ascent - descent) / 2 + descent
        context.saveGState()
        context.clip(to: bounds.insetBy(dx: horizontalInset, dy: 0))
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: originX, y: baseline)
        context.setFillColor(NSColor.white.cgColor)
        CTLineDraw(shapedLine, context)
        if !frame.highlights.isEmpty {
            context.saveGState()
            let clips = frame.highlights.map {
                CGRect(x: originX + $0.x, y: 0, width: $0.width, height: bounds.height)
            }
            context.clip(to: clips)
            context.textPosition = CGPoint(x: originX, y: baseline)
            context.setFillColor(NSColor(srgbRed: 0.2, green: 1, blue: 0.75, alpha: 1).cgColor)
            CTLineDraw(shapedLine, context)
            context.restoreGState()
        }
        context.restoreGState()
    }
}
