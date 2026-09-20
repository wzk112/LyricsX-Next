import Foundation

/// Adaptive cue lookup must run during window tracking as well as idle UI.
/// The callback returns its next interval; paused/hidden playback stays cheap.
@MainActor final class PlaybackTicker: NSObject {
    private let update: () -> Double?
    private var timer: Timer?
    private(set) var running = false
    init(update: @escaping () -> Double?) { self.update = update }
    func start() {
        guard !running else { return }
        running = true; tick()
    }
    @objc private func tick() {
        timer = nil
        guard running, let milliseconds = update(), running else { stop(); return }
        let timer = Timer(timeInterval: max(0.008, milliseconds / 1_000), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    func stop() { running = false; timer?.invalidate(); timer = nil }
    isolated deinit { timer?.invalidate() }
}
