import Foundation

/// Adaptive cue lookup must run during window tracking as well as idle UI.
/// The callback returns its next interval; paused/hidden playback stays cheap.
@MainActor final class PlaybackTicker: NSObject {
    private let update: () -> Double?
    private var timer: Timer?
    private(set) var nextFireAt: Double?
    private(set) var running = false
    init(update: @escaping () -> Double?) { self.update = update }
    func start() {
        guard !running else { return }
        running = true; tick()
    }
    @objc private func tick() {
        timer = nil
        nextFireAt = nil
        guard running, let milliseconds = update(), running else { stop(); return }
        schedule(milliseconds)
    }
    /// A seek or new cue may move the next line ahead of the pending timer.
    /// Frequent unchanged player samples leave the existing timer untouched.
    func scheduleEarlier(_ milliseconds: Double) {
        guard running, milliseconds.isFinite, milliseconds > 0 else { return }
        let candidate = ProcessInfo.processInfo.systemUptime + max(0.008, milliseconds / 1_000)
        guard let nextFireAt, candidate + 0.005 < nextFireAt else { return }
        timer?.invalidate()
        schedule(milliseconds)
    }
    private func schedule(_ milliseconds: Double) {
        let delay = max(0.008, milliseconds / 1_000)
        nextFireAt = ProcessInfo.processInfo.systemUptime + delay
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    func stop() { running = false; timer?.invalidate(); timer = nil; nextFireAt = nil }
    isolated deinit { timer?.invalidate() }
}
