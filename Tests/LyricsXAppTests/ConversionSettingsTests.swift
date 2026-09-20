import AppKit
import Testing
import LyricsXCore
@testable import LyricsXApp

@Suite @MainActor struct ConversionSettingsTests {
    private func fixture(_ body: (Preferences, UserDefaults) throws -> Void) throws {
        let suite = "LyricsXConversionTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(Preferences(defaults: defaults), defaults)
    }
    @Test func scriptConversionsRetainCueTimesAcrossGraphemesSpacesAndRepeatedWords() throws {
        try fixture { p, _ in
            for (source, mode) in [("让爱随风，爱 👩🏽‍🚀 e\u{301} Music", "繁體"), ("讓愛隨風，愛 👩🏽‍🚀 e\u{301} Music", "简体")] {
                let words = source.enumerated().filter { !$0.element.isWhitespace }.map {
                    WordCue(text: String($0.element), start: Double($0.offset), end: Double($0.offset) + 1.8)
                }
                let line = LyricLine(id: 0, time: 0, text: source, words: words)
                p.conversion = mode
                let text = p.text(source)
                #expect(text != source)
                let fragments = TimedLyricFragment.make(line: line, text: text)
                #expect(fragments.map(\.text).joined() == text)
                let cues = fragments.compactMap(\.cue)
                #expect(cues.map(\.start) == words.map(\.start))
                #expect(cues.map(\.end) == words.map(\.end))
                #expect(cues.first?.text == (mode == "繁體" ? "讓" : "让"))
                #expect(LyricEmphasisFrame(cue: cues[0], time: 0.8, options: .init()).glow > 0)
                #expect(line.words == words && line.text == source)
                // Cached conversion and switching back must not retain the wrong script.
                #expect(p.text(source) == text)
                p.conversion = "原文"
                #expect(p.text(source) == source)
            }
        }
    }
    @Test func changedWordingNeverInheritsUnrelatedTimings() {
        let line = LyricLine(id: 0, time: 0, text: "让爱随风", words: [.init(text: "让爱随风", start: 0, end: 4)])
        #expect(TimedLyricFragment.make(line: line, text: "另一歌词").allSatisfy { $0.cue == nil })
        #expect(TimedLyricFragment.make(line: line, text: "让爱随风更长").allSatisfy { $0.cue == nil })
    }
    @Test func invalidPersistedSizesAndUnknownModesCannotBreakLayout() throws {
        try fixture { _, defaults in
            for key in ["overlayWidth", "fontSize", "translationFontSize", "nextLineFontSize", "mainLyricFontSize", "mainTranslationFontSize", "lyricHDRBrightness"] {
                defaults.set(-1000.0, forKey: key)
            }
            defaults.set("missing", forKey: "conversion")
            let p = Preferences(defaults: defaults)
            #expect(p.overlayWidth == 320 && p.fontSize == 18)
            #expect(p.translationFontSize == 10 && p.nextLineFontSize == 10)
            #expect(p.mainLyricFontSize == 20 && p.mainTranslationFontSize == 11)
            #expect(p.lyricHDRBrightness == 1 && p.conversion == "原文")
        }
    }
    @Test func secondaryControlAvailabilityMatchesEveryMode() {
        for mode in OverlaySecondaryMode.allCases {
            let content = mode.content(translation: "译文", next: "Next")
            #expect(mode.supportsTranslation == (content.translation != nil))
            #expect(mode.supportsNext == (mode.content(translation: nil, next: "Next").next != nil))
        }
    }
    @Test func everyBooleanSettingPersistsBothTrueAndFalse() throws {
        try fixture { p, defaults in
            let fields: [ReferenceWritableKeyPath<Preferences, Bool>] = [
                \.overlayVisible,
                \.overlayLocked,
                \.overlayClickThrough,
                \.hideOverlayOnHover,
                \.overlayAdaptiveSize,
                \.followArtworkColors,
                \.separateWordColors,
                \.showTranslation,
                \.showMenubarLyrics,
                \.showMenuBarIcon,
                \.showDockIcon,
                \.combinedMenubarLyrics,
                \.hideWhenPaused,
                \.reduceMotion,
                \.lyricWordLift,
                \.lyricGlow,
                \.lyricHDR,
                \.preferBilingual,
                \.preferWordTiming,
                \.strictLyricsMatching
            ]
            for value in [true, false] {
                for field in fields { p[keyPath: field] = value }
                let restored = Preferences(defaults: defaults)
                for field in fields { #expect(restored[keyPath: field] == value) }
            }
        }
    }

}
