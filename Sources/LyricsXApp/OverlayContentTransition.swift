import SwiftUI

/// Only visible content participates; playback ticks never restart a transition.
struct OverlayContentIdentity: Equatable {
    var track: String?
    var document: UUID?
    var primary = ""
    var translation: String?
    var next: String?
    var compact = false
    var artwork: ObjectIdentifier?
    var songScope: Self {
        // The whole-window handover belongs to the playback item. Waiting,
        // lyric, and artwork-card modes often arrive in separate observations
        // for that same item; including them here replayed the title blur when
        // lyrics finished loading.
        .init(track: track)
    }
}

struct OverlayBlurStyle: Equatable {
    var radius = 0.0
    var duration = 0.0
    static func change(from old: OverlayContentIdentity?, to new: OverlayContentIdentity,
                       incremental: Bool, lineDuration: Double) -> Self {
        guard old != new else { return .init() }
        guard let old, old.track == new.track, old.document == new.document, old.compact == new.compact else {
            return .init(radius: 3, duration: 0.42)
        }
        // Appending a suffix already animates just the new glyphs. A full-card
        // blur here would repeatedly obscure the stable prefix at high speed.
        if incremental, new.primary.hasPrefix(old.primary), new.primary.count > old.primary.count { return .init() }
        let duration = min(0.36, max(0.04, lineDuration * 0.7))
        return .init(radius: 1.6 * min(1, duration / 0.24), duration: duration)
    }
    func blur(elapsed: Double) -> Double {
        guard duration > 0 else { return 0 }
        let progress = min(1, max(0, elapsed / duration))
        return radius * (1 - LyricMotion.overlayArrivalCurve.value(at: progress))
    }
}

/// A single committed transition owns both its clock and its terminal state.
/// A content mismatch must never itself become a permanent blur radius.
struct OverlayContentAnimation {
    struct Request: Equatable {
        let identity: OverlayContentIdentity
        let reduced: Bool
        let visible: Bool
        let preparingSince: Double?
    }
    private(set) var request: Request?
    private(set) var startedAt: Double?
    private(set) var duration = 0.0
    private var style = OverlayBlurStyle()

    mutating func update(_ next: Request, at now: Double, incremental: Bool, lineDuration: Double, animateInitial: Bool) {
        guard request != next else { return }
        let old = request
        request = next
        cancel()
        guard !next.reduced, next.visible else { return }
        if next.preparingSince != nil {
            // The presentation already holds a coherent frame during handover.
            // Keep it sharp until the new song commits, then run one arrival;
            // fading the held frame first caused two blur pulses and a blank.
            return
        }
        if old?.identity != next.identity {
            style = old == nil && !animateInitial ? .init() : .change(from: old?.identity, to: next.identity,
                incremental: incremental, lineDuration: lineDuration)
            if style.radius > 0 { startedAt = now; duration = style.duration }
        }
    }
    func frame(at now: Double) -> LyricMotion.Frame {
        guard let startedAt else { return .init() }
        let elapsed = max(0, now - startedAt)
        // Even a delayed completion or stale display callback has a sharp end.
        guard elapsed < duration else { return .init() }
        return .init(blur: style.blur(elapsed: elapsed))
    }
    mutating func finish(_ token: Double) {
        if startedAt == token { startedAt = nil }
    }
    mutating func cancel() { startedAt = nil }
}

struct OverlayContentTransition: ViewModifier {
    let identity: OverlayContentIdentity
    var incremental = false
    var lineDuration = 1.0
    var reduced = false
    var visible = true
    var preparingSince: Double?
    var animateInitial = true
    @State private var state = OverlayContentAnimation()

    func body(content: Content) -> some View {
        let request = OverlayContentAnimation.Request(identity: identity, reduced: reduced, visible: visible, preparingSince: preparingSince)
        LyricRenderTimeline(running: !reduced && visible && state.startedAt != nil,
                            sampledTime: ProcessInfo.processInfo.systemUptime,
                            preciseTime: { ProcessInfo.processInfo.systemUptime }) { now in
            let frame = reduced || !visible ? LyricMotion.Frame() : state.frame(at: now)
            content.blur(radius: frame.blur).offset(y: frame.offset).opacity(frame.opacity)
                .transaction { $0.animation = nil; $0.disablesAnimations = true }
        }
        .onChange(of: request, initial: true) { _, value in
            state.update(value, at: ProcessInfo.processInfo.systemUptime, incremental: incremental,
                lineDuration: lineDuration, animateInitial: animateInitial)
        }
        .task(id: state.startedAt) {
            guard let token = state.startedAt else { return }
            let remaining = max(0, token + state.duration - ProcessInfo.processInfo.systemUptime)
            do { try await Task.sleep(for: .seconds(remaining)) } catch { return }
            state.finish(token)
        }
        .onDisappear { state.cancel() }
    }
}
