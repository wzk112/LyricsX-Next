import SwiftUI
import LyricsXCore

struct LyricEmphasisOptions: Equatable, Sendable {
    var lift = true
    var glow = true
    var hdr = false
    var hdrBrightness = 1.6
    var reduced = false
    var usesHDR: Bool { glow && hdr && !reduced }
}

/// All motion derives from the real cue clock. Seeking, pausing and changing
/// lines cannot leave a detached animation or glow running behind the lyrics.
struct LyricEmphasisFrame: Equatable {
    let progress: Double
    let scale: Double
    let lift: Double
    let glow: Double

    init(cue: WordCue, time: Double, options: LyricEmphasisOptions) {
        progress = cue.progress(at: time)
        let duration = cue.end - cue.start
        let singing = time.isFinite && time >= cue.start && time < cue.end && duration > 0
        let swell = singing ? Self.smooth(progress / 0.42) * (1 - Self.smooth((progress - 0.76) / 0.24)) : 0
        // A held note anywhere in the line earns emphasis; there is no
        // special-case glow attached to the last letter or the last word.
        let sustained = Self.smooth((duration - 0.45) / 1.15)
        let emphasis = sustained * swell
        let smallLift = singing ? sin(.pi * progress) * 0.012 : 0
        scale = options.lift && !options.reduced
            ? 0.985 + 0.015 * Self.smooth(progress / 0.22) + smallLift + 0.055 * emphasis : 1
        lift = options.lift && !options.reduced ? 0.035 * emphasis + smallLift * 0.5 : 0
        glow = options.glow && !options.reduced ? (options.usesHDR ? 0.8 : 1.0) * emphasis : 0
    }

    static func smooth(_ value: Double) -> Double {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }

    /// A cue may wrap onto several visual runs; distribute its reveal over
    /// their combined advance instead of restarting it at each wrapped line.
    static func reveal(progress: Double, offset: Double, width: Double, total: Double) -> Double {
        guard width > 0, total > 0 else { return progress }
        return min(1, max(0, (progress * total - offset) / width))
    }
}

struct TimedLyricFragment: Equatable {
    let text: String
    let cue: WordCue?

    static func make(line: LyricLine, text: String) -> [Self] {
        // Keep the original script and shaping. Text conversion without a
        // reliable range mapping falls back to legible, untimed text.
        guard text == line.text else { return [.init(text: text, cue: nil)] }
        var fragments: [Self] = []
        var cursor = text.startIndex
        for (range, cue) in line.wordTimingRanges {
            if cursor < range.lowerBound { fragments.append(.init(text: String(text[cursor..<range.lowerBound]), cue: nil)) }
            fragments.append(.init(text: String(text[range]), cue: cue))
            cursor = range.upperBound
        }
        if cursor < text.endIndex { fragments.append(.init(text: String(text[cursor...]), cue: nil)) }
        return fragments
    }
}

private struct TimedWordAttribute: TextAttribute {
    let id: Int
    let cue: WordCue
}

private struct ArrivalAttribute: TextAttribute { let fresh: Bool }
private struct HiddenLyricAttribute: TextAttribute {}

/// This subtree is independent of playback time, so timestamps don't rebuild
/// the string or its custom attributes on each tick. Native Text keeps kerning,
/// ligatures, emoji, bidi layout, selection and wrapping together.
private struct TimedLyricLabel: View, Equatable {
    let line: LyricLine
    let text: String
    var arrival: LyricLinePresentation?
    var ink: Color?
    var body: some View {
        var cursor = 0
        var result = Text("")
        for (id, fragment) in TimedLyricFragment.make(line: line, text: text).enumerated() {
            let count = fragment.text.count
            let stable = min(count, max(0, (arrival?.stablePrefixCount ?? 0) - cursor))
            let portions = [(String(fragment.text.prefix(stable)), false), (String(fragment.text.dropFirst(stable)), true)]
            for (part, fresh) in portions where !part.isEmpty {
                var value = Text(verbatim: part)
                if let cue = fragment.cue { value = value.customAttribute(TimedWordAttribute(id: id, cue: cue)) }
                if arrival != nil { value = value.customAttribute(ArrivalAttribute(fresh: fresh)) }
                result = Text("\(result)\(value)")
            }
            cursor += count
        }
        if let tail = arrival?.layoutTail, !tail.isEmpty {
            result = Text("\(result)\(Text(verbatim: tail).customAttribute(HiddenLyricAttribute()))")
        }
        if let ink { return result.foregroundColor(ink).accessibilityLabel(text) }
        return result.accessibilityLabel(text)
    }
}

