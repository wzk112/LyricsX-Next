import AppKit
import SwiftUI
import Foundation
import Testing
import LyricsXCore
@testable import LyricsXApp

private struct CustomizationRepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

@Suite @MainActor struct CustomizationTests {
    @Test func glassInkKeepsCueStatesDistinctForBlackWhiteAndArtworkColors() throws {
        for seed in ["000000", "FFFFFF", "777777", "FFE000", "1020C0", "F03868", "009933"] {
            let source = LyricTypography(primaryHex: seed, secondaryHex: seed,
                wordColors: .init(sung: LyricTypography.color(seed), unsung: LyricTypography.color(seed), plain: .white))
            for dark in [false, true] {
                let adapted = source.adaptedForGlass(dark: dark)
                let words = try #require(adapted.wordColors)
                let sung = LyricTypography.luminance(LyricTypography.hex(words.sung))
                let unsung = LyricTypography.luminance(LyricTypography.hex(words.unsung))
                let background = dark ? 0.03 : 0.85
                func contrast(_ a: Double, _ b: Double) -> Double { (max(a, b) + 0.05) / (min(a, b) + 0.05) }
                #expect(contrast(sung, unsung) > 2.2, "Indistinct cue states: \(seed), dark=\(dark)")
                #expect(contrast(sung, background) > 7)
                #expect(contrast(unsung, background) > 2.9)
                if !dark {
                    #expect(contrast(unsung, background) >= 4.4)
                    let secondary = LyricTypography.luminance(adapted.secondaryHex)
                    #expect(contrast(secondary, 0.3) >= 4.5, "Translation should also survive middle-gray glass")
                    #expect(contrast(sung, 0.3) >= 4.5)
                }
                #expect(dark ? sung > unsung : sung < unsung)
                #expect((words.glow != nil) == !dark)
                #expect(source.primaryHex == seed)
            }
        }
    }

    @Test func cachedLineMetricsPreserveNativeFontSizesAndMeasurements() {
        for name in ["", "Georgia", "Menlo-Regular", "PingFangSC-Regular"] {
            let type = LyricTypography(fontName: name)
            for size in [13.0, 26.0, 40.0] {
                let font = type.nativeFont(size: size, weight: .semibold)
                let expected = ceil(max(size * 1.4, NSLayoutManager().defaultLineHeight(for: font)))
                for _ in 0..<3 {
                    #expect(type.lineHeight(size: size) == expected)
                    #expect(abs(Double(type.nativeFont(size: size, weight: .semibold).pointSize) - size) < 0.001)
                }
            }
        }
    }

    @Test func customFontsKeepTranslationCenteredAndSeparated() throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlaySecondaryMode = .translation; prefs.reduceMotion = true
        prefs.lyricPrimaryColor = "FF0000"; prefs.lyricSecondaryColor = "0000FF"
        let document = LyricsDocument(lines: [.init(id: 0, time: 0, text: "Mixed 中文 Lyrics", translation: "翻译 Translation")])
        for name in ["Georgia", "Menlo-Regular", "HelveticaNeue", "PingFangSC-Regular", "PingFangSC-Semibold"] {
            prefs.lyricFontName = name
            let view = OverlayLyricsContent(preferences: prefs, document: document, index: 0,
                lyricTime: { 2 }, adaptiveCanvasWidth: 400).frame(width: 400).padding(16).background(.black)
                .environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: view)
            let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
            var main = CGRect.null, translation = CGRect.null
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                    let pixel = CGRect(x: x, y: y, width: 1, height: 1)
                    // Adaptive ink changes lightness; identify the requested hue
                    // instead of assuming saturated RGB survives adaptation.
                    if color.redComponent > color.blueComponent + 0.08 && color.redComponent > color.greenComponent + 0.08 { main = main.union(pixel) }
                    if color.blueComponent > color.redComponent + 0.08 && color.blueComponent > color.greenComponent + 0.08 { translation = translation.union(pixel) }
                }
            }
            #expect(!main.isNull && !translation.isNull)
            #expect(abs(main.midX - translation.midX) < 7, "Font: \(name)")
            #expect(translation.minY > main.maxY + 3, "Font: \(name), main=\(main), translation=\(translation)")
            #expect(translation.maxY < Double(bitmap.pixelsHigh) - 5)
        }
    }

    @Test func selectingAFontNeverSilentlyChangesTheRequestedPointSize() throws {
        for name in ["PingFangSC-Regular", "PingFangSC-Semibold", "Georgia", "Menlo-Regular"] {
            for size in [13.0, 26, 40] {
                let font = LyricTypography(fontName: name).nativeFont(size: size, weight: .semibold)
                #expect(abs(font.pointSize - size) < 0.01)
            }
        }
    }

    @Test func wordColorsPersistAndRemainOptIn() throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        #expect(prefs.typography.wordColors == nil)
        prefs.separateWordColors = true; prefs.sungWordColor = "FF0000"; prefs.unsungWordColor = "0000FF"
        let restored = Preferences(defaults: defaults)
        #expect(restored.separateWordColors && restored.sungWordColor == "FF0000" && restored.unsungWordColor == "0000FF")
        restored.separateWordColors = false
        #expect(restored.typography.wordColors == nil && restored.unsungWordColor == "0000FF")
    }

    @Test func actualRendererSeparatesSungAndUnsungInk() throws {
        let line = LyricLine(id: 0, time: 0, text: "MMMMMMMM", words: [.init(text: "MMMMMMMM", start: 0, end: 4)])
        for (time, redExpected, blueExpected) in [(0.0, false, true), (2.0, true, true), (4.0, true, false)] {
            let view = WordHighlight(line: line, time: time, active: true, text: line.text,
                effects: .init(lift: false, glow: false, hdr: false))
                .environment(\.lyricWordColors, .init(sung: LyricTypography.color("FF0000"), unsung: LyricTypography.color("0000FF"), plain: .white))
                .foregroundStyle(.green).font(.system(size: 30)).padding(20).background(.black)
            let renderer = ImageRenderer(content: view)
            let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
            var red = 0, blue = 0
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    guard let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                    if c.redComponent > 0.5 && c.blueComponent < 0.2 { red += 1 }
                    if c.blueComponent > 0.5 && c.redComponent < 0.2 { blue += 1 }
                }
            }
            #expect((red > 30) == redExpected, "time=\(time), red=\(red), blue=\(blue)")
            #expect((blue > 30) == blueExpected)
        }
    }

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
