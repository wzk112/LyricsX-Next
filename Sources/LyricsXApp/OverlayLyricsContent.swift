import SwiftUI
import LyricsXCore

enum OverlayLayoutMetrics {
    // Header and insets plus a real bottom gap, including room for text bloom.
    static let chromeHeight = 80.0
    @MainActor static func height(preferences: Preferences) -> Double {
        chromeHeight + ceil(preferences.fontSize * 1.4) * 2 + preferences.overlaySecondaryMode.reservedHeight(
            translationSize: preferences.translationFontSize, nextSize: preferences.nextLineFontSize,
            primarySpacing: preferences.overlayPrimarySpacing, secondarySpacing: preferences.overlaySecondarySpacing)
    }
}

/// The incoming surface starts at the previously displayed preview geometry.
/// A separate, strictly bounded departure handles the old primary row.
struct OverlayMotionFrame: Equatable {
    static let durationLimit = 0.64
    var offset = 0.0
    var scale = 1.0
    var blur = 0.0
    var opacity = 1.0

    static func make(time: Double, plan: LyricLinePresentation?, distance: Double?, nextScale: Double, reduced: Bool) -> Self {
        guard !reduced, let plan, plan.stablePrefixCount == 0 else { return .init() }
        let duration = min(durationLimit, plan.duration)
        let progress = min(1, max(0, (time - plan.start) / duration))
        guard progress < 1 else { return .init() }
        let settle = 0.007 * sin(.pi * max(0, (progress - 0.7) / 0.3))
        let eased = LyricMotion.overlayArrivalCurve.value(at: progress) + settle
        let weight = min(1, duration / 0.3)
        let movingBlur = 1.15 * sin(.pi * progress) * weight
        if let distance {
            return .init(offset: distance * (1 - eased), scale: nextScale + (1 - nextScale) * eased,
                         blur: 0.45 * (1 - min(1, eased)) + movingBlur, opacity: 0.85 + 0.15 * min(1, eased))
        }
        return .init(offset: 10 * (1 - eased) * weight, blur: 2.65 * (1 - min(1, eased)) * weight,
                     opacity: 1 - 0.3 * (1 - min(1, eased)) * weight)
    }

    func auxiliaryOpacity(top: Double, primaryHeight: Double, reduced: Bool) -> Double {
        guard !reduced else { return 1 }
        let primaryBottom = primaryHeight / 2 + offset + primaryHeight * scale / 2
        return LyricEmphasisFrame.smooth((top - primaryBottom) / min(16, max(6, top - primaryHeight)))
    }
}

struct OverlayAuxiliaryFrame: Equatable {
    var opacity = 1.0
    var offset = 0.0
    var blur = 0.0
    static func make(time: Double, plan: LyricLinePresentation?, changed: Bool, reduced: Bool) -> Self {
        guard changed, !reduced, let plan, plan.stablePrefixCount == 0 else { return .init() }
        let duration = min(0.46, plan.duration)
        let progress = min(1, max(0, (time - plan.start) / duration))
        guard progress < 1 else { return .init() }
        let eased = LyricMotion.overlayArrivalCurve.value(at: progress)
        let weight = min(1, duration / 0.24)
        return .init(opacity: eased, offset: 4 * (1 - eased) * weight, blur: 1.5 * (1 - eased) * weight)
    }
}

struct OverlayLyricsContent: View {
    let preferences: Preferences
    let document: LyricsDocument
    let index: Int
    let lyricTime: () -> Double
    var renderTime: (() -> Double)?
    var playing = false
    var visible = true
    var secondaryMode: OverlaySecondaryMode?
    var adaptiveCanvasWidth: Double?
    var animationTime: () -> Double = { ProcessInfo.processInfo.systemUptime }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State var transition = OverlayCueTransition()
    @State private var settledCue: OverlayCueSnapshot?

    private var prefs: Preferences { preferences }
    private func secondary(at index: Int) -> OverlaySecondaryMode.Content {
        guard document.lines.indices.contains(index) else { return .init() }
        let line = document.lines[index]
        let translation = prefs.showTranslation && line.hasTranslation ? line.translation.map(prefs.text) : nil
        let next = document.lines.indices.contains(index + 1) ? prefs.text(document.lines[index + 1].text) : nil
        return (secondaryMode ?? prefs.overlaySecondaryMode).content(translation: translation, next: next)
    }
    private func nextCenter(translationHeight: Double, primaryHeight: Double, nextHeight: Double) -> Double {
        primaryHeight + prefs.overlayPrimarySpacing + (translationHeight > 0 ? translationHeight + prefs.overlaySecondarySpacing : 0) + nextHeight / 2
    }

    private func primaryHeight(at index: Int) -> Double {
        guard let width = adaptiveCanvasWidth else { return ceil(prefs.fontSize * 1.4) * 2 }
        return OverlayTextMeasure.primaryHeight(document: document, index: index, preferences: prefs, canvasWidth: width)
    }

