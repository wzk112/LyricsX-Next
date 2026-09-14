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
        .init(track: track, primary: compact ? primary : "", compact: compact, artwork: compact ? artwork : nil)
    }
}

struct OverlayBlurStyle: Equatable {
    var radius = 0.0
    var duration = 0.0
    static func change(from old: OverlayContentIdentity?, to new: OverlayContentIdentity,
                       incremental: Bool, lineDuration: Double) -> Self {
        guard old != new else { return .init() }
        guard let old, old.track == new.track, old.document == new.document, old.compact == new.compact else {
            return .init(radius: 3, duration: 0.52)
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

/// One persistent foreground, with no outgoing copy or delayed removal. The
/// first frame of changed content is already blurred, before onChange runs.
struct OverlayContentTransition: ViewModifier {
    let identity: OverlayContentIdentity
    var incremental = false
    var lineDuration = 1.0
    var reduced = false
    var visible = true
    var preparingSince: Double?
    var animateInitial = true
    @State private var displayed: OverlayContentIdentity?
    @State private var style = OverlayBlurStyle()
    @State private var clock = LyricArrivalClock()

    func body(content: Content) -> some View {
        let pending = displayed != identity
        let incoming = displayed == nil && !animateInitial ? OverlayBlurStyle() : OverlayBlurStyle.change(from: displayed, to: identity, incremental: incremental, lineDuration: lineDuration)
        LyricRenderTimeline(running: !reduced && visible && clock.startedAt != nil,
                            sampledTime: ProcessInfo.processInfo.systemUptime,
                            preciseTime: { ProcessInfo.processInfo.systemUptime }) { now in
            let blur: Double = if let preparingSince {
                3 * LyricMotion.arrivalCurve.value(at: min(1, max(0, (now - preparingSince) / OverlayPresentation.handoverDuration)))
            } else {
                pending ? incoming.radius : clock.startedAt.map { style.blur(elapsed: now - $0) } ?? 0
            }
            let departure = preparingSince.map { LyricEmphasisFrame.smooth((now - $0) / OverlayPresentation.handoverDuration) } ?? 0
            content.blur(radius: reduced || !visible ? 0 : blur)
                .offset(y: reduced || !visible ? 0 : -12 * departure)
                .opacity(reduced || !visible ? 1 : 1 - departure)
                .transaction { $0.animation = nil; $0.disablesAnimations = true }
                .onChange(of: clock.finishedToken(at: now)) { _, token in clock.finish(token) }
        }
        .onChange(of: identity, initial: true) { _, value in
            style = incoming; displayed = value
            if !reduced && visible && style.radius > 0 { clock.start(at: ProcessInfo.processInfo.systemUptime, duration: style.duration) }
            else { clock.cancel() }
        }
        .onChange(of: reduced) { _, value in if value { clock.cancel() } }
        .onChange(of: preparingSince) { _, value in
            if reduced || !visible { clock.cancel() }
            else if value != nil { clock.start(at: ProcessInfo.processInfo.systemUptime, duration: OverlayPresentation.handoverDuration) }
            else if !pending && !reduced && visible {
                style = .init(radius: 3, duration: 0.25)
                clock.start(at: ProcessInfo.processInfo.systemUptime, duration: style.duration)
            }
        }
        .onChange(of: visible) { _, value in if !value { clock.cancel() } }
        .task(id: clock.startedAt) {
            // Finish independently of display callbacks (occlusion/minimizing
            // can suspend them before the final sharp frame is delivered).
            guard let token = clock.startedAt else { return }
            let remaining = max(0, token + clock.duration - ProcessInfo.processInfo.systemUptime)
            do { try await Task.sleep(for: .seconds(remaining)) } catch { return }
            clock.finish(token)
        }
        .onDisappear { clock.cancel() }
    }
}
