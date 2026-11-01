import AppKit
import SwiftUI
import Testing
import LyricsXCore
@testable import LyricsXApp

private struct TouchBarIdleRepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

@MainActor private func touchBarModel() throws -> (AppModel, UserDefaults, String) {
    _ = NSApplication.shared
    let suite = "LyricsXTouchBarTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    return (AppModel(repository: TouchBarIdleRepository(), preferences: Preferences(defaults: defaults)), defaults, suite)
}

private let touchBarTrack = Track(playerID: "test", playerName: "Test", title: "测试歌曲", artist: "测试歌手", duration: 60)

private func touchBarDocument() -> LyricsDocument {
    .init(lines: [
        .init(id: 0, time: 0, text: "歌词正在播放", words: [
            .init(text: "歌词", start: 0, end: 4), .init(text: "正在", start: 4, end: 6), .init(text: "播放", start: 6, end: 9)
        ]),
        .init(id: 1, time: 10, text: "下一句也能同步显示", words: [
            .init(text: "下一句", start: 10, end: 12), .init(text: "也能", start: 12, end: 14), .init(text: "同步显示", start: 14, end: 18)
        ])
    ])
}

@MainActor private func touchBarEventually(_ condition: () -> Bool) async throws {
    for _ in 0..<100 {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(2))
    }
    #expect(condition())
}

@MainActor private func touchBarContent(_ controller: TouchBarController) throws -> TouchBarContentView {
    let item = try #require(controller.touchBar(NSTouchBar(), makeItemForIdentifier: .init("com.wzk112.lyricsxnext.touchbar.content")) as? NSCustomTouchBarItem)
    return try #require(item.view as? TouchBarContentView)
}

@Suite(.serialized) @MainActor struct TouchBarControllerTests {
    @Test func preferencesDefaultOffAndPersistSeparatelyFromFlexbar() throws {
        let (model, defaults, suite) = try touchBarModel()
        defer { model.stop(); defaults.removePersistentDomain(forName: suite) }
        #expect(!model.preferences.touchBarEnabled)
        #expect(!model.preferences.touchBarBackgroundEnabled)
        model.preferences.touchBarEnabled = true
        model.preferences.touchBarBackgroundEnabled = true
        let restored = Preferences(defaults: defaults)
        #expect(restored.touchBarEnabled && restored.touchBarBackgroundEnabled)
        #expect(!restored.flexbarEnabled)
        restored.touchBarEnabled = false
        #expect(!Preferences(defaults: defaults).touchBarEnabled)
        #expect(Preferences(defaults: defaults).touchBarBackgroundEnabled)
    }

    @Test func refreshRequiresEnabledVisiblePlayingSyncedLyrics() async throws {
        let (model, defaults, suite) = try touchBarModel()
        var visible = false
        let controller = TouchBarController(managesSystemTouchBar: false, visibilityOverride: { visible })
        defer { controller.stop(); model.stop(); defaults.removePersistentDomain(forName: suite) }
        model.session.accept(.init(track: touchBarTrack, position: 1, isPlaying: true), shouldSearch: false)
        model.session.use(touchBarDocument(), persist: false)
        controller.start(model: model)
        #expect(controller.isRunning && !controller.isRefreshing)
        visible = true
        controller.visibilityChanged()
        #expect(!controller.isRefreshing)
        model.preferences.touchBarEnabled = true
        try await touchBarEventually { controller.isRefreshing }
        visible = false
        controller.visibilityChanged()
        #expect(!controller.isRefreshing)
        visible = true
        controller.visibilityChanged()
        #expect(controller.isRefreshing)
        model.session.accept(.init(track: touchBarTrack, position: 2, isPlaying: false))
        try await touchBarEventually { !controller.isRefreshing }
        model.session.accept(.init(track: touchBarTrack, position: 2, isPlaying: true))
        try await touchBarEventually { controller.isRefreshing }
        model.session.use(.init(plainText: "没有时间轴的歌词"), persist: false)
        try await touchBarEventually { !controller.isRefreshing }
        model.session.use(touchBarDocument(), persist: false)
        try await touchBarEventually { controller.isRefreshing }
        model.preferences.touchBarEnabled = false
        try await touchBarEventually { !controller.isRefreshing }
        #expect(controller.status == "未启用")
    }

