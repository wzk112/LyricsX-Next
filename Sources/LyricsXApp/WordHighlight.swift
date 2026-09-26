import SwiftUI
import LyricsXCore

struct LyricEmphasisOptions: Equatable, Sendable {
    var lift = true
    var glow = true
    var hdr = false
    var hdrBrightness = 1.6
    var reduced = false
    var compactHalo = false
    var usesHDR: Bool { glow && hdr && !reduced }
}

/// All motion derives from the real cue clock. Seeking, pausing and changing
/// lines cannot leave a detached animation or glow running behind the lyrics.
struct LyricEmphasisFrame: Equatable {
    let progress: Double
    let scale: Double
    let lift: Double
    let glow: Double

    init(cue: WordCue, time: Double, options: LyricEmphasisOptions, characterPhase: Double = 0) {
        progress = cue.progress(at: time)
        let duration = cue.end - cue.start
        let singing = time.isFinite && time >= cue.start && time < cue.end && duration > 0
        // Stagger only the visual envelope. The karaoke reveal continues to
        // use the original cue timing, including after a pause or direct seek.
        let delay = 0.22 * min(1, max(0, characterPhase))
        let motion = min(1, max(0, (progress - delay) / (1 - delay)))
        let swell = singing ? Self.smoother(motion / 0.42) * (1 - Self.smoother((motion - 0.70) / 0.30)) : 0
        // A held note anywhere in the line earns emphasis; there is no
        // special-case glow attached to the last letter or the last word.
        let sustained = Self.smooth((duration - 0.45) / 1.15)
        let emphasis = sustained * swell
        let smallLift = singing ? pow(sin(.pi * motion), 2) * 0.012 : 0
        scale = options.lift && !options.reduced
            ? 0.985 + 0.015 * Self.smoother(motion / 0.22) + smallLift + 0.055 * emphasis : 1
        lift = options.lift && !options.reduced ? 0.035 * emphasis + smallLift * 0.5 : 0
        // EDR adds brightness; it must not weaken the ordinary halo when
        // macOS has little extra headroom and tone-maps the highlight down.
        glow = options.glow && !options.reduced ? emphasis : 0
    }

    // Zero velocity and acceleration at both ends avoid a visible kick when
    // a short cue starts/stops; evaluating absolute time is frame-rate independent.
    static func smoother(_ value: Double) -> Double {
        let t = min(1, max(0, value))
        return t * t * t * (t * (t * 6 - 15) + 10)
    }

