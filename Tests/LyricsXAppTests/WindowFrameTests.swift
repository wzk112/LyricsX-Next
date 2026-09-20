import AppKit
import Testing
import SwiftUI
import LyricsXCore
@testable import LyricsXApp

// This suite owns NSApplication's event pump. Run it in its own process so it
// cannot consume other suites' AppKit events or block their async deadlines.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["LYRICSX_WINDOW_QA"] == "1"))
@MainActor struct WindowFrameTests {
    @Test func variableHeightLyricRowsFollowWithoutReverseJumpsOrLateFlight() async throws {
        _ = NSApplication.shared
        NSApp.finishLaunching()
        struct Repository: LyricsRepository {
            func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
            func save(_ document: LyricsDocument, for track: Track) async throws {}
        }
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.reduceMotion = false
        let model = AppModel(repository: Repository(), preferences: prefs)
        let doc = LyricsDocument(lines: (0..<45).map { index in
            .init(id: index, time: Double(index) * 2,
                  text: index.isMultiple(of: 2) ? "Short line \(index)" : "A variable height lyric with several wrapped lines and a stable destination for scrolling \(index)",
                  translation: index.isMultiple(of: 3) ? "翻译第一行\n第二行" : nil)
        })
        model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Scroll fixture"), position: 0, isPlaying: false), shouldSearch: false)
        model.session.use(doc, persist: false); model.mainWindowVisible = true
        let panel = NSPanel(contentRect: .init(x: 40, y: 180, width: 540, height: 480), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: LyricsScrollView(model: model))
        panel.contentView = host; panel.orderFrontRegardless()
        defer { panel.close(); model.stop() }
        func nativeScroll(_ view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView { return scroll }
            return view.subviews.lazy.compactMap { nativeScroll($0) }.first
        }
        func samples(_ count: Int) async throws -> [Double] {
            var offsets: [Double] = []
            for _ in 0..<count {
                runTracking(for: 0.015, mode: .default)
                try await Task.sleep(for: .milliseconds(5))
                let scroll = try #require(nativeScroll(host))
                offsets.append(scroll.contentView.bounds.minY)
            }
            return offsets
        }
        print("Native scroll: mounted")
        _ = try await samples(50)
        print("Native scroll: settled initial rows")
        for index in 1...6 {
            model.session.seek(to: Double(index) * 2); model.updateMainLyricSelection()
            print("Native scroll: follow row \(index)")
            let offsets = try await samples(55)
            let backwards = zip(offsets, offsets.dropFirst()).map { $0 - $1 }.max() ?? 0
            #expect(backwards < 2, "Sequential scroll reversed by \(backwards) points at line \(index)")
            let end = try #require(offsets.last)
            let resting = try await samples(5)
            #expect(resting.allSatisfy { abs($0 - end) < 2 })
        }
        model.session.seek(to: 70); model.updateMainLyricSelection()
        _ = try await samples(15)
        let resting = try await samples(20)
        #expect((resting.max() ?? 0) - (resting.min() ?? 0) < 2)
    }
    private func runTracking(for seconds: Double, mode: RunLoop.Mode = .eventTracking) {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            if let event = NSApp.nextEvent(matching: .any, until: min(end, Date().addingTimeInterval(0.01)), inMode: mode, dequeue: true) {
                NSApp.sendEvent(event)
            }
        }
    }

    @Test func playbackTickerAdvancesDuringTrackingAndCancelsWithoutAQueuedRestart() {
        _ = NSApplication.shared
        var ticks = 0
        let ticker = PlaybackTicker { ticks += 1; return 10 }
        ticker.start()
        runTracking(for: 0.12)
        #expect(ticks > 2)
        ticker.stop()
        let stopped = ticks
        runTracking(for: 0.05)
        #expect(!ticker.running && ticks == stopped)
        ticker.start()
        runTracking(for: 0.05)
        #expect(ticks > stopped)
        ticker.stop()
        let finished = PlaybackTicker { nil }
        finished.start()
        #expect(!finished.running)
    }

    @Test func eachWindowKeepsItsOwnFrameDeliveryDuringMainWindowLifecycle() async throws {
        _ = NSApplication.shared
        NSApp.finishLaunching()
        let screen = try #require(NSScreen.main)
        let main = NSPanel(contentRect: .init(x: screen.visibleFrame.minX + 30, y: screen.visibleFrame.minY + 30, width: 100, height: 60),
                           styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let overlay = NSPanel(contentRect: .init(x: screen.visibleFrame.minX + 140, y: screen.visibleFrame.minY + 30, width: 100, height: 60),
                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        main.isReleasedWhenClosed = false; overlay.isReleasedWhenClosed = false
        main.level = .floating; overlay.level = .floating
        main.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let mainFrames = LyricFrameView(), overlayFrames = LyricFrameView()
        var mainCount = 0, overlayCount = 0
        mainFrames.frameCallback = { mainCount += 1 }; overlayFrames.frameCallback = { overlayCount += 1 }
        mainFrames.running = true; overlayFrames.running = true
        main.contentView = mainFrames; overlay.contentView = overlayFrames
        main.orderFrontRegardless(); overlay.orderFrontRegardless()
        defer { mainFrames.stop(); overlayFrames.stop(); main.close(); overlay.close() }
        for _ in 0..<20 where mainCount == 0 || overlayCount == 0 { runTracking(for: 0.04, mode: .default) }
        #expect(mainCount > 0 && overlayCount > 0)
        #expect(mainFrames.requestedFrameRate == main.screen?.maximumFramesPerSecond)
        #expect(overlayFrames.requestedFrameRate == overlay.screen?.maximumFramesPerSecond)
        overlayFrames.frameRateLimit = 60
        #expect(overlayFrames.requestedFrameRate == min(60, overlay.screen?.maximumFramesPerSecond ?? 60))
        #expect(mainFrames.requestedFrameRate == main.screen?.maximumFramesPerSecond)
        overlayFrames.frameRateLimit = 0
        #expect(overlayFrames.requestedFrameRate == overlay.screen?.maximumFramesPerSecond)
        NotificationCenter.default.post(name: NSWindow.didChangeScreenNotification, object: overlay)
        #expect(overlayFrames.requestedFrameRate == overlay.screen?.maximumFramesPerSecond)
        let before = overlayCount
        let started = ProcessInfo.processInfo.systemUptime
        runTracking(for: 0.5)
        let measured = Double(overlayCount - before) / (ProcessInfo.processInfo.systemUptime - started)
        #expect(overlayCount > before)
        // Notifications are scoped to their actual window, including the
        // interval before AppKit has finished minimizing or taking a snapshot.
        NotificationCenter.default.post(name: NSWindow.willMiniaturizeNotification, object: main)
        let frozen = mainCount, continuing = overlayCount
        runTracking(for: 0.12)
        #expect(!mainFrames.deliveringFrames && overlayFrames.deliveringFrames)
        #expect(mainCount == frozen && overlayCount > continuing)
        NotificationCenter.default.post(name: NSWindow.didDeminiaturizeNotification, object: main)
        runTracking(for: 0.08)
        #expect(mainCount > frozen)
        main.close()
        let closed = mainCount, overlayBefore = overlayCount
        runTracking(for: 0.08)
        #expect(mainCount == closed && overlayCount > overlayBefore)
        overlayFrames.running = false
        let paused = overlayCount
        runTracking(for: 0.05)
        #expect(overlayCount == paused && !overlayFrames.deliveringFrames)
        print(String(format: "Native frame delivery: requested %d Hz; measured %.1f callbacks/s; tracking and main-window minimize/close preserved overlay callbacks",
                     overlayFrames.requestedFrameRate, measured))
    }
    @Test func lyricListResetsForPreludeCachedTrackChangeAndLateLoading() async throws {
        _ = NSApplication.shared
        NSApp.finishLaunching()
        struct Repository: LyricsRepository {
            func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> {
                AsyncThrowingStream { $0.finish() }
            }
            func save(_ document: LyricsDocument, for track: Track) async throws {}
        }
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.reduceMotion = true
        let model = AppModel(repository: Repository(), preferences: prefs)
        let first = Track(playerID: "test", playerName: "Test", title: "First", duration: 200)
        let second = Track(playerID: "test", playerName: "Test", title: "Second", duration: 200)
        let doc = LyricsDocument(lines: (0..<40).map {
            .init(id: $0, time: 10 + Double($0) * 3, text: "Original fixture line \($0)")
        })
        model.session.accept(.init(track: first, position: 75, isPlaying: false), shouldSearch: false)
        model.session.use(doc, persist: false)
        model.mainWindowVisible = true
        let panel = NSPanel(contentRect: .init(x: 40, y: 180, width: 540, height: 480),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        let host = NSHostingView(rootView: LyricsScrollView(model: model))
        panel.contentView = host; panel.orderFrontRegardless()
        defer { panel.close(); model.stop() }
        func settle() async throws {
            for _ in 0..<12 {
                runTracking(for: 0.025, mode: .default)
                try await Task.sleep(for: .milliseconds(5))
            }
        }
        func scrollView(_ view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView { return scroll }
            return view.subviews.lazy.compactMap { scrollView($0) }.first
        }
        func offset() throws -> CGFloat {
            let scroll = try #require(scrollView(host))
            return scroll.contentView.bounds.minY
        }
        try await settle()
        #expect(try offset() > 300)
        model.session.seek(to: 0); model.updateMainLyricSelection()
        try await settle()
        #expect(model.mainLyricIndex == nil)
        #expect(try abs(offset()) < 2)

        model.session.seek(to: 75); model.updateMainLyricSelection()
        try await settle()
        #expect(try offset() > 300)
        // A cached document can arrive in the same UI update and reuse its ID.
        // Leave the old main selection until the next tick to expose that race.
        model.session.accept(.init(track: second, position: 0, isPlaying: false), shouldSearch: false)
        model.session.use(doc, persist: false)
        try await settle()
        #expect(try abs(offset()) < 2)
        model.updateMainLyricSelection()

        model.session.seek(to: 75); model.updateMainLyricSelection()
        try await settle()
        model.session.accept(.init(track: first, position: 0, isPlaying: false), shouldSearch: false)
        model.updateMainLyricSelection()
        try await settle()
        #expect(scrollView(host) == nil)
        model.session.use(doc, persist: false); model.updateMainLyricSelection()
        try await settle()
        #expect(try abs(offset()) < 2)
        model.mainWindowVisible = false
        model.session.seek(to: 75); model.updateMainLyricSelection()
        model.mainWindowVisible = true
        try await settle()
        #expect(try offset() > 300)
        prefs.reduceMotion = false
        model.session.seek(to: 0); model.updateMainLyricSelection()
        try await settle()
        model.session.seek(to: 75); model.updateMainLyricSelection()
        runTracking(for: 0.05, mode: .default)
        model.session.accept(.init(track: second, position: 0, isPlaying: false), shouldSearch: false)
        model.session.use(doc, persist: false); model.updateMainLyricSelection()
        try await settle()
        #expect(try abs(offset()) < 2)
        try await settle()
        #expect(try abs(offset()) < 2)
        print("Native lyric scrolling: prelude, cached song change, late loading, window return and interrupted animation passed")
    }

}
