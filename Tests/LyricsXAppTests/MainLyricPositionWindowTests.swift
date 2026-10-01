import AppKit
import Foundation
import SwiftUI
import Testing
import LyricsXCore
@testable import LyricsXApp

// This suite owns the AppKit event pump. Run it alone with LYRICSX_WINDOW_QA=1.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["LYRICSX_WINDOW_QA"] == "1"))
@MainActor struct MainLyricPositionWindowTests {
    private final class FixtureDelegate: NSObject, NSApplicationDelegate {
        func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
        func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { .terminateCancel }
    }
    @Test func actualMainRowsReachUpperAnchorAtBothEndsAndAfterReflow() async throws {
        _ = NSApplication.shared
        let delegate = FixtureDelegate(), oldDelegate = NSApp.delegate
        NSApp.delegate = delegate
        defer { NSApp.delegate = oldDelegate; withExtendedLifetime(delegate) {} }
        NSApp.finishLaunching()
        struct Repository: LyricsRepository {
            func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
            func save(_ document: LyricsDocument, for track: Track) async throws {}
        }
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        preferences.reduceMotion = true
        let model = AppModel(repository: Repository(), preferences: preferences)
        let doc = LyricsDocument(lines: (0..<35).map { index in
            .init(id: index, time: 5 + Double(index) * 2,
                  text: index.isMultiple(of: 2) ? "Short lyric \(index)" : "A long primary lyric that wraps across several lines in this viewport \(index)",
                  translation: "译文第一行 \(index)\n译文第二行\n译文第三行")
        })
        model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Position fixture"), position: 0, isPlaying: false), shouldSearch: false)
        model.session.use(doc, persist: false)
        model.mainWindowVisible = true
        let panel = NSPanel(contentRect: .init(x: 40, y: 180, width: 540, height: 480),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: LyricsScrollView(model: model))
        panel.contentView = host
        panel.orderFrontRegardless()
        defer { panel.close(); model.stop() }

        func settle() async throws {
            for _ in 0..<20 {
                NSApp.updateWindows()
                host.layoutSubtreeIfNeeded()
                let until = Date().addingTimeInterval(0.012)
                while Date() < until {
                    if let event = NSApp.nextEvent(matching: .any, until: until, inMode: .default, dequeue: true) { NSApp.sendEvent(event) }
                }
                try await Task.sleep(for: .milliseconds(5))
            }
        }
        func scrollView(_ view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView { return scroll }
            return view.subviews.lazy.compactMap { scrollView($0) }.first
        }
        func focusFrames(_ view: NSView) -> [NSRect] {
            let own = String(describing: type(of: view)).contains("FocusRingView")
                ? [panel.convertToScreen(view.convert(view.bounds, to: nil))] : []
            return own + view.subviews.flatMap(focusFrames)
        }
        func currentFrame(viewport: NSRect, fraction: Double) throws -> NSRect {
            // The in-process hosting view does not always expose SwiftUI's
            // semantic AX children. Compare native button frames by their
            // actual fractional anchor, not by midY (wrong near the edges).
            try #require(focusFrames(host).filter { $0.height > 40 }.min {
                abs(viewport.maxY - $0.maxY + $0.height * fraction - viewport.height * fraction)
                    < abs(viewport.maxY - $1.maxY + $1.height * fraction - viewport.height * fraction)
            })
        }
        @discardableResult func check(_ index: Int, fraction: Double, prelude: Bool = false) async throws -> CGFloat {
            model.session.seek(to: prelude ? 0 : 5 + Double(index) * 2)
            model.updateMainLyricSelection()
            #expect(model.mainLyricIndex == (prelude ? nil : index))
            try await settle()
            let scroll = try #require(scrollView(host))
            let viewport = panel.convertToScreen(scroll.contentView.convert(scroll.contentView.bounds, to: nil))
            let screenFrame = try currentFrame(viewport: viewport, fraction: fraction)
            let rowAnchor = viewport.maxY - screenFrame.maxY + screenFrame.height * fraction
            #expect(abs(rowAnchor - viewport.height * fraction) < 3,
                    "Row \(index), height \(screenFrame.height), anchor \(rowAnchor), viewport \(viewport.height), fraction \(fraction)")
            let offset = scroll.contentView.bounds.minY
            try await settle()
            let settledFrame = try currentFrame(viewport: viewport, fraction: fraction)
            // Lazy estimates can change the absolute content offset while
            // compensating the visible row. Check the actual on-screen frame.
            #expect(abs(settledFrame.minY - screenFrame.minY) < 2 && abs(settledFrame.height - screenFrame.height) < 2,
                    "The visible row must not drift after settling")
            print("Main lyric row \(index): height=\(screenFrame.height), anchor=\(rowAnchor), viewport=\(viewport.height), offset=\(offset)")
            return scroll.contentView.bounds.minY
        }

        try await check(0, fraction: 0.5, prelude: true)
        preferences.mainLyricPosition = .upper
        try await check(0, fraction: 0.3, prelude: true)
        try await check(0, fraction: 0.3)
        preferences.mainLyricPosition = .center
        try await check(0, fraction: 0.5)
        preferences.mainLyricPosition = .upper
        try await check(0, fraction: 0.3)
        try await check(15, fraction: 0.3)
        try await check(34, fraction: 0.3)
        try await check(15, fraction: 0.3)
        preferences.showTranslation = false
        preferences.mainLyricFontSize = 42
        try await check(15, fraction: 0.3)
        panel.setContentSize(.init(width: 360, height: 300))
        try await check(15, fraction: 0.3)
        preferences.showTranslation = true
        try await check(15, fraction: 0.3)
        preferences.mainLyricPosition = .center
        try await check(15, fraction: 0.5)
        preferences.mainLyricPosition = .custom
        for percent in [5.0, 12, 80, 95] {
            preferences.mainLyricCustomPercent = percent
            try await check(0, fraction: percent / 100, prelude: true)
            let beginning = try await check(0, fraction: percent / 100)
            let middle = try await check(15, fraction: percent / 100)
            let end = try await check(34, fraction: percent / 100)
            let returned = try await check(15, fraction: percent / 100)
            // Also prove that distant seeks moved the list itself. A stale
            // previously anchored row must not satisfy the geometry check.
            #expect(middle > beginning + 100 && end > middle + 100 && returned < end - 100)
        }
        preferences.mainLyricCustomPercent = 12
        try await check(15, fraction: 0.12)
        preferences.showTranslation = false
        panel.setContentSize(.init(width: 540, height: 480))
        try await check(15, fraction: 0.12)
        preferences.showTranslation = true
        try await check(15, fraction: 0.12)
    }
}
