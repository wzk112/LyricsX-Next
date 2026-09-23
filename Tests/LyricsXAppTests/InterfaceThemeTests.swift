import AppKit
import SwiftUI
import Testing
import LyricsXCore
@testable import LyricsXApp

@Suite @MainActor struct InterfaceThemeTests {
    private struct Repository: LyricsRepository {
        func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
        func save(_ document: LyricsDocument, for track: Track) async throws {}
    }
    @Test func independentThemesPersistAndReachTheNativePanel() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXThemeTest-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("invalid", forKey: "overlayTheme")
        let prefs = Preferences(defaults: defaults)
        #expect(prefs.appTheme == .system && prefs.overlayTheme == .system)
        prefs.overlayAppearance = .frosted
        prefs.appTheme = .dark; prefs.overlayTheme = .light
        let model = AppModel(repository: Repository(), preferences: prefs)
        let controller = OverlayController(model: model, frameAutosaveName: nil)
        defer { controller.stop(); model.stop() }
        #expect(controller.panel.appearance?.name == .aqua)
        prefs.appTheme = .light
        try await Task.sleep(for: .milliseconds(20))
        #expect(controller.panel.appearance?.name == .aqua)
        prefs.overlayTheme = .dark
        try await Task.sleep(for: .milliseconds(20))
        #expect(controller.panel.appearance?.name == .darkAqua)
        let restored = Preferences(defaults: defaults)
        #expect(restored.appTheme == .light && restored.overlayTheme == .dark)
        #expect(restored.lyricPrimaryColor == "FFFFFF")
        #expect(restored.mainTypography(colorScheme: .light).primaryHex != "FFFFFF")
        #expect(restored.mainTypography(colorScheme: .dark) == restored.typography)
        prefs.overlayTheme = .system
        try await Task.sleep(for: .milliseconds(20))
        #expect(controller.panel.appearance == nil)
    }

    @Test func nativeMaterialAndInkAgreeForBothThemesAndStyles() throws {
        let suite = "LyricsXThemeTest-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        let view = OverlayGlassBackground(frame: .init(x: 0, y: 0, width: 620, height: 160))
        for style in OverlayAppearance.allCases {
            prefs.overlayAppearance = style
            for theme in [InterfaceTheme.light, .dark, .light] {
                view.appearance = theme.appearance
                view.configure(appearance: style, transparency: 0.34, frostAmount: style.defaultFrost,
                               reduceTransparency: false, reduceMotion: true)
                let native = try #require(view.subviews.first as? NSGlassEffectView)
                #expect(native.appearance?.name == (style == .glass ? NSAppearance.Name.darkAqua : theme.appearance?.name))
                let colors = prefs.overlayTypography(colorScheme: try #require(theme.colorScheme))
                #expect((LyricTypography.luminance(colors.primaryHex) < 0.1) == (style == .frosted && theme == .light))
            }
        }
    }

    @Test func livePanelSettingsReachEverySurfaceWhileShownHiddenAndDetached() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXThemeTest-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlayVisible = true; prefs.hideWhenPaused = false
        prefs.hideOverlayOnHover = false; prefs.reduceMotion = true
        let model = AppModel(repository: Repository(), preferences: prefs)
        let track = Track(playerID: "test", playerName: "Test", title: "Theme", artist: "Artist", duration: 100)
        model.session.accept(.init(track: track, position: 1, isPlaying: false), shouldSearch: false)
        model.session.use(.init(title: "Theme", lines: [.init(id: 0, time: 0, text: "A visible line", translation: "可见的翻译")]), persist: false)
        let controller = OverlayController(model: model, frameAutosaveName: nil,
            pointerLocation: { .init(x: -10_000, y: -10_000) })
        defer { controller.stop(); model.stop() }
        let background = try #require(controller.panel.contentView?.subviews.compactMap { $0 as? OverlayGlassBackground }.first)
        let host = controller.lyricHostingView
        try await Task.sleep(for: .milliseconds(100))
        let size = controller.panel.frame.size
        for detached in [false, true] {
            model.setOverlayClickThrough(detached)
            for style in OverlayAppearance.allCases {
                prefs.overlayAppearance = style
                for theme in [InterfaceTheme.dark, .light, .dark, .system] {
                    prefs.overlayVisible = false
                    prefs.overlayTheme = theme
                    // Deliberately oppose the application window's theme.
                    prefs.appTheme = theme == .dark ? .light : .dark
                    prefs.overlayMaterialTransparency = 0.8
                    try await Task.sleep(for: .milliseconds(25))
                    prefs.overlayVisible = true
                    try await Task.sleep(for: .milliseconds(25))
                    let material = try #require(background.subviews.first as? NSGlassEffectView)
                    #expect(controller.panel.isVisible)
                    #expect(controller.panel.appearance?.name == prefs.overlayEffectiveTheme.appearance?.name)
                    #expect(background.appearance?.name == prefs.overlayEffectiveTheme.appearance?.name)
                    #expect(host.appearance?.name == prefs.overlayEffectiveTheme.appearance?.name)
                    #expect(controller.controlsView.appearance?.name == prefs.overlayEffectiveTheme.appearance?.name)
                    #expect(material.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) ==
                        (style == .glass ? .darkAqua : background.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])))
                    let transparent = material.alphaValue
                    let gradient = try #require(material.contentView?.layer as? CAGradientLayer)
                    let clearTint = try #require((gradient.colors as? [CGColor])?.first).alpha
                    prefs.overlayMaterialTransparency = 0.2
                    try await Task.sleep(for: .milliseconds(25))
                    if style == .glass {
                        // Glass alpha must never reintroduce undistorted desktop
                        // detail, even though its tint control remains effective.
                        #expect(transparent == 1 && material.alphaValue == 1)
                        let tinted = try #require((gradient.colors as? [CGColor])?.first).alpha
                        #expect(tinted - clearTint > 0.3)
                        #expect((gradient.colors as? [CGColor])?.last?.alpha == 0)
                    } else {
                        #expect(material.alphaValue - transparent > 0.3)
                    }
                    #expect(host.alphaValue == 1)
                    #expect(controller.lyricHostingView === host)
                    #expect(background.subviews.first === material)
                    #expect(controller.panel.frame.size == size)
                }
            }
        }
    }

    @Test func reducedTransparencyRestoresTheLastMaterialSettings() throws {
        let background = OverlayGlassBackground(frame: .init(x: 0, y: 0, width: 620, height: 160))
        for theme in [InterfaceTheme.dark, .light] {
            background.appearance = theme.appearance
            background.configure(appearance: .glass, transparency: 0.8, frostAmount: 0,
                reduceTransparency: true, reduceMotion: true)
            let material = try #require(background.subviews.first as? NSGlassEffectView)
            #expect(material.isHidden)
            #expect(background.layer?.backgroundColor?.alpha == 1)
            background.configure(appearance: .glass, transparency: 0.8, frostAmount: 0,
                reduceTransparency: false, reduceMotion: true)
            let restored = try #require(background.subviews.first as? NSGlassEffectView)
            #expect(!restored.isHidden && restored.alphaValue == 1 && restored.style == .clear)
            #expect(background.layer?.backgroundColor == nil)
        }
    }

    @Test func glassTintMigratesWithoutChangingAppearanceAndAdjustsIndependently() throws {
        let suite = "LyricsXThemeTest-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for oldValue in [0.2, 0.26, 0.46, 0.8] {
            defaults.removePersistentDomain(forName: suite)
            defaults.set(oldValue, forKey: "overlayTransparency")
            let prefs = Preferences(defaults: defaults)
            let oldShade = 0.34 * (0.8 - oldValue) / 0.6
            let newShade = OverlayAppearance.glass.shadeOpacities(transparency: prefs.overlayMaterialTransparency)[0]
            #expect(abs(oldShade - newShade) < 0.000001)
            prefs.overlayMaterialTransparency = 1
            #expect(OverlayAppearance.glass.shadeOpacities(transparency: prefs.overlayMaterialTransparency).allSatisfy { $0 == 0 })
            prefs.overlayAppearance = .frosted
            #expect(prefs.overlayMaterialTransparency == oldValue)
            prefs.overlayMaterialTransparency = 0.52
            prefs.overlayAppearance = .glass
            #expect(prefs.overlayMaterialTransparency == 1)
            prefs.overlayMaterialTransparency = 0
            #expect(OverlayAppearance.glass.shadeOpacities(transparency: prefs.overlayMaterialTransparency)[0] > 0.5)
            let restored = Preferences(defaults: defaults)
            #expect(restored.overlayGlassTintTransparency == 0)
            #expect(restored.overlayTransparency == 0.52)
        }
        // The optical layer never changes style, tint, opacity or identity,
        // including the new full-range endpoints in both appearances.
        let view = OverlayGlassBackground(frame: .init(x: 0, y: 0, width: 620, height: 160))
        view.configure(appearance: .glass, transparency: 0.6, frostAmount: 0.55,
            reduceTransparency: false, reduceMotion: true)
        let native = try #require(view.subviews.first as? NSGlassEffectView)
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            view.appearance = NSAppearance(named: appearance)
            for value in stride(from: 0.0, through: 1.0, by: 0.1) {
                view.configure(appearance: .glass, transparency: value, frostAmount: 0.55,
                    reduceTransparency: false, reduceMotion: true)
                #expect(view.subviews.first === native)
                #expect(native.style == .clear && native.alphaValue == 1 && native.tintColor == nil)
            }
        }
    }

    @Test func opticalChangesReplaceOnlyTheMaterialAndKeepSliderUpdatesInPlace() throws {
        let background = OverlayGlassBackground(frame: .init(x: 0, y: 0, width: 620, height: 160))
        var previous: NSGlassEffectView?
        for (style, theme) in [(OverlayAppearance.glass, InterfaceTheme.dark),
                               (.frosted, .dark), (.frosted, .light), (.glass, .light),
                               (.frosted, .light), (.frosted, .dark), (.glass, .dark)] {
            background.configure(appearance: style, transparency: 0.6, frostAmount: 0.82,
                reduceTransparency: false, reduceMotion: true, theme: theme)
            let native = try #require(background.subviews.first as? NSGlassEffectView)
            #expect(native !== previous)
            #expect(previous?.superview == nil)
            #expect(background.subviews.count == 1)
            #expect(native.style == (style == .glass ? .clear : .regular))
            #expect(native.appearance?.name == (style == .glass || theme == .dark ? .darkAqua : .aqua))
            for transparency in [0.2, 0.8, 0.6] {
                background.configure(appearance: style, transparency: transparency, frostAmount: 0.82,
                    reduceTransparency: false, reduceMotion: true, theme: theme)
                #expect(background.subviews.first === native)
                #expect(native.frame == background.bounds)
                #expect(native.contentView?.frame == native.bounds)
            }
            previous = native
        }
    }

    @Test func freshGlassDefaultsToSixtyPercentWithoutOverwritingSavedValues() throws {
        let suite = "LyricsXGlassDefaults-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(Preferences(defaults: defaults).overlayMaterialTransparency == 0.6)
        #expect(Preferences(defaults: defaults).overlayMaterialTransparency == 0.6)
        defaults.set(0.68, forKey: "overlayGlassTintTransparency")
        #expect(Preferences(defaults: defaults).overlayMaterialTransparency == 0.68)
        #expect(OverlayAppearance.glass.clampedMaterialTransparency(.nan) == 0.6)
        let light = OverlayAppearance.glass.shadeOpacities(transparency: 0.6, dark: false)
        let dark = OverlayAppearance.glass.shadeOpacities(transparency: 0.6, dark: true)
        #expect(light[2] > dark[2] * 2)
        #expect(light.last == 0 && dark.last == 0)
    }

    @Test func displayTargetsRemoveDeliveryJitterAndRejectStaleFrames() {
        let first = DisplayFrameTime.sample(4.001, target: 10.008, now: 10.001)
        let delayed = DisplayFrameTime.sample(4.006, target: 10.008, now: 10.006)
        #expect(abs(first - delayed) < 0.000_001)
        #expect(DisplayFrameTime.sample(4, target: 9, now: 10) == 4)
        #expect(DisplayFrameTime.sample(4, target: .nan, now: 10) == 4)
        #expect(DisplayFrameTime.sample(0, target: nil, now: 10) == 0)
        // A seek changes the musical clock immediately, with only the same
        // sub-frame prediction; it never replays a cached pre-seek timestamp.
        #expect(abs(DisplayFrameTime.sample(50, target: 10.008, now: 10) - 50.008) < 0.000_001)
    }
}
