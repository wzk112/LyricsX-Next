import AppKit
import SwiftUI
import Testing
import LyricsXCore
@testable import LyricsXApp

private struct SettingsQARepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}
@Suite(.enabled(if: ProcessInfo.processInfo.environment["LYRICSX_SETTINGS_QA"] == "1"))
@MainActor struct SettingsVisualTests {
    @Test func renderEverySettingsSectionAndGuideAtMinimumSize() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXSettingsQA-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.reduceMotion = true
        let model = AppModel(repository: SettingsQARepository(), preferences: prefs)
        defer { model.stop() }
        let output = URL(fileURLWithPath: "/tmp/lyricsx-settings-qa", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func snapshot<V: View>(_ root: V, name: String, width: CGFloat = 800,
                               height: CGFloat = 640, appearance: NSAppearance.Name? = nil) async throws {
            let host = NSHostingView(rootView: root)
            host.frame = .init(x: 0, y: 0, width: width, height: height)
            let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            if let appearance { window.appearance = NSAppearance(named: appearance) }
            window.contentView = host; window.orderFrontRegardless()
            defer { window.close() }
            try await Task.sleep(for: .milliseconds(120))
            host.layoutSubtreeIfNeeded()
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: output.appendingPathComponent(name + ".png"))
            #expect(host.frame.width <= width + 1)
        }
        for section in SettingsSection.allCases {
            try await snapshot(PreferencesView(model: model, initialSection: section), name: "settings-" + section.id, width: 760)
        }
        for (scheme, appearance) in [(ColorScheme.light, NSAppearance.Name.aqua), (.dark, .darkAqua)] {
            let picker = OverlayAppearancePicker(selection: .constant(.glass), transparency: 0.26,
                readingFrostAmount: 0.82, theme: scheme == .dark ? .dark : .light)
                .environment(\.colorScheme, scheme)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(scheme == .light ? Color.white : Color(white: 0.10))
            try await snapshot(picker, name: "material-\(scheme)", width: 520, height: 300,
                appearance: appearance)
        }
        prefs.appTheme = .dark
        try await snapshot(PreferencesView(model: model, initialSection: .general), name: "settings-dark", width: 760, appearance: .darkAqua)
        prefs.appTheme = .light
        try await snapshot(MainView(model: model), name: "main-light", width: 1040, height: 720, appearance: .aqua)
        prefs.followArtworkColors = true
        prefs.artworkTheme = .init(accent: "BB55AA", sung: "FFD6EF", unsung: "6E5C67", secondary: "FFE0F4")
        try await snapshot(PreferencesView(model: model, initialSection: .lyrics), name: "settings-theme", width: 760)
        for index in GuideContent.tutorial.indices {
            try await snapshot(FeatureGuideView(mode: .tutorial, initialPage: index, preferences: prefs, model: model, close: {}), name: "guide-\(index)")
        }
        for index in GuideContent.updates(after: "2.0.33").indices {
            try await snapshot(FeatureGuideView(mode: .update(previous: "2.0.33"), initialPage: index, close: {}), name: "update-\(index)")
        }
    }
}
