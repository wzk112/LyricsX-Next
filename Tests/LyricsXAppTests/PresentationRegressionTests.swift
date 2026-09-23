import AppKit
import Foundation
import Testing
import SwiftUI
import Darwin
import LyricsXCore
@testable import LyricsXApp

private struct EmptyRepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws { }
}

private let overlayTrack = Track(playerID: "test", playerName: "Test", title: "Overlay Song", artist: "Artist", duration: 180)
private let overlayLyrics = LyricsDocument(title: "Overlay Song", artist: "Artist", duration: 180,
    lines: [.init(id: 0, time: 0, text: "Visible lyric")])

@Suite @MainActor struct PresentationRegressionTests {
    @Test func nativeOverlayKeepsControlsClickableDuringPassThroughAndHoverHide() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.hideWhenPaused = false
        prefs.hideOverlayOnHover = true
        prefs.reduceMotion = true
        let model = AppModel(repository: EmptyRepository(), preferences: prefs)
        model.session.accept(.init(track: overlayTrack, position: 1, isPlaying: true), shouldSearch: false)
        model.session.use(overlayLyrics, persist: false)
        let overlay = OverlayController(model: model, frameAutosaveName: nil)
        defer { overlay.stop(); model.stop() }
        let center = NSPoint(x: overlay.panel.frame.midX, y: overlay.panel.frame.midY)
        let outside = NSPoint(x: -10_000, y: -10_000)
        let dragPoint = NSPoint(x: 100, y: 50)
        model.setOverlayClickThrough(true)
        try await Task.sleep(for: .milliseconds(25))
        overlay.refreshAppearance(at: center)
        #expect(overlay.panel.ignoresMouseEvents)
        #expect(!overlay.controlPanel.ignoresMouseEvents && overlay.controlPanel.isVisible)
        #expect(!overlay.isRenderingLyrics)
        #expect(!overlay.panel.shouldDrag(at: dragPoint))
        overlay.refreshAppearance(at: outside)
        #expect(overlay.isRenderingLyrics && !overlay.controlPanel.isVisible)
        overlay.refreshAppearance(at: center)
        #expect(overlay.controlPanel.isVisible)
        model.setOverlayLocked(false)
        try await Task.sleep(for: .milliseconds(25))
        overlay.refreshAppearance(at: center)
        #expect(!overlay.panel.ignoresMouseEvents && overlay.panel.shouldDrag(at: dragPoint))
        #expect(overlay.isRenderingLyrics)
        #expect(overlay.controlsView.window === overlay.panel)
        #expect(!overlay.controlsView.isHidden && !overlay.controlPanel.isVisible)
        #expect(!overlay.panel.shouldDrag(at: NSPoint(x: overlay.panel.frame.width - 40, y: overlay.panel.frame.height - 20)))
        let originalFrame = overlay.panel.frame
        let originalControlRect = overlay.controlsView.convert(overlay.controlsView.bounds, to: nil)
        overlay.panel.onDragActivity?(true)
        // Assert visibility and fixed screen-relative geometry DURING every move,
        // including when the pointer sample falls outside during a fast drag.
        for step in 1...12 {
            let delta = NSPoint(x: Double(step) * 9, y: Double(step) * 4)
            overlay.panel.setFrameOrigin(NSPoint(x: originalFrame.minX + delta.x, y: originalFrame.minY + delta.y))
            overlay.refreshAppearance(at: outside)
            #expect(overlay.controlsView.window === overlay.panel)
            #expect(!overlay.controlsView.isHidden && overlay.controlsView.alphaValue == 1)
            #expect(!overlay.controlPanel.isVisible)
            let rect = overlay.panel.convertToScreen(overlay.controlsView.convert(overlay.controlsView.bounds, to: nil))
            #expect(rect.origin == NSPoint(x: originalFrame.minX + originalControlRect.minX + delta.x, y: originalFrame.minY + originalControlRect.minY + delta.y))
        }
        overlay.panel.onDragActivity?(false)
        overlay.refreshAppearance(at: NSPoint(x: overlay.panel.frame.midX, y: overlay.panel.frame.midY))
        #expect(!overlay.controlsView.isHidden && overlay.controlsView.window === overlay.panel)
        model.setOverlayClickThrough(true)
        try await Task.sleep(for: .milliseconds(25))
        overlay.refreshAppearance(at: NSPoint(x: overlay.panel.frame.midX, y: overlay.panel.frame.midY))
        #expect(overlay.controlsView.window === overlay.controlPanel)
        #expect(overlay.controlPanel.isVisible && !overlay.controlPanel.ignoresMouseEvents)
        #expect(overlay.panel.ignoresMouseEvents)
        prefs.overlayVisible = false
        try await Task.sleep(for: .milliseconds(25))
        #expect(!overlay.panel.isVisible && !overlay.controlPanel.isVisible)
    }

    @Test func overlayShowsSongTitleWhenLyricsAreUnavailable() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.hideWhenPaused = false
        let model = AppModel(repository: EmptyRepository(), preferences: prefs)
        defer { model.stop() }
        let overlay = OverlayController(model: model, frameAutosaveName: nil)
        defer { overlay.stop() }
        #expect(!overlay.panel.isVisible)

        model.session.accept(.init(track: overlayTrack, position: 1, isPlaying: true), shouldSearch: false)
        model.session.use(overlayLyrics, persist: false)
        try await Task.sleep(for: .milliseconds(25))
        #expect(overlay.panel.isVisible)

        model.session.use(.init(title: "Overlay Song",
            lines: [.init(id: 0, time: 0, text: "Instrumental")], isInstrumental: true), persist: false)
        try await Task.sleep(for: .milliseconds(25))
        #expect(overlay.panel.isVisible)

        model.session.use(.init(title: "Overlay Song",
            lines: [.init(id: 0, time: 0, text: "   ")]), persist: false)
        try await Task.sleep(for: .milliseconds(25))
        #expect(overlay.panel.isVisible)
    }

    @Test func overlayPositionSurvivesControllerRecreation() throws {
        _ = NSApplication.shared
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        let model = AppModel(repository: EmptyRepository(), preferences: prefs)
        let autosaveName = "LyricsXTestOverlay-\(UUID().uuidString)"
        let first = OverlayController(model: model, frameAutosaveName: autosaveName)
        defer { first.stop(); model.stop() }
        let target = NSPoint(x: first.panel.frame.minX + 83, y: first.panel.frame.minY + 47)
        first.panel.setFrameOrigin(target)
        first.windowDidMove(Notification(name: NSWindow.didMoveNotification, object: first.panel))
        let second = OverlayController(model: model, frameAutosaveName: autosaveName)
        defer { second.stop() }
        #expect(abs(second.panel.frame.minX - target.x) < 1)
        #expect(abs(second.panel.frame.minY - target.y) < 1)
        UserDefaults.standard.removeObject(forKey: "NSWindow Frame \(autosaveName)")
        UserDefaults.standard.removeObject(forKey: "LyricsX.OverlayPosition.\(autosaveName)")
        UserDefaults.standard.removeObject(forKey: "LyricsX.OverlayCenter.\(autosaveName)")
        UserDefaults.standard.removeObject(forKey: "LyricsX.OverlayTop.\(autosaveName)")
    }

    @Test func compactCardAndTimedLyricsKeepTopAndRestoreAfterEdgeClamping() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.fontSize = 42; prefs.overlayWidth = 600
        prefs.overlayAdaptiveSize = false; prefs.reduceMotion = true
        let model = AppModel(repository: EmptyRepository(), preferences: prefs)
        model.session.accept(.init(track: overlayTrack, position: 10, isPlaying: true), shouldSearch: false)
        let name = "LyricsXTestOverlay-" + UUID().uuidString
        let overlay = OverlayController(model: model, frameAutosaveName: name)
        defer {
            overlay.stop(); model.stop()
            UserDefaults.standard.removeObject(forKey: "NSWindow Frame \(name)")
            UserDefaults.standard.removeObject(forKey: "LyricsX.OverlayPosition.\(name)")
        }
        let screen = try #require(NSScreen.main)
        let target = NSPoint(x: screen.visibleFrame.maxX - 604, y: screen.visibleFrame.minY + 100)
        overlay.panel.setFrameOrigin(target)
        let top = NSPoint(x: overlay.panel.frame.midX, y: overlay.panel.frame.maxY)
        overlay.windowDidMove(.init(name: NSWindow.didMoveNotification, object: overlay.panel))
        for _ in 0..<3 {
            model.session.use(overlayLyrics, persist: false)
            try await Task.sleep(for: .milliseconds(25))
            #expect(!model.overlayUsesCompactPresentation && overlay.panel.frame.width == 600)
            #expect(overlay.panel.frame.maxX <= screen.visibleFrame.maxX)
            model.session.use(.init(plainText: "纯音乐，请欣赏"), persist: false)
            try await Task.sleep(for: .milliseconds(25))
            #expect(model.overlayUsesCompactPresentation && overlay.panel.frame.size == NSSize(width: 600, height: OverlaySongCardLayout(width: 600).height))
            #expect(overlay.panel.frame.origin == target)
            #expect(UserDefaults.standard.string(forKey: "LyricsX.OverlayPosition.\(name)") == NSStringFromPoint(target))
            #expect(UserDefaults.standard.string(forKey: "LyricsX.OverlayTop.\(name)") == NSStringFromPoint(top))
        }
        UserDefaults.standard.removeObject(forKey: "LyricsX.OverlayCenter.\(name)")
        UserDefaults.standard.removeObject(forKey: "LyricsX.OverlayTop.\(name)")
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LYRICSX_RENDER_QA"] != nil))
    func renderCompactCardForVisualInspection() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults); prefs.overlayVisible = true; prefs.hideWhenPaused = false
        prefs.overlayWidth = 400; prefs.hideOverlayOnHover = false
        let model = AppModel(repository: EmptyRepository(), preferences: prefs)
        let track = Track(playerID: "test", playerName: "Test", title: "ATLAS RUSH", artist: "kanone")
        model.session.accept(.init(track: track, position: 0, isPlaying: false), shouldSearch: false)
        model.session.use(.init(plainText: "纯音乐，请欣赏"), persist: false)
        let overlay = OverlayController(model: model, frameAutosaveName: nil)
        defer { overlay.stop(); model.stop() }
        overlay.panel.orderFrontRegardless()
        try await Task.sleep(for: .milliseconds(350))
        let directory = try #require(ProcessInfo.processInfo.environment["LYRICSX_RENDER_QA"])
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-l", String(overlay.panel.windowNumber), directory + "/compact-overlay.png"]
        try process.run(); process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    @Test func overlayControlsKeepARecoverableDragState() throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        let model = AppModel(repository: EmptyRepository(), preferences: prefs)
        prefs.hideOverlayOnHover = true
        model.setOverlayClickThrough(true)
        #expect(prefs.overlayClickThrough && prefs.overlayLocked)
        model.setOverlayClickThrough(false)
        #expect(!prefs.overlayClickThrough && prefs.overlayLocked)
        #expect(prefs.hideOverlayOnHover)
        model.setOverlayClickThrough(true)
        model.setOverlayLocked(false)
        #expect(!prefs.overlayClickThrough && !prefs.overlayLocked)
        model.setOverlayLocked(true)
        #expect(prefs.overlayLocked && !prefs.overlayClickThrough)
        model.setOverlayVisible(false)
        #expect(!prefs.overlayVisible && prefs.overlayLocked)
        model.setOverlayVisible(true)
        #expect(prefs.overlayVisible && prefs.overlayLocked)
        model.stop()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LYRICSX_CONTROL_QA"] != nil))
    func renderControlsOverLightAndDarkBackgrounds() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlayVisible = true; prefs.hideWhenPaused = false; prefs.hideOverlayOnHover = false
        prefs.reduceMotion = false; prefs.overlayTransparency = 0.6
        if let accent = ProcessInfo.processInfo.environment["LYRICSX_CONTROL_QA_ACCENT"] {
            prefs.followArtworkColors = true
            prefs.artworkTheme = .init(accent: accent, sung: "FFFFFF", unsung: "777777", secondary: "FFFFFF")
        }
        let model = AppModel(repository: EmptyRepository(), preferences: prefs)
        model.session.accept(.init(track: overlayTrack, position: 1, isPlaying: false), shouldSearch: false)
        model.session.use(LyricsDocument(title: overlayTrack.title, artist: overlayTrack.artist,
            lines: [.init(id: 0, time: 0, text: "Light moves through the glass", translation: "光线穿过玻璃",
                          words: [.init(text: "Light", start: 0, end: 3)]),
                    .init(id: 1, time: 20, text: "And the words stay clear")]), persist: false)
        let overlay = OverlayController(model: model, frameAutosaveName: nil)
        defer { overlay.stop(); model.stop() }
        if ProcessInfo.processInfo.environment["LYRICSX_CONTROL_QA_FOREGROUND"] == "1" {
            // Keep an opt-in compositing capture above unrelated front windows.
            // This does not activate the panel or change production levels.
            overlay.panel.level = .statusBar
            overlay.controlPanel.level = .statusBar
        }
        overlay.panel.onDragActivity?(true)
        let directory = try #require(ProcessInfo.processInfo.environment["LYRICSX_CONTROL_QA"])
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("scripts/qa/glass-backdrop.swift")
        let executable = directory + "/glass-backdrop"
        let compiler = Process(); compiler.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
        compiler.arguments = [fixture.path, "-o", executable]
        try compiler.run(); compiler.waitUntilExit()
        try #require(compiler.terminationStatus == 0)
        let focusedStyle = ProcessInfo.processInfo.environment["LYRICSX_CONTROL_QA_STYLE"]
        var examples = OverlayAppearance.allCases.filter { focusedStyle == nil || $0.rawValue == focusedStyle }.flatMap { appearance in
            ["light", "dark", "color", "reference-light", "reference-dark"].map { (appearance, $0, 0.6, appearance.defaultFrost) }
                + [0.2, 0.8].flatMap { transparency in ["light", "text"].map { (appearance, $0, transparency, appearance.defaultFrost) } }
                + [0.0, 1.0].map { (appearance, "text", 0.8, $0) }
        }
        if focusedStyle == "glass" {
            examples += [0.0, 1.0].map { (OverlayAppearance.glass, "light", $0, OverlayAppearance.glass.defaultFrost) }
        }
        if let surfaces = ProcessInfo.processInfo.environment["LYRICSX_CONTROL_QA_SURFACES"] {
            let selected = Set(surfaces.split(separator: ",").map(String.init))
            examples = examples.filter { selected.contains($0.1) }
        }
        try #require(!examples.isEmpty)
        let themeProbe = ProcessInfo.processInfo.environment["LYRICSX_CONTROL_QA_THEME"].flatMap(InterfaceTheme.init(rawValue:))
        let ranges = ProcessInfo.processInfo.environment["LYRICSX_CONTROL_QA_HDR"] == "1" ? [true] : themeProbe == nil ? [false, true] : [false]
        for hdr in ranges {
            prefs.lyricHDRBrightness = 3.5
            prefs.lyricHDR = hdr
            for (appearance, surface, transparency, frost) in examples {
                prefs.overlayAppearance = appearance
                prefs.overlayMaterialTransparency = transparency
                prefs.overlayFrostAmount = frost
                // Reproduce a compact waiting card expanding into timed lyrics.
                // Fixed-size material previews miss stale content-mask bounds.
                let top = overlay.panel.frame.maxY
                var resized = overlay.panel.frame
                resized.size.height = 104
                resized.origin.y = top - resized.height
                overlay.panel.setFrame(resized, display: true)
                try await Task.sleep(for: .milliseconds(30))
                resized.size.height = 196
                resized.origin.y = top - resized.height
                overlay.panel.setFrame(resized, display: true)
                let dark = surface == "dark" || surface == "reference-dark"
                prefs.overlayTheme = themeProbe ?? (dark ? .dark : .light)
                let frame = overlay.panel.frame.insetBy(dx: -20, dy: -20)
                let ready = directory + "/" + UUID().uuidString + ".ready"
                let backdrop = Process(); backdrop.executableURL = URL(fileURLWithPath: executable)
                backdrop.arguments = [frame.minX, frame.minY, frame.width, frame.height].map { String(Double($0)) }
                    + [surface, ready]
                try backdrop.run()
                defer {
                    if backdrop.isRunning { backdrop.terminate() }
                    backdrop.waitUntilExit()
                    try? FileManager.default.removeItem(atPath: ready)
                }
                // Readiness is bounded and yields the main actor for native drawing.
                for _ in 0..<100 where !FileManager.default.fileExists(atPath: ready) {
                    try await Task.sleep(for: .milliseconds(20))
                }
                try #require(FileManager.default.fileExists(atPath: ready))
                overlay.panel.orderFrontRegardless()
                for detached in themeProbe == nil ? [false, true] : [false] {
                    model.setOverlayClickThrough(detached)
                    try await Task.sleep(for: .milliseconds(100))
                    overlay.refreshAppearance(at: NSPoint(x: overlay.panel.frame.midX, y: overlay.panel.frame.midY))
                    try await Task.sleep(for: .milliseconds(500))
                    if themeProbe != nil {
                        let material = overlay.panel.contentView!.subviews.compactMap { $0 as? OverlayGlassBackground }.first!
                        let native = material.subviews.first as! NSGlassEffectView
                        print("THEME probe pref=\(prefs.overlayTheme) window=\(String(describing: overlay.panel.appearance?.name)) bg=\(material.effectiveAppearance.name) glass=\(native.effectiveAppearance.name) host=\(overlay.lyricHostingView.effectiveAppearance.name) alpha=\(native.alphaValue)")
                    }
                    let window = detached ? overlay.controlPanel : overlay.panel
                    let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                    let frostSuffix = frost == appearance.defaultFrost ? "" : "-frost-\(Int(frost * 100))"
                    let name = "controls-\(appearance.rawValue)-\(surface)-\(Int((transparency * 100).rounded()))-\(hdr ? "hdr" : "sdr")-\(detached ? "detached" : "inline")\(frostSuffix).png"
                    // Capture different processes together, including real EDR
                    // compositing. Isolated window captures can replace glass with grey.
                    let frame = window.frame
                    let top = (NSScreen.screens.first?.frame.maxY ?? 0) - frame.maxY
                    let region = "\(Int(frame.minX)),\(Int(top)),\(Int(frame.width)),\(Int(frame.height))"
                    process.arguments = ["-x", "-R", region, directory + "/" + name]
                    try process.run(); process.waitUntilExit()
                    #expect(process.terminationStatus == 0)
                }
            }
        }
        // A focused capture is for visual comparison, not the two-style blur ratio.
        if focusedStyle != nil { return }
        // Measure fine background detail away from the foreground lyrics. A
        // successful screenshot alone cannot detect an opaque grey fallback.
        func backgroundDetail(_ style: String, _ range: String, frostSuffix: String = "") throws -> Double {
            let path = directory + "/controls-\(style)-text-80-\(range)-inline\(frostSuffix).png"
            let bitmap = try #require(NSBitmapImageRep(data: Data(contentsOf: URL(fileURLWithPath: path))))
            let scale = Double(bitmap.pixelsWide) / overlay.panel.frame.width
            var energy = 0.0, samples = 0.0
            for y in Int(78 * scale)..<Int(120 * scale) {
                for x in Int(32 * scale)..<Int(110 * scale) {
                    let first = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                    let next = try #require(bitmap.colorAt(x: x + 1, y: y)?.usingColorSpace(.deviceRGB))
                    energy += abs(first.redComponent - next.redComponent)
                    samples += 1
                }
            }
            return energy / samples
        }
        for range in ["sdr", "hdr"] {
            // Only reading glass exposes a blur-strength adjustment now.
            let low = try backgroundDetail("frosted", range, frostSuffix: "-frost-0")
            let high = try backgroundDetail("frosted", range, frostSuffix: "-frost-100")
            #expect(low > high * 1.5)
            // A mask left at the compact height creates a horizontal tint seam
            // after expansion. Sample the blank area between header and lyrics.
            let path = directory + "/controls-glass-light-20-\(range)-inline.png"
            let bitmap = try #require(NSBitmapImageRep(data: Data(contentsOf: URL(fileURLWithPath: path))))
            let scale = Double(bitmap.pixelsWide) / overlay.panel.frame.width
            let x = Int(82 * scale)
            var largestStep = 0.0
            // The real overlay may settle to its measured lyric height after
            // the forced resize. Stay within its reading area, excluding the
            // bottom optical edge and the desktop beyond the rounded panel.
            for y in Int(50 * scale)..<min(Int(170 * scale), bitmap.pixelsHigh - Int(20 * scale)) {
                let first = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                let next = try #require(bitmap.colorAt(x: x, y: y + 1)?.usingColorSpace(.deviceRGB))
                largestStep = max(largestStep, abs(first.redComponent - next.redComponent))
            }
            #expect(largestStep < 0.04)
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LYRICSX_PERFORMANCE_QA"] == "1"))
    func animatedSurfacesStopWorkWhenHiddenAndKeepNativeCadence() async throws {
        _ = NSApplication.shared
        NSApp.finishLaunching()
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlayVisible = true; prefs.hideWhenPaused = false
        prefs.overlayLocked = true; prefs.hideOverlayOnHover = true
        prefs.overlaySecondaryMode = .both; prefs.lyricHDR = true
        let model = AppModel(repository: EmptyRepository(), preferences: prefs)
        let document = LyricsDocument(title: "Performance fixture", lines: (0..<12).map { index in
            let time = Double(index) * 2
            return LyricLine(id: index, time: time, text: "Light moves through the glass",
                translation: index.isMultiple(of: 2) ? "光线穿过玻璃" : "保持清晰与流畅",
                words: [.init(text: "Light", start: time, end: time + 1.2),
                        .init(text: "moves through the glass", start: time + 1.2, end: time + 2)])
        })
        model.session.accept(.init(track: overlayTrack, position: 0, isPlaying: true), shouldSearch: false)
        model.session.use(document, persist: false)
        model.mainWindowVisible = true
        var pointer = NSPoint(x: -10_000, y: -10_000)
        let overlay = OverlayController(model: model, frameAutosaveName: nil, pointerLocation: { pointer })
        let main = NSPanel(contentRect: .init(x: 50, y: 250, width: 760, height: 480),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        main.isReleasedWhenClosed = false
        main.contentView = NSHostingView(rootView: NowPlayingView(model: model).hdrDisplayScope(requested: true))
        main.orderFrontRegardless()
        overlay.panel.orderFrontRegardless()
        let playbackStart = ProcessInfo.processInfo.systemUptime
        let ticker = PlaybackTicker {
            let now = ProcessInfo.processInfo.systemUptime
            model.session.accept(.init(track: overlayTrack, position: now - playbackStart, isPlaying: true), now: now)
            model.updateMainLyricSelection()
            return LyricTickCadence.milliseconds(playing: true,
                visible: model.mainWindowVisible || overlay.needsPreciseLyricTicks,
                document: document, position: model.session.position)
        }
        ticker.start()
        defer { ticker.stop(); overlay.stop(); main.close(); model.stop() }
        func frames(in view: NSView) -> [LyricFrameView] {
            (view as? LyricFrameView).map { [$0] } ?? view.subviews.flatMap { frames(in: $0) }
        }
        // Swift Testing has no NSApplication.run(). Drain its native event queue
        // so WindowServer occlusion events reach the real window observers.
        func render(for seconds: Double) async throws {
            let end = ProcessInfo.processInfo.systemUptime + seconds
            while ProcessInfo.processInfo.systemUptime < end {
                if let event = NSApp.nextEvent(matching: .any, until: Date().addingTimeInterval(0.01), inMode: .default, dequeue: true) {
                    NSApp.sendEvent(event)
                }
                try await Task.sleep(for: .milliseconds(5))
            }
        }
        func cpuTime() -> Double {
            var usage = rusage()
            getrusage(RUSAGE_SELF, &usage)
            return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
                + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
        }
        let begin = cpuTime()
        try await render(for: 3)
        let bothCPU = (cpuTime() - begin) / 3 * 100
        let active = frames(in: overlay.lyricHostingView).filter(\.deliveringFrames)
        print("Overlay render probe: visible=\(overlay.panel.isVisible), exposed=\(overlay.panel.occlusionState.contains(.visible)), lyric=\(overlay.isRenderingLyrics), playing=\(model.session.isPlaying), sources=\(frames(in: overlay.lyricHostingView).map { [$0.running, $0.deliveringFrames] })")
        #expect(!active.isEmpty)
        #expect(active.allSatisfy { $0.requestedFrameRate == overlay.panel.screen?.maximumFramesPerSecond })
        main.orderOut(nil); model.mainWindowVisible = false
        let overlayBegin = cpuTime()
        try await render(for: 3)
        let overlayCPU = (cpuTime() - overlayBegin) / 3 * 100
        #expect(!frames(in: overlay.lyricHostingView).filter(\.deliveringFrames).isEmpty)
        // Holding the same synthetic pointer position avoids a real mouse move.
        pointer = NSPoint(x: overlay.panel.frame.midX, y: overlay.panel.frame.midY)
        overlay.refreshAppearance()
        try await render(for: 0.25)
        #expect(!frames(in: overlay.lyricHostingView).contains { $0.deliveringFrames })
        prefs.overlayVisible = false
        try await render(for: 0.25)
        let hiddenBegin = cpuTime()
        try await render(for: 1)
        #expect(!frames(in: overlay.lyricHostingView).contains { $0.deliveringFrames })
        print(String(format: "Isolated render CPU: both %.1f%%; overlay %.1f%%; hidden %.1f%%; requested %d Hz",
            bothCPU, overlayCPU, (cpuTime() - hiddenBegin) * 100, overlay.panel.screen?.maximumFramesPerSecond ?? 0))
    }

    @Test func repeatedArtworkSamplesKeepTheDecodedImageAndTrackChangeClearsIt() async throws {
        let model = AppModel(repository: EmptyRepository())
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        let track = Track(playerID: "test", playerName: "Test", title: "A", artworkData: data)
        let snapshot = PlaybackSnapshot(track: track, position: 2, isPlaying: true)
        model.bridge.onSnapshot?(snapshot)
        for _ in 0..<200 where model.artwork == nil { try await Task.sleep(for: .milliseconds(10)) }
        let image = try #require(model.artwork)
        for _ in 0..<6 { model.bridge.onSnapshot?(snapshot); #expect(model.artwork === image) }
        model.bridge.onSnapshot?(.init(track: .init(playerID: "test", playerName: "Test", title: "B"), position: 0, isPlaying: true))
        #expect(model.artwork == nil)
        #expect(model.session.track?.title == "B")
        model.stop()
    }

    @Test func rejectedTransportGapDoesNotClearAcceptedTrackOrArtwork() async throws {
        let model = AppModel(repository: EmptyRepository())
        defer { model.stop() }
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        let track = Track(playerID: "test", playerName: "Test", title: "A", artworkData: data)
        model.bridge.onSnapshot?(.init(track: track, position: 40, isPlaying: true))
        for _ in 0..<200 where model.artwork == nil { try await Task.sleep(for: .milliseconds(10)) }
        let image = try #require(model.artwork)
        let generation = model.session.searchGeneration
        model.bridge.onSnapshot?(.init(track: nil, position: 0, isPlaying: false, positionIsReliable: false, playbackStateIsReliable: false))
        #expect(model.artwork === image)
        #expect(model.session.track == track && model.session.searchGeneration == generation)
    }

    @Test func previewDataCannotReplaceTheProductionSession() {
        let model = AppModel(repository: EmptyRepository())
        model.bridge.onSnapshot?(.init(track: .init(playerID: "test", playerName: "Test", title: "Real song"), position: 10, isPlaying: true))
        let preview = LyricsPreviewView(preferences: model.preferences)
        _ = preview
        _ = DemoContent.document
        #expect(model.session.track?.title == "Real song")
        #expect(model.session.track?.playerID != "lyricsx.demo")
        model.stop()
    }

    @Test func legacyMaterialSettingsMigrateOnceAndRespectNewTransparency() throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for (oldStyle, expectedStyle) in [("native", OverlayAppearance.glass), ("glass", .glass), ("petGlass", .glass), ("dark", .frosted)] {
            defaults.removePersistentDomain(forName: suite)
            defaults.set(oldStyle, forKey: "overlayAppearance")
            defaults.set(0.28, forKey: "overlayBackgroundStrength")
            let migrated = Preferences(defaults: defaults)
            #expect(migrated.overlayAppearance == expectedStyle)
            #expect(abs(migrated.overlayTransparency - 0.72) < 0.001)
            migrated.overlayTransparency = 0.42
            migrated.overlayFrostAmount = 0.24
            let restored = Preferences(defaults: defaults)
            #expect(restored.overlayAppearance == expectedStyle)
            #expect(restored.overlayTransparency == 0.42)
            #expect(restored.overlayFrostAmount == (expectedStyle == .frosted ? 0.24 : OverlayAppearance.glass.defaultFrost))
        }
        defaults.set(0.95, forKey: "overlayTransparency")
        #expect(Preferences(defaults: defaults).overlayTransparency == 0.8)
        defaults.set(-0.5, forKey: "overlayTransparency")
        #expect(Preferences(defaults: defaults).overlayTransparency == 0.2)
    }

    @Test func menuAndOverlayPreferencesSurviveRelaunch() throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.showMenuBarIcon = false
        #expect(prefs.overlayAppearance == .glass)
        prefs.overlayAppearance = .frosted
        prefs.overlayFrostAmount = 0.72
        prefs.overlayAppearance = .glass
        prefs.overlayGlassFrostAmount = 0.26 // Legacy value survives replacement for rollback.
        prefs.overlayFrostAmount = 0.43 // Must not change either adjustable material.
        prefs.overlayAppearance = .frosted
        #expect(prefs.overlayFrostAmount == 0.72)
        prefs.overlayAppearance = .glass
        #expect(prefs.overlayFrostAmount == OverlayAppearance.glass.defaultFrost)
        prefs.overlayAppearance = .frosted
        prefs.overlayTransparency = 0.34
        prefs.showDockIcon = false
        prefs.showMenubarLyrics = true
        prefs.combinedMenubarLyrics = false
        prefs.translationFontSize = 19
        prefs.nextLineFontSize = 15
        prefs.overlaySecondaryMode = .both
        prefs.setSource("Kugou", enabled: false)
        prefs.moveSource("NetEase", by: -1)
        #expect(prefs.moveSource("QQMusic", before: "LRCLIB"))
        #expect(!prefs.moveSource("Unknown", before: "LRCLIB"))
        prefs.preferBilingual = false
        prefs.preferWordTiming = false
        prefs.strictLyricsMatching = false
        let restored = Preferences(defaults: defaults)
        #expect(restored.overlayAppearance == .frosted && restored.overlayTransparency == 0.34)
        #expect(restored.overlayFrostAmount == 0.72 && restored.overlayGlassFrostAmount == 0.26)
        restored.overlayAppearance = .glass
        #expect(restored.overlayFrostAmount == OverlayAppearance.glass.defaultFrost)
        let liveConfiguration = prefs.sourceConfigurationReader.read()
        #expect(liveConfiguration.sourceOrder == prefs.sourceOrder)
        #expect(!liveConfiguration.preferBilingual && !liveConfiguration.preferWordTiming && !liveConfiguration.strictMatching)
        #expect(!liveConfiguration.enabled.contains("Kugou"))
        #expect(!restored.showDockIcon)
        #expect(!restored.showMenuBarIcon && restored.showMenubarLyrics && !restored.combinedMenubarLyrics)
        #expect(restored.translationFontSize == 19 && restored.nextLineFontSize == 15)
        #expect(restored.overlaySecondaryMode == .both)
        #expect(restored.sourceOrder == ["NetEase", "QQMusic", "LRCLIB", "Kugou", "Musixmatch"])
        #expect(!restored.preferBilingual && !restored.preferWordTiming && !restored.strictLyricsMatching && restored.disabledSources.contains("Kugou"))
    }

    @Test func clearGlassUsesOnePaletteAcrossAppearancesWithoutChangingSavedColors() throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlayAppearance = .glass
        let original = prefs.typography
        let light = prefs.overlayTypography(colorScheme: .light)
        #expect(light.primaryHex == original.primaryHex)
        #expect(light == prefs.overlayTypography(colorScheme: .dark))
        #expect(light.wordColors != nil)
        #expect(prefs.overlayTypography(colorScheme: .dark).wordColors != nil)
        #expect(prefs.typography == original)
        prefs.lyricPrimaryColor = "EFAA7A"
        #expect(prefs.overlayTypography(colorScheme: .light).primaryHex != light.primaryHex)
        #expect(prefs.lyricPrimaryColor == "EFAA7A")
        prefs.followArtworkColors = true
        var lightAccents = Set<String>(), darkAccents = Set<String>()
        for accent in ["FFDA20", "1122CC", "F03868"] {
            let theme = ArtworkTheme(accent: accent, sung: "FFFFFF", unsung: "777777", secondary: "FFFFFF")
            prefs.artworkTheme = theme
            lightAccents.insert(prefs.overlayTypography(colorScheme: .light).primaryHex)
            darkAccents.insert(prefs.overlayTypography(colorScheme: .dark).primaryHex)
            #expect(prefs.artworkTheme == theme && prefs.lyricPrimaryColor == "EFAA7A")
        }
        #expect(lightAccents.count == 3 && darkAccents.count == 3)
        for style in [OverlayAppearance.frosted] {
            prefs.overlayAppearance = style
            #expect(LyricTypography.luminance(prefs.overlayTypography(colorScheme: .light).primaryHex) < 0.1)
            #expect(prefs.overlayTypography(colorScheme: .dark) == prefs.typography)
        }
    }
}

@Test func floatingVisibilityAndFrameDeliveryUseTheSameOcclusionPolicy() {
    var activity = WindowRenderActivity()
    let state1 = activity.update(event: nil, visible: true, miniaturized: false, exposed: false, floating: true)
    #expect(state1)
    let state2 = activity.update(event: NSWindow.didChangeOcclusionStateNotification, visible: true, miniaturized: false, exposed: false, floating: true)
    #expect(state2)
    let state3 = !activity.update(event: nil, visible: false, miniaturized: false, exposed: false, floating: true)
    #expect(state3)
    let state4 = activity.update(event: nil, visible: true, miniaturized: false, exposed: false, floating: true)
    #expect(state4)
    let state5 = !activity.update(event: nil, visible: true, miniaturized: false, exposed: false, floating: false)
    #expect(state5)
}