struct WordHighlight: View {
    let line: LyricLine
    let time: Double
    let active: Bool
    let text: String
    var effects = LyricEmphasisOptions()
    var arrival: LyricLinePresentation?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.multilineTextAlignment) private var alignment
    @Environment(\.layoutDirection) private var direction
    @Environment(\.lyricHDRSupported) private var hdrSupported
    @Environment(\.lyricWordColors) private var wordColors
    @Environment(\.lyricHDRHeadroom) private var hdrHeadroom

    var body: some View {
        var options = effects
        options.reduced = options.reduced || reduceMotion
        options.hdr = options.hdr && hdrSupported && hdrHeadroom.isFinite && hdrHeadroom > 1
        if options.hdr { options.hdrBrightness = min(options.hdrBrightness, hdrHeadroom) }
        return LyricLayoutBoundary(text: text + (arrival?.layoutTail ?? "")) {
            TimedLyricLabel(line: line, text: text, arrival: arrival, ink: active && wordColors != nil ? .white : nil).equatable()
                .textRenderer(HeldNoteRenderer(time: time, options: options, arrival: arrival,
                    alignment: alignment, direction: direction, active: active, wordColors: wordColors))
                .allowedDynamicRange(options.usesHDR ? .high : .standard)
        }
    }
}

struct HeldNoteRenderer: TextRenderer {
    let time: Double
    let options: LyricEmphasisOptions
    var arrival: LyricLinePresentation?
    var alignment: TextAlignment = .leading
    var direction: LayoutDirection = .leftToRight
    var active = true
    var wordColors: LyricWordColors?
    // Extra drawing space doesn't affect measured text size or window position.
    var displayPadding: EdgeInsets { .init(top: 12, leading: 12, bottom: 12, trailing: 12) }
    static func hdrWhite(brightness: Double) -> Color {
        let value = brightness.isFinite ? min(4, max(1, brightness)) : 1.6
        return Color(.sRGBLinear, white: value, opacity: 1).headroom(value)
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        // TextRenderer aligns paragraphs inside the extra horizontal drawing
        // space. Remove only that alignment's share of the padding: leading
        // text has none, centered text half, trailing text the full width.
        let fraction = alignment == .center ? 0.5 : alignment == .trailing ? 1.0 : 0.0
        let physicalFraction = direction == .rightToLeft ? 1 - fraction : fraction
        context.translateBy(x: -(displayPadding.leading + displayPadding.trailing) * physicalFraction, y: 0)
        // Inactive lines reuse the same shaped text and backing surface. No
        // cue grouping, masks or per-frame clock is needed for these rows.
        guard active else {
            for line in layout { context.draw(line) }
            return
        }
        var groups: [Int: [Text.Layout.Run]] = [:]
        var order: [Int] = []
        for line in layout {
            for run in line {
                if run[HiddenLyricAttribute.self] != nil { continue }
                if let attribute = run[TimedWordAttribute.self] {
                    if groups[attribute.id] == nil { order.append(attribute.id) }
                    groups[attribute.id, default: []].append(run)
                }
                else {
                    var plain = arrivalContext(context, run: run)
                    if let wordColors { plain.addFilter(.colorMultiply(wordColors.plain)) }
                    plain.draw(run)
                }
            }
        }
        for id in order {
            guard let runs = groups[id], let attribute = runs.first?[TimedWordAttribute.self] else { continue }
            let ordered = runs.count == 1 ? runs : runs.sorted {
                guard let a = $0.characterIndices.min(), let b = $1.characterIndices.min() else { return false }
                return a < b
            }
            let total = ordered.reduce(0.0) { $0 + $1.typographicBounds.rect.width }
            let frame = LyricEmphasisFrame(cue: attribute.cue, time: time, options: options)
            var offset = 0.0
            for run in ordered {
                let bounds = run.typographicBounds.rect
                let progress = LyricEmphasisFrame.reveal(progress: frame.progress, offset: offset, width: bounds.width, total: total)
                offset += bounds.width
                var drawing = arrivalContext(context, run: run)
                drawing.translateBy(x: bounds.midX, y: bounds.maxY - bounds.height * frame.lift)
                drawing.scaleBy(x: frame.scale, y: frame.scale)
                drawing.translateBy(x: -bounds.midX, y: -bounds.maxY)
                if progress >= 1 {
                    var sung = drawing
                    if let wordColors { sung.addFilter(.colorMultiply(wordColors.sung)) }
                    sung.draw(run)
                } else {
                    var dim = drawing
                    if let wordColors { dim.addFilter(.colorMultiply(wordColors.unsung)) }
                    else { dim.opacity *= 0.46 }
                    dim.draw(run)
                    if progress > 0 {
                        var sung = drawing
                        clipReveal(&sung, run: run, progress: progress)
                        if let wordColors { sung.addFilter(.colorMultiply(wordColors.sung)) }
                        sung.draw(run)
                    }
                }
                if frame.glow > 0.005, progress > 0 {
                    let white = options.usesHDR ? Self.hdrWhite(brightness: options.hdrBrightness) : .white
                    var bloom = drawing
                    bloom.opacity *= frame.glow
                    // SDR cannot exceed white. A denser, slightly wider halo
                    // makes the held cue visible without an extra render pass.
                    bloom.addFilter(.shadow(color: white.opacity(options.usesHDR ? 0.85 : 1),
                        radius: min(9, bounds.height * (options.usesHDR ? 0.19 : 0.24))))
                    bloom.drawLayer { ink in
                        clipReveal(&ink, run: run, progress: progress)
                        if let wordColors { ink.addFilter(.colorMultiply(wordColors.sung)) }
                        if options.usesHDR { ink.addFilter(.colorMultiply(white)) }
                        ink.draw(run)
                    }
                }
            }
        }
    }

