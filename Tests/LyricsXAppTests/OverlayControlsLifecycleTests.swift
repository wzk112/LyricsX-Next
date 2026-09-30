import AppKit
import Foundation
import Testing
import LyricsXCore
@testable import LyricsXApp

private struct ControlsRepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> {
        .init { $0.finish() }
    }
    func save(_ document: LyricsDocument, for track: Track) async throws { }
}

@Suite(.serialized) @MainActor struct OverlayControlsLifecycleTests {
    @Test(arguments: [false, true])
    func pausedHoverHiddenControlsDisappearAndResumeFollowsPointer(_ reduced: Bool) async throws {
        _ = NSApplication.shared
        let suite = "LyricsXControls-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlayVisible = true; prefs.hideWhenPaused = true
        prefs.hideOverlayOnHover = true; prefs.overlayLocked = true
        prefs.overlayClickThrough = true; prefs.reduceMotion = reduced
        let track = Track(playerID: "test", playerName: "Test", title: "Controls lifecycle", duration: 180)
        let model = AppModel(repository: ControlsRepository(), preferences: prefs)
        model.session.accept(.init(track: track, position: 1, isPlaying: true), shouldSearch: false)
        model.session.use(.init(lines: [.init(id: 0, time: 0, text: "Visible lyric")]), persist: false)
        let outside = NSPoint(x: -10_000, y: -10_000)
        var pointer = outside
        let overlay = OverlayController(model: model, frameAutosaveName: nil, pointerLocation: { pointer })
        defer { overlay.stop(); model.stop() }
        try await Task.sleep(for: .milliseconds(240))
        let center = NSPoint(x: overlay.panel.frame.midX, y: overlay.panel.frame.midY)
        pointer = center; overlay.refreshAppearance(at: pointer)
        try await Task.sleep(for: .milliseconds(240))
        #expect(overlay.panel.alphaValue == 0)
        #expect(overlay.controlPanel.isVisible && overlay.controlPanel.alphaValue == 1)

        // The parent fade has already finished. Pause must dismiss the
        // separate control window without waiting for another parent fade.
        model.session.freeze()
        try await Task.sleep(for: .milliseconds(240))
        #expect(!overlay.panel.isVisible && !overlay.controlPanel.isVisible)
        #expect(overlay.controlsView.isHidden && overlay.controlsView.alphaValue == 0)
        overlay.refreshAppearance(at: pointer)
        pointer = outside; overlay.refreshAppearance(at: pointer)
        pointer = center; overlay.refreshAppearance(at: pointer)
        try await Task.sleep(for: .milliseconds(60))
        #expect(!overlay.panel.isVisible && !overlay.controlPanel.isVisible,
                "Pointer movement must not reveal a paused, automatically hidden overlay")

        model.session.accept(.init(track: track, position: 1, isPlaying: true), shouldSearch: false)
        try await Task.sleep(for: .milliseconds(240))
        #expect(overlay.panel.isVisible && overlay.panel.alphaValue == 0)
        #expect(overlay.controlPanel.isVisible && overlay.controlPanel.alphaValue == 1)
        pointer = outside; overlay.refreshAppearance(at: pointer)
        try await Task.sleep(for: .milliseconds(240))
        #expect(overlay.panel.alphaValue == 1 && !overlay.controlPanel.isVisible)

        pointer = center; prefs.overlayLocked = false
        overlay.refreshAppearance(at: pointer)
        try await Task.sleep(for: .milliseconds(240))
        #expect(overlay.panel.alphaValue == 1 && overlay.controlPanel.isVisible)
        prefs.overlayClickThrough = false
        try await Task.sleep(for: .milliseconds(60))
        #expect(!overlay.controlPanel.isVisible && overlay.controlsView.window === overlay.panel)
        #expect(!overlay.controlsView.isHidden)
        prefs.overlayLocked = true
        try await Task.sleep(for: .milliseconds(240))
        #expect(overlay.panel.alphaValue == 0 && !overlay.controlPanel.isVisible)
        model.session.freeze()
        try await Task.sleep(for: .milliseconds(240))
        #expect(!overlay.panel.isVisible && overlay.controlsView.isHidden)
    }

    @Test func pauseDuringHoverFadeAndResumeDuringControlFadeUseLatestState() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXControls-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlayVisible = true; prefs.hideWhenPaused = true
        prefs.hideOverlayOnHover = true; prefs.overlayLocked = true
        prefs.overlayClickThrough = true; prefs.reduceMotion = false
        let track = Track(playerID: "test", playerName: "Test", title: "Controls fade reversal", duration: 180)
        let model = AppModel(repository: ControlsRepository(), preferences: prefs)
        model.session.accept(.init(track: track, position: 1, isPlaying: true), shouldSearch: false)
        let outside = NSPoint(x: -10_000, y: -10_000)
        var pointer = outside
        let overlay = OverlayController(model: model, frameAutosaveName: nil, pointerLocation: { pointer })
        defer { overlay.stop(); model.stop() }
        try await Task.sleep(for: .milliseconds(240))
        pointer = NSPoint(x: overlay.panel.frame.midX, y: overlay.panel.frame.midY)
        overlay.refreshAppearance(at: pointer)
        try await Task.sleep(for: .milliseconds(30))
        model.session.freeze()
        try await Task.sleep(for: .milliseconds(240))
        #expect(!overlay.panel.isVisible && !overlay.controlPanel.isVisible)

        model.session.accept(.init(track: track, position: 1, isPlaying: true), shouldSearch: false)
        try await Task.sleep(for: .milliseconds(240))
        #expect(overlay.controlPanel.isVisible)
        model.session.freeze()
        try await Task.sleep(for: .milliseconds(40))
        model.session.accept(.init(track: track, position: 1, isPlaying: true), shouldSearch: false)
        try await Task.sleep(for: .milliseconds(240))
        #expect(overlay.panel.isVisible && overlay.panel.alphaValue == 0)
        #expect(overlay.controlPanel.isVisible && !overlay.controlsView.isHidden)
        #expect(overlay.controlsView.alphaValue == 1)

        prefs.overlayVisible = false
        try await Task.sleep(for: .milliseconds(240))
        #expect(!overlay.panel.isVisible && !overlay.controlPanel.isVisible)
        #expect(overlay.controlsView.isHidden)
    }
}
