import AppKit
import QuartzCore

/// Width and height share one native frame writer. A new target changes spring
/// force while retaining size velocity and the current display link. The top
/// center is a separate anchor and never receives spring motion.
@MainActor final class OverlayWindowMotion {
    private struct Axis {
        var position = 0.0
        var velocity = 0.0
        var target = 0.0

        mutating func step(seconds: Double, frequency: Double) {
            let displacement = position - target
            if abs(displacement) < 0.001 { position = target; velocity = 0; return }
            let initialVelocity = velocity
            let coefficient = initialVelocity + frequency * displacement
            let decay = exp(-frequency * seconds)
            let next = target + (displacement + coefficient * seconds) * decay
            let nextVelocity = (initialVelocity - frequency * coefficient * seconds) * decay
            // Retarget momentum can cross a nearby target. Native glass
            // should settle there rather than visibly stretch past it.
            if displacement != 0, (next - target) * displacement <= 0 {
                position = target; velocity = 0
            } else {
                position = next; velocity = nextVelocity
            }
        }

        var settled: Bool { abs(position - target) <= 0.35 && abs(velocity) <= 2 }
    }

    private weak var window: NSWindow?
    private var link: CADisplayLink?
    private var watchdog: Timer?
    private var lastDisplayTick: Double?
    private var logicalTopCenter = NSPoint.zero
    private var finalTarget = NSRect.zero
    private var visibleFrame: NSRect?
    private var width = Axis()
    private var height = Axis()
    private var frequency = 0.0
    private var lastSample: Double?
    private var constrainToVisibleFrame = true
    private var completion: (() -> Void)?
    private(set) var displayLinkCreations = 0

    init(window: NSWindow) { self.window = window }
    @MainActor private final class Target: NSObject {
        weak var owner: OverlayWindowMotion?
        @objc func tick(_ link: CADisplayLink) {
            // The spring state and retargets must use the same actual clock.
            // CADisplayLink.targetTimestamp can be in the future.
            owner?.displayTick(at: ProcessInfo.processInfo.systemUptime)
        }
    }

    func start(to rect: NSRect, logicalTopCenter: NSPoint? = nil,
               visibleFrame: NSRect? = nil, duration: Double, frameRateLimit: Int,
               constrainToVisibleFrame: Bool = true, completion: @escaping () -> Void) {
        guard let window else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if lastSample == nil {
            let frame = window.frame
            width.position = Double(frame.width); height.position = Double(frame.height)
            width.velocity = 0; height.velocity = 0
            lastSample = now
        } else { integrate(at: now) }
        self.logicalTopCenter = logicalTopCenter ?? NSPoint(x: rect.midX, y: rect.maxY)
        finalTarget = rect
        self.visibleFrame = visibleFrame ?? window.screen?.visibleFrame
        width.target = Double(rect.width); height.target = Double(rect.height)
        frequency = 9 / max(0.025, duration)
        self.constrainToVisibleFrame = constrainToVisibleFrame
        self.completion = completion
        guard duration > 0 else { finish(); return }
        if width.settled && height.settled { finish(); return }
        if link == nil {
            let proxy = Target(); proxy.owner = self
            let displayLink = window.displayLink(target: proxy, selector: #selector(Target.tick(_:)))
            link = displayLink
            displayLinkCreations += 1
            displayLink.add(to: .main, forMode: .common)
        }
        if watchdog == nil {
            // A visible window's display link can be starved while its app is
            // occluded or while an AppKit test host has no active display cycle.
            // Keep spring settlement bounded without polling when idle.
            let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.watchdogTick() }
            }
            watchdog = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        let maximum = max(1, window.screen?.maximumFramesPerSecond ?? 60)
        let constrained = ProcessInfo.processInfo.isLowPowerModeEnabled
            || [.serious, .critical].contains(ProcessInfo.processInfo.thermalState)
        let cap = frameRateLimit == -1 ? (constrained ? 60 : 0) : frameRateLimit
        let rate = Float(cap > 0 ? min(maximum, cap) : maximum)
        link?.preferredFrameRateRange = CAFrameRateRange(minimum: rate, maximum: rate, preferred: rate)
    }

    private func integrate(at now: Double) {
        guard let previous = lastSample else { return }
        let seconds = max(0, now - previous)
        guard seconds > 0 else { return }
        width.step(seconds: seconds, frequency: frequency)
        height.step(seconds: seconds, frequency: frequency)
        lastSample = now
    }

    private func displayTick(at now: Double) {
        lastDisplayTick = now
        advance(at: now)
    }

    private func watchdogTick() {
        let now = ProcessInfo.processInfo.systemUptime
        guard lastDisplayTick.map({ now - $0 >= 0.075 }) ?? true else { return }
        advance(at: now)
    }

    func advance(at now: Double) {
        guard lastSample != nil, let window else { return }
        integrate(at: now)
        if width.settled && height.settled { finish(); return }
        let size = NSSize(width: max(1, width.position.rounded()), height: max(1, height.position.rounded()))
        let rect: NSRect = if constrainToVisibleFrame, let bounds = visibleFrame {
            OverlayAnchor(topCenter: logicalTopCenter).frame(size: size, in: bounds)
        } else {
            NSRect(x: logicalTopCenter.x - size.width / 2,
                   y: logicalTopCenter.y - size.height, width: size.width, height: size.height)
        }
        // Whole-point sizes avoid redundant native redraws near rest. Every
        // distinct frame still asks AppKit to display fresh glass and content.
        if window.frame != rect { window.setFrame(rect, display: true) }
    }

    func moveTopCenter(to point: NSPoint) {
        guard let window else { return }
        logicalTopCenter = point
        finalTarget = NSRect(x: point.x - width.target / 2, y: point.y - height.target,
                             width: width.target, height: height.target)
        constrainToVisibleFrame = false
        visibleFrame = nil
        let frame = NSRect(x: point.x - window.frame.width / 2, y: point.y - window.frame.height,
                           width: window.frame.width, height: window.frame.height)
        if window.frame != frame { window.setFrame(frame, display: true) }
    }

    func finish() {
        guard lastSample != nil else { return }
        let completion = completion
        let rect = finalTarget
        cancel()
        if let window, window.frame != rect { window.setFrame(rect, display: true) }
        completion?()
    }

    func cancel() {
        link?.invalidate(); link = nil
        watchdog?.invalidate(); watchdog = nil
        lastDisplayTick = nil
        lastSample = nil; completion = nil
    }
    isolated deinit { link?.invalidate(); watchdog?.invalidate() }
}
