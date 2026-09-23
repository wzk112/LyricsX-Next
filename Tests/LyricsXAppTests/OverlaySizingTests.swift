import AppKit
import SwiftUI
import Testing
import LyricsXCore
@testable import LyricsXApp

@Test func resizingKeepsTopAndHorizontalCenterAcrossSizesAndScreenClamps() {
    let screen = NSRect(x: -1440, y: -200, width: 1440, height: 1000)
    let anchor = OverlayAnchor(topCenter: .init(x: -700, y: 680))
    for width in stride(from: 320.0, through: 920, by: 40) {
        let frame = anchor.frame(size: .init(width: width, height: width / 4), in: screen)
        #expect(frame.midX == -700 && frame.maxY == 680)
    }
    let edge = OverlayAnchor(topCenter: .init(x: -210, y: 680))
    #expect(edge.frame(size: .init(width: 800, height: 220), in: screen).maxX == 0)
    #expect(edge.frame(size: .init(width: 320, height: 160), in: screen).midX == -210)
}

@MainActor @Test func adaptiveGeometryReservesIncrementalChainsAndHonorsSizeBounds() throws {
    let suite = "LyricsXTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let p = Preferences(defaults: defaults)
    p.overlayWidth = 620; p.overlaySecondaryMode = .none
    let doc = LyricsDocument(lines: [
        .init(id: 0, time: 0, text: "C"), .init(id: 1, time: 0.1, text: "Cor"),
        .init(id: 2, time: 0.2, text: "Corporation"),
        .init(id: 3, time: 3, text: String(repeating: "A long sentence with words ", count: 8))])
    let sizes = (0..<3).map { OverlayTextMeasure.desiredSize(document: doc, index: $0, preferences: p, maximumWidth: 620) }
    #expect(sizes.allSatisfy { $0 == sizes[0] })
    #expect(sizes[0].width == 620)
    let long = OverlayTextMeasure.desiredSize(document: doc, index: 3, preferences: p, maximumWidth: 620)
    #expect(long.width == 620 && long.height > sizes[0].height)
    let singleTranslation = OverlayTextMeasure.translationHeight("MMMM", font: 20, canvasWidth: 260)
    #expect(OverlayTextMeasure.translationHeight("MMMM\nMMMM", font: 20, canvasWidth: 260) == singleTranslation * 2)
    #expect(OverlayTextMeasure.translationHeight(String(repeating: "MMMM ", count: 6), font: 20, canvasWidth: 260) == singleTranslation * 2)
    p.overlayWidth = 320
    #expect(p.overlayLayoutWidth == 320)
    p.overlayAdaptiveSize = false
    let restored = Preferences(defaults: defaults)
    #expect(!restored.overlayAdaptiveSize && restored.overlayLayoutWidth == 320)
}

private struct SizingRepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

@MainActor @Test func renderedLyricsReportTheirHeightWithoutControllerObservationOrHover() async throws {
    _ = NSApplication.shared
    let suite = "LyricsXTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let prefs = Preferences(defaults: defaults)
    prefs.overlayWidth = 620; prefs.overlayAdaptiveSize = true
    prefs.overlaySecondaryMode = .translation
    let model = AppModel(repository: SizingRepository(), preferences: prefs)
    let viewport = OverlayViewport(width: 620)
    var reported: NSSize?
    viewport.contentSizeChanged = { reported = $0 }
    model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Wildfire"),
                               position: 0, isPlaying: false), shouldSearch: false)
    let doc = LyricsDocument(lines: [
        .init(id: 0, time: 0, text: "•••"),
        .init(id: 1, time: 1, text: "Pain will wake up the despondent crowd in this dormant world somehow",
              translation: "伤痛会唤醒沉睡的世界中绝望的人们")])
    model.session.use(doc, persist: false)
    let window = NSPanel(contentRect: .init(x: 0, y: 0, width: 620, height: 400),
                         styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: OverlayView(model: model, viewport: viewport))
    window.orderFrontRegardless()
    defer { window.orderOut(nil); window.contentView = nil; model.stop() }
    for position in [0.0, 1, 0, 1] {
        model.session.seek(to: position)
        let expected = position == 0 ? OverlayPresentationMode.waitingHeight :
            OverlayTextMeasure.height(document: doc, index: 1, preferences: prefs, maximumWidth: 620)
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while reported?.height != CGFloat(expected), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(reported == NSSize(width: 620, height: expected))
    }
}

