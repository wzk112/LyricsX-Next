import AppKit
import Testing
import SwiftUI
import LyricsXCore
@testable import LyricsXApp

// A CLI test process is not guaranteed to receive WindowServer exposure. Inject
// only that compositor signal; visibility, native ordering, the real player
// host, overlay and display links continue through the production paths.
private final class CloseQAWindow: NSWindow {
    override var occlusionState: NSWindow.OcclusionState { isVisible ? .visible : [] }
}

// Tracking-mode QA owns NSApplication's event pump. Run it in its own process
// so it cannot consume other suites' events or block their async deadlines.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["LYRICSX_WINDOW_QA"] == "1"))
@MainActor struct WindowFrameTests {
    private final class FixtureDelegate: NSObject, NSApplicationDelegate {
        func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
        func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { .terminateCancel }
    }
    // Keep the AppKit delegate alive for the whole isolated suite.
    private static let fixtureDelegate = FixtureDelegate()
    private static var launched = false
    init() {
        _ = NSApplication.shared
        NSApp.delegate = Self.fixtureDelegate
        if !Self.launched { NSApp.finishLaunching(); Self.launched = true }
    }

    @Test func compactExpandedResizeKeepsLyricViewportForTheSameSong() async throws {
        _ = NSApplication.shared
        struct Repository: LyricsRepository {
            func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
            func save(_ document: LyricsDocument, for track: Track) async throws {}
        }
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(repository: Repository(), preferences: Preferences(defaults: defaults))
        defer { model.stop() }
        let track = Track(playerID: "fixture", playerName: "Fixture", title: "Layout fixture", duration: 160)
        let document = LyricsDocument(lines: (0..<80).map {
            .init(id: $0, time: Double($0) * 2, text: "A stable lyric line \($0)")
        })
        model.session.accept(.init(track: track, position: 20, isPlaying: false), shouldSearch: false)
        model.session.use(document, persist: false)
        model.mainWindowVisible = true
        let panel = NSPanel(contentRect: .init(x: 40, y: 180, width: 760, height: 600),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: NowPlayingView(model: model))
        panel.contentView = host
        panel.orderFrontRegardless()
        defer { panel.close() }
        func lyricScroll(_ view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView { return scroll }
            return view.subviews.lazy.compactMap { lyricScroll($0) }.first
        }
        func mountedScroll() async throws -> NSScrollView {
            for _ in 0..<30 {
                NSApp.updateWindows()
                host.layoutSubtreeIfNeeded()
                if let scroll = lyricScroll(host) { return scroll }
                try await Task.sleep(for: .milliseconds(10))
            }
            return try #require(lyricScroll(host))
        }
        let compactScroll = try await mountedScroll()
        compactScroll.contentView.scroll(to: .init(x: 0, y: 350))
        compactScroll.reflectScrolledClipView(compactScroll.contentView)
        #expect(compactScroll.contentView.bounds.minY > 100)
        panel.setContentSize(.init(width: 820, height: 600))
        let expandedScroll = try await mountedScroll()
        #expect(expandedScroll === compactScroll, "Layout changes must preserve the lyric scroll view")
        #expect(expandedScroll.contentView.bounds.minY > 100)
        panel.setContentSize(.init(width: 760, height: 600))
        let compactAgain = try await mountedScroll()
        #expect(compactAgain === compactScroll)
        #expect(compactAgain.contentView.bounds.minY > 100)
    }

    @Test func variableHeightLyricRowsFollowWithoutReverseJumpsOrLateFlight() async throws {
        _ = NSApplication.shared
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
        func samples(_ count: Int, row: NSView? = nil) async throws -> [Double] {
            var offsets: [Double] = []
            for _ in 0..<count {
                NSApp.updateWindows(); host.layoutSubtreeIfNeeded()
                try await Task.sleep(for: .milliseconds(20))
                let scroll = try #require(nativeScroll(host))
                if let row {
                    try #require(row.window === panel)
                    offsets.append(panel.convertToScreen(row.convert(row.bounds, to: nil)).midY)
                } else { offsets.append(scroll.contentView.bounds.minY) }
            }
            return offsets
        }
        print("Native scroll: mounted")
        _ = try await samples(50)
        print("Native scroll: settled initial rows")
        func frame(_ row: NSView) -> NSRect { panel.convertToScreen(row.convert(row.bounds, to: nil)) }
        let rowsHost = try #require(nativeScroll(host)?.documentView)
        var currentRow = try #require(lyricButtons(in: rowsHost).max { frame($0).midY < frame($1).midY })
        for index in 1...6 {
            // Follow the same mounted native button throughout the animation.
            // Raw scroll offsets can jump when LazyVStack refines offscreen
            // height estimates even while the visible row stays stationary.
            let previousY = frame(currentRow).midY
            currentRow = try #require(lyricButtons(in: rowsHost).filter { frame($0).midY < previousY - 1 }
                .max { frame($0).midY < frame($1).midY })
            model.session.seek(to: Double(index) * 2); model.updateMainLyricSelection()
            print("Native scroll: follow row \(index)")
            #expect(model.mainLyricIndex == index)
            let offsets = try await samples(55, row: currentRow)
            let backwards = zip(offsets, offsets.dropFirst()).map { $0 - $1 }.max() ?? 0
            print("Native row \(index): maximum reverse=\(backwards), final=\(offsets.last ?? 0)")
            #expect(backwards < 2, "Sequential scroll reversed by \(backwards) points at line \(index)")
            let end = try #require(offsets.last)
            let resting = try await samples(5, row: currentRow)
            #expect(resting.allSatisfy { abs($0 - end) < 2 })
        }
        model.session.seek(to: 70); model.updateMainLyricSelection()
        _ = try await samples(15)
        #expect(model.mainLyricIndex == 35)
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

