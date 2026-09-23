import AppKit
import SwiftUI
import Testing
import LyricsXCore
@testable import LyricsXApp

private struct PendingOverlayRepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { _ in } }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

private func whiteInkBounds(_ bitmap: NSBitmapImageRep, columns: Range<Int>? = nil) throws -> CGRect {
    let image = try #require(bitmap.cgImage)
    let context = try #require(CGContext(data: nil, width: bitmap.pixelsWide, height: bitmap.pixelsHigh,
        bitsPerComponent: 8, bytesPerRow: bitmap.pixelsWide * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(image, in: .init(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh))
    let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
    var left = bitmap.pixelsWide, right = 0, top = bitmap.pixelsHigh, bottom = 0
    for y in 0..<bitmap.pixelsHigh {
        for x in columns ?? 0..<bitmap.pixelsWide {
            // Convert extended-range output once, not one NSColor per pixel.
            if bytes[y * context.bytesPerRow + x * 4 + 1] > 127 {
                left = min(left, x); right = max(right, x); top = min(top, y); bottom = max(bottom, y)
            }
        }
    }
    return .init(x: left, y: top, width: max(0, right - left), height: max(0, bottom - top))
}

@Suite @MainActor struct OverlayPresentationTests {
    private func fixture(_ run: (AppModel) throws -> Void) throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(repository: PendingOverlayRepository(), preferences: Preferences(defaults: defaults))
        defer { model.stop() }
        model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "First"), position: 2, isPlaying: false), shouldSearch: false)
        model.session.use(.init(lines: [.init(id: 0, time: 0, text: "First lyric")]), persist: false)
        try run(model)
    }

    @Test func stoppedOverlayCannotBeReopenedByDelayedVisibilityUpdates() throws {
        try fixture { model in
            let controller = OverlayController(model: model, frameAutosaveName: nil)
            controller.stop()
            controller.setUserVisible(true)
            #expect(!controller.panel.isVisible && !controller.controlPanel.isVisible)
        }
    }

    @Test func cachedSongHandoverKeepsOneCoherentFrameAndSkipsLoadingCard() throws {
        try fixture { model in
            let presentation = OverlayPresentation(); defer { presentation.stop() }
            presentation.update(model: model, at: 10)
            model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Second"), position: 0, isPlaying: true))
            presentation.update(model: model, at: 10.01)
            let held = try #require(presentation.held)
            #expect(held.track?.title == "First" && held.document?.lines.first?.text == "First lyric")
            #expect(!held.compact && !held.playing && held.position == 2)
            let newDocument = LyricsDocument(lines: [.init(id: 0, time: 0, text: "Second lyric")])
            model.session.use(newDocument, persist: false)
            presentation.update(model: model, at: 10.06)
            #expect(presentation.held == nil && presentation.preparingSince == nil)
            #expect(model.session.document?.id == newDocument.id && model.session.track?.title == "Second")
            presentation.finishIfDue(model: model, at: 20)
            #expect(presentation.held == nil && model.session.document?.id == newDocument.id)
        }
    }

    @Test func rapidSkipsKeepTheOriginalShortDeadlineAndSlowSearchReleasesIt() throws {
        try fixture { model in
            let presentation = OverlayPresentation(); defer { presentation.stop() }
            presentation.update(model: model, at: 10)
            for index in 0..<3 {
                model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Skip \(index)"), position: 0, isPlaying: true))
                presentation.update(model: model, at: 10.01 + Double(index) * 0.05)
                #expect(presentation.preparingSince == 10.01)
            }
            presentation.finishIfDue(model: model, at: 10.16)
            #expect(presentation.held != nil)
            presentation.finishIfDue(model: model, at: 10.18)
            #expect(presentation.held == nil && model.session.track?.title == "Skip 2")
            presentation.update(model: model, at: 10.19)
            #expect(presentation.held == nil) // No repeated old-frame hold during a slow search.
        }
    }

    @Test func introEmptyLinesAndDotPlaceholdersUseWaitingDots() throws {
        try fixture { model in
            let document = LyricsDocument(lines: [.init(id: 0, time: 5, text: "A real lyric"),
                .init(id: 1, time: 10, text: ""), .init(id: 2, time: 15, text: " ••• "),
                .init(id: 3, time: 20, text: "… …"), .init(id: 4, time: 25, text: "Wait...")])
            model.session.use(document, persist: false)
            for time in [0.0, 10, 15, 20] {
                model.session.seek(to: time)
                #expect(model.overlayPresentationMode == .waiting)
            }
            for time in [5.0, 25] {
                model.session.seek(to: time)
                #expect(model.overlayPresentationMode == .lyrics)
            }
        }
    }

    @Test func waitingKeepsItsHeaderAndRendersDotsWithoutTheArtworkCard() throws {
        try fixture { model in
            model.preferences.reduceMotion = true
            model.session.use(.init(lines: [.init(id: 0, time: 20, text: "Later lyric")]), persist: false)
            model.artwork = NSImage(size: .init(width: 64, height: 64), flipped: false) { rect in
                NSColor.white.setFill(); rect.fill(); return true
            }
            for width in [320.0, 620, 1000] {
                model.preferences.overlayWidth = width
                let height = OverlayPresentationMode.waitingHeight
                let renderer = ImageRenderer(content: OverlayView(model: model, viewport: .init(width: width))
                    .frame(width: width, height: height).background(.black).environment(\.colorScheme, .dark))
                renderer.scale = 1
                let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
                let ink = try whiteInkBounds(bitmap, columns: (Int(width / 2) - 20)..<(Int(width / 2) + 20))
                #expect(ink.width > 20 && ink.width < 35 && ink.height <= 6)
                #expect(abs(ink.midX - width / 2) <= 2)
                let allInk = try whiteInkBounds(bitmap)
                #expect(allInk.minX >= 24 && allInk.minX < 60 && allInk.width > width / 3)
            }
            model.session.use(.init(plainText: "Instrumental"), persist: false)
            #expect(model.overlayPresentationMode == .song)
        }
    }

    @Test func waitingLoadingAndFinishedSearchResizeAtTheSameTopWithoutReplacingTheHost() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.reduceMotion = true; prefs.hideWhenPaused = false
        let model = AppModel(repository: PendingOverlayRepository(), preferences: prefs)
        defer { model.stop() }
        model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Waiting"), position: 0, isPlaying: false))
        #expect(model.overlayPresentationMode == .waiting && model.session.isSearching)
        let overlay = OverlayController(model: model, frameAutosaveName: nil)
        defer { overlay.stop() }
        let top = overlay.panel.frame.maxY, width = overlay.panel.frame.width
        let host = overlay.lyricHostingView
        #expect(abs(overlay.panel.frame.height - OverlayPresentationMode.waitingHeight) < 0.5)
        model.session.use(.init(lines: [.init(id: 0, time: 0, text: "Visible lyric"),
                                       .init(id: 1, time: 5, text: ""), .init(id: 2, time: 8, text: "Next lyric")]), persist: false)
        try await Task.sleep(for: .milliseconds(30))
        #expect(model.overlayPresentationMode == .lyrics && overlay.panel.frame.height > OverlayPresentationMode.waitingHeight)
        model.session.seek(to: 5)
        try await Task.sleep(for: .milliseconds(30))
        #expect(model.overlayPresentationMode == .waiting && abs(overlay.panel.frame.height - OverlayPresentationMode.waitingHeight) < 0.5)
        model.session.suppressLyrics()
        try await Task.sleep(for: .milliseconds(30))
        #expect(model.overlayPresentationMode == .song)
        #expect(abs(overlay.panel.frame.height - OverlaySongCardLayout(width: width).height) < 0.5)
        #expect(abs(overlay.panel.frame.maxY - top) < 0.5 && abs(overlay.panel.frame.width - width) < 0.5 && overlay.lyricHostingView === host)
    }

    @Test func hiddenMainSelectionFreezesWhilePlaybackAndOverlayContinue() throws {
        try fixture { model in
            model.session.use(.init(lines: (0..<10).map { .init(id: $0, time: Double($0), text: "Line \($0)") }), persist: false)
            model.mainWindowVisible = true
            model.session.seek(to: 0); model.updateMainLyricSelection()
            #expect(model.mainLyricIndex == 0)
            model.mainWindowVisible = false
            for index in 1...8 {
                model.session.seek(to: Double(index)); model.updateMainLyricSelection()
                #expect(model.mainLyricIndex == 0 && model.session.currentLineIndex == index)
                #expect(model.playbackControlPosition == 0)
                #expect(!model.overlayUsesCompactPresentation)
            }
            model.mainWindowVisible = true
            #expect(model.mainLyricIndex == 8 && model.playbackControlPosition == 8)
        }
    }

    @Test func compactArtworkAndTitleGroupAreCenteredInBothDirections() throws {
        try fixture { model in
            model.preferences.reduceMotion = true
            model.session.use(.init(plainText: "Instrumental"), persist: false)
            model.artwork = NSImage(size: .init(width: 64, height: 64), flipped: false) { rect in
                NSColor.white.setFill(); rect.fill(); return true
            }
            for width in [320.0, 400.0, 620.0, 1000.0] {
                model.preferences.overlayWidth = width
                let cardWidth = width, height = OverlaySongCardLayout(width: width).height
                let view = OverlayView(model: model, viewport: .init(width: cardWidth))
                    .frame(width: cardWidth, height: height).background(.black).environment(\.colorScheme, .dark)
                let renderer = ImageRenderer(content: view); renderer.scale = 1
                let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
                let ink = try whiteInkBounds(bitmap)
                #expect(abs(ink.midX - cardWidth / 2) <= 2)
                #expect(abs(ink.midY - height / 2) <= 2)
            }
        }
    }

    @Test func longSongTitlesFitTheFullWidthInformationCard() throws {
        try fixture { model in
            model.preferences.reduceMotion = true
            model.session.accept(.init(track: .init(playerID: "test", playerName: "Test",
                title: "A Long Song Title With A Second Line And Featured Musicians", artist: "Several Artists & Orchestra"),
                position: 0, isPlaying: false), shouldSearch: false)
            model.session.use(.init(plainText: "Instrumental"), persist: false)
            for width in [320.0, 620, 1000] {
                model.preferences.overlayWidth = width
                let card = OverlaySongCardLayout(width: width)
                let renderer = ImageRenderer(content: OverlayView(model: model, viewport: .init(width: width))
                    .frame(width: width, height: card.height).background(.black).environment(\.colorScheme, .dark))
                renderer.scale = 1
                let ink = try whiteInkBounds(NSBitmapImageRep(cgImage: try #require(renderer.cgImage)))
                #expect(ink.minX >= 24 && ink.maxX <= width - 24)
                #expect(ink.minY >= 16 && ink.maxY <= card.height - 16)
            }
        }
    }
}

@Test func windowRenderingStopsBeforeMinimizingAndRestartsWhenShown() {
    var main = WindowRenderActivity(), overlay = WindowRenderActivity()
    #expect(main.update(event: nil, visible: true, miniaturized: false, exposed: true) == true)
    #expect(main.update(event: NSWindow.willMiniaturizeNotification, visible: true, miniaturized: false, exposed: true) == false)
    #expect(main.update(event: NSWindow.didChangeOcclusionStateNotification, visible: true, miniaturized: false, exposed: true) == false)
    #expect(overlay.update(event: nil, visible: true, miniaturized: false, exposed: true) == true)
    #expect(main.update(event: NSWindow.didMiniaturizeNotification, visible: true, miniaturized: true, exposed: false) == false)
    #expect(main.update(event: NSWindow.didDeminiaturizeNotification, visible: true, miniaturized: false, exposed: true) == true)
    #expect(main.update(event: NSWindow.willCloseNotification, visible: true, miniaturized: false, exposed: true) == false)
    #expect(main.update(event: nil, visible: false, miniaturized: false, exposed: false) == false)
    #expect(main.update(event: NSWindow.didBecomeKeyNotification, visible: true, miniaturized: false, exposed: true) == true)
}

@MainActor @Test func disappearingLyricsLeaveForTheCardOnAShortDeadlineWithoutReplayingTheHeader() throws {
    let suite = "LyricsXTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(repository: PendingOverlayRepository(), preferences: Preferences(defaults: defaults))
    defer { model.stop() }
    model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Gap"), position: 1, isPlaying: false), shouldSearch: false)
    model.session.use(.init(lines: [.init(id: 0, time: 0, text: "Before"), .init(id: 1, time: 2, text: ""), .init(id: 2, time: 5, text: "After")]), persist: false)
    let presentation = OverlayPresentation(); defer { presentation.stop() }
    presentation.update(model: model, at: 10)
    model.session.seek(to: 2)
    presentation.update(model: model, at: 11)
    #expect(presentation.held?.index == 0 && presentation.preparingSince == 11)
    presentation.finishIfDue(model: model, at: 11.161)
    #expect(presentation.held == nil && model.overlayUsesCompactPresentation)
    presentation.update(model: model, at: 11.2)
    #expect(presentation.held == nil)
}