@MainActor @Test func glassGeometryFollowsResizesWithoutWaitingForDisplayOrHover() throws {
    let background = OverlayGlassBackground(frame: .init(x: 0, y: 0, width: 608, height: 84))
    background.configure(appearance: .glass, transparency: 0.26, frostAmount: 0.8,
                         reduceTransparency: false, reduceMotion: false)
    let glass = try #require(background.subviews.first as? NSGlassEffectView)
    let scrim = try #require(glass.contentView)
    for height in [260.0, 84, 180, 84, 320, 120] {
        background.setFrameSize(.init(width: 608, height: height))
        // No layoutIfNeeded, redraw, visibility toggle, or run-loop delay.
        #expect(glass.frame == background.bounds)
        #expect(scrim.frame == glass.bounds)
        #expect(glass.layer?.mask == nil)
        #expect(glass.alphaValue == 1)
        #expect(scrim.layer?.mask == nil)
    }
}

@MainActor @Test func nativeGlassSwitchKeepsOneNativeSurfaceAlignedThroughResizes() throws {
    let background = OverlayGlassBackground(frame: .init(x: 0, y: 0, width: 608, height: 84))
    background.appearance = NSAppearance(named: .darkAqua)
    background.configure(appearance: .frosted, transparency: 0.26, frostAmount: 0.8,
                         reduceTransparency: false, reduceMotion: true)
    let initial = try #require(background.subviews.first as? NSGlassEffectView)
    let scrim = try #require(initial.contentView)
    func adaptiveAppearance(_ glass: NSGlassEffectView) -> Int? {
        let selector = NSSelectorFromString("_adaptiveAppearance")
        guard glass.responds(to: selector), let implementation = glass.method(for: selector) else { return nil }
        typealias Query = @convention(c) (AnyObject, Selector) -> Int
        return unsafeBitCast(implementation, to: Query.self)(glass, selector)
    }
    for appearance in [OverlayAppearance.glass, .frosted, .glass, .frosted, .glass] {
        background.configure(appearance: appearance, transparency: 0.34,
                             frostAmount: appearance.defaultFrost,
                             reduceTransparency: false, reduceMotion: true)
        let glass = try #require(background.subviews.first as? NSGlassEffectView)
        #expect(background.subviews.count == 1)
        #expect(glass.contentView === scrim)
        if let mode = adaptiveAppearance(glass) {
            #expect(mode == 1, "Both explicit ink palettes need fixed material appearance")
        }
        if appearance == .glass {
            #expect(glass.style == .clear)
            #expect(glass.alphaValue == 1 && glass.layer?.mask == nil)
            #expect(glass.cornerRadius == 32 && scrim.layer?.mask == nil)
            for theme in [NSAppearance.Name.aqua, .darkAqua] {
                background.appearance = NSAppearance(named: theme)
                #expect(glass.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
            }
        }
        for height in [84.0, 196, 120] {
            background.setFrameSize(.init(width: 608, height: height))
            // A material switch must not leave the previous lyric height in
            // the native surface, even before the next display pass.
            #expect(glass.frame == background.bounds)
            #expect(scrim.frame == glass.bounds)
            if let mask = glass.layer?.mask { #expect(mask.frame == glass.bounds) }
            if let mask = scrim.layer?.mask { #expect(mask.frame == scrim.bounds) }
        }
    }
}

@MainActor @Test func nativeGlassAppearanceOverrideKeepsThePanelNonactivating() throws {
    let panel = OverlayMaterialPanel(contentRect: .init(x: 0, y: 0, width: 400, height: 100),
                                    styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    let keyWindow = NSApp.keyWindow
    typealias Query = @convention(c) (AnyObject, Selector) -> Bool
    for name in ["_hasActiveAppearance", "_hasActiveAppearanceIgnoringKeyFocus"] {
        let selector = NSSelectorFromString(name)
        let implementation = try #require(panel.method(for: selector))
        let query = unsafeBitCast(implementation, to: Query.self)
        let original = query(panel, selector)
        panel.keepsGlassAppearanceActive = true
        #expect(query(panel, selector))
        #expect(!panel.isKeyWindow && NSApp.keyWindow === keyWindow)
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        panel.keepsGlassAppearanceActive = false
        #expect(query(panel, selector) == original)
    }
}

@MainActor @Test func overlayFrameRatePreferencePreservesTheUsersChoice() throws {
    let suite = "LyricsXTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let prefs = Preferences(defaults: defaults)
    #expect(prefs.overlayFrameRate == .display)
    prefs.overlayFrameRate = .sixty
    #expect(Preferences(defaults: defaults).overlayFrameRate.limit == 60)
    defaults.set("invalid", forKey: "overlayFrameRate")
    #expect(Preferences(defaults: defaults).overlayFrameRate == .display)
}

@MainActor @Test func nativeWaitingHandoverKeepsTheDepartingLyricsInsideTheWindow() async throws {
    _ = NSApplication.shared
    let suite = "LyricsXTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let prefs = Preferences(defaults: defaults)
    prefs.overlayWidth = 620; prefs.hideWhenPaused = false; prefs.hideOverlayOnHover = false
    prefs.overlaySecondaryMode = .translation
    let model = AppModel(repository: SizingRepository(), preferences: prefs)
    let track = Track(playerID: "test", playerName: "Test", title: "Window sizing fixture")
    model.session.accept(.init(track: track, position: 1, isPlaying: false), shouldSearch: false)
    let doc = LyricsDocument(lines: [
        .init(id: 0, time: 0, text: "A long line\nWith a second row", translation: "A translation"),
        .init(id: 1, time: 5, text: ""), .init(id: 2, time: 8, text: "Short lyric")])
    model.session.use(doc, persist: false)
    let overlay = OverlayController(model: model, frameAutosaveName: nil)
    defer { overlay.stop(); model.stop() }
    try await Task.sleep(for: .milliseconds(120))
    let height = overlay.panel.frame.height
    let top = overlay.panel.frame.maxY
    model.session.seek(to: 5)
    try await Task.sleep(for: .milliseconds(90))
    if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
        #expect(abs(overlay.panel.frame.height - height) < 1, "The old lyric is still fading out; a waiting-size window clips it")
    }
    try await Task.sleep(for: .milliseconds(700))
    // Parallel AppKit fixtures can quantize one display-pixel boundary in
    // opposite directions. Accept the same one-point tolerance used by the
    // interrupted-resize checks below; larger drift still fails.
    #expect(abs(overlay.panel.frame.height - OverlayPresentationMode.waitingHeight) <= 1)
    #expect(abs(overlay.panel.frame.maxY - top) < 1)
    model.session.seek(to: 8)
    try await Task.sleep(for: .milliseconds(500))
    let lyricHeight = OverlayTextMeasure.height(document: doc, index: 2, preferences: prefs, maximumWidth: 620)
    #expect(abs(overlay.panel.frame.height - lyricHeight) < 1)
    #expect(abs(overlay.panel.frame.maxY - top) < 1)
    // Retarget while both expansion and contraction are still in flight.
    // The pointer stays outside; recovery must not depend on a hover refresh.
    for position in [5.0, 8, 0, 5, 8] {
        model.session.seek(to: position)
        try await Task.sleep(for: .milliseconds(190))
    }
    try await Task.sleep(for: .milliseconds(600))
    #expect(abs(overlay.panel.frame.height - lyricHeight) < 1)
    let material = try #require(overlay.panel.contentView?.subviews.first as? OverlayGlassBackground)
    let glass = try #require(material.subviews.first as? NSGlassEffectView)
    #expect(glass.layer?.mask == nil)
}

@MainActor @Test func nativeHeightResizeKeepsWidthHostingBoundsAndTopEdge() async throws {
    _ = NSApplication.shared
    let suite = "LyricsXTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let prefs = Preferences(defaults: defaults)
    prefs.overlayWidth = 620; prefs.hideWhenPaused = false; prefs.overlaySecondaryMode = .both
    let model = AppModel(repository: SizingRepository(), preferences: prefs)
    model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Sizing fixture"), position: 0, isPlaying: false), shouldSearch: false)
    let doc = LyricsDocument(lines: [
        .init(id: 0, time: 0, text: "Corpora", translation: "公司"),
        .init(id: 1, time: 3, text: "A longer current sentence needs enough room to stay readable", translation: "较长的一句"),
        .init(id: 2, time: 6, text: "Light", translation: "光")])
    model.session.use(doc, persist: false)
    let overlay = OverlayController(model: model, frameAutosaveName: nil)
    defer { overlay.stop(); model.stop() }
    let screen = try #require(NSScreen.main)
    overlay.panel.setFrameOrigin(.init(x: screen.visibleFrame.midX - overlay.panel.frame.width / 2, y: screen.visibleFrame.midY))
    overlay.windowDidMove(.init(name: NSWindow.didMoveNotification, object: overlay.panel))
    // Let native window setup and concurrent offscreen render tests drain;
    // otherwise a blocked MainActor can consume the entire animation duration.
    for _ in 0..<5 { try await Task.sleep(for: .milliseconds(50)) }
    let top = overlay.panel.frame.maxY, center = overlay.panel.frame.midX
    let host = overlay.lyricHostingView, bounds = overlay.lyricHostingView.bounds
    let settledGeneration = overlay.resizeGeneration
    // Player time observations must not restart the same rounded native size.
    for position in [0.1, 0.2, 0.3] {
        model.session.seek(to: position)
        try await Task.sleep(for: .milliseconds(20))
    }
    #expect(overlay.resizeGeneration == settledGeneration)
    let originalWidth = overlay.panel.frame.width
    let originalHeight = overlay.panel.frame.height
    let targetHeight = OverlayTextMeasure.height(document: doc, index: 1, preferences: prefs, maximumWidth: prefs.overlayLayoutWidth)
    let maximum = prefs.overlayLayoutWidth
    model.session.seek(to: 3)
    var intermediate = false
    for _ in 0..<28 {
        try await Task.sleep(for: .milliseconds(20))
        let frame = overlay.panel.frame
        let root = try #require(overlay.panel.contentView)
        let material = try #require(root.subviews.first as? OverlayGlassBackground)
        let glass = try #require(material.subviews.first as? NSGlassEffectView)
        #expect(material.frame == root.bounds.insetBy(dx: 6, dy: 6))
        #expect(glass.frame == material.bounds)
        #expect(glass.layer?.mask == nil)
        let scrim = try #require(glass.contentView)
        #expect(scrim.layer?.mask == nil)
        #expect(abs(frame.maxY - top) <= 1 && abs(frame.midX - center) <= 1)
        #expect(overlay.lyricHostingView === host && host.bounds == bounds)
        #expect(abs(host.frame.maxY - (overlay.panel.contentView?.bounds.maxY ?? 0)) <= 1)
        #expect(abs(frame.width - originalWidth) <= 1)
        if frame.height > originalHeight && frame.height < targetHeight { intermediate = true }
    }
    #expect(abs(overlay.panel.frame.width - maximum) <= 1)
    if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { #expect(intermediate) }
    #expect(abs(overlay.panel.frame.height - targetHeight) <= 1)
    model.session.seek(to: 6)
    try await Task.sleep(for: .milliseconds(250))
    #expect(overlay.panel.frame.height < targetHeight - 1)
    // Shrink starts immediately; wait only for the native animation to finish.
    for _ in 0..<115 where overlay.panel.frame.height > originalHeight + 1 {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(overlay.panel.frame.height <= originalHeight + 1)
    #expect(abs(overlay.panel.frame.width - originalWidth) <= 1)
    #expect(abs(overlay.panel.frame.maxY - top) <= 1)
    #expect(host.bounds == bounds)
    // Drag during an expansion without suspending its size animation.
    model.session.seek(to: 3)
    try await Task.sleep(for: .milliseconds(50))
    overlay.panel.onDragActivity?(true)
    let movedTop = overlay.panel.frame.maxY + 10
    overlay.panel.onDragAnchor?(.init(x: overlay.panel.frame.midX + 10, y: movedTop))
    try await Task.sleep(for: .milliseconds(420))
    #expect(abs(overlay.panel.frame.height - targetHeight) <= 1)
    #expect(abs(overlay.panel.frame.maxY - movedTop) <= 1)
    overlay.panel.onDragActivity?(false)
    try await Task.sleep(for: .milliseconds(500))
    #expect(abs(overlay.panel.frame.maxY - movedTop) <= 1)
    #expect(abs(overlay.panel.frame.height - targetHeight) <= 1)
}

@MainActor @Test func replacingLyricsResizesBeforeTheNextCueEvenWithTheSameDocumentID() async throws {
    _ = NSApplication.shared
    let suite = "LyricsXTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let prefs = Preferences(defaults: defaults)
    prefs.overlayWidth = 620; prefs.overlayAdaptiveSize = true
    prefs.overlaySecondaryMode = .translation; prefs.reduceMotion = true
    prefs.hideWhenPaused = false; prefs.hideOverlayOnHover = false
    let model = AppModel(repository: SizingRepository(), preferences: prefs)
    model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Replacement fixture"), position: 1, isPlaying: false), shouldSearch: false)
    let original = LyricsDocument(lines: [.init(id: 0, time: 0, text: "Short"), .init(id: 1, time: 60, text: "Next")])
    model.session.use(original, persist: false)
    let overlay = OverlayController(model: model, frameAutosaveName: nil)
    defer { overlay.stop(); model.stop() }
    let top = overlay.panel.frame.maxY
    let host = overlay.lyricHostingView
    var replacement = original
    replacement.lines[0].text = "A longer lyric\nWith a second row"
    replacement.lines[0].translation = "第一行翻译\n第二行翻译"
    let expected = OverlayTextMeasure.height(document: replacement, index: 0, preferences: prefs, maximumWidth: 620)
    #expect(expected > overlay.panel.frame.height)
    model.session.use(replacement, persist: false)
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while abs(overlay.panel.frame.height - expected) > 1, ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(model.session.currentLineIndex == 0 && model.session.position == 1)
    #expect(abs(overlay.panel.frame.height - expected) <= 1)
    #expect(abs(overlay.panel.frame.maxY - top) <= 1)
    #expect(overlay.lyricHostingView === host)
}

private struct SizingStreamRepository: LyricsRepository {
    let stream: AsyncThrowingStream<LyricCandidate, Error>
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { stream }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

@MainActor @Test func automaticSearchReplacesWaitingHeightAndUpdatesIncrementalTailWhilePaused() async throws {
    _ = NSApplication.shared
    let suite = "LyricsXTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let prefs = Preferences(defaults: defaults)
    prefs.overlayWidth = 620; prefs.overlayAdaptiveSize = true
    prefs.overlaySecondaryMode = .translation; prefs.reduceMotion = false
    prefs.hideWhenPaused = false; prefs.hideOverlayOnHover = false
    let pair = AsyncThrowingStream<LyricCandidate, Error>.makeStream()
    let model = AppModel(repository: SizingStreamRepository(stream: pair.stream), preferences: prefs)
    model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Automatic replacement"), position: 1, isPlaying: false))
    let overlay = OverlayController(model: model, frameAutosaveName: nil)
    defer { pair.continuation.finish(); overlay.stop(); model.stop() }
    let top = overlay.panel.frame.maxY
    let host = overlay.lyricHostingView
    #expect(abs(overlay.panel.frame.height - OverlayPresentationMode.waitingHeight) <= 1)
    let short = LyricsDocument(lines: [.init(id: 0, time: 0, text: "Short"), .init(id: 1, time: 60, text: "Next")])
    pair.continuation.yield(.init(document: short, score: 80))
    let shortHeight = OverlayTextMeasure.height(document: short, index: 0, preferences: prefs, maximumWidth: 620)
    var deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while abs(overlay.panel.frame.height - shortHeight) > 1, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
    #expect(abs(overlay.panel.frame.height - shortHeight) <= 1)
    var upgraded = short
    upgraded.lines[1].time = 1.1
    upgraded.lines[1].text = "Short text with a long incremental continuation that needs a second row to stay readable"
    upgraded.lines[0].translation = "新增翻译\n第二行翻译"
    var uncached = upgraded; uncached.id = UUID()
    let tall = OverlayTextMeasure.height(document: uncached, index: 0, preferences: prefs, maximumWidth: 620)
    #expect(tall > shortHeight)
    pair.continuation.yield(.init(document: upgraded, score: 90))
    deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while abs(overlay.panel.frame.height - tall) > 1, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
    #expect(abs(overlay.panel.frame.height - tall) <= 1)
    #expect(model.session.currentLineIndex == 0 && model.session.position == 1)
    #expect(abs(overlay.panel.frame.maxY - top) <= 1)
    #expect(overlay.lyricHostingView === host)
    model.session.use(short, persist: false)
    deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while abs(overlay.panel.frame.height - shortHeight) > 1, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
    #expect(abs(overlay.panel.frame.height - shortHeight) <= 1)
}

@MainActor @Test func screenNotificationDuringTrackHandoverCannotStrandAnIntermediateWindowHeight() async throws {
    _ = NSApplication.shared
    let suite = "LyricsXTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let prefs = Preferences(defaults: defaults)
    prefs.overlayWidth = 620; prefs.hideWhenPaused = false; prefs.hideOverlayOnHover = false
    prefs.overlaySecondaryMode = .translation
    let model = AppModel(repository: SizingRepository(), preferences: prefs)
    let overlay = OverlayController(model: model, frameAutosaveName: nil,
                                    pointerLocation: { .init(x: -100_000, y: -100_000) })
    defer { overlay.stop(); model.stop() }
    func song(_ title: String) {
        model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: title),
                                   position: 0, isPlaying: false), shouldSearch: false)
    }
    song("Waiting")
    let waitingDocument = LyricsDocument(lines: [.init(id: 0, time: 0, text: ""),
                                                .init(id: 1, time: 5, text: "Next lyric")])
    model.session.use(waitingDocument, persist: false)
    try await Task.sleep(for: .milliseconds(700))
    let waiting = overlay.panel.frame.height
    song("New song")
    let long = LyricsDocument(lines: [.init(id: 0, time: 0,
        text: "Pain will wake up the despondent crowd in this dormant world somehow",
        translation: "伤痛会唤醒沉睡的世界中绝望的人们")])
    model.session.use(long, persist: false)
    try await Task.sleep(for: .milliseconds(90))
    NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
    try await Task.sleep(for: .milliseconds(800))
    let expected = ceil(OverlayTextMeasure.height(document: long, index: 0, preferences: prefs, maximumWidth: 620))
    #expect(expected > waiting)
    #expect(abs(overlay.panel.frame.height - expected) <= 1)
    model.session.use(waitingDocument, persist: false)
    try await Task.sleep(for: .milliseconds(260))
    NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
    try await Task.sleep(for: .milliseconds(800))
    #expect(abs(overlay.panel.frame.height - OverlayPresentationMode.waitingHeight) <= 1)
}

@MainActor @Test func draggingAndLiveResizingKeepThePointerAnchorWithoutRestartingMotion() async throws {
    _ = NSApplication.shared
    let suite = "LyricsXTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let prefs = Preferences(defaults: defaults)
    prefs.hideWhenPaused = false; prefs.hideOverlayOnHover = false
    prefs.overlaySecondaryMode = .translation
    let model = AppModel(repository: SizingRepository(), preferences: prefs)
    model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Dragging"), position: 0, isPlaying: false), shouldSearch: false)
    let short = LyricsDocument(lines: [.init(id: 0, time: 0, text: "Short")])
    let long = LyricsDocument(lines: [.init(id: 0, time: 0,
        text: "A long replacement lyric keeps resizing smoothly while the user moves the window",
        translation: "第一行翻译\n第二行翻译")])
    model.session.use(short, persist: false)
    let overlay = OverlayController(model: model, frameAutosaveName: nil, pointerLocation: { .init(x: -10000, y: -10000) })
    defer { overlay.stop(); model.stop() }
    try await Task.sleep(for: .milliseconds(100))
    model.session.use(long, persist: false)
    try await Task.sleep(for: .milliseconds(60))
    overlay.panel.onDragActivity?(true)
    let start = NSPoint(x: overlay.panel.frame.midX, y: overlay.panel.frame.maxY)
    var anchor = start
    for step in 1...16 {
        anchor = NSPoint(x: start.x + Double(step) * 2, y: start.y - Double(step))
        overlay.panel.onDragAnchor?(anchor)
        if step == 8 { NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil) }
        try await Task.sleep(for: .milliseconds(25))
        #expect(abs(overlay.panel.frame.midX - anchor.x) < 1)
        #expect(abs(overlay.panel.frame.maxY - anchor.y) < 1)
    }
    let tall = ceil(OverlayTextMeasure.height(document: long, index: 0, preferences: prefs, maximumWidth: prefs.overlayLayoutWidth))
    #expect(abs(overlay.panel.frame.height - tall) < 1) // Expansion completes while the pointer is still down.
    model.session.use(short, persist: false)
    try await Task.sleep(for: .milliseconds(650))
    let expected = ceil(OverlayTextMeasure.height(document: short, index: 0, preferences: prefs, maximumWidth: prefs.overlayLayoutWidth))
    #expect(abs(overlay.panel.frame.height - expected) < 1) // Shrink also runs during dragging.
    #expect(abs(overlay.panel.frame.midX - anchor.x) < 1)
    #expect(abs(overlay.panel.frame.maxY - anchor.y) < 1)
    let generation = overlay.resizeGeneration
    overlay.panel.onDragActivity?(false)
    try await Task.sleep(for: .milliseconds(100))
    #expect(overlay.resizeGeneration == generation)
    #expect(abs(overlay.panel.frame.height - expected) < 1)
    #expect(abs(overlay.panel.frame.midX - anchor.x) < 1)
    #expect(abs(overlay.panel.frame.maxY - anchor.y) < 1)
}

@MainActor @Test func smallResizesSkipDuplicateNativeRedrawsWithoutMovingTheAnchor() {
    final class CountingPanel: NSPanel {
        var writes = 0
        override func setFrame(_ frameRect: NSRect, display flag: Bool) {
            writes += 1
            super.setFrame(frameRect, display: flag)
        }
    }
    let window = CountingPanel(contentRect: .init(x: 100, y: 300, width: 620, height: 100),
        styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    defer { window.close() }
    let motion = OverlayWindowMotion(window: window)
    let now = ProcessInfo.processInfo.systemUptime
    var completed = 0
    motion.start(to: .init(x: 100, y: 296, width: 620, height: 104), duration: 1, frameRateLimit: 0) { completed += 1 }
    window.writes = 0
    for step in 1...120 {
        motion.advance(at: now + Double(step) / 120)
        #expect(window.frame.maxY == 400 && window.frame.midX == 410)
    }
    motion.finish()
    #expect(window.writes <= 5 && window.writes >= 4)
    #expect(window.frame.height == 104 && completed == 1)
}

@MainActor @Test func cancelledWindowMotionCannotMoveTheWindowOrInvokeOldCompletion() {
    let window = NSPanel(contentRect: .init(x: 100, y: 100, width: 620, height: 100), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let motion = OverlayWindowMotion(window: window)
    var completed = false
    let now = ProcessInfo.processInfo.systemUptime
    motion.start(to: .init(x: 100, y: 0, width: 620, height: 200), duration: 0.4, frameRateLimit: 60) { completed = true }
    motion.advance(at: now + 0.15)
    motion.cancel()
    window.setFrameOrigin(.init(x: 240, y: 300))
    let dragged = window.frame
    motion.advance(at: now + 10); motion.finish()
    #expect(window.frame == dragged && !completed)
    window.close()
}

@MainActor @Test func movingAnchorDoesNotRestartResizeOrChangeItsPointerOffset() {
    let window = NSPanel(contentRect: .init(x: 100, y: 300, width: 620, height: 100), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    defer { window.close() }
    let motion = OverlayWindowMotion(window: window)
    var completions = 0
    let now = ProcessInfo.processInfo.systemUptime
    motion.start(to: .init(x: 100, y: 100, width: 620, height: 300), duration: 0.4, frameRateLimit: 60) { completions += 1 }
    var previousHeight = window.frame.height
    var changedHeights = 0
    for step in 1...60 {
        let point = NSPoint(x: 450 + Double(step), y: 450 - Double(step) * 0.5)
        motion.moveTopCenter(to: point)
        motion.advance(at: now + Double(step) / 120)
        #expect(abs(window.frame.midX - point.x) <= 1)
        #expect(abs(window.frame.maxY - point.y) <= 1)
        #expect(window.frame.height >= previousHeight)
        if window.frame.height > previousHeight { changedHeights += 1 }
        previousHeight = window.frame.height
    }
    #expect(changedHeights > 8)
    #expect(window.frame.height == 300 && completions == 1)
}

@MainActor @Test func overlayDragUsesDeliveredEventCoordinatesRatherThanTheGlobalPointer() throws {
    let panel = DraggableOverlayPanel(contentRect: .init(x: 100, y: 300, width: 620, height: 100),
                                     styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.isReleasedWhenClosed = false
    defer { panel.close() }
    var activity: [Bool] = []
    var anchors: [NSPoint] = []
    panel.onDragActivity = { activity.append($0) }
    panel.onDragAnchor = { anchors.append($0) }
    func send(_ type: NSEvent.EventType, _ point: NSPoint) throws {
        let event = try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        panel.sendEvent(event)
    }
    let original = panel.frame
    try send(.leftMouseDown, .init(x: 100, y: 50))
    try send(.leftMouseDragged, .init(x: 120, y: 60))
    try send(.leftMouseUp, .init(x: 120, y: 60))
    #expect(activity == [true, false])
    #expect(anchors.count == 2)
    #expect(anchors.allSatisfy { $0 == NSPoint(x: original.midX + 20, y: original.maxY + 10) })
}
