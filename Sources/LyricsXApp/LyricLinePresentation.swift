import SwiftUI
import LyricsXCore

struct LyricLinePresentation: Equatable, Sendable {
    let start: Double
    let duration: Double
    let stablePrefixCount: Int
    let layoutTail: String

    func withoutEntry(text: String) -> Self {
        .init(start: start, duration: duration, stablePrefixCount: text.count, layoutTail: layoutTail)
    }

    static func make(lines: [LyricLine], index: Int, transform: (String) -> String = { $0 }) -> Self? {
        guard lines.indices.contains(index) else { return nil }
        let line = lines[index]
        let text = transform(line.text)
        guard !text.isEmpty else { return nil }
        let nextTime = lines.indices.contains(index + 1) ? lines[index + 1].time : line.time + 1
        let duration = min(0.84, max(0.025, (nextTime - line.time) * 0.8))
        var prefix = 0
        if index > 0 {
            let previous = lines[index - 1]
            let old = transform(previous.text)
            if !old.isEmpty, text.count > old.count, line.time - previous.time <= 1.2, line.time > previous.time, text.hasPrefix(old) {
                prefix = old.count
            }
        }
        // Reserve a bounded exact-prefix chain, without drawing future text.
        // Existing letters then stay in place as each suffix becomes visible.
        var finalText = text
        var previousTime = line.time
        for next in lines.dropFirst(index + 1).prefix(256) {
            let value = transform(next.text)
            guard next.time > previousTime, next.time - previousTime <= 1.2,
                  value.hasPrefix(finalText), value.count > finalText.count, value.count <= 512 else { break }
            finalText = value; previousTime = next.time
        }
        return .init(start: line.time, duration: duration, stablePrefixCount: prefix,
                     layoutTail: String(finalText.dropFirst(text.count)))
    }

    func frame(at time: Double) -> LyricMotion.Frame {
        guard time.isFinite else { return .init() }
        let progress = min(1, max(0, (time - start) / duration))
        guard progress < 1 else { return .init() }
        // Short syllables must be readable on their first displayed frame.
        // Scale travel/blur down with their available time, never queue them.
        let weight = min(1, duration / 0.38)
        let eased = LyricMotion.arrivalCurve.value(at: progress)
        let settle = 0.35 * sin(.pi * max(0, (progress - 0.68) / 0.32))
        return .init(offset: (10 * (1 - eased) - settle) * weight,
                     blur: 2.65 * (1 - UnitCurve.easeInOut.value(at: min(1, progress / 0.55))) * weight,
                     opacity: 1 - 0.4 * (1 - UnitCurve.easeOut.value(at: min(1, progress / 0.4))) * weight)
    }
}

enum LyricTickCadence {
    static func milliseconds(playing: Bool, visible: Bool, document: LyricsDocument?, position: Double) -> Double {
        guard playing else { return 500 }
        guard visible else { return 250 }
        // Continuous word rendering has its own display schedule.
        let normal = 100.0
        guard let document, document.isSynced else { return normal }
        let index = document.index(at: position)
        let nextIndex = (index ?? -1) + 1
        let now = document.lyricTime(for: position)
        let current = index.map { document.lines[$0].time } ?? now
        let elapsed = max(0, now - current)
        guard document.lines.indices.contains(nextIndex) else { return elapsed < 0.85 ? 33 : normal }
        let next = document.lines[nextIndex].time
        // Keep line arrivals smooth too, including ordinary LRC with no tt.
        let animationCadence = next - current < 0.35 ? 16.0 : elapsed < 0.85 ? 33.0 : normal
        return max(8, min(animationCadence, max(0, next - now) * 1_000 + 0.5))
    }
}

/// Flexbar receives cue changes; its plugin owns local animation frames.
enum FlexbarCueCadence {
    static func milliseconds(document: LyricsDocument?, position: Double) -> Double {
        guard let document, document.isSynced else { return 250 }
        let next = (document.index(at: position) ?? -1) + 1
        guard document.lines.indices.contains(next) else { return 250 }
        return max(8, min(250, (document.lines[next].time - document.lyricTime(for: position)) * 1000 + 0.5))
    }
}