    static func separatesCharacters(in cue: WordCue, time: Double, options: LyricEmphasisOptions) -> Bool {
        guard !options.reduced, options.lift || options.glow,
              cue.end - cue.start > 0.45, time >= cue.start, time < cue.end else { return false }
        // Connected scripts stay shaped as a unit. Latin, CJK and Hangul can
        // move by native glyph cluster without separating their combining marks.
        return cue.text.unicodeScalars.allSatisfy {
            let c = $0.value
            return c <= 0x052f || (0x2000...0x206f).contains(c) || (0x3000...0x9fff).contains(c)
                || (0xac00...0xd7af).contains(c) || (0xff00...0xffef).contains(c)
        }
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
        if text != line.text {
            // Only map verified script conversions, never arbitrary replacement
            // lyrics. Map grapheme boundaries, not UTF-8/UTF-16 offsets.
            let converted = ["Simplified-Traditional", "Traditional-Simplified"].contains {
                line.text.applyingTransform(StringTransform($0), reverse: false) == text
            }
            guard converted, line.text.count == text.count else { return [.init(text: text, cue: nil)] }
            let original = make(line: line, text: line.text)
            var cursor = text.startIndex
            return original.map { fragment in
                let end = text.index(cursor, offsetBy: fragment.text.count)
                defer { cursor = end }
                let part = String(text[cursor..<end])
                let cue = fragment.cue.map { WordCue(text: part, start: $0.start, end: $0.end) }
                return .init(text: part, cue: cue)
            }
        }
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
struct TimedLyricLabel: View, Equatable {
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
    @Environment(\.lyricHDRRevision) private var hdrRevision

    var body: some View {
        var options = effects
        options.reduced = options.reduced || reduceMotion
        options.hdr = options.hdr && hdrSupported && hdrHeadroom.isFinite && hdrHeadroom > 1
        if options.hdr { options.hdrBrightness = min(options.hdrBrightness, hdrHeadroom) }
        return LyricLayoutBoundary(text: text + (arrival?.layoutTail ?? "")) {
            TimedLyricLabel(line: line, text: text, arrival: arrival, ink: active && wordColors != nil ? .white : nil).equatable()
                .textRenderer(HeldNoteRenderer(time: time, options: options, arrival: arrival,
                    alignment: alignment, direction: direction, active: active, wordColors: wordColors,
                    displayRevision: options.usesHDR ? hdrRevision : 0))
                .allowedDynamicRange(options.usesHDR ? .high : .standard)
        }
        .preference(key: LyricHDRContentHeadroomKey.self,
                    value: active && line.hasWordTiming && options.usesHDR ? options.hdrBrightness : 1)
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
    // Invalidates the native drawing after focus/wake without changing cue time.
    var displayRevision: UInt64 = 0
    // Extra drawing space doesn't affect measured text size or window position.
    var displayPadding: EdgeInsets { .init(top: 12, leading: 12, bottom: 12, trailing: 12) }
    static func hdrWhite(brightness: Double) -> Color {
        let value = HDRBrightness.clamped(brightness)
        return Color(.sRGBLinear, white: value, opacity: 1).headroom(value)
    }

    static func hdrInk(_ color: Color, brightness: Double) -> Color {
        let value = HDRBrightness.clamped(brightness)
        let ink = color.resolveHDR(in: EnvironmentValues())
        return Color(.sRGBLinear, red: Double(ink.linearRed) * value,
                     green: Double(ink.linearGreen) * value, blue: Double(ink.linearBlue) * value,
                     opacity: Double(ink.opacity)).headroom(value)
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        // Keep fractional glyph positions during scrolling, lift and scaling.
        // Native text quantization is useful for still text but makes small
        // animation steps snap. Use the same drawing option at rest so cue
        // activation/deactivation never switches rasterization policy.
        // TextRenderer aligns paragraphs inside the extra horizontal drawing
        // space. Remove only that alignment's share of the padding: leading
        // text has none, centered text half, trailing text the full width.
        let fraction = alignment == .center ? 0.5 : alignment == .trailing ? 1.0 : 0.0
        let physicalFraction = direction == .rightToLeft ? 1 - fraction : fraction
        context.translateBy(x: -(displayPadding.leading + displayPadding.trailing) * physicalFraction, y: 0)
        // Inactive lines reuse the same shaped text and backing surface. No
        // cue grouping, masks or per-frame clock is needed for these rows.
        guard active else {
            for line in layout { context.draw(line, options: .disablesSubpixelQuantization) }
            return
        }
        // Resolve once per text draw, not per character. Chaining an SDR
        // color-multiply and an HDR multiply can compress native window output
        // even though ImageRenderer preserves both filters' extended pixels.
        let bloomTint = wordColors.map {
            options.usesHDR && $0.glow == nil
                ? Self.hdrInk($0.sung, brightness: options.hdrBrightness) : $0.sung
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
                    plain.draw(run, options: .disablesSubpixelQuantization)
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
            let separate = LyricEmphasisFrame.separatesCharacters(in: attribute.cue, time: time, options: options)
            var offset = 0.0
            for run in ordered {
                let bounds = run.typographicBounds.rect
                let slices = separate ? Self.clusters(in: run) : [run[run.startIndex..<run.endIndex]]
                let units = slices.map { slice -> (Text.Layout.RunSlice, CGRect, LyricEmphasisFrame, Double) in
                    let box = slice.typographicBounds.rect
                    let advance = run.layoutDirection == .rightToLeft ? bounds.maxX - box.maxX : box.minX - bounds.minX
                    let phase = total > 0 ? (offset + max(0, advance)) / total : 0
                    let frame = LyricEmphasisFrame(cue: attribute.cue, time: time, options: options,
                                                  characterPhase: separate ? phase : 0)
                    let progress = LyricEmphasisFrame.reveal(progress: frame.progress,
                        offset: offset + max(0, advance), width: box.width, total: total)
                    return (slice, box, frame, progress)
                }
                offset += bounds.width
                let base = arrivalContext(context, run: run)
                // One bloom surface per native run, shared by every moving
                // character. Dark ink is drawn over its halo so an EDR halo
                // cannot wash out the glyph core or its karaoke boundary.
                func drawBloom() {
                    guard units.contains(where: { $0.2.glow > 0.001 && $0.3 > 0 }) else { return }
                    let white = options.usesHDR ? Self.hdrWhite(brightness: options.hdrBrightness) : .white
                    let halo = wordColors?.glow?.color(brightness: options.usesHDR ? options.hdrBrightness : 1) ?? white
                    var bloom = base
                    // A dark core covers the emitter itself. Keep its EDR halo
                    // close enough to the edge to retain a visible peak instead
                    // of averaging all the extra luminance away in a wide blur.
                    let radius = options.usesHDR && wordColors?.glow != nil ? 0.065 : 0.24
                    // Tighten only the broad desktop halo (about 12% versus
                    // the previous compact radius). Keep its opacity/emitter
                    // unchanged so the brightness control retains its meaning.
                    // Dark lettering already has a narrow HDR rim: preserve it.
                    let compactRadius = options.compactHalo ? (wordColors?.glow != nil ? 0.82 : 0.72) : 1
                    bloom.addFilter(.shadow(color: halo.opacity(options.compactHalo ? 0.82 : 1),
                        radius: min(9, bounds.height * radius) * compactRadius))
                    bloom.drawLayer { layer in
                        for (slice, box, frame, progress) in units where frame.glow > 0.001 && progress > 0 {
                            var ink = transformed(layer, bounds: box, referenceBounds: bounds, frame: frame)
                            // Bloom the glyph alpha, never the rectangular
                            // karaoke mask (which would glow as a capsule).
                            ink.opacity *= frame.glow * LyricEmphasisFrame.smoother(progress)
                            if let bloomTint { ink.addFilter(.colorMultiply(bloomTint)) }
                            else if options.usesHDR { ink.addFilter(.colorMultiply(white)) }
                            ink.draw(slice, options: .disablesSubpixelQuantization)
                        }
                    }
                }
                if wordColors?.glow != nil { drawBloom() }
                for (slice, box, frame, progress) in units {
                    let drawing = transformed(base, bounds: box, referenceBounds: bounds, frame: frame)
                    if progress >= 1 {
                        var sung = drawing
                        if let wordColors { sung.addFilter(.colorMultiply(wordColors.sung)) }
                        sung.draw(slice, options: .disablesSubpixelQuantization)
                    } else {
                        var dim = drawing
                        if let wordColors { dim.addFilter(.colorMultiply(wordColors.unsung)) }
                        else { dim.opacity *= 0.46 }
                        dim.draw(slice, options: .disablesSubpixelQuantization)
                        if progress > 0 {
                            var sung = drawing
                            clipReveal(&sung, bounds: box, rtl: run.layoutDirection == .rightToLeft, progress: progress)
                            if let wordColors { sung.addFilter(.colorMultiply(wordColors.sung)) }
                            sung.draw(slice, options: .disablesSubpixelQuantization)
                        }
                    }
                }
                if wordColors?.glow == nil { drawBloom() }
            }
        }
    }

    private func transformed(_ context: GraphicsContext, bounds: CGRect, referenceBounds: CGRect, frame: LyricEmphasisFrame) -> GraphicsContext {
        var drawing = context
        // At the first frame, per-character scaling must match the resting
        // whole-run transform exactly, including its shared horizontal anchor.
        let resting = options.lift && !options.reduced ? 0.985 + 0.015 * LyricEmphasisFrame.smoother(frame.progress / 0.22) : 1
        drawing.translateBy(x: (referenceBounds.midX - bounds.midX) * (1 - resting),
                            y: (referenceBounds.maxY - bounds.maxY) * (1 - resting))
        drawing.translateBy(x: bounds.midX, y: bounds.maxY - bounds.height * frame.lift)
        drawing.scaleBy(x: frame.scale, y: frame.scale)
        drawing.translateBy(x: -bounds.midX, y: -bounds.maxY)
        return drawing
    }

    /// Keep glyphs sharing a character (marks/ligatures) in the same unit. Native
    /// shaping, kerning and layout remain untouched; only drawing transforms vary.
    static func clusters(in run: Text.Layout.Run) -> [Text.Layout.RunSlice] {
        guard !run.isEmpty else { return [] }
        var result: [Text.Layout.RunSlice] = []
        var start = run.startIndex
        var characters = Set(run[start].characterIndices)
        for index in run.indices.dropFirst() {
            let next = Set(run[index].characterIndices)
            if !characters.isDisjoint(with: next) || run[index].typographicBounds.rect.width == 0 {
                characters.formUnion(next)
            } else {
                result.append(run[start..<index]); start = index; characters = next
            }
        }
        result.append(run[start..<run.endIndex])
        return result
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

    private func clipReveal(_ context: inout GraphicsContext, bounds: CGRect, rtl: Bool, progress: Double) {
        guard progress < 1 else { return }
        let start = CGPoint(x: rtl ? bounds.maxX : bounds.minX, y: bounds.midY)
        let end = CGPoint(x: rtl ? bounds.minX : bounds.maxX, y: bounds.midY)
        // Collapse the feather at cue boundaries. A fixed-width feather
        // reveals a visible strip on the first nonzero frame, then leaves an
        // equally abrupt dim strip just before completion.
        let feather = min(0.16, 3 / max(1, bounds.width), progress, 1 - progress)
        context.clipToLayer { mask in
            mask.fill(Path(bounds.insetBy(dx: -2, dy: -3)), with: .linearGradient(
                Gradient(stops: [.init(color: .white, location: max(0, progress - feather)),
                                 .init(color: .clear, location: min(1, progress + feather))]),
                startPoint: start, endPoint: end))
        }
    }
}
