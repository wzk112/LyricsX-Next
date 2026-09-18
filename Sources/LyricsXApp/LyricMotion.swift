import SwiftUI
import LyricsXCore

enum LyricMotion {
    static let response = 0.82
    static let damping = 0.86
    static let arrivalCurve = UnitCurve.bezier(startControlPoint: .init(x: 0.22, y: 0), endControlPoint: .init(x: 0.18, y: 1))
    static let overlayArrivalCurve = UnitCurve.bezier(startControlPoint: .init(x: 0.28, y: 0), endControlPoint: .init(x: 0.30, y: 1))
    static var animation: Animation { .spring(response: response, dampingFraction: damping, blendDuration: 0.2) }

    static func followResponse(lines: [LyricLine], index: Int?) -> Double {
        guard let index, lines.indices.contains(index), lines.indices.contains(index + 1) else { return response }
        return min(response, max(0.025, (lines[index + 1].time - lines[index].time) * 0.8))
    }

    static func following(lines: [LyricLine], index: Int?) -> Animation {
        let duration = followResponse(lines: lines, index: index)
        return .spring(response: duration, dampingFraction: damping, blendDuration: min(0.2, duration * 0.25))
    }

    struct Frame: Equatable, Sendable {
        var offset = 0.0
        var blur = 0.0
        var opacity = 1.0
    }
}

/// A cancelled arrival must return to its resting frame. An old completion
/// cannot stop a newer track's arrival, even in the same run-loop turn.
struct LyricArrivalClock {
    private(set) var startedAt: Double?
    private(set) var duration = 0.84
    mutating func start(at time: Double, duration: Double = 0.84) { startedAt = time; self.duration = max(0.025, duration) }
    mutating func cancel() { startedAt = nil }
    mutating func finish(_ token: Double?) {
        if let token, token == startedAt { cancel() }
    }
    func frame(at now: Double) -> LyricMotion.Frame {
        guard let startedAt else { return .init() }
        return LyricLinePresentation(start: startedAt, duration: duration, stablePrefixCount: 0, layoutTail: "").frame(at: now)
    }
    func finishedToken(at now: Double) -> Double? {
        guard let startedAt, now - startedAt >= duration else { return nil }
        return startedAt
    }
}

private struct LyricArrival<Trigger: Equatable & Sendable>: ViewModifier {
    let trigger: Trigger
    let reduced: Bool
    let distance: Double
    var visible: () -> Bool
    @State private var clock = LyricArrivalClock()
    @State private var displayedTrigger: Trigger?

    func body(content: Content) -> some View {
        let visible = visible()
        var staged = clock
        if displayedTrigger != nil, displayedTrigger != trigger, !reduced, visible {
            staged.start(at: ProcessInfo.processInfo.systemUptime)
        }
        let presentation = staged
        return LyricRenderTimeline(running: presentation.startedAt != nil && !reduced && visible,
                            sampledTime: ProcessInfo.processInfo.systemUptime,
                            preciseTime: { ProcessInfo.processInfo.systemUptime }) { now in
            let frame = reduced ? LyricMotion.Frame() : presentation.frame(at: now)
            content.offset(y: frame.offset * distance / 10).blur(radius: frame.blur).opacity(frame.opacity)
                .onChange(of: clock.finishedToken(at: now)) { _, token in clock.finish(token) }
        }
        .onChange(of: trigger, initial: true) { _, value in
            let first = displayedTrigger == nil
            displayedTrigger = value
            if first || reduced || !visible { clock.cancel() } else { clock.start(at: ProcessInfo.processInfo.systemUptime) }
        }
        .onChange(of: visible) { _, value in if !value { clock.cancel() } }
        .onChange(of: reduced) { _, value in if value { clock.cancel() } }
        .onDisappear { clock.cancel() }
    }
}

extension View {
    func lyricArrival(trigger: some Equatable & Sendable, reduced: Bool, distance: Double = 12, visible: @escaping () -> Bool = { true }) -> some View {
        modifier(LyricArrival(trigger: trigger, reduced: reduced, distance: distance, visible: visible))
    }
}
