import AppKit
import Darwin
import SwiftUI
import Testing
import LyricsXCore
@testable import LyricsXApp

/// Measures evaluations of the production moving lyric surface, not an idle
/// display-link probe. Runs alone and never connects to the user's player.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["LYRICSX_OVERLAY_MOTION_QA"] != nil))
@MainActor struct OverlayMotionPerformanceTests {
    private final class Clock {
        var anchor = ProcessInfo.processInfo.systemUptime
        var evaluations: [Double] = []
        func now() -> Double {
            let value = ProcessInfo.processInfo.systemUptime
            if value - (evaluations.last ?? 0) > 0.002 { evaluations.append(value) }
            return value
        }
    }

    @Test(arguments: [false, true]) func measureUntranslatedPromotionAndDeparture(timed: Bool) async throws {
        _ = NSApplication.shared
        NSApp.finishLaunching()
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlaySecondaryMode = .next
        let samples = ["Let the light move across every word", "The next line rises into view", "星の光をたどって", "保持文字的移动连续自然"]
        let doc = LyricsDocument(lines: (0..<30).map { index in
            let start = Double(index) * 1.5, text = samples[index % samples.count]
            return .init(id: index, time: start, text: text,
                words: timed ? [.init(text: text, start: start, end: start + 1.45)] : [])
        })
        let clock = Clock()
        let panel = DraggableOverlayPanel(contentRect: .init(x: 100, y: 250, width: 620, height: 220),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false; panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        func content(_ index: Int) -> some View {
            OverlayLyricsContent(preferences: prefs, document: doc, index: index,
                lyricTime: { ProcessInfo.processInfo.systemUptime - clock.anchor }, playing: true,
                adaptiveCanvasWidth: 560, animationTime: { clock.now() })
                .frame(width: 560).padding(30).foregroundStyle(.white).background(.black)
                .environment(\.lyricFrameRateLimit, 0)
        }
        let host = NSHostingView(rootView: content(0))
        panel.contentView = host; panel.orderFrontRegardless()
        defer { panel.orderOut(nil); panel.contentView = nil }
        func cpu() -> Double {
            var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
            return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
                + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
        }
        var index = 0
        var starts: [Double] = []
        let start = ProcessInfo.processInfo.systemUptime, cpuStart = cpu()
        while ProcessInfo.processInfo.systemUptime - start < 10 {
            let elapsed = ProcessInfo.processInfo.systemUptime - clock.anchor
            let next = min(doc.lines.count - 1, Int(elapsed / 1.5))
            if next != index {
                index = next; starts.append(ProcessInfo.processInfo.systemUptime)
                host.rootView = content(index)
            }
            NSApp.updateWindows()
            try await Task.sleep(for: .milliseconds(8))
        }
        let intervals = starts.dropFirst().flatMap { start in
            let values = clock.evaluations.filter { $0 >= start + 0.015 && $0 < start + 0.6 }
            return zip(values, values.dropFirst()).map { ($1 - $0) * 1000 }
        }.sorted()
        try #require(intervals.count > 60, "Moving lyric surface did not receive frames")
        let result: [String: Any] = ["wordTiming": timed, "samples": intervals.count, "medianMS": intervals[intervals.count / 2],
            "p95MS": intervals[Int(Double(intervals.count - 1) * 0.95)], "maxMS": intervals.last!,
            "cpuPercent": (cpu() - cpuStart) / (ProcessInfo.processInfo.systemUptime - start) * 100,
            "screenMaximumFPS": panel.screen?.maximumFramesPerSecond ?? 0]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        let path = try #require(ProcessInfo.processInfo.environment["LYRICSX_OVERLAY_MOTION_QA"])
        try data.write(to: URL(fileURLWithPath: path + (timed ? ".timed.json" : ".plain.json")))
    }
}
