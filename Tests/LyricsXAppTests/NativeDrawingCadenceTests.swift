import AppKit
import Darwin
import SwiftUI
import Testing
import LyricsXCore
@testable import LyricsXApp

/// Count production text renderer draws, separately from display-link callbacks.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["LYRICSX_DRAW_CADENCE"] != nil))
@MainActor struct NativeDrawingCadenceTests {
    private final class Samples: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [Double] = []
        func record() {
            let time = ProcessInfo.processInfo.systemUptime
            lock.lock(); defer { lock.unlock() }
            if time - (values.last ?? 0) > 0.002 { values.append(time) }
        }
        func read() -> [Double] { lock.lock(); defer { lock.unlock() }; return values }
    }
    private struct MeasuredRenderer: TextRenderer {
        let base: HeldNoteRenderer
        let samples: Samples
        var displayPadding: EdgeInsets { base.displayPadding }
        func draw(layout: Text.Layout, in context: inout GraphicsContext) {
            base.draw(layout: layout, in: &context)
            samples.record()
        }
    }
    @Test(arguments: [false, true]) func nativeGlassTextDrawCadence(dark: Bool) async throws {
        _ = NSApplication.shared; NSApp.finishLaunching()
        let samples = Samples()
        let panel = DraggableOverlayPanel(contentRect: .init(x: 200, y: 250, width: 620, height: 190),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false; panel.level = .floating
        panel.isOpaque = false; panel.backgroundColor = .clear
        panel.keepsGlassAppearanceActive = true
        panel.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let root = NSView(frame: .init(origin: .zero, size: panel.frame.size))
        let glass = OverlayGlassBackground(frame: root.bounds.insetBy(dx: 6, dy: 6))
        glass.appearance = panel.appearance
        glass.configure(appearance: .glass, transparency: 0.26, frostAmount: 0.55, reduceTransparency: false, reduceMotion: true)
        root.addSubview(glass)
        let text = "让文字连续流动 · Light moves smoothly"
        let line = LyricLine(id: 0, time: 0, text: text, words: [.init(text: text, start: 0, end: 4)])
        let typography = LyricTypography().adaptedForGlass(dark: dark)
        let anchor = ProcessInfo.processInfo.systemUptime
        let view = LyricRenderTimeline(running: true, sampledTime: 0,
            preciseTime: { ProcessInfo.processInfo.systemUptime - anchor }) { elapsed in
                TimedLyricLabel(line: line, text: text, ink: .white)
                    .textRenderer(MeasuredRenderer(base: .init(time: elapsed.truncatingRemainder(dividingBy: 4),
                        options: .init(lift: true, glow: true, hdr: true, hdrBrightness: 3),
                        alignment: .center, wordColors: typography.wordColors), samples: samples))
                    .font(.system(size: 26, weight: .semibold)).multilineTextAlignment(.center)
                    .allowedDynamicRange(.high)
                    .frame(width: 540, height: 140).padding(40)
        }
        .preference(key: LyricHDRContentHeadroomKey.self, value: 3)
        .hdrDisplayScope(requested: true)
        let host = NSHostingView(rootView: view); host.frame = root.bounds; host.sizingOptions = []
        root.addSubview(host); panel.contentView = root; panel.orderFrontRegardless()
        defer { panel.orderOut(nil); panel.contentView = nil }
        let end = ProcessInfo.processInfo.systemUptime + 8
        while ProcessInfo.processInfo.systemUptime < end {
            NSApp.updateWindows()
            try await Task.sleep(for: .milliseconds(8))
        }
        let frames = samples.read().filter { $0 > anchor + 1 }
        let intervals = zip(frames, frames.dropFirst()).map { ($1 - $0) * 1000 }.sorted()
        try #require(intervals.count > 100)
        let data = try JSONSerialization.data(withJSONObject: ["dark": dark, "draws": intervals.count,
            "medianMS": intervals[intervals.count / 2], "p95MS": intervals[Int(Double(intervals.count - 1) * 0.95)],
            "maxMS": intervals.last!, "screenMaximumFPS": panel.screen?.maximumFramesPerSecond ?? 0], options: [.prettyPrinted, .sortedKeys])
        let path = try #require(ProcessInfo.processInfo.environment["LYRICSX_DRAW_CADENCE"])
        try data.write(to: URL(fileURLWithPath: path + (dark ? ".dark.json" : ".light.json")))
        print(String(decoding: data, as: UTF8.self))
    }
}
