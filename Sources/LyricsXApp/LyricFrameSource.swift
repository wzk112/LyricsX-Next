import AppKit
import QuartzCore
import SwiftUI

enum OverlayFrameRate: String, CaseIterable, Identifiable {
    case display, sixty, adaptive
    var id: String { rawValue }
    var limit: Int { self == .adaptive ? -1 : self == .sixty ? 60 : 0 }
    var title: String { self == .adaptive ? "智能节能" : self == .sixty ? "60 帧" : "跟随屏幕" }
}

private struct LyricFrameRateLimitKey: EnvironmentKey { static let defaultValue = 0 }
extension EnvironmentValues {
    var lyricFrameRateLimit: Int {
        get { self[LyricFrameRateLimitKey.self] }
        set { self[LyricFrameRateLimitKey.self] = newValue }
    }
}

/// Each lyric surface follows its own window's display link. Common run-loop
/// modes keep frames eligible while AppKit is tracking a window interaction.
struct LyricFrameSource: NSViewRepresentable {
    var running: Bool
    var frame: () -> Void
    @Environment(\.lyricFrameRateLimit) private var frameRateLimit

    func makeNSView(context: Context) -> LyricFrameView { LyricFrameView() }
    func updateNSView(_ view: LyricFrameView, context: Context) {
        view.frameCallback = frame
        view.frameRateLimit = frameRateLimit
        view.running = running
    }
    static func dismantleNSView(_ view: LyricFrameView, coordinator: ()) { view.stop(); view.frameCallback = nil }
}

@MainActor final class LyricFrameView: NSView {
    var frameCallback: (() -> Void)?
    var frameRateLimit = 0 { didSet { if frameRateLimit != oldValue { updateFrameRate() } } }
    var running = false { didSet { if running != oldValue { updateActivity(nil) } } }
    private var link: CADisplayLink?
    private var activity = WindowRenderActivity()
    private var attachment: UInt64 = 0
    private(set) var deliveringFrames = false
    private(set) var requestedFrameRate = 0

    // CADisplayLink retains its target. The proxy must not retain the view.
    @MainActor private final class Target: NSObject {
        weak var view: LyricFrameView?
        @objc func tick(_ sender: CADisplayLink) {
            guard let view, view.deliveringFrames else { return }
            view.frameCallback?()
        }
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stop()
        activity = WindowRenderActivity()
        guard let window else { return }
        for name in WindowRenderActivity.notifications {
            NotificationCenter.default.addObserver(self, selector: #selector(updateActivity(_:)), name: name, object: window)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(frameRateEnvironmentDidChange),
            name: NSWindow.didChangeScreenNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(frameRateEnvironmentDidChange),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        for name in [Notification.Name.NSProcessInfoPowerStateDidChange, ProcessInfo.thermalStateDidChangeNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(frameRateEnvironmentDidChange), name: name, object: nil)
        }
        updateActivity(nil)
        // Attachment often precedes the window's first orderFront. Read again
        // after that operation even if AppKit coalesces its occlusion event.
        let token = attachment
        DispatchQueue.main.async { [weak self] in
            guard let self, self.attachment == token else { return }
            self.updateActivity(nil)
        }
    }
    @objc private func updateActivity(_ notification: Notification?) {
        // Transparent floating panels may receive transient occlusion changes
        // during another window's minimize animation. Their own visibility and
        // `running` (including hover hiding) own rendering, not that occlusion.
        let floating = window is DraggableOverlayPanel
        let visible = activity.update(event: notification?.name, visible: window?.isVisible == true,
            miniaturized: window?.isMiniaturized == true, exposed: window?.occlusionState.contains(.visible) == true, floating: floating)
        deliveringFrames = visible && running
        if deliveringFrames, link == nil, let window {
            let target = Target(); target.view = self
            let link = window.displayLink(target: target, selector: #selector(Target.tick(_:)))
            self.link = link
            updateFrameRate()
            link.add(to: .main, forMode: .common)
        }
        link?.isPaused = !deliveringFrames
    }
    // ProcessInfo notifications arrive on the posting thread, including system
    // worker queues. The Objective-C entry point must itself be nonisolated:
    // an actor-isolated selector traps before its body can dispatch to main.
    @objc private nonisolated func frameRateEnvironmentDidChange() {
        Task { @MainActor [weak self] in self?.updateFrameRate() }
    }

    private func updateFrameRate() {
        guard let link else { return }
        let screenMaximum = max(1, window?.screen?.maximumFramesPerSecond ?? NSScreen.main?.maximumFramesPerSecond ?? 60)
        let constrained = ProcessInfo.processInfo.isLowPowerModeEnabled || ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical
        let limit = frameRateLimit == -1 ? (constrained ? 60 : 0) : frameRateLimit
        let maximum = limit > 0 ? min(screenMaximum, limit) : screenMaximum
        guard requestedFrameRate != maximum else { return }
        requestedFrameRate = maximum
        // A window-scoped limit never exceeds its display. AppKit moves this
        // link across screens; macOS still applies power/thermal constraints.
        let rate = Float(maximum)
        link.preferredFrameRateRange = CAFrameRateRange(minimum: rate, maximum: rate, preferred: rate)
    }
    func stop() {
        attachment &+= 1
        link?.invalidate(); link = nil
        deliveringFrames = false
        requestedFrameRate = 0
        NotificationCenter.default.removeObserver(self)
    }
}