    private func arrivalContext(_ context: GraphicsContext, run: Text.Layout.Run) -> GraphicsContext {
        guard !options.reduced, run[ArrivalAttribute.self]?.fresh == true, let arrival else { return context }
        let frame = arrival.frame(at: time)
        var drawing = context
        drawing.translateBy(x: 0, y: frame.offset)
        drawing.opacity *= frame.opacity
        if frame.blur > 0.01 { drawing.addFilter(.blur(radius: frame.blur)) }
        return drawing
    }

    private func clipReveal(_ context: inout GraphicsContext, run: Text.Layout.Run, progress: Double) {
        guard progress < 1 else { return }
        let bounds = run.typographicBounds.rect
        let rtl = run.layoutDirection == .rightToLeft
        let start = CGPoint(x: rtl ? bounds.maxX : bounds.minX, y: bounds.midY)
        let end = CGPoint(x: rtl ? bounds.minX : bounds.maxX, y: bounds.midY)
        let feather = min(0.16, 3 / max(1, bounds.width))
        context.clipToLayer { mask in
            mask.fill(Path(bounds.insetBy(dx: -2, dy: -3)), with: .linearGradient(
                Gradient(stops: [.init(color: .white, location: max(0, progress - feather)),
                                 .init(color: .clear, location: min(1, progress + feather))]),
                startPoint: start, endPoint: end))
        }
    }
}
