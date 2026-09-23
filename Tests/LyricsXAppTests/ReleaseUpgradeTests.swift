import AppKit
import SwiftUI
import Testing
import LyricsXCore
@testable import LyricsXApp

@Suite @MainActor struct ReleaseUpgradeTests {
    @Test func publishedPreferencesSurviveMigrationAndRepeatedLaunches() throws {
        let suite = "LyricsXUpgrade-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for style in ["glass", "frosted", "dark", "petGlass"] {
            let saved: [String: Any] = [
                "compactOverlayVersion": 1, "fixedOverlayWidthVersion": 1,
                "overlayAppearance": style, "overlayTransparency": 0.26,
                "overlayGlassFrostAmount": 0.8, "overlayReadingFrostAmount": 0.72,
                "overlayWidth": 713.0, "overlayVisible": false, "overlayLocked": true,
                "overlayClickThrough": true, "hideOverlayOnHover": false,
                "lyricFontName": "Georgia", "fontSize": 31.0, "lyricPrimaryColor": "FF93AA",
                "lyricSecondaryColor": "AACCFF", "separateWordColors": true,
                "sungWordColor": "FF8811", "unsungWordColor": "775566", "followArtworkColors": true,
                "lyricHDR": false, "lyricHDRBrightness": 2.8,
                "sourceOrder": ["QQMusic", "NetEase", "LRCLIB", "Kugou", "Musixmatch"],
                "disabledSources": ["Musixmatch"], "preferWordTiming": false,
                "guideLastVersion": "2.0.34", "guidePresentedEditions": ["2.0.34:complete-2"],
                "LyricsX.OverlayTop.LyricsXModernOverlay": "{850, 930}",
                "manualLyricOverrides": ["track": "cached-id"], "blockedTracks": ["another-track"]
            ]
            defaults.setPersistentDomain(saved, forName: suite)
            let history = GuideHistory(defaults: defaults, version: "2.0.35")
            #expect(history.pending == .update(previous: "2.0.34"))
            let first = Preferences(defaults: defaults)
            #expect(first.overlayAppearance == (["frosted", "dark"].contains(style) ? .frosted : .glass))
            #expect(first.overlayTransparency == 0.26)
            #expect(first.overlayGlassTintTransparency == OverlayAppearance.migratedGlassTint(0.26))
            #expect(first.overlayGlassFrostAmount == 0.8 && first.overlayReadingFrostAmount == 0.72)
            #expect(!first.lyricHDR && !first.overlayVisible && !first.hideOverlayOnHover)
            first.overlayGlassTintTransparency = 0.87
            let second = Preferences(defaults: defaults)
            #expect(second.overlayGlassTintTransparency == 0.87)
            for (key, value) in saved where key != "overlayAppearance" {
                #expect(NSDictionary(dictionary: [key: defaults.object(forKey: key) as Any]) ==
                        NSDictionary(dictionary: [key: value]), "Changed saved preference: \(key)")
            }
        }
    }

    @Test func reservedMetadataHeightDoesNotDependOnTrackText() throws {
        let tracks: [Track?] = [nil,
            .init(playerID: "test", playerName: "Test", title: "Short", artist: "Artist"),
            .init(playerID: "test", playerName: "Test", title: String(repeating: "长歌名 Long title ", count: 6),
                  artist: String(repeating: "Long artist ", count: 5), album: "An album")]
        for width in [220.0, 300, 330] {
            let sizes = tracks.map { track in
                NSHostingView(rootView: TrackMetadata(track: track).frame(width: width)).fittingSize
            }
            #expect(sizes.allSatisfy { abs($0.height - sizes[0].height) < 0.5 }, "\(sizes)")
        }
    }

    @Test func actualPlayerTransportStaysFixedThroughTrackAndDocumentChanges() async throws {
        _ = NSApplication.shared
        let demo = GuideDemoSession(reduced: false)
        defer { demo.stop() }
        let model = demo.model
        let host = NSHostingView(rootView: MainView(model: model))
        let window = NSWindow(contentRect: .init(x: 100, y: 100, width: 1040, height: 720),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host; window.orderFrontRegardless()
        defer { window.close() }
        func controlFrame() throws -> CGRect {
            // SwiftUI installs a native focus view with the play button's
            // explicit 40 × 42 layout. Measure that view in the real hierarchy;
            // in-process accessibility does not expose SwiftUI button labels.
            func matches(_ view: NSView) -> [NSView] {
                let own = String(describing: type(of: view)).contains("FocusRingView")
                    && abs(view.frame.width - 40) < 0.1 && abs(view.frame.height - 42) < 0.1 ? [view] : []
                return own + view.subviews.flatMap(matches)
            }
            let views = matches(host)
            try #require(views.count == 1, "Expected one native playback-button frame")
            return views[0].convert(views[0].bounds, to: host)
        }
        for size in [CGSize(width: 1040, height: 720), .init(width: 820, height: 600)] {
            window.setContentSize(size)
            try await Task.sleep(for: .milliseconds(80))
            host.layoutSubtreeIfNeeded()
            let expected = try controlFrame()
            for change in 0..<4 {
                let long = change % 2 == 0
                let track = Track(playerID: "guide-demo", playerName: "演示",
                    title: long ? "Long title with many words that occupies both lines" : "Short \(change)",
                    artist: long ? "A longer artist credit using two lines" : "Artist", album: "")
                model.session.accept(.init(track: track, position: 0, isPlaying: true), shouldSearch: false)
                for frame in 0..<26 {
                    if frame == 5 { model.session.use(GuideDemoSession.document, persist: false) }
                    if frame == 10 {
                        var refined = track; refined.album = "Album arrives later"
                        model.session.accept(.init(track: refined, position: 0.3, isPlaying: true), shouldSearch: false)
                        model.session.use(GuideDemoSession.document, persist: false)
                    }
                    try await Task.sleep(for: .milliseconds(20))
                    host.layoutSubtreeIfNeeded()
                    let actual = try controlFrame()
                    #expect(abs(actual.minY - expected.minY) < 0.5,
                            "Transport moved during track \(change), frame \(frame): \(actual) vs \(expected)")
                }
            }
        }
    }
}
