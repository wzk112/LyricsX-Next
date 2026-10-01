import AppKit
import SwiftUI
import Testing
import LyricsXCore
@testable import LyricsXApp

@MainActor struct OverlayTextSpacingTests {
    private func fixture() throws -> (String, UserDefaults, Preferences) {
        let suite = "LyricsXSpacing-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (suite, defaults, Preferences(defaults: defaults))
    }
    @Test func defaultSpacingPreservesExistingFontsAndCustomValuesPersist() throws {
        let (suite, defaults, preferences) = try fixture()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(preferences.overlayTextSpacing == .init())
        for font in [18.0, 26, 42] {
            preferences.fontSize = font
            #expect(preferences.overlayPrimarySpacing == max(10, font * 0.44))
            #expect(preferences.overlaySecondarySpacing == max(8, max(preferences.translationFontSize, preferences.nextLineFontSize) * 0.6))
        }
        preferences.overlayTextSpacing = .init(primaryLineSpacing: 10, translationLineSpacing: 6,
                                                automaticGaps: false, primaryGap: 25, secondaryGap: 14)
        let restored = Preferences(defaults: defaults)
        #expect(restored.overlayTextSpacing == preferences.overlayTextSpacing)
        #expect(restored.overlayPrimarySpacing == 25 && restored.overlaySecondarySpacing == 14)
        let position = restored.mainLyricPosition, font = restored.fontSize
        restored.overlayTextSpacing = .init()
        #expect(restored.mainLyricPosition == position && restored.fontSize == font)
        preferences.overlayTextSpacing = .init(primaryLineSpacing: .nan, translationLineSpacing: 999,
                                                automaticGaps: false, primaryGap: -10, secondaryGap: .infinity)
        #expect(preferences.overlayTextSpacing.primaryLineSpacing == 0)
        #expect(preferences.overlayTextSpacing.translationLineSpacing == 18)
        #expect(preferences.overlayPrimarySpacing == 0 && preferences.overlaySecondarySpacing == 8)
        #expect(OverlayTextSpacing.load(Data("broken".utf8)) == .init())
    }
    @Test func lineSpacingOnlyAddsSpaceBetweenRowsAndInvalidatesLayoutCache() {
        let original = OverlayTextMeasure.layout("First row\nSecond row", font: 26, canvasWidth: 500)
        let spaced = OverlayTextMeasure.layout("First row\nSecond row", font: 26, canvasWidth: 500, lineSpacing: 10)
        #expect(original.rows == 2 && spaced.rows == 2)
        #expect(spaced.height == original.height + 10 && spaced.fontSize == original.fontSize)
        #expect(OverlayTextMeasure.layout("First row\nSecond row", font: 26, canvasWidth: 500).height == original.height)
        let single = OverlayTextMeasure.layout("One row", font: 26, canvasWidth: 500)
        #expect(OverlayTextMeasure.layout("One row", font: 26, canvasWidth: 500, lineSpacing: 10).height == single.height)
        let translation = OverlayTextMeasure.translationHeight("翻译一\n翻译二", font: 13, canvasWidth: 500)
        #expect(OverlayTextMeasure.translationHeight("翻译一\n翻译二", font: 13, canvasWidth: 500, lineSpacing: 6) == translation + 6)
        #expect(OverlayTextMeasure.translationHeight(nil, font: 13, canvasWidth: 500, lineSpacing: 6) == 0)
    }
    @Test func everyAuxiliaryModeAndFixedHeightIncludeOnlyApplicableGaps() throws {
        let (suite, defaults, preferences) = try fixture()
        defer { defaults.removePersistentDomain(forName: suite) }
        preferences.showTranslation = true
        let doc = LyricsDocument(lines: [
            .init(id: 0, time: 0, text: "First\nSecond", translation: "译文一\n译文二"),
            .init(id: 1, time: 4, text: "Next\nPreview")])
        let initialPrimaryGap = preferences.overlayPrimarySpacing
        let initialSecondaryGap = preferences.overlaySecondarySpacing
        for mode in OverlaySecondaryMode.allCases {
            preferences.overlaySecondaryMode = mode
            preferences.overlayTextSpacing = .init()
            let original = OverlayTextMeasure.visibleHeight(document: doc, index: 0, preferences: preferences, maximumWidth: 620)
            preferences.overlayTextSpacing = .init(primaryLineSpacing: 10, translationLineSpacing: 6,
                                                    automaticGaps: false, primaryGap: 25, secondaryGap: 14)
            let updated = OverlayTextMeasure.visibleHeight(document: doc, index: 0, preferences: preferences, maximumWidth: 620)
            var extra = 10.0
            if mode != .none { extra += 25 - initialPrimaryGap }
            if mode == .translation || mode == .either || mode == .both { extra += 6 }
            if mode == .next || mode == .both { extra += 10 * preferences.nextLineFontSize / preferences.fontSize }
            if mode == .both { extra += 14 - initialSecondaryGap }
            #expect(abs(updated - original - extra) < 0.001)
        }
        preferences.overlaySecondaryMode = .both
        preferences.overlayTextSpacing = .init()
        let fixed = OverlayLayoutMetrics.height(preferences: preferences)
        preferences.overlayTextSpacing.primaryLineSpacing = 10
        preferences.overlayTextSpacing.translationLineSpacing = 6
        #expect(abs(OverlayLayoutMetrics.height(preferences: preferences) - fixed - 16 - 10 * preferences.nextLineFontSize / preferences.fontSize) < 0.001)
    }
    @Test func actualSwiftUITextAddsTheSameInterlineSpaceAsMeasurement() throws {
        _ = NSApplication.shared
        let line = LyricLine(id: 0, time: 0, text: "First row\nSecond row")
        func primaryHeight(spacing: Double) throws -> Int {
            let renderer = ImageRenderer(content: WordHighlight(line: line, time: 0, active: true,
                text: line.text, effects: .init(lift: false, glow: false, reduced: true))
                .font(.system(size: 26, weight: .semibold)).tracking(-0.4).lineSpacing(spacing)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true).frame(width: 500))
            renderer.scale = 1
            return try #require(renderer.cgImage).height
        }
        func translationHeight(spacing: Double) throws -> Int {
            let renderer = ImageRenderer(content: Text("译文一\n译文二")
                .font(.system(size: 13, weight: .medium)).lineSpacing(spacing)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true).frame(width: 500))
            renderer.scale = 1
            return try #require(renderer.cgImage).height
        }
        #expect(try primaryHeight(spacing: 10) - primaryHeight(spacing: 0) == 10)
        #expect(try translationHeight(spacing: 6) - translationHeight(spacing: 0) == 6)
    }
    @Test func spacingChangeRetargetsTheRealPanelWithoutChangingCue() async throws {
        _ = NSApplication.shared
        struct Repository: LyricsRepository {
            func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
            func save(_ document: LyricsDocument, for track: Track) async throws {}
        }
        let (suite, defaults, p) = try fixture()
        defer { defaults.removePersistentDomain(forName: suite) }
        p.overlayVisible = true; p.hideWhenPaused = false; p.reduceMotion = true
        p.overlaySecondaryMode = .both
        let model = AppModel(repository: Repository(), preferences: p)
        let doc = LyricsDocument(lines: [.init(id: 0, time: 0, text: "First\nSecond", translation: "译文一\n译文二"),
                                          .init(id: 1, time: 5, text: "Next\nPreview")])
        model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Spacing fixture"),
                                   position: 1, isPlaying: false), shouldSearch: false)
        model.session.use(doc, persist: false)
        let overlay = OverlayController(model: model, frameAutosaveName: nil)
        defer { overlay.stop(); model.stop() }
        func checkHeight() async throws {
            let target = ceil(OverlayLyricsWindowLayout.baseHeight(document: doc, index: 0, preferences: p, maximumWidth: p.overlayLayoutWidth))
            for _ in 0..<50 where abs(overlay.panel.frame.height - target) > 1 {
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(abs(overlay.panel.frame.height - target) <= 1)
            #expect(model.session.currentLineIndex == 0)
        }
        try await checkHeight()
        let original = overlay.panel.frame.height
        p.overlayTextSpacing = .init(primaryLineSpacing: 10, translationLineSpacing: 6,
                                     automaticGaps: false, primaryGap: 25, secondaryGap: 14)
        try await checkHeight()
        #expect(overlay.panel.frame.height > original + 20)
        p.overlayTextSpacing = .init()
        try await checkHeight()
        #expect(abs(overlay.panel.frame.height - original) <= 1)
    }
    @Test func zeroAndSmallGapsKeepSettledAuxiliaryTextVisibleAndFadeContinuously() {
        for gap in [0.0, 1, 5, 12] {
            #expect(OverlayMotionFrame().auxiliaryOpacity(top: 40 + gap, primaryHeight: 40, reduced: false) == 1)
            let near = OverlayMotionFrame(offset: 0.01).auxiliaryOpacity(top: 40 + gap, primaryHeight: 40, reduced: false)
            #expect(near > 0.999)
            let overlap = OverlayMotionFrame(offset: 20).auxiliaryOpacity(top: 40 + gap, primaryHeight: 40, reduced: false)
            #expect(overlap == 0)
        }
    }
}
