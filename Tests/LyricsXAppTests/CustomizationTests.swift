import AppKit
import Foundation
import Testing
import LyricsXCore
@testable import LyricsXApp

private struct CustomizationRepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

@Suite @MainActor struct CustomizationTests {
    @Test func mainWindowLifecycleDoesNotPauseFloatingLyricFrames() async throws {
        _ = NSApplication.shared
        let main = NSWindow(contentRect: .init(x: 100, y: 100, width: 300, height: 200),
            styleMask: [.titled, .miniaturizable], backing: .buffered, defer: false)
        let panel = DraggableOverlayPanel(contentRect: .init(x: 150, y: 450, width: 300, height: 100),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        let frames = LyricFrameView()
        panel.contentView = frames
        frames.running = true
        panel.orderFrontRegardless()
        defer { frames.stop(); panel.orderOut(nil); main.orderOut(nil) }
        try await Task.sleep(for: .milliseconds(40))
        #expect(frames.deliveringFrames)
        for event in [NSWindow.willMiniaturizeNotification, NSWindow.didMiniaturizeNotification, NSWindow.willCloseNotification] {
            NotificationCenter.default.post(name: event, object: main)
            NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: panel)
            #expect(frames.deliveringFrames)
        }
        frames.running = false
        #expect(!frames.deliveringFrames)
    }

    @Test func hiddenOverlayResizesForReplacementAndFontBeforeShowing() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlayVisible = false; prefs.overlayAdaptiveSize = true
        prefs.overlayWidth = 620; prefs.overlaySecondaryMode = .translation
        let model = AppModel(repository: CustomizationRepository(), preferences: prefs)
        model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Hidden fixture"), position: 0, isPlaying: false), shouldSearch: false)
        model.session.use(.init(lines: [.init(id: 0, time: 0, text: ""), .init(id: 1, time: 10, text: "Future lyric")]), persist: false)
        let overlay = OverlayController(model: model, frameAutosaveName: nil)
        defer { overlay.stop(); model.stop() }
        let document = LyricsDocument(lines: [.init(id: 0, time: 0,
            text: "First row\nSecond row", translation: "Translation below two rows")])
        model.session.use(document, persist: false)
        prefs.lyricFontName = "Menlo-Regular"
        try await Task.sleep(for: .milliseconds(150))
        #expect(!overlay.panel.isVisible)
        #expect(abs(overlay.panel.frame.height - OverlayTextMeasure.height(document: document, index: 0, preferences: prefs, maximumWidth: 620)) < 1)
        model.session.use(.init(lines: [.init(id: 0, time: 0, text: ""), .init(id: 1, time: 10, text: "Future lyric")]), persist: false)
        try await Task.sleep(for: .milliseconds(300))
        #expect(abs(overlay.panel.frame.height - OverlayPresentationMode.waitingHeight) < 1)
    }

    @Test func typographyPersistsAndMissingFontsAndInvalidColorsFallback() throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.lyricFontName = "Menlo-Regular"
        prefs.lyricPrimaryColor = "#ff8800"
        prefs.lyricSecondaryColor = "0088FF"
        let restored = Preferences(defaults: defaults)
        #expect(restored.lyricFontName == "Menlo-Regular")
        #expect(restored.lyricPrimaryColor == "FF8800")
        #expect(LyricTypography.hex(restored.typography.secondary) == "0088FF")
        #expect(LyricTypography.normalizedHex("invalid") == "FFFFFF")
        let fallback = LyricTypography(fontName: "NoSuchFont-LyricsX-Fixture")
        #expect(fallback.nativeFont(size: 26, weight: .semibold) == NSFont.systemFont(ofSize: 26, weight: .semibold))
    }

    @Test func fontChangesInvalidateMeasuredWrapping() throws {
        let text = "iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii"
        let standard = OverlayTextMeasure.layout(text, font: 26, canvasWidth: 260)
        let mono = OverlayTextMeasure.layout(text, font: 26, canvasWidth: 260,
                                             typography: .init(fontName: "Menlo-Regular"))
        #expect(standard.rows != mono.rows || standard.fontSize != mono.fontSize)
        #expect(OverlayTextMeasure.layout(text, font: 26, canvasWidth: 260).height == standard.height)
    }

    @Test func menubarLyricsUpdateWithBothWindowsHiddenAndFallbackDuringGaps() throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlayVisible = false; prefs.showMenubarLyrics = true
        let model = AppModel(repository: CustomizationRepository(), preferences: prefs)
        defer { model.stop() }
        let track = Track(playerID: "test", playerName: "Test", title: "Menu fixture")
        model.session.accept(.init(track: track, position: 0, isPlaying: false), shouldSearch: false)
        model.session.use(.init(lines: [.init(id: 0, time: 0, text: "First\nline"),
                                       .init(id: 1, time: 1, text: "Second"),
                                       .init(id: 2, time: 2, text: "•••")]), persist: false)
        #expect(model.menubarText == "First line")
        model.session.seek(to: 1)
        #expect(model.menubarText == "Second")
        model.session.seek(to: 2)
        #expect(model.menubarText == "Menu fixture")
        #expect(!model.mainWindowVisible && !prefs.overlayVisible)
    }
}
