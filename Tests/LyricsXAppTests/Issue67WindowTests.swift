import AppKit
import SwiftUI
import Testing
import LyricsXCore
import LyricsXServices
import ScreenCaptureKit
@testable import LyricsXApp

private struct Issue67Repository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

@Suite(.serialized) @MainActor struct Issue67WindowTests {
    private func makeModel() throws -> (AppModel, UserDefaults, String) {
        _ = NSApplication.shared
        let suite = "LyricsXIssue67-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        let prefs = Preferences(defaults: defaults)
        prefs.reduceMotion = true; prefs.overlayWaveformEnabled = false
        prefs.overlayVisible = true; prefs.overlayWidth = 620
        prefs.disabledSources = SourceConfiguration.defaultOrder
        prefs.setSource("Apple Music", enabled: true)
        prefs.directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        let model = AppModel(repository: Issue67Repository(), preferences: prefs)
        let track = Track(playerID: "com.apple.Music", playerName: "Apple Music", persistentID: "qa-fixture",
            title: "界面验证示例 · 非真实歌曲", artist: "原生组件预览", duration: 120,
            embeddedLyrics: "[00:00.00]这是一段用于验证的歌词\n[00:08.00]先预览，再决定是否应用\n[00:16.00]切换版本不会改变播放进度")
        model.session.accept(.init(track: track, position: 9, isPlaying: false), shouldSearch: false)
        model.session.use(.init(title: track.title, artist: track.artist,
            lines: [.init(id: 0, time: 0, text: "保留原来的歌词位置"), .init(id: 1, time: 8, text: "点击按钮，调整歌词同步", translation: "调整只影响这首歌")]), persist: false)
        return (model, defaults, suite)
    }
    private func settle() async throws {
        for _ in 0..<12 { NSApp.updateWindows(); try await Task.sleep(for: .milliseconds(20)) }
    }
    private func capture(_ view: NSView, name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["LYRICSX_ISSUE67_QA_DIR"] else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        view.layoutSubtreeIfNeeded()
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: directory.appendingPathComponent(name + ".png"))
        #expect(bitmap.pixelsWide > 0 && bitmap.pixelsHigh > 0)
    }

    // Capture the WindowServer composite: cacheDisplay cannot reveal whether
    // a separate control window is being sampled by the lyric glass below it.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["LYRICSX_ISSUE67_SCREEN_QA"] == "1"))
    func interactiveSurfacesOverBusyDesktop() async throws {
        _ = NSApplication.shared
        NSApp.finishLaunching()
        try #require(CGPreflightScreenCaptureAccess())
        let (model, defaults, suite) = try makeModel()
        model.preferences.overlayAppearance = .glass
        model.preferences.hideOverlayOnHover = false
        model.preferences.overlayLocked = true
        model.preferences.overlayClickThrough = true
        var pointer = NSPoint(x: -10_000, y: -10_000)
        let overlay = OverlayController(model: model, frameAutosaveName: nil,
            pointerLocation: { pointer })
        let screen = try #require(overlay.panel.screen ?? NSScreen.main)
        let frame = NSRect(x: screen.visibleFrame.midX - 310, y: screen.visibleFrame.midY + 50,
            width: 620, height: overlay.panel.frame.height)
        overlay.panel.setFrame(frame, display: true)
        overlay.toggleOffsetEditor()
        let editor = try #require(overlay.offsetEditorPanel)
        let region = overlay.panel.frame.union(editor.frame).insetBy(dx: -16, dy: -16)
        let backdrop = NSPanel(contentRect: region, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        backdrop.isReleasedWhenClosed = false
        backdrop.level = NSWindow.Level(rawValue: overlay.panel.level.rawValue - 1)
        backdrop.isOpaque = true
        backdrop.backgroundColor = NSColor(white: 0.08, alpha: 1)
        backdrop.contentView = NSHostingView(rootView: VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<20) { row in
                Text("背景文字 \(row) · Apple Music 歌词预览 · 控制按钮应始终清晰显示")
                    .font(.system(size: 18, weight: .medium)).foregroundStyle(.white)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(white: 0.08)))
        defer { overlay.stop(); model.stop(); backdrop.close(); defaults.removePersistentDomain(forName: suite) }
        backdrop.orderFrontRegardless(); overlay.panel.orderFrontRegardless()
        let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        let display = try #require(content.displays.first { $0.displayID == displayID })
        let config = SCStreamConfiguration()
        config.showsCursor = false
        config.sourceRect = .init(x: region.minX - screen.frame.minX, y: screen.frame.maxY - region.maxY,
            width: region.width, height: region.height)
        config.width = Int(region.width * screen.backingScaleFactor)
        config.height = Int(region.height * screen.backingScaleFactor)
        let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LYRICSX_ISSUE67_QA_DIR"]
            ?? "/tmp/lyricsx-composite-qa", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        func screenImage() async throws -> CGImage {
            try await SCScreenshotManager.captureImage(contentFilter:
                SCContentFilter(display: display, excludingWindows: []), configuration: config)
        }
        var visibleControls: CGImage?
        for detached in [false, true] {
            model.preferences.overlayClickThrough = detached
            overlay.refreshAppearance(at: overlay.panel.frame.origin)
            try await settle()
            let image = try await screenImage()
            try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
                .write(to: directory.appendingPathComponent("desktop-\(detached ? "detached" : "inline").png"))
            #expect(editor.isVisible && editor.alphaValue == 1)
            if detached { visibleControls = image }
        }
        overlay.closeOffsetEditor()
        pointer = .init(x: overlay.panel.frame.midX, y: overlay.panel.frame.midY)
        model.preferences.hideOverlayOnHover = true
        overlay.refreshAppearance(at: pointer)
        try await settle()
        #expect(overlay.panel.alphaValue == 0 && overlay.controlPanel.alphaValue == 1)
        let hiddenImage = try await screenImage()
        try #require(NSBitmapImageRep(cgImage: hiddenImage).representation(using: .png, properties: [:]))
            .write(to: directory.appendingPathComponent("desktop-hover-hidden.png"))
        // Foreground glyphs must retain their shape when the lyric glass is
        // present or hidden; this detects a control sampled into refraction.
        let scale = screen.backingScaleFactor
        let controlRect = CGRect(x: (overlay.controlPanel.frame.minX - region.minX) * scale,
            y: (region.maxY - overlay.controlPanel.frame.maxY) * scale,
            width: overlay.controlPanel.frame.width * scale, height: overlay.controlPanel.frame.height * scale)
        let visibleImage = try #require(visibleControls)
        let before = NSBitmapImageRep(cgImage: try #require(visibleImage.cropping(to: controlRect)))
        let after = NSBitmapImageRep(cgImage: try #require(hiddenImage.cropping(to: controlRect)))
        func ink(_ bitmap: NSBitmapImageRep, _ x: Int, _ y: Int) -> Bool {
            guard let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return false }
            return min(c.redComponent, c.greenComponent, c.blueComponent) > 0.9
        }
        var foreground = 0, changed = 0
        for y in 0..<before.pixelsHigh {
            for x in 0..<before.pixelsWide {
                let a = ink(before, x, y), b = ink(after, x, y)
                if a || b { foreground += 1 }
                if a != b { changed += 1 }
            }
        }
        let difference = Double(changed) / Double(max(1, foreground))
        print("Control foreground shape change with lyric glass: \(difference)")
        #expect(foreground > 200 && difference < 0.08)
    }

    @Test func headerTogglePersistsWithoutMovingLyricsAndControlsFitNarrowWindows() async throws {
        let (model, defaults, suite) = try makeModel()
        let overlay = OverlayController(model: model, frameAutosaveName: nil, pointerLocation: { .init(x: -10_000, y: -10_000) })
        defer { overlay.stop(); model.stop(); defaults.removePersistentDomain(forName: suite) }
        try await settle()
        let frame = overlay.lyricHostingView.frame
        #expect(!overlay.pinnedHeaderView.isHidden)
        model.preferences.overlayShowSongInfo = false
        try await settle()
        #expect(overlay.pinnedHeaderView.isHidden)
        #expect(overlay.lyricHostingView.frame == frame)
        #expect(!Preferences(defaults: defaults).overlayShowSongInfo)
        for width in [320.0, 620.0, 1000.0] {
            model.preferences.overlayWidth = width
            try await settle()
            let controls = overlay.controlsView.frame
            #expect(controls.width == OverlayControlLayout.width)
            #expect(controls.minX >= 0 && controls.maxX <= overlay.panel.frame.width)
        }
        try capture(try #require(overlay.panel.contentView), name: "overlay-hidden-header")
    }

    @Test(arguments: [false, true]) func offsetEditorSurvivesPointerMovementButClosesOnSongOrPause(_ detached: Bool) async throws {
        let (model, defaults, suite) = try makeModel()
        model.preferences.overlayClickThrough = detached; model.preferences.overlayLocked = true
        model.preferences.hideOverlayOnHover = true
        let overlay = OverlayController(model: model, frameAutosaveName: nil, pointerLocation: { .init(x: -10_000, y: -10_000) })
        defer { overlay.stop(); model.stop(); defaults.removePersistentDomain(forName: suite) }
        try await settle()
        let target = try #require(OverlayOffsetTarget(session: model.session))
        overlay.toggleOffsetEditor()
        try await settle()
        let editor = try #require(overlay.offsetEditorPanel)
        #expect(editor.isVisible)
        #expect(abs(editor.frame.maxX - overlay.panel.frame.maxX) < 1)
        #expect(!editor.frame.intersects(overlay.panel.frame))
        overlay.refreshAppearance(at: .init(x: editor.frame.midX, y: editor.frame.midY))
        #expect(!overlay.controlsView.isHidden && overlay.panel.alphaValue == 1)
        #expect(overlay.controlsView.window === (detached ? overlay.controlPanel : overlay.panel))
        model.session.adjustOffset(by: 100)
        #expect(target.matches(model.session) && model.session.position == 9)
        try capture(try #require(editor.contentView), name: "offset-editor")
        try capture(overlay.controlsView, name: "control-strip")
        overlay.closeOffsetEditor()
        overlay.refreshAppearance(at: .init(x: overlay.panel.frame.midX, y: overlay.panel.frame.midY))
        #expect(overlay.panel.alphaValue == 0, "Closing the editor restores hover hiding")
        overlay.toggleOffsetEditor()
        let next = Track(playerID: "test", playerName: "Test", title: "Next")
        model.session.accept(.init(track: next, position: 0, isPlaying: false), shouldSearch: false)
        try await settle()
        #expect(overlay.offsetEditorPanel == nil && !target.matches(model.session))
        model.session.use(.init(lines: [.init(id: 0, time: 0, text: "Next lyrics")]), persist: false)
        overlay.toggleOffsetEditor()
        #expect(overlay.offsetEditorPanel != nil)
        model.preferences.hideWhenPaused = true
        try await settle()
        #expect(overlay.offsetEditorPanel == nil)
    }

    @Test func sourceListMigrationAndToggleUseTheSameSearchConfiguration() async throws {
        let (model, defaults, suite) = try makeModel()
        defer { model.stop(); defaults.removePersistentDomain(forName: suite) }
        #expect(model.preferences.sourceOrder.contains("Apple Music"))
        model.preferences.setSource("Apple Music", enabled: false)
        #expect(!model.preferences.sourceConfigurationReader.read().enabled.contains("Apple Music"))
        model.preferences.setSource("Apple Music", enabled: true)
        _ = model.preferences.moveSource("Apple Music", before: "LRCLIB")
        #expect(model.preferences.sourceConfigurationReader.read().sourceOrder.first == "Apple Music")
        defaults.set(false, forKey: "appleMusicLyricsEnabled")
        let migrated = Preferences(defaults: defaults)
        #expect(migrated.disabledSources.contains("Apple Music") && defaults.object(forKey: "appleMusicLyricsEnabled") == nil)
        migrated.setSource("Apple Music", enabled: true)
        #expect(Preferences(defaults: defaults).sourceConfigurationReader.read().enabled.contains("Apple Music"))
        let panel = NSPanel(contentRect: .init(x: 100, y: 160, width: 860, height: 960),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .aqua)
        panel.contentView = NSHostingView(rootView: PreferencesView(model: model, initialSection: .sources)
            .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .light))
        panel.orderFrontRegardless()
        defer { panel.orderOut(nil); panel.contentView = nil; panel.close() }
        try await settle()
        try capture(try #require(panel.contentView), name: "apple-music-source-settings")
    }

    @Test func animatedEditorReopenCannotBeClosedByAnOldCompletionAndNarrowControlsStayWhole() async throws {
        let (model, defaults, suite) = try makeModel()
        model.preferences.reduceMotion = false; model.preferences.overlayWidth = 320
        model.preferences.overlayClickThrough = true
        model.preferences.hideOverlayOnHover = true; model.preferences.overlayLocked = true
        var pointer = NSPoint(x: -10_000, y: -10_000)
        let overlay = OverlayController(model: model, frameAutosaveName: nil, pointerLocation: { pointer })
        defer { overlay.stop(); model.stop(); defaults.removePersistentDomain(forName: suite) }
        try await settle()
        overlay.toggleOffsetEditor()
        let old = try #require(overlay.offsetEditorPanel)
        overlay.closeOffsetEditor()
        overlay.toggleOffsetEditor()
        let current = try #require(overlay.offsetEditorPanel)
        try await settle()
        #expect(old !== current && old.contentView == nil && !old.isVisible)
        #expect(current.isVisible && current.alphaValue == 1)
        #expect(abs(current.frame.maxX - overlay.panel.frame.maxX) < 1)
        #expect(!current.frame.intersects(overlay.panel.frame))
        func glassCount(_ view: NSView) -> Int {
            (view is NSGlassEffectView ? 1 : 0) + view.subviews.reduce(0) { $0 + glassCount($1) }
        }
        #expect(glassCount(overlay.controlsView) == 0, "The controls must not refract the lyric glass a second time")
        #expect(glassCount(try #require(current.contentView)) == 0,
            "The sync editor must blur its backdrop without refracting text into its controls")
        try capture(try #require(current.contentView), name: "offset-editor-320")
        overlay.closeOffsetEditor()
        pointer = .init(x: overlay.panel.frame.midX, y: overlay.panel.frame.midY)
        overlay.refreshAppearance(at: pointer)
        try await settle()
        #expect(overlay.panel.alphaValue == 0 && overlay.controlPanel.isVisible)
    }

    @Test func plainTextCannotOpenOffsetEditorAndNativeSearchOffersMusicPreview() async throws {
        let (model, defaults, suite) = try makeModel()
        defer { model.stop(); defaults.removePersistentDomain(forName: suite) }
        let track = try #require(model.session.track)
        model.session.use(.init(source: "Apple Music", plainText: "第一行纯文本\n第二行纯文本"), persist: false)
        #expect(OverlayOffsetTarget(session: model.session) == nil)
        let original = try #require(model.session.document)
        model.session.use(.init(lines: [.init(id: 0, time: 0, text: "纯音乐")]), persist: false)
        #expect(model.session.documentIsPlaceholder && OverlayOffsetTarget(session: model.session) == nil)
        model.session.use(original, persist: false)
        var candidates: [LyricCandidate] = []
        for try await candidate in model.store.search(track: track, keyword: track.title + " " + track.artist) { candidates.append(candidate) }
        let candidate = try #require(candidates.first { $0.document.source == "Apple Music" })
        #expect(candidate.document.isSynced)
        let previewPanel = NSPanel(contentRect: .init(x: 100, y: 160, width: 340, height: 450),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        previewPanel.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: SearchLyricPreview(model: model, document: candidate.document, isPreview: true))
        previewPanel.contentView = host; previewPanel.orderFrontRegardless()
        defer { previewPanel.orderOut(nil); previewPanel.contentView = nil; previewPanel.close() }
        try await settle()
        try capture(host, name: "apple-music-synced-preview")
        #expect(model.session.document?.id == original.id && model.session.position == 9)
        #expect(model.applySearchCandidate(candidate, forTrackRevision: model.session.trackRevision))
        #expect(model.session.document?.source == "Apple Music")
        previewPanel.setContentSize(.init(width: 900, height: 620))
        previewPanel.appearance = NSAppearance(named: .aqua)
        let searchHost = NSHostingView(rootView: SearchView(model: model)
            .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .light))
        previewPanel.contentView = searchHost
        try await settle()
        try capture(searchHost, name: "apple-music-search")
        previewPanel.setContentSize(.init(width: 340, height: 450))
        let plainHost = NSHostingView(rootView: SearchLyricPreview(model: model, document: original, isPreview: true))
        previewPanel.contentView = plainHost
        try await settle()
        try capture(plainHost, name: "apple-music-plain-preview")
    }

    @Test func songCardArtworkAndTextStayCenteredTogetherAtEveryWidth() async throws {
        let (model, defaults, suite) = try makeModel()
        let overlay = OverlayController(model: model, frameAutosaveName: nil, pointerLocation: { .init(x: -10_000, y: -10_000) })
        defer { overlay.stop(); model.stop(); defaults.removePersistentDomain(forName: suite) }
        model.session.suppressLyrics()
        model.artwork = NSImage(size: .init(width: 64, height: 64), flipped: false) { rect in NSColor.red.setFill(); rect.fill(); return true }
        for width in [320.0, 620.0, 1000.0] {
            model.preferences.overlayWidth = width
            try await settle()
            let host = try #require(overlay.panel.contentView)
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            var left = bitmap.pixelsWide, right = 0
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                       color.alphaComponent > 0.7,
                       (color.redComponent > 0.7 && color.greenComponent < 0.25 && color.blueComponent < 0.25
                        || min(color.redComponent, color.greenComponent, color.blueComponent) > 0.7) {
                        left = min(left, x); right = max(right, x)
                    }
                }
            }
            #expect(left < bitmap.pixelsWide)
            let scale = CGFloat(bitmap.pixelsWide) / host.bounds.width
            #expect(abs(CGFloat(left + right) / (2 * scale) - width / 2) < 3)
            try capture(try #require(overlay.panel.contentView), name: "song-card-\(Int(width))")
        }
    }
}
