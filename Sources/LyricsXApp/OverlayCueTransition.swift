import Foundation
import LyricsXCore

/// Remember what was actually on screen, rather than inventing an outgoing
/// row from index - 1 after a seek, document replacement or window reopening.
struct OverlayCueSnapshot: Equatable {
    let document: UUID
    let index: Int
    let line: LyricLine
    let text: String
    let plan: LyricLinePresentation?
    let height: Double
    let fontSize: Double
    let previewText: String?
    let previewCenter: Double?
    let previewScale: Double
    var fontName = ""
}

struct OverlayCueDeparture {
    let cue: OverlayCueSnapshot
    let time: Double
    let startedAt: Double
    let duration: Double
    let pose: OverlayMotionFrame

    func frame(at now: Double) -> LyricMotion.Frame? {
        let progress = max(0, (now - startedAt) / duration)
        guard progress < 1 else { return nil }
        let eased = LyricEmphasisFrame.smoother(progress)
        let distance = min(16, max(8, cue.height * 0.3))
        return .init(offset: -distance * eased, blur: 3.2 * eased, opacity: 1 - eased)
    }
}

struct OverlayCueTransition {
    private(set) var current: OverlayCueSnapshot?
    private(set) var promotionDistance: Double?
    private(set) var departure: OverlayCueDeparture?
    private(set) var motionPlan: LyricLinePresentation?
    private(set) var arrivedAt: Double?

    func layoutTime(at now: Double, fallback: Double) -> Double {
        guard let current, let arrivedAt else { return fallback }
        return current.line.time + max(0, now - arrivedAt)
    }

    func needsFrames(at now: Double, reduced: Bool) -> Bool {
        guard !reduced else { return false }
        if departure?.frame(at: now) != nil { return true }
        guard let plan = motionPlan, plan.stablePrefixCount == 0 else { return false }
        return layoutTime(at: now, fallback: .infinity) < plan.start + min(OverlayMotionFrame.durationLimit, plan.duration)
    }

    func updating(to cue: OverlayCueSnapshot, lyricTime: Double, at now: Double, animated: Bool) -> Self {
        var result = self
        result.current = cue
        if let current, current.document == cue.document, current.index == cue.index, current.text == cue.text {
            let reflowed = current.fontName != cue.fontName || current.height != cue.height || current.fontSize != cue.fontSize || current.previewCenter != cue.previewCenter
            if !animated || reflowed { result.settle() }
            return result
        }
        result.arrivedAt = now - max(0, lyricTime - cue.line.time)
        result.motionPlan = cue.plan
        result.promotionDistance = nil
        result.departure = nil
        guard animated else { result.settle(); return result }
        guard let current, current.document == cue.document, current.index + 1 == cue.index,
              lyricTime >= cue.line.time, lyricTime - cue.line.time < 0.2,
              cue.plan?.stablePrefixCount == 0 else { return result }
        // A playback tick can arrive partway into a cue. Start geometry at the
        // pixels still on screen, not partway up the promotion curve. Shorten
        // only the remaining motion budget; word timing keeps its music clock.
        result.arrivedAt = now
        if let plan = cue.plan {
            result.motionPlan = .init(start: plan.start,
                duration: max(0.025, plan.duration - max(0, lyricTime - cue.line.time)),
                stablePrefixCount: plan.stablePrefixCount, layoutTail: plan.layoutTail)
        }
        // The auxiliary policy trims padding from provider text; the primary
        // retains it so word timing ranges keep their original character offsets.
        // Compare the displayed content, without language-specific matching.
        if let preview = current.previewText,
           preview.trimmingCharacters(in: .whitespacesAndNewlines) == cue.text.trimmingCharacters(in: .whitespacesAndNewlines),
           let center = current.previewCenter {
            result.promotionDistance = center - cue.height / 2
        }
        // A new cue replaces the sole departing row. Its deadline uses uptime,
        // so pausing cannot leave a translucent old lyric behind the new one.
        result.departure = .init(cue: current, time: lyricTime, startedAt: now,
            duration: min(0.24, (result.motionPlan?.duration ?? 0.4) * 0.45),
            pose: OverlayMotionFrame.make(time: layoutTime(at: now, fallback: lyricTime), plan: motionPlan,
                distance: promotionDistance, nextScale: current.previewScale, reduced: false))
        return result
    }

    mutating func settle() {
        arrivedAt = nil; motionPlan = nil; promotionDistance = nil; departure = nil
    }

    mutating func finishDeparture(startedAt: Double) {
        if departure?.startedAt == startedAt { departure = nil }
    }
}