    @Test func sleepingStopsRefreshAndWakeRespectsCurrentPreference() async throws {
        let (model, defaults, suite) = try touchBarModel()
        let controller = TouchBarController(managesSystemTouchBar: false, visibilityOverride: { true })
        defer { controller.stop(); model.stop(); defaults.removePersistentDomain(forName: suite) }
        model.preferences.touchBarEnabled = true
        model.session.accept(.init(track: touchBarTrack, position: 1, isPlaying: true), shouldSearch: false)
        model.session.use(touchBarDocument(), persist: false)
        controller.start(model: model)
        #expect(controller.isRefreshing)
        controller.sleep()
        #expect(!controller.isRefreshing)
        controller.synchronizePlayback()
        #expect(!controller.isRefreshing)
        controller.wake()
        #expect(controller.isRefreshing)
        controller.sleep()
        model.preferences.touchBarEnabled = false
        controller.wake()
        #expect(!controller.isRefreshing)
        model.preferences.touchBarEnabled = true
        try await touchBarEventually { controller.isRefreshing }
    }

    @Test func launchInInactiveUserSessionDefersPresentationUntilActiveRestart() throws {
        let (model, defaults, suite) = try touchBarModel()
        var active = false
        let controller = TouchBarController(managesSystemTouchBar: false, visibilityOverride: { true },
                                            sessionActivity: { active })
        defer { controller.stop(); model.stop(); defaults.removePersistentDomain(forName: suite) }
        model.preferences.touchBarEnabled = true
        model.preferences.touchBarBackgroundEnabled = true
        model.session.accept(.init(track: touchBarTrack, position: 1, isPlaying: true), shouldSearch: false)
        model.session.use(touchBarDocument(), persist: false)
        controller.start(model: model)
        #expect(controller.isRunning && !controller.isRefreshing)
        #expect(controller.status == "已暂停，唤醒后恢复")
        controller.wake()
        controller.visibilityChanged()
        #expect(!controller.isRefreshing)
        #expect(controller.status == "已暂停，唤醒后恢复")

        controller.stop()
        active = true
        controller.start(model: model)
        #expect(controller.isRunning && controller.isRefreshing)
        #expect(controller.status != "已暂停，唤醒后恢复")
    }

    @Test func pausedSeekAndCombinedOffsetsRefreshNativeLyricsWithoutTimer() async throws {
        let (model, defaults, suite) = try touchBarModel()
        let controller = TouchBarController(managesSystemTouchBar: false, visibilityOverride: { true })
        defer { controller.stop(); model.stop(); defaults.removePersistentDomain(forName: suite) }
        model.preferences.touchBarEnabled = true
        model.session.accept(.init(track: touchBarTrack, position: 1, isPlaying: false), shouldSearch: false)
        model.session.use(touchBarDocument(), persist: false)
        controller.start(model: model)
        let content = try touchBarContent(controller)
        #expect(content.lyrics.renderedText == "歌词正在播放")
        let initial = content.lyrics.currentFrame(viewportWidth: 400)
        #expect(!initial.highlights.isEmpty && !controller.isRefreshing)
        model.session.seek(to: 12)
        controller.synchronizePlayback()
        #expect(content.lyrics.renderedText == "下一句也能同步显示")
        #expect(!controller.isRefreshing)
        model.session.seek(to: 1)
        controller.synchronizePlayback()
        #expect(content.lyrics.currentFrame(viewportWidth: 400) == initial)
        model.session.adjustOffset(by: 500)
        model.preferences.globalOffsetMilliseconds = 500
        try await touchBarEventually { model.session.effectiveOffsetMilliseconds == 1000 }
        controller.synchronizePlayback()
        let advanced = content.lyrics.currentFrame(viewportWidth: 400)
        #expect(advanced.highlights.map(\.width).reduce(0, +) > initial.highlights.map(\.width).reduce(0, +))
        #expect(model.session.position == 1 && !controller.isRefreshing)
        model.preferences.conversion = "繁體"
        try await touchBarEventually { content.lyrics.renderedText == "歌詞正在播放" }
    }

