import Foundation
import AppKit
import SwiftUI
import Testing
import LyricsXCore
@testable import LyricsXApp

private struct GlobalOffsetIdleRepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

@Suite @MainActor struct GlobalLyricOffsetTests {
    @Test func preferenceDefaultsToZeroAndPersistsIndependentlyOfSongFiles() throws {
        let suite = "LyricsXOffsetTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.globalOffsetMilliseconds == 0)
        let sourceKey = preferences.sourceSelectionKey
        preferences.globalOffsetMilliseconds = -250
        #expect(Preferences(defaults: defaults).globalOffsetMilliseconds == -250)
        #expect(preferences.sourceSelectionKey == sourceKey)
        preferences.globalOffsetMilliseconds = .max
        #expect(Preferences(defaults: defaults).globalOffsetMilliseconds == 300_000)
        defaults.set(Int.min, forKey: "globalOffsetMilliseconds")
        #expect(Preferences(defaults: defaults).globalOffsetMilliseconds == -300_000)
        defaults.set("invalid", forKey: "globalOffsetMilliseconds")
        #expect(Preferences(defaults: defaults).globalOffsetMilliseconds == 0)
        preferences.globalOffsetMilliseconds = 0
        #expect(Preferences(defaults: defaults).globalOffsetMilliseconds == 0)
    }

    @Test func savedAndLiveGlobalOffsetsReachAllPresentationsWhilePaused() async throws {
        let suite = "LyricsXOffsetTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(300, forKey: "globalOffsetMilliseconds")
        let model = AppModel(repository: GlobalOffsetIdleRepository(), preferences: Preferences(defaults: defaults))
        defer { model.stop() }
        model.mainWindowVisible = true
        model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Offset"), position: 9.5, isPlaying: false), shouldSearch: false)
        let doc = LyricsDocument(lines: [.init(id: 0, time: 0, text: "First"), .init(id: 1, time: 10, text: "Next")], offsetMilliseconds: 200)
        model.session.use(doc, persist: false); model.updateMainLyricSelection()
        #expect(model.session.globalOffsetMilliseconds == 300 && model.mainLyricIndex == 1)
        #expect(model.menubarText == "Next")
        let frozen = OverlayDisplaySnapshot(model: model, at: ProcessInfo.processInfo.systemUptime)
        model.preferences.globalOffsetMilliseconds = -300
        for _ in 0..<100 where model.session.globalOffsetMilliseconds != -300 { try await Task.sleep(for: .milliseconds(5)) }
        #expect(model.mainLyricIndex == 0 && model.menubarText == "First")
        #expect(model.session.position == 9.5 && model.playbackControlPosition == 9.5)
        let main = MainLyricSnapshot(model: model)
        let overlay = OverlayDisplaySnapshot(model: model, at: ProcessInfo.processInfo.systemUptime)
        #expect(main.globalOffsetMilliseconds == -300 && overlay.globalOffsetMilliseconds == -300)
        #expect(frozen.globalOffsetMilliseconds == 300 && frozen.index == 1)
        var preview = doc; preview.offsetMilliseconds = 1000
        #expect(preview.lineID(at: model.session.position, globalOffsetMilliseconds: model.session.globalOffsetMilliseconds) == 1)
        #expect(model.session.document?.offsetMilliseconds == 200 && model.session.document?.id == doc.id)
    }

    @Test func cueSchedulingIncludesGlobalOffsetWithoutIncreasingIdleRefresh() {
        let doc = LyricsDocument(lines: [.init(id: 0, time: 0, text: "First"), .init(id: 1, time: 10, text: "Next")], offsetMilliseconds: 200)
        let near = LyricTickCadence.milliseconds(playing: true, visible: true, document: doc, position: 9.49, globalOffsetMilliseconds: 300)
        let flexbar = FlexbarCueCadence.milliseconds(document: doc, position: 9.49, globalOffsetMilliseconds: 300)
        #expect(abs(near - 10.5) < 0.001 && abs(flexbar - 10.5) < 0.001)
        #expect(LyricTickCadence.milliseconds(playing: false, visible: true, document: doc, position: 9.49, globalOffsetMilliseconds: 300) == 500)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LYRICSX_GLOBAL_OFFSET_QA"] == "1"))
    func nativeSettingsInputAndNarrowOverlayEditor() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXOffsetWindowTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        let model = AppModel(repository: GlobalOffsetIdleRepository(), preferences: prefs)
        defer { model.stop() }
        model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Native offset QA"), position: 9.5, isPlaying: false), shouldSearch: false)
        model.session.use(.init(lines: [.init(id: 0, time: 0, text: "First"), .init(id: 1, time: 10, text: "Next")], offsetMilliseconds: 200), persist: false)
        let root = SettingsCard(title: "同步") { GlobalLyricOffsetSettings(preferences: prefs) }
            .padding(20).frame(width: 470, height: 270).background(Color(nsColor: .windowBackgroundColor))
        let host = NSHostingView(rootView: root)
        let panel = NSWindow(contentRect: .init(x: 100, y: 100, width: 470, height: 270), styleMask: [.titled], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false; panel.contentView = host; panel.orderFrontRegardless()
        defer { panel.close() }
        func settle() async throws {
            try await Task.sleep(for: .milliseconds(120))
            host.layoutSubtreeIfNeeded()
        }
        try await settle()
        func textField(_ view: NSView) -> NSTextField? {
            if let field = view as? NSTextField, field.isEditable { return field }
            return view.subviews.lazy.compactMap { textField($0) }.first
        }
        let field = try #require(textField(host))
        field.selectText(nil)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.selectAll(nil); editor.insertText("0.7", replacementRange: editor.selectedRange())
        panel.makeFirstResponder(nil)
        try await settle()
        #expect(prefs.globalOffsetMilliseconds == 700 && model.session.globalOffsetMilliseconds == 700)
        #expect(model.session.currentLineIndex == 1 && model.session.position == 9.5)
        #expect(Preferences(defaults: defaults).globalOffsetMilliseconds == 700)
        let output = URL(fileURLWithPath: "/tmp/lyricsx-global-offset-qa", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func capture(_ view: NSView, name: String) throws {
            view.layoutSubtreeIfNeeded()
            let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try #require(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent(name + ".png"))
        }
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            panel.appearance = NSAppearance(named: appearance)
            try await settle()
            try capture(host, name: "settings-" + appearance.rawValue)
        }
        let target = try #require(OverlayOffsetTarget(session: model.session))
        let overlay = NSHostingView(rootView: OverlayThemedRoot(preferences: prefs,
            content: OverlayOffsetEditor(model: model, target: target, width: 308))
            .background(Color(nsColor: .windowBackgroundColor)))
        panel.appearance = prefs.overlayEffectiveTheme.appearance
        panel.setContentSize(.init(width: 308, height: 186)); panel.contentView = overlay
        try await settle()
        #expect(overlay.fittingSize.height <= 187 && overlay.fittingSize.width <= 309)
        try capture(overlay, name: "single-song-editor-320")
    }
}
