import SwiftUI
import Testing
@testable import LyricsXApp

@Suite @MainActor struct GlassColorOptimizationTests {
    private func fixture(_ body: (Preferences, UserDefaults) throws -> Void) throws {
        let suite = "LyricsXGlassColorTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(Preferences(defaults: defaults), defaults)
    }

    @Test func legacySwitchCannotOverrideTheActivePalette() throws {
        try fixture { _, defaults in
            for legacy in [false, true] {
                defaults.set(legacy, forKey: "glassColorOptimization")
                defaults.set("FFFFFF", forKey: "lyricPrimaryColor")
                let plain = Preferences(defaults: defaults)
                #expect(plain.glassColorOptimization)
                #expect(plain.overlayTypography(colorScheme: .dark).wordColors != nil)
                defaults.set("123456", forKey: "lyricPrimaryColor")
                let custom = Preferences(defaults: defaults)
                #expect(!custom.glassColorOptimization)
                #expect(custom.overlayTypography(colorScheme: .dark) == custom.typography)
            }
        }
    }

    @Test func customColorsAndResetImmediatelyChangeTheDerivedPolicy() throws {
        try fixture { prefs, defaults in
            for role in [\Preferences.lyricPrimaryColor, \Preferences.lyricSecondaryColor] {
                #expect(prefs.glassColorOptimization)
                prefs[keyPath: role] = "123456"
                #expect(!prefs.glassColorOptimization)
                for scheme in [ColorScheme.light, .dark] {
                    #expect(prefs.overlayTypography(colorScheme: scheme) == prefs.typography)
                }
                #expect(!Preferences(defaults: defaults).glassColorOptimization)
                prefs[keyPath: role] = "FFFFFF"
                #expect(prefs.glassColorOptimization)
            }
            prefs.sungWordColor = "EF1020"
            prefs.unsungWordColor = "345678"
            #expect(prefs.glassColorOptimization) // Inactive saved word colors do not select a palette.
            prefs.separateWordColors = true
            #expect(!prefs.glassColorOptimization)
            #expect(prefs.overlayTypography(colorScheme: .dark) == prefs.typography)
            prefs.separateWordColors = false
            #expect(prefs.glassColorOptimization)
            #expect(prefs.sungWordColor == "EF1020" && prefs.unsungWordColor == "345678")
        }
    }

    @Test func artworkModeAlwaysBypassesExtraGlassCorrection() throws {
        try fixture { prefs, defaults in
            prefs.followArtworkColors = true
            #expect(!prefs.glassColorOptimization)
            #expect(prefs.overlayTypography(colorScheme: .dark) == prefs.typography)
            prefs.artworkTheme = .init(accent: "DDAA00", sung: "FFEEDD", unsung: "776655", secondary: "CCBBAA")
            #expect(prefs.overlayTypography(colorScheme: .light).primaryHex == "FFEEDD")
            #expect(!Preferences(defaults: defaults).glassColorOptimization)
            prefs.followArtworkColors = false
            #expect(prefs.glassColorOptimization)
            prefs.lyricPrimaryColor = "123456"
            prefs.followArtworkColors = true
            prefs.followArtworkColors = false
            #expect(!prefs.glassColorOptimization)
            #expect(prefs.overlayTypography(colorScheme: .dark).primaryHex == "123456")
        }
    }

    @Test func switchingMaterialsUsesCurrentPaletteWithoutChangingMainTypography() throws {
        try fixture { prefs, _ in
            prefs.overlayAppearance = .frosted
            prefs.lyricPrimaryColor = "192A3B"
            let dark = prefs.mainTypography(colorScheme: .dark)
            let light = prefs.mainTypography(colorScheme: .light)
            let frostedLight = prefs.overlayTypography(colorScheme: .light)
            prefs.overlayAppearance = .glass
            #expect(!prefs.glassColorOptimization)
            #expect(prefs.overlayTypography(colorScheme: .light) == prefs.typography)
            #expect(prefs.mainTypography(colorScheme: .dark) == dark)
            #expect(prefs.mainTypography(colorScheme: .light) == light)
            prefs.overlayAppearance = .frosted
            #expect(prefs.overlayTypography(colorScheme: .light) == frostedLight)
        }
    }

    @Test func artworkSecondaryHueSurvivesAdaptationAndRefreshesCachedInk() throws {
        try fixture { prefs, _ in
            prefs.lyricPrimaryColor = "123456"
            prefs.lyricSecondaryColor = "654321"
            prefs.followArtworkColors = true
            prefs.overlayAppearance = .frosted
            prefs.artworkTheme = .init(accent: "E03030", sung: "FFCCCC", unsung: "665252",
                secondary: "CCD5FF", palette: ["E03030", "3040E0"])
            let light = prefs.mainTypography(colorScheme: .light)
            #expect(light.primaryHex != light.secondaryHex)
            #expect(LyricTypography.luminance(light.secondaryHex) <= 0.016)
            #expect(prefs.overlayTypography(colorScheme: .light).secondaryHex == light.secondaryHex)
            prefs.overlayAppearance = .glass
            #expect(prefs.overlayTypography(colorScheme: .dark).secondaryHex == "CCD5FF")

            // A new auxiliary color with the same dominant color must invalidate
            // the adaptation cache instead of retaining the previous song's hue.
            prefs.artworkTheme = .init(accent: "E03030", sung: "FFCCCC", unsung: "665252",
                secondary: "CCFFCC", palette: ["E03030", "30E040"])
            let updated = prefs.mainTypography(colorScheme: .light)
            #expect(updated.primaryHex == light.primaryHex)
            #expect(updated.secondaryHex != light.secondaryHex)
            #expect(prefs.overlayTypography(colorScheme: .dark).secondaryHex == "CCFFCC")
            prefs.followArtworkColors = false
            #expect(prefs.typography.primaryHex == "123456" && prefs.typography.secondaryHex == "654321")
        }
    }
}