    private func lyricButtons(in view: NSView) -> [NSView] {
        let own = String(describing: type(of: view)).contains("FocusRingView") && view.bounds.height > 20
            ? [view] : []
        return own + view.subviews.flatMap { lyricButtons(in: $0) }
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

    @Test func realMainWindowCloseKeepsOverlayFramesAndCueClockMoving() async throws {
        _ = NSApplication.shared
        struct Repository: LyricsRepository {
            func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
            func save(_ document: LyricsDocument, for track: Track) async throws {}
        }
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlayVisible = true; prefs.hideWhenPaused = false; prefs.hideOverlayOnHover = false
        prefs.lyricHDR = true; prefs.lyricHDRBrightness = 3.5
        let model = AppModel(repository: Repository(), preferences: prefs)
        let lines = (0..<80).map { index in
            LyricLine(id: index, time: Double(index) * 3, text: "A continuously moving lyric line \(index)",
                words: [.init(text: "A continuously moving lyric line \(index)",
                    start: Double(index) * 3, end: Double(index + 1) * 3)])
        }
        model.session.accept(.init(track: .init(playerID: "fixture", playerName: "Fixture", title: "Window closing fixture", duration: 240),
            position: 1, isPlaying: true), shouldSearch: false)
        model.session.use(.init(lines: lines), persist: false)
        let overlay = OverlayController(model: model, frameAutosaveName: nil,
            pointerLocation: { .init(x: -10_000, y: -10_000) })
        model.overlay = overlay
        model.startLyricClock()
        let owner = MainWindowController(model: model, frameAutosaveName: nil, makeWindow: {
            CloseQAWindow(contentRect: .init(x: 40, y: 40, width: 760, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
        })
        owner.show()
        let main = try #require(owner.window)
        main.level = .floating
        let host = try #require(main.contentView)
        let probe = LyricFrameView(frame: .init(x: 0, y: 0, width: 1, height: 1))
        probe.running = true
        try #require(overlay.panel.contentView).addSubview(probe)
        defer { probe.stop(); owner.stop(); model.stop() }
        func pump(for seconds: Double) async throws {
            let until = ProcessInfo.processInfo.systemUptime + seconds
            while ProcessInfo.processInfo.systemUptime < until {
                NSApp.updateWindows()
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        try await pump(for: 1)
        #expect(model.mainWindowVisible && probe.deliveringFrames)
        var times: [Double] = []
        probe.frameCallback = { _ in times.append(ProcessInfo.processInfo.systemUptime) }
        try await pump(for: 0.5)
        let baseline = zip(times, times.dropFirst()).map { $1 - $0 }.max() ?? 0
        #expect(times.count > 5)
        let position = model.session.position
        let closeStart = ProcessInfo.processInfo.systemUptime
        main.performClose(nil)
        let closeDuration = ProcessInfo.processInfo.systemUptime - closeStart
        try await pump(for: 0.9)
        let closing = zip(times, times.dropFirst()).filter { $1 >= closeStart }.map { $1 - $0 }.max() ?? 0
        #expect(!model.mainWindowVisible && probe.deliveringFrames)
        #expect(!main.isVisible && main.contentView === host)
        #expect(model.session.position > position + 0.7)
        #expect(closing < max(0.12, baseline * 3), "Closing blocked overlay delivery for \(closing)s; baseline \(baseline)s")
        print("Real main close: duration=\(closeDuration)s, baseline frame gap=\(baseline)s, closing gap=\(closing)s")
        main.makeKeyAndOrderFront(nil); main.orderFrontRegardless()
        try await pump(for: 0.2)
        #expect(model.mainWindowVisible && main.contentView === host)
        // Both the menu's Close action and the native red control use this
        // responder action; closing repeatedly must keep the same host.
        main.standardWindowButton(.closeButton)?.performClick(nil)
        try await pump(for: 0.1)
        #expect(!model.mainWindowVisible && !main.isVisible && main.contentView === host)
    }

    @Test func eachWindowKeepsItsOwnFrameDeliveryDuringMainWindowLifecycle() async throws {
        _ = NSApplication.shared
        let screen = try #require(NSScreen.main)
        let main = NSPanel(contentRect: .init(x: screen.visibleFrame.minX + 30, y: screen.visibleFrame.minY + 30, width: 100, height: 60),
                           styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let overlay = DraggableOverlayPanel(contentRect: .init(x: screen.visibleFrame.minX + 140, y: screen.visibleFrame.minY + 30, width: 100, height: 60),
                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        main.isReleasedWhenClosed = false; overlay.isReleasedWhenClosed = false
        main.level = .floating; overlay.level = .floating
        main.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let mainFrames = LyricFrameView(), overlayFrames = LyricFrameView()
        var mainCount = 0, overlayCount = 0
        mainFrames.frameCallback = { _ in mainCount += 1 }; overlayFrames.frameCallback = { _ in overlayCount += 1 }
        mainFrames.running = true; overlayFrames.running = true
        main.contentView = mainFrames; overlay.contentView = overlayFrames
        main.orderFrontRegardless(); overlay.orderFrontRegardless()
        defer { mainFrames.stop(); overlayFrames.stop(); main.close(); overlay.close() }
        for _ in 0..<20 where mainCount == 0 || overlayCount == 0 { runTracking(for: 0.04) }
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
        for _ in 0..<3 {
            overlay.orderOut(nil)
            try await Task.sleep(for: .milliseconds(20))
            #expect(!overlayFrames.deliveringFrames)
            let hiddenCount = overlayCount
            runTracking(for: 0.04)
            #expect(overlayCount == hiddenCount)
            overlay.orderFrontRegardless()
            try await Task.sleep(for: .milliseconds(20))
            runTracking(for: 0.08)
            #expect(overlayFrames.deliveringFrames && overlayCount > hiddenCount)
        }
        overlayFrames.running = false
        let paused = overlayCount
        runTracking(for: 0.05)
        #expect(overlayCount == paused && !overlayFrames.deliveringFrames)
        print(String(format: "Native frame delivery: requested %d Hz; measured %.1f callbacks/s; tracking and main-window minimize/close preserved overlay callbacks",
                     overlayFrames.requestedFrameRate, measured))
    }
    @Test func lyricListResetsForPreludeCachedTrackChangeAndLateLoading() async throws {
        _ = NSApplication.shared
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
                NSApp.updateWindows(); host.layoutSubtreeIfNeeded()
                try await Task.sleep(for: .milliseconds(30))
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
        func expectPreludeAnchor() throws {
            let scroll = try #require(scrollView(host))
            let fraction = prefs.mainLyricPlacement.fraction
            // At the prelude the first document row is the topmost native
            // button. Measure its real frame without relying on in-process AX.
            let frames = lyricButtons(in: host).map { panel.convertToScreen($0.convert($0.bounds, to: nil)) }
            let screenFrame = try #require(frames.max { $0.maxY < $1.maxY })
            let viewport = panel.convertToScreen(scroll.contentView.convert(scroll.contentView.bounds, to: nil))
            let rowAnchor = viewport.maxY - screenFrame.maxY + screenFrame.height * fraction
            #expect(abs(rowAnchor - viewport.height * fraction) < 3,
                "Prelude row anchor \(rowAnchor), viewport \(viewport.height), fraction \(fraction)")
        }
        try await settle()
        #expect(try offset() > 300)
        model.session.seek(to: 0); model.updateMainLyricSelection()
        try await settle()
        #expect(model.mainLyricIndex == nil)
        try expectPreludeAnchor()

        model.session.seek(to: 75); model.updateMainLyricSelection()
        try await settle()
        #expect(try offset() > 300)
        // A cached document can arrive in the same UI update and reuse its ID.
        // Leave the old main selection until the next tick to expose that race.
        model.session.accept(.init(track: second, position: 0, isPlaying: false), shouldSearch: false)
        model.session.use(doc, persist: false)
        try await settle()
        try expectPreludeAnchor()
        model.updateMainLyricSelection()

        model.session.seek(to: 75); model.updateMainLyricSelection()
        try await settle()
        model.session.accept(.init(track: first, position: 0, isPlaying: false), shouldSearch: false)
        model.updateMainLyricSelection()
        try await settle()
        #expect(scrollView(host) == nil)
        model.session.use(doc, persist: false); model.updateMainLyricSelection()
        try await settle()
        try expectPreludeAnchor()
        model.mainWindowVisible = false
        model.session.seek(to: 75); model.updateMainLyricSelection()
        model.mainWindowVisible = true
        try await settle()
        #expect(try offset() > 300)
        prefs.reduceMotion = false
        model.session.seek(to: 0); model.updateMainLyricSelection()
        try await settle()
        model.session.seek(to: 75); model.updateMainLyricSelection()
        try await Task.sleep(for: .milliseconds(50))
        model.session.accept(.init(track: second, position: 0, isPlaying: false), shouldSearch: false)
        model.session.use(doc, persist: false); model.updateMainLyricSelection()
        try await settle()
        try expectPreludeAnchor()
        try await settle()
        try expectPreludeAnchor()
        print("Native lyric scrolling: prelude, cached song change, late loading, window return and interrupted animation passed")
    }

}