    @Test func unsyncedInstrumentalAndNewTrackUsePlainFallback() throws {
        let (model, defaults, suite) = try touchBarModel()
        let controller = TouchBarController(managesSystemTouchBar: false, visibilityOverride: { true })
        defer { controller.stop(); model.stop(); defaults.removePersistentDomain(forName: suite) }
        controller.start(model: model)
        let content = try touchBarContent(controller)
        #expect(content.lyrics.renderedText == "LyricsX Next · 等待播放")
        model.session.accept(.init(track: touchBarTrack, position: 1, isPlaying: false), shouldSearch: false)
        model.session.use(.init(plainText: "未同步歌词"), persist: false)
        controller.synchronizePlayback()
        #expect(content.lyrics.renderedText == "测试歌曲 · 测试歌手")
        #expect(content.lyrics.timedSpans.isEmpty)
        model.session.use(.init(lines: [.init(id: 0, time: 0, text: "纯音乐")], isInstrumental: true), persist: false)
        controller.synchronizePlayback()
        #expect(content.lyrics.renderedText == "测试歌曲 · 测试歌手")
        model.session.use(touchBarDocument(), persist: false)
        controller.synchronizePlayback()
        #expect(content.lyrics.renderedText == "歌词正在播放")
        model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "另一首歌"), position: 0, isPlaying: false), shouldSearch: false)
        controller.synchronizePlayback()
        #expect(content.lyrics.renderedText == "另一首歌")
        #expect(content.lyrics.timedSpans.isEmpty)
    }

    @Test func stoppedObservationCannotReviveOrReplaceRestartedModel() async throws {
        let (oldModel, oldDefaults, oldSuite) = try touchBarModel()
        let (newModel, newDefaults, newSuite) = try touchBarModel()
        let controller = TouchBarController(managesSystemTouchBar: false, visibilityOverride: { true })
        defer {
            controller.stop(); oldModel.stop(); newModel.stop()
            oldDefaults.removePersistentDomain(forName: oldSuite); newDefaults.removePersistentDomain(forName: newSuite)
        }
        oldModel.preferences.touchBarEnabled = true
        oldModel.session.accept(.init(track: touchBarTrack, position: 1, isPlaying: true), shouldSearch: false)
        oldModel.session.use(touchBarDocument(), persist: false)
        controller.start(model: oldModel)
        oldModel.preferences.touchBarEnabled = false // Queues an observation callback for the old generation.
        controller.stop()
        oldModel.preferences.touchBarEnabled = true
        for _ in 0..<3 { await Task.yield() }
        #expect(!controller.isRunning && !controller.isRefreshing)
        controller.start(model: oldModel)
        oldModel.preferences.touchBarEnabled = false
        controller.stop() // Leave this generation's callback queued across the next start.
        newModel.preferences.touchBarEnabled = true
        newModel.session.accept(.init(track: touchBarTrack, position: 12, isPlaying: true), shouldSearch: false)
        newModel.session.use(touchBarDocument(), persist: false)
        controller.start(model: newModel)
        let content = try touchBarContent(controller)
        oldModel.preferences.conversion = "繁體"
        oldModel.session.seek(to: 3)
        for _ in 0..<3 { await Task.yield() }
        #expect(controller.isRunning && controller.isRefreshing)
        #expect(content.lyrics.renderedText == "下一句也能同步显示")
        newModel.preferences.touchBarEnabled = false
        try await touchBarEventually { !controller.isRefreshing }
        controller.stop()
        controller.visibilityChanged(); controller.wake(); controller.synchronizePlayback()
        #expect(!controller.isRunning && !controller.isRefreshing)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LYRICSX_TOUCHBAR_QA"] == "1"))
    func nativeControlsAndSettingsPreview() async throws {
        let (model, defaults, suite) = try touchBarModel()
        defer { model.stop(); defaults.removePersistentDomain(forName: suite) }
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("outputs/touch-bar-2026-11-02", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func capture(_ view: NSView, name: String) throws {
            view.layoutSubtreeIfNeeded()
            let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try #require(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent(name + ".png"))
        }
        let content = TouchBarContentView(frame: .init(x: 0, y: 0, width: 685, height: 30))
        let panel = NSWindow(contentRect: .init(x: 100, y: 100, width: 685, height: 30), styleMask: [.borderless], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false; panel.contentView = content; panel.orderFrontRegardless()
        defer { panel.close() }
        let line = touchBarDocument().lines[1]
        let cover = NSImage(size: .init(width: 28, height: 28), flipped: false) { rect in
            NSColor.systemTeal.setFill(); NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
            NSColor.white.setStroke(); let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 7, dy: 7)); circle.lineWidth = 2; circle.stroke()
            return true
        }
        content.update(line: line, text: line.text, position: 13, offset: 0, playing: true, artwork: cover, hasTrack: true)
        try await Task.sleep(for: .milliseconds(100))
        #expect(content.bounds.width == 685 && content.bounds.height == 30)
        try capture(content, name: "native-controls-685-simulated")
        content.update(line: line, text: line.text, position: 13, offset: 0, playing: false, artwork: cover, hasTrack: true)
        try capture(content, name: "native-controls-paused-simulated")
        let label = NSTextField(labelWithString: "Touch Bar 原生控件预览 · 测试歌词 · 非实体触控条画面")
        label.textColor = .secondaryLabelColor; label.font = .systemFont(ofSize: 12)
        let stack = NSStackView(views: [content, label])
        stack.orientation = .vertical; stack.spacing = 14
        stack.edgeInsets = .init(top: 18, left: 18, bottom: 16, right: 18)
        content.widthAnchor.constraint(equalToConstant: 685).isActive = true
        panel.setContentSize(.init(width: 721, height: 96)); panel.contentView = stack
        try await Task.sleep(for: .milliseconds(80))
        try capture(stack, name: "native-preview-labeled-simulated")
        let settings = NSHostingView(rootView: PreferencesView(model: model, initialSection: .developer))
        panel.setContentSize(.init(width: 980, height: 860)); panel.contentView = settings
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            panel.appearance = NSAppearance(named: appearance)
            try await Task.sleep(for: .milliseconds(160))
            try capture(settings, name: "settings-" + appearance.rawValue)
        }
        panel.orderOut(nil)
        model.session.accept(.init(track: touchBarTrack, position: 13, isPlaying: false), shouldSearch: false)
        model.session.use(touchBarDocument(), persist: false)
        model.artwork = cover
        model.touchBar.start(model: model)
        model.touchBar.showPreview()
        try await Task.sleep(for: .milliseconds(150))
        let preview = try #require(NSApp.windows.first { $0.title == "Touch Bar 预览" && $0.isVisible })
        let root = try #require(preview.contentView)
        let liveContent = try #require(root.subviews.compactMap { $0 as? TouchBarContentView }.first)
        #expect(liveContent.bounds.height == 30)
        #expect(abs(liveContent.bounds.width - (root.bounds.width - 36)) < 1)
        #expect(liveContent.lyrics.renderedText == "下一句也能同步显示")
        try capture(root, name: "actual-preview-window-simulated")
        preview.close()
        #expect(!model.touchBar.isRefreshing)
    }
}
