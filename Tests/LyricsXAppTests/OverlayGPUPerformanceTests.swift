import AppKit
import Darwin
import Testing
import LyricsXCore
@testable import LyricsXApp

/// Run alone; owns a native window and event pump, never the real music player.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["LYRICSX_GPU_QA"] != nil))
@MainActor struct OverlayGPUPerformanceTests {
    private final class FixtureDelegate: NSObject, NSApplicationDelegate {
        func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
        func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { .terminateCancel }
    }
    @Test func compareNativeOverlayFrameRates() async throws {
        struct Repository: LyricsRepository {
            func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
            func save(_ document: LyricsDocument, for track: Track) async throws {}
        }
        _ = NSApplication.shared
        let delegate = FixtureDelegate(), oldDelegate = NSApp.delegate
        NSApp.delegate = delegate
        defer { NSApp.delegate = oldDelegate; withExtendedLifetime(delegate) {} }
        NSApp.finishLaunching()
        let directory = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["LYRICSX_GPU_QA"]))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.hideWhenPaused = false; prefs.hideOverlayOnHover = false; prefs.overlaySecondaryMode = .both
        let model = AppModel(repository: Repository(), preferences: prefs)
        let track = Track(playerID: "test", playerName: "Test", title: "GPU measurement")
        let document = LyricsDocument(lines: (0..<100).map { index in
            let start = Double(index) * 3
            let text = index.isMultiple(of: 2) ? "Light moves through the glass" : "保持光线与文字流畅清晰"
            return LyricLine(id: index, time: start, text: text, translation: "Independent render fixture",
                words: [.init(text: text, start: start, end: start + 3)])
        })
        model.session.accept(.init(track: track, position: 0, isPlaying: true), shouldSearch: false)
        model.session.use(document, persist: false)
        let overlay = OverlayController(model: model, frameAutosaveName: nil,
            pointerLocation: { .init(x: -10_000, y: -10_000) })
        let screen = try #require(NSScreen.main)
        overlay.panel.setFrameOrigin(.init(x: screen.visibleFrame.midX - 310, y: screen.visibleFrame.midY))
        var phaseAnchor = ProcessInfo.processInfo.systemUptime
        var lastSnapshot = phaseAnchor
        let ticker = PlaybackTicker {
            let now = ProcessInfo.processInfo.systemUptime
            // Real playback provides fresh anchors. Without them the production
            // safety clock correctly freezes extrapolation after three seconds.
            if now - lastSnapshot >= 0.5 {
                model.session.accept(.init(track: track, position: now - phaseAnchor, isPlaying: true, sampledAt: now), now: now)
                lastSnapshot = now
            } else { model.session.tick(now: now) }
            return LyricTickCadence.milliseconds(playing: true, visible: true, document: document, position: model.session.position)
        }
        ticker.start()
        defer { ticker.stop(); overlay.stop(); model.stop() }
        func render(_ seconds: Double) async throws {
            let end = ProcessInfo.processInfo.systemUptime + seconds
            while ProcessInfo.processInfo.systemUptime < end {
                NSApp.updateWindows()
                // Yield to the native main run loop; do not nest an event pump
                // inside Swift Testing's async executor.
                try await Task.sleep(for: .milliseconds(8))
            }
        }
        func frames(in view: NSView) -> [LyricFrameView] {
            (view as? LyricFrameView).map { [$0] } ?? view.subviews.flatMap { frames(in: $0) }
        }
        func cpuTime() -> Double {
            var value = rusage(); getrusage(RUSAGE_SELF, &value)
            return Double(value.ru_utime.tv_sec + value.ru_stime.tv_sec) + Double(value.ru_utime.tv_usec + value.ru_stime.tv_usec) / 1_000_000
        }
        func phase(_ name: String) throws {
            let data = try JSONSerialization.data(withJSONObject: ["phase": name, "pid": ProcessInfo.processInfo.processIdentifier,
                "time": Date().timeIntervalSince1970, "screenMaximumFPS": screen.maximumFramesPerSecond, "scale": screen.backingScaleFactor])
            try data.write(to: directory.appendingPathComponent("phase.json"), options: .atomic)
        }
        try phase("warmup"); try await render(10)
        var measurements: [[String: Any]] = []
        for (index, cap) in [0, 120, 60, 60, 120, 0].enumerated() {
            prefs.overlayVisible = cap != 0
            prefs.overlayFrameRate = cap == 60 ? .sixty : .display
            phaseAnchor = ProcessInfo.processInfo.systemUptime; lastSnapshot = phaseAnchor
            model.session.accept(.init(track: track, position: 0, isPlaying: true, sampledAt: phaseAnchor), now: phaseAnchor)
            try phase("settle"); try await render(1)
            overlay.lyricHostingView.layoutSubtreeIfNeeded()
            overlay.lyricHostingView.displayIfNeeded()
            let active = frames(in: overlay.lyricHostingView).filter(\.deliveringFrames)
            if cap == 0 { #expect(active.isEmpty) }
            else {
                try #require(overlay.panel.isVisible && !active.isEmpty,
                    "No active native render surface; reject this sample instead of reporting an invalid saving.")
                #expect(active.allSatisfy { $0.requestedFrameRate == min(cap, screen.maximumFramesPerSecond) })
            }
            let position = model.session.position
            let name = cap == 0 ? "hidden" : "\(cap)fps"
            try phase(name)
            let epoch = Date().timeIntervalSince1970
            let wall = ProcessInfo.processInfo.systemUptime, cpu = cpuTime()
            try await render(6)
            #expect(model.session.position - position > 5.5)
            let elapsed = ProcessInfo.processInfo.systemUptime - wall
            let value = (cpuTime() - cpu) / elapsed * 100
            measurements.append(["phase": name, "order": index, "cpuPercent": value, "seconds": elapsed, "startedAt": epoch, "screenMaximumFPS": screen.maximumFramesPerSecond])
            try JSONSerialization.data(withJSONObject: measurements, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("cpu.json"), options: .atomic)
            print("GPU QA phase \(name): CPU \(value)%")
        }
        try phase("finished")
        try JSONSerialization.data(withJSONObject: measurements, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("cpu.json"))
    }
}