    var body: some View {
        let line = document.lines[index]
        let text = line.text.isEmpty ? "•••" : prefs.text(line.text)
        let content = secondary(at: index)
        let nextLine = document.lines.indices.contains(index + 1) ? document.lines[index + 1] : nil
        let nextPlan = nextLine.flatMap { _ in LyricLinePresentation.make(lines: document.lines, index: index + 1, transform: prefs.text) }?.withoutEntry(text: content.next ?? "")
        let previous = secondary(at: index - 1)
        let plan = LyricLinePresentation.make(lines: document.lines, index: index, transform: prefs.text)
        let reduced = reduceMotion || prefs.reduceMotion
        let primaryHeight = primaryHeight(at: index)
        let nextPrimaryHeight = self.primaryHeight(at: index + 1)
        let measureWidth = adaptiveCanvasWidth ?? prefs.overlayLayoutWidth - 60
        let primaryFont = OverlayTextMeasure.primaryLayout(document: document, index: index, preferences: prefs, canvasWidth: measureWidth).fontSize
        let nextFont = OverlayTextMeasure.primaryLayout(document: document, index: index + 1, preferences: prefs, canvasWidth: measureWidth).fontSize
        let nextScale = prefs.nextLineFontSize / prefs.fontSize
        let nextHeight = nextPrimaryHeight * nextScale
        let translationTop = primaryHeight + prefs.overlayPrimarySpacing
        let auxiliaryHeight = adaptiveCanvasWidth == nil
            ? (secondaryMode ?? prefs.overlaySecondaryMode).reservedHeight(
                translationSize: prefs.translationFontSize, nextSize: prefs.nextLineFontSize,
                primarySpacing: prefs.overlayPrimarySpacing, secondarySpacing: prefs.overlaySecondarySpacing)
            : content.height(translationHeight: OverlayTextMeasure.translationHeight(content.translation,
                font: prefs.translationFontSize, canvasWidth: adaptiveCanvasWidth ?? 0, typography: prefs.typography), nextHeight: nextHeight,
                primarySpacing: prefs.overlayPrimarySpacing, secondarySpacing: prefs.overlaySecondarySpacing)
        let height = primaryHeight + auxiliaryHeight
        let _ = settledCue
        let sampledTime = lyricTime()
        GeometryReader { geometry in
            let translationHeight = OverlayTextMeasure.translationHeight(content.translation, font: prefs.translationFontSize, canvasWidth: geometry.size.width, typography: prefs.typography)
            let translationFont = content.translation.map {
                OverlayTextMeasure.layout($0, font: prefs.translationFontSize, canvasWidth: geometry.size.width,
                    tracking: 0, weight: .medium, minimumScale: 0.75, typography: prefs.typography).fontSize
            } ?? prefs.translationFontSize
            let nextY = nextCenter(translationHeight: translationHeight, primaryHeight: primaryHeight, nextHeight: nextHeight)
            let cue = OverlayCueSnapshot(document: document.id, index: index, line: line, text: text,
                plan: plan, height: primaryHeight, fontSize: primaryFont, previewText: content.next,
                previewCenter: content.next == nil ? nil : nextY, previewScale: nextScale)
            let now = animationTime()
            // Resolve before onChange so the first frame already contains the
            // right geometry and departure, without a one-frame flash.
            let staged = transition.updating(to: cue, lyricTime: sampledTime, at: now, animated: !reduced && visible)
            let arrival = plan?.stablePrefixCount == 0 ? plan?.withoutEntry(text: text) : plan
            let animatingLayout = visible && staged.needsFrames(at: now, reduced: reduced)
            LyricRenderTimeline(running: animatingLayout, sampledTime: now, preciseTime: animationTime,
                                continueFrames: { staged.needsFrames(at: animationTime(), reduced: reduced) }) { wallTime in
                let time = playing ? (renderTime ?? lyricTime)() : sampledTime
                let layoutTime = staged.layoutTime(at: wallTime, fallback: sampledTime)
                let motion = OverlayMotionFrame.make(time: layoutTime, plan: plan, distance: staged.promotionDistance, nextScale: nextScale, reduced: reduced)
                let translationMotion = OverlayAuxiliaryFrame.make(time: layoutTime, plan: plan, changed: previous.translation != content.translation, reduced: reduced)
                let nextMotion = OverlayAuxiliaryFrame.make(time: layoutTime, plan: plan, changed: previous.next != content.next, reduced: reduced)
                ZStack {
                    if let departure = staged.departure, let exit = departure.frame(at: wallTime) {
                        let old = departure.cue
                        OverlayLyricSurface(line: old.line, text: old.text, time: departure.time,
                            arrival: old.plan?.withoutEntry(text: old.text), fontSize: old.fontSize,
                            effects: prefs.lyricEmphasis, typography: prefs.typography)
                            .equatable()
                            .frame(width: geometry.size.width, height: old.height, alignment: .bottom)
                            .scaleEffect(departure.pose.scale).blur(radius: departure.pose.blur + exit.blur)
                            .opacity(departure.pose.opacity * exit.opacity)
                            .position(x: geometry.size.width / 2, y: old.height / 2 + departure.pose.offset + exit.offset)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                    // Once row movement settles, only the primary text receives
                    // display-rate word updates; translation and preview rest.
                    LyricRenderTimeline(running: playing && visible && !staged.needsFrames(at: wallTime, reduced: reduced) && LyricRenderTimelineActivity.needsFrames(line: line, time: time, arrival: arrival),
                                        sampledTime: time, preciseTime: renderTime ?? lyricTime,
                                        continueFrames: { LyricRenderTimelineActivity.needsFrames(line: line, time: (renderTime ?? lyricTime)(), arrival: arrival) }) { wordTime in
                        OverlayLyricSurface(line: line, text: text, time: wordTime, arrival: arrival,
                            fontSize: primaryFont, effects: prefs.lyricEmphasis, typography: prefs.typography)
                    }
                        .frame(width: geometry.size.width, height: primaryHeight, alignment: .bottom)
                        .scaleEffect(motion.scale).blur(radius: motion.blur)
                        .opacity(motion.opacity)
                        .position(x: geometry.size.width / 2, y: primaryHeight / 2 + motion.offset)
                    if let translation = content.translation {
                        OverlayTranslationSurface(text: translation, fontSize: translationFont, typography: prefs.typography).equatable()
                            .frame(width: geometry.size.width, height: translationHeight)
                            .blur(radius: translationMotion.blur)
                            .opacity(translationMotion.opacity * motion.auxiliaryOpacity(top: translationTop, primaryHeight: primaryHeight, reduced: reduced))
                            .position(x: geometry.size.width / 2, y: translationTop + translationHeight / 2 + translationMotion.offset)
                    }
                    if let next = content.next, let nextLine {
                        // Preview and primary use identical wrapping. Transform
                        // the cached layout rather than re-typesetting each size.
                        OverlayLyricSurface(line: nextLine, text: next, time: nextLine.time, arrival: nextPlan,
                            fontSize: nextFont, effects: .init(lift: prefs.lyricWordLift, glow: false, reduced: reduced), typography: prefs.typography, secondary: true)
                            .equatable()
                            .frame(width: geometry.size.width, height: nextPrimaryHeight, alignment: .bottom)
                            .scaleEffect(nextScale).blur(radius: reduced ? 0 : 0.45 + nextMotion.blur)
                            .opacity(0.85 * nextMotion.opacity * motion.auxiliaryOpacity(top: nextY - nextHeight / 2, primaryHeight: primaryHeight, reduced: reduced))
                            .position(x: geometry.size.width / 2, y: nextY + nextMotion.offset)
                    }
                }
                .onChange(of: staged.departure.map { $0.frame(at: wallTime) == nil }) { _, finished in
                    if finished == true, let token = staged.departure?.startedAt { transition.finishDeparture(startedAt: token) }
                }
            }
            .onChange(of: cue, initial: true) { _, value in
                transition = transition.updating(to: value, lyricTime: sampledTime, at: now, animated: !reduced && visible)
            }
            .task(id: cue) {
                guard !reduced, visible else { return }
                // A terminal update is required even if native display delivery
                // was interrupted while the arrival was blurred.
                do { try await Task.sleep(for: .seconds(OverlayMotionFrame.durationLimit)) } catch { return }
                settledCue = cue
            }
            .onChange(of: visible) { _, shown in if !shown { transition = .init() } }
            .onChange(of: reduced) { _, value in if value { transition = .init() } }
            .onDisappear { transition = .init() }
        }.frame(height: height)
            .modifier(OverlayContentTransition(identity: .init(document: document.id), reduced: reduced, visible: visible, animateInitial: false))
            .transaction { $0.animation = nil; $0.disablesAnimations = true }
    }

}

private struct OverlayLyricSurface: View, Equatable {
    let line: LyricLine
    let text: String
    let time: Double
    let arrival: LyricLinePresentation?
    let fontSize: Double
    let effects: LyricEmphasisOptions
    var typography = LyricTypography()
    var secondary = false
    var body: some View {
        WordHighlight(line: line, time: time, active: true, text: text, effects: effects, arrival: arrival)
            .font(typography.font(size: fontSize))
            .tracking(-0.4).multilineTextAlignment(.center).foregroundStyle(secondary ? typography.secondary : typography.primary)
            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
    }
}

private struct OverlayTranslationSurface: View, Equatable {
    let text: String
    let fontSize: Double
    var typography = LyricTypography()
    var body: some View {
        Text(text).font(typography.font(size: fontSize, weight: .medium))
            .foregroundStyle(typography.secondary.opacity(0.95)).lineLimit(2).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
