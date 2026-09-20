import AppKit
import Darwin
import SwiftUI
import Testing
import LyricsXCore
@testable import LyricsXApp

/// Opt-in native playback fixture; does not connect to or seek a music player.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["LYRICSX_PLAYBACK_QA"] != nil))
@MainActor struct PlaybackPerformanceTests {
    private final class FixtureDelegate: NSObject, NSApplicationDelegate {
        func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
        func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { .terminateCancel }
    }
    private struct Repository: LyricsRepository {
        func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
        func save(_ document: LyricsDocument, for track: Track) async throws {}
    }
    @Test func measurePlayingAndTrackHandover() async throws {
        _ = NSApplication.shared
        let delegate = FixtureDelegate(), oldDelegate = NSApp.delegate
        NSApp.delegate = delegate
        defer { NSApp.delegate = oldDelegate; withExtendedLifetime(delegate) {} }
        NSApp.finishLaunching()
        let directory = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["LYRICSX_PLAYBACK_QA"]))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.hideOverlayOnHover = false; prefs.hideWhenPaused = false
        let model = AppModel(repository: Repository(), preferences: prefs)
        let main = NSPanel(contentRect: .init(x: 40, y: 80, width: 960, height: 640),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        main.isReleasedWhenClosed = false
        main.level = .floating
        main.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let host = NSHostingView(rootView: ZStack {
            AmbientBackground(artwork: model.artwork)
            NowPlayingView(model: model)
        }.foregroundStyle(.white).preferredColorScheme(.dark).hdrDisplayScope(requested: true))
        let root = NSView(frame: main.contentLayoutRect)
        host.frame = root.bounds; host.autoresizingMask = [.width, .height]
        root.addSubview(host); main.contentView = root
        main.orderFrontRegardless(); model.mainWindowVisible = true
        let overlay = OverlayController(model: model, frameAutosaveName: nil, pointerLocation: { .init(x: -10_000, y: -10_000) })
        overlay.panel.setFrameOrigin(.init(x: 650, y: 750))
        // Large compressed artwork exercises the same production decode path.
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2400, pixelsHigh: 2400,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let pixels = try #require(bitmap.bitmapData)
        for y in 0..<2400 { for x in 0..<2400 {
            let offset = y * bitmap.bytesPerRow + x * 4
            pixels[offset] = UInt8(x % 256); pixels[offset + 1] = UInt8(y % 256)
            pixels[offset + 2] = UInt8((x + y) % 256); pixels[offset + 3] = 255
        } }
        let bytes = try #require(bitmap.representation(using: .png, properties: [:]))
        func document() -> LyricsDocument {
            LyricsDocument(lines: (0..<100).map { index in
                let start = Double(index) * 2
                let text = index.isMultiple(of: 2) ? "Let the light move smoothly across every word" : "保持文字与辉光的动画流畅自然"
                return .init(id: index, time: start, text: text, translation: "Independent playback performance fixture",
                    words: [.init(text: text, start: start, end: start + 1.85)])
            })
        }
        var track = Track(playerID: "test", playerName: "Test", title: "Performance 0", duration: 200, artworkData: bytes)
        var anchor = ProcessInfo.processInfo.systemUptime
        var lastSnapshot = anchor
        var handoverMilliseconds: [Double] = []
        func replace(_ index: Int) {
            track = Track(playerID: "test", playerName: "Test", title: "Performance \(index)", duration: 200, artworkData: bytes)
            anchor = ProcessInfo.processInfo.systemUptime; lastSnapshot = anchor
            model.bridge.onSnapshot?(.init(track: track, position: 0, isPlaying: true, sampledAt: anchor))
            model.session.use(document(), persist: false); model.updateMainLyricSelection()
            handoverMilliseconds.append((ProcessInfo.processInfo.systemUptime - anchor) * 1000)
        }
        replace(0)
        let ticker = PlaybackTicker {
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastSnapshot >= 0.5 {
                model.session.accept(.init(track: track, position: now - anchor, isPlaying: true, sampledAt: now), now: now)
                lastSnapshot = now
            } else { model.session.tick(now: now) }
            model.updateMainLyricSelection()
            return 16
        }
        ticker.start()
        let probe = LyricFrameView(frame: .zero)
        main.contentView?.addSubview(probe)
        var intervals: [Double] = [], previous = 0.0
        probe.frameCallback = {
            let now = ProcessInfo.processInfo.systemUptime
            if previous > 0 { intervals.append((now - previous) * 1000) }
            previous = now
        }
        probe.running = true
        let exposureEnd = Date().addingTimeInterval(0.5)
        while Date() < exposureEnd {
            if let event = NSApp.nextEvent(matching: .any, until: Date().addingTimeInterval(0.01), inMode: .default, dequeue: true) {
                NSApp.sendEvent(event)
            }
        }
        defer { probe.stop(); ticker.stop(); overlay.stop(); main.close(); model.stop() }
        func render(_ seconds: Double) async throws {
            let end = ProcessInfo.processInfo.systemUptime + seconds
            while ProcessInfo.processInfo.systemUptime < end {
                NSApp.updateWindows()
                try await Task.sleep(for: .milliseconds(8))
            }
        }
        try String(ProcessInfo.processInfo.processIdentifier).write(to: directory.appendingPathComponent("pid"), atomically: true, encoding: .utf8)
        try await render(3)
        func cpuTime() -> Double {
            var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
            return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
                + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
        }
        var results: [[String: Any]] = []
        for switching in [false, true] {
            intervals = []; previous = 0
            let wallStart = ProcessInfo.processInfo.systemUptime, cpuStart = cpuTime()
            for index in 1...6 {
                if switching { replace(index) }
                try await render(1.5)
            }
            let sorted = intervals.sorted()
            print("Probe state: callbacks=\(sorted.count), visible=\(model.mainWindowVisible), delivering=\(probe.deliveringFrames), window=\(probe.window != nil), exposed=\(main.occlusionState.contains(.visible))")
            try #require(sorted.count > 100 && model.mainWindowVisible && probe.deliveringFrames)
            results.append(["phase": switching ? "switching" : "playing", "callbacks": sorted.count,
                "cpuPercent": (cpuTime() - cpuStart) / (ProcessInfo.processInfo.systemUptime - wallStart) * 100,
                "p50ms": sorted[sorted.count / 2], "p95ms": sorted[Int(Double(sorted.count) * 0.95)],
                "maxMs": sorted.last!, "over25ms": sorted.filter { $0 > 25 }.count])
        }
        // The full native lyric/cover hierarchy, not just two idle probes.
        // Keep recording the floating window while the main window is removed.
        let overlayProbe = LyricFrameView(frame: .zero)
        overlay.lyricHostingView.addSubview(overlayProbe)
        var overlayTimes: [Double] = []
        overlayProbe.frameCallback = { overlayTimes.append(ProcessInfo.processInfo.systemUptime) }
        overlayProbe.running = true
        defer { overlayProbe.stop(); overlayProbe.removeFromSuperview() }
        prefs.followArtworkColors = true
        for iteration in 0..<4 {
            main.orderFrontRegardless(); model.mainWindowVisible = true
            replace(iteration + 20)
            try await render(0.08)
            overlayTimes = []
            main.orderOut(nil); model.mainWindowVisible = false
            try await render(0.85)
            let gaps = zip(overlayTimes, overlayTimes.dropFirst()).map { ($1 - $0) * 1000 }.sorted()
            try #require(gaps.count > 10 && overlayProbe.deliveringFrames)
            results.append(["phase": "close-during-switch-\(iteration)", "callbacks": gaps.count,
                "p50ms": gaps[gaps.count / 2], "p95ms": gaps[Int(Double(gaps.count - 1) * 0.95)], "maxMs": gaps.last!])
        }
        let output: [String: Any] = ["phases": results, "handoverMainThreadMs": handoverMilliseconds,
            "requestedFPS": probe.requestedFrameRate]
        try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("result.json"))
        print("Playback QA: \(output)")
    }
}
