import SwiftUI
import Testing
@testable import LyricsXApp

@Suite @MainActor struct GlassColorOptimizationTests {
    private func preferences() throws -> (Preferences, UserDefaults, String) {
        let suite = "LyricsXGlassColorTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (Preferences(defaults: defaults), defaults, suite)
    }

    @Test func missingKeyDefaultsToEnabledAndExplicitValuesSurviveReload() throws {
        let (prefs, defaults, suite) = try preferences()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(defaults.object(forKey: "glassColorOptimization") == nil)
        #expect(prefs.glassColorOptimization)
        prefs.glassColorOptimization = false
        #expect(defaults.object(forKey: "glassColorOptimization") as? Bool == false)
        #expect(!Preferences(defaults: defaults).glassColorOptimization)
        prefs.glassColorOptimization = true
        #expect(Preferences(defaults: defaults).glassColorOptimization)
    }

    @Test func eachManualColorTurnsOffGlassOptimizationAndKeepsSavedPalette() throws {
        let (prefs, defaults, suite) = try preferences()
        defer { defaults.removePersistentDomain(forName: suite) }
        prefs.overlayAppearance = .glass
        prefs.separateWordColors = true
        let changes: [(Preferences.ManualLyricColor, String)] = [
            (.primary, "123456"), (.secondary, "A1B2C3"),
            (.sung, "EF1020"), (.unsung, "345678")
        ]
        for (role, color) in changes {
            prefs.glassColorOptimization = true
            let unchanged: String
            switch role {
            case .primary: unchanged = prefs.lyricPrimaryColor
            case .secondary: unchanged = prefs.lyricSecondaryColor
            case .sung: unchanged = prefs.sungWordColor
            case .unsung: unchanged = prefs.unsungWordColor
            }
            prefs.setManualLyricColor(unchanged, for: role)
            #expect(prefs.glassColorOptimization)
            prefs.setManualLyricColor(color, for: role)
            #expect(!prefs.glassColorOptimization)
            #expect(prefs.overlayTypography(colorScheme: .dark) == prefs.typography)
        }
        #expect(prefs.lyricPrimaryColor == "123456")
        #expect(prefs.lyricSecondaryColor == "A1B2C3")
        #expect(prefs.sungWordColor == "EF1020")
        #expect(prefs.unsungWordColor == "345678")

        let saved = prefs.typography
        prefs.glassColorOptimization = true
        #expect(prefs.typography == saved)
        #expect(prefs.mainTypography(colorScheme: .dark) == saved)
        #expect(prefs.overlayTypography(colorScheme: .dark) != saved)
        let restored = Preferences(defaults: defaults)
        #expect(restored.glassColorOptimization)
        #expect(restored.lyricPrimaryColor == "123456")
        #expect(restored.lyricSecondaryColor == "A1B2C3")
        #expect(restored.sungWordColor == "EF1020")
        #expect(restored.unsungWordColor == "345678")
    }

    @Test func frostedManualEditsDoNotChangeGlassSwitchOrMainColors() throws {
        let (prefs, defaults, suite) = try preferences()
        defer { defaults.removePersistentDomain(forName: suite) }
        prefs.overlayAppearance = .frosted
        prefs.setManualLyricColor("192A3B", for: .primary)
        #expect(prefs.glassColorOptimization)
        let main = prefs.mainTypography(colorScheme: .dark)
        let frosted = prefs.overlayTypography(colorScheme: .dark)
        prefs.glassColorOptimization = false
        #expect(prefs.mainTypography(colorScheme: .dark) == main)
        #expect(prefs.overlayTypography(colorScheme: .dark) == frosted)
        #expect(frosted.primaryHex == "192A3B")
    }

    @Test func artworkPaletteStillWinsWhenGlassOptimizationIsOff() throws {
        let (prefs, defaults, suite) = try preferences()
        defer { defaults.removePersistentDomain(forName: suite) }
        prefs.overlayAppearance = .glass
        prefs.setManualLyricColor("123456", for: .primary)
        prefs.followArtworkColors = true
        prefs.artworkTheme = .init(accent: "DDAA00", sung: "FFEEDD", unsung: "776655", secondary: "CCBBAA")
        #expect(!prefs.glassColorOptimization)
        #expect(prefs.overlayTypography(colorScheme: .dark) == prefs.typography)
        #expect(prefs.overlayTypography(colorScheme: .dark).primaryHex == "FFEEDD")
        #expect(prefs.mainTypography(colorScheme: .dark).primaryHex == "FFEEDD")
        prefs.glassColorOptimization = true
        #expect(prefs.overlayTypography(colorScheme: .dark) != prefs.typography)
        #expect(prefs.mainTypography(colorScheme: .dark).primaryHex == "FFEEDD")
        #expect(prefs.lyricPrimaryColor == "123456")
    }
}
