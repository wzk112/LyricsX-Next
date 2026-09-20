import AppKit
import QuartzCore
import SwiftUI

/// Dragging and resizing share this frame writer. Dragging changes the top
/// anchor of both animation endpoints without restarting the size clock.
@MainActor final class OverlayWindowMotion {
    private weak var window: NSWindow?
    private var link: CADisplayLink?
    private var origin = NSRect.zero
    private var target = NSRect.zero
    private var startedAt: Double?
    private var duration = 0.0
    private var completion: (() -> Void)?
    init(window: NSWindow) { self.window = window }
    @MainActor private final class Target: NSObject {
        weak var owner: OverlayWindowMotion?
        @objc func tick(_ link: CADisplayLink) { owner?.advance(at: ProcessInfo.processInfo.systemUptime) }
    }
    func start(to target: NSRect, duration: Double, frameRateLimit: Int, completion: @escaping () -> Void) {
        cancel()
        guard let window else { return }
        origin = window.frame; self.target = target; self.duration = duration
        self.completion = completion
        startedAt = ProcessInfo.processInfo.systemUptime
        guard duration > 0, origin != target else { finish(); return }
        let proxy = Target(); proxy.owner = self
        let link = window.displayLink(target: proxy, selector: #selector(Target.tick(_:)))
        self.link = link
        let maximum = max(1, window.screen?.maximumFramesPerSecond ?? 60)
        let constrained = ProcessInfo.processInfo.isLowPowerModeEnabled || [.serious, .critical].contains(ProcessInfo.processInfo.thermalState)
        let cap = frameRateLimit == -1 ? (constrained ? 60 : 0) : frameRateLimit
        let rate = Float(cap > 0 ? min(maximum, cap) : maximum)
        link.preferredFrameRateRange = CAFrameRateRange(minimum: rate, maximum: rate, preferred: rate)
        link.add(to: .main, forMode: .common)
    }
    func advance(at now: Double) {
        guard let startedAt, let window else { return }
        let progress = max(0, (now - startedAt) / duration)
        guard progress < 1 else { finish(); return }
        let fraction = LyricMotion.arrivalCurve.value(at: progress)
        let rect = NSRect(x: origin.minX + (target.minX - origin.minX) * fraction,
            y: origin.minY + (target.minY - origin.minY) * fraction,
            width: origin.width + (target.width - origin.width) * fraction,
            height: origin.height + (target.height - origin.height) * fraction)
        // The display link provides the cadence; display each intermediate
        // native frame as well. Geometry-only writes leave AppKit's previous
        // backing pixels stretched between occasional redraws, which looks
        // like a low-frame-rate resize even though the frame clock is running.
        if window.frame != rect { window.setFrame(rect, display: true) }
    }
    func moveTopCenter(to point: NSPoint) {
        guard let window else { return }
        func anchored(_ rect: NSRect) -> NSRect {
            NSRect(x: point.x - rect.width / 2, y: point.y - rect.height,
                   width: rect.width, height: rect.height)
        }
        origin = anchored(origin)
        target = anchored(target)
        let frame = anchored(window.frame)
        if window.frame != frame { window.setFrame(frame, display: true) }
    }
    func finish() {
        guard startedAt != nil else { return }
        let completion = completion, target = target
        cancel()
        if let window, window.frame != target { window.setFrame(target, display: true) }
        completion?()
    }
    func cancel() {
        link?.invalidate(); link = nil
        startedAt = nil; completion = nil
    }
    isolated deinit { link?.invalidate() }
}
