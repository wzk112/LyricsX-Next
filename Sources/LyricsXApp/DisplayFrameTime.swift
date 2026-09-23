import Foundation

/// CADisplayLink timestamps and the presentation clock share the monotonic
/// system clock. Correct small delivery jitter without extending old frames.
enum DisplayFrameTime {
    static func sample(_ value: Double, target: Double?, now: Double) -> Double {
        guard let target, target.isFinite, now.isFinite else { return value }
        let delta = target - now
        guard abs(delta) <= 1.0 / 30 else { return value }
        return value + delta
    }
}
