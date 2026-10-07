import AppKit
import SwiftUI
import Testing
import LyricsXCore
import LyricsXServices
@testable import LyricsXApp

private struct CloudSettingsRepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

@Suite(.serialized) @MainActor struct AppleMusicCloudSettingsTests {
    private func makeModel() throws -> (AppModel, UserDefaults, String) {
        let suite = "LyricsXCloudControls-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        let preferences = Preferences(defaults: defaults)
        preferences.setSource(AppleMusicCloudLyricsSource.name, enabled: true)
        return (AppModel(repository: CloudSettingsRepository(), preferences: preferences), defaults, suite)
    }
    private func settle(_ done: () -> Bool) async throws {
        for _ in 0..<40 {
            if done() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(done())
    }
    @Test func completingLoginChecksTheAccountWithoutAWebSongOrNativeTrack() async throws {
        let (model, defaults, suite) = try makeModel()
        defer { model.stop(); defaults.removePersistentDomain(forName: suite) }
        var checks = 0, refreshes = 0, reads = 0, clears = 0
        let controls = AppleMusicCloudControls(model: model,
            check: { checks += 1; return "登录会话有效" },
            read: { _ in reads += 1; return nil }, clear: { clears += 1 }, refresh: { refreshes += 1 })
        controls.loginDidClose()
        try await settle { !controls.checking }
        #expect(checks == 1 && refreshes == 1 && controls.result == "登录会话有效")
        #expect(model.session.track == nil)
        #expect(controls.canCheckLogin && controls.canTestCurrentTrack && controls.canClearLogin)
        controls.testCurrentTrack()
        #expect(reads == 0 && refreshes == 2 && controls.result.contains("Mac 的“音乐”"))
        #expect(!controls.testing)
        model.preferences.setSource(AppleMusicCloudLyricsSource.name, enabled: false)
        #expect(!controls.canTestCurrentTrack && !controls.canCheckLogin && controls.canClearLogin)
        controls.clearLogin()
        try await settle { !controls.clearing }
        #expect(clears == 1 && controls.result == "已清除本机登录会话")
    }
    @Test func pausedNativeSongCanBeTestedWithoutWebPlaybackOrReplacingLyrics() async throws {
        let (model, defaults, suite) = try makeModel()
        defer { model.stop(); defaults.removePersistentDomain(forName: suite) }
        let track = Track(playerID: "com.apple.Music", playerName: "Apple Music", title: "Native song", artist: "Artist")
        model.session.accept(.init(track: track, position: 1, isPlaying: false), shouldSearch: false)
        let before = LyricsDocument(lines: [.init(id: 0, time: 0, text: "Already selected")])
        model.session.use(before, persist: false)
        var received: Track?
        let controls = AppleMusicCloudControls(model: model, read: { track in
            received = track
            return .init(lines: [.init(id: 0, time: 0, text: "Word", words: [.init(text: "Word", start: 0, end: 1)])])
        })
        controls.testCurrentTrack()
        #expect(controls.testing && !controls.canTestCurrentTrack && controls.canClearLogin)
        try await settle { !controls.testing }
        #expect(received == track && controls.result.contains("逐字词段"))
        #expect(controls.result.contains("《Native song》"))
        #expect(model.session.document == before && !model.session.isPlaying)
        var next = track; next.title = "Next song"
        model.session.accept(.init(track: next, position: 0, isPlaying: false), shouldSearch: false)
        controls.trackChanged()
        #expect(controls.result == "歌曲已切换，请重新测试。")
        #expect(controls.targetDescription.contains("Next song") && !controls.result.contains("读取成功"))
    }
    @Test func unrelatedPlayerDoesNotBecomeTheCloudTestTarget() throws {
        let (model, defaults, suite) = try makeModel()
        defer { model.stop(); defaults.removePersistentDomain(forName: suite) }
        let track = Track(playerID: "com.spotify.client", playerName: "Spotify", title: "Other song", artist: "Artist")
        model.session.accept(.init(track: track, position: 0, isPlaying: false), shouldSearch: false)
        var reads = 0
        let controls = AppleMusicCloudControls(model: model, read: { _ in reads += 1; return nil }, refresh: {})
        controls.testCurrentTrack(); controls.previewCurrentTrack()
        #expect(reads == 0 && !model.showSearch && !controls.testing)
        #expect(controls.result.contains("Mac 的“音乐”"))
    }
    @Test func accountActionsCannotOverwriteAnInFlightTestAndClearingSurvivesClosingTheCard() async throws {
        let (model, defaults, suite) = try makeModel()
        defer { model.stop(); defaults.removePersistentDomain(forName: suite) }
        model.session.accept(.init(track: .init(playerID: "com.apple.Music", playerName: "Music", title: "Fixture"), position: 0, isPlaying: false), shouldSearch: false)
        var checks = 0
        var finishRead: CheckedContinuation<LyricsDocument?, Never>?
        var finishClear: CheckedContinuation<Void, Never>?
        let controls = AppleMusicCloudControls(model: model,
            check: { checks += 1; return "Account result" },
            read: { _ in await withCheckedContinuation { finishRead = $0 } },
            clear: { await withCheckedContinuation { finishClear = $0 } })
        controls.testCurrentTrack()
        try await settle { finishRead != nil }
        #expect(!controls.canCheckLogin && !controls.canOpenLogin && !controls.canTestCurrentTrack)
        controls.checkLogin()
        #expect(checks == 0 && controls.testing && controls.result.contains("正在读取"))
        controls.clearLogin()
        try await settle { finishClear != nil }
        controls.cancel() // The view disappeared while WebKit was clearing its store.
        #expect(controls.clearing && !controls.canOpenLogin && !controls.canClearLogin)
        finishRead?.resume(returning: .init(lines: [.init(id: 0, time: 0, text: "Late result")]))
        finishClear?.resume()
        try await settle { !controls.clearing }
        #expect(controls.result == "已清除本机登录会话" && controls.canOpenLogin)
    }
    @Test func cloudPreferencesRequireOptInAndShareOneSearchSource() throws {
        let suite = "LyricsXCloudPreferences-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set([], forKey: "disabledSources")
        let preferences = Preferences(defaults: defaults)
        let music = AppleMusicLyricsSource.name
        #expect(!preferences.appleMusicCloudEnabled)
        #expect(!preferences.sourceConfigurationReader.read().appleMusicCloudEnabled)
        #expect(preferences.sourceOrder.filter { $0.hasPrefix("Apple Music") } == [music])
        preferences.setAppleMusicCloudEnabled(true)
        let restored = Preferences(defaults: defaults)
        #expect(restored.appleMusicCloudEnabled && restored.sourceConfigurationReader.read().appleMusicCloudEnabled)
        restored.setSource(music, enabled: false)
        #expect(!restored.sourceConfigurationReader.read().enabled.contains(music))
        #expect(Preferences(defaults: defaults).disabledSources.contains(music))
        restored.setAppleMusicCloudEnabled(false)
        #expect(!Preferences(defaults: defaults).appleMusicCloudEnabled)
    }
    @Test func oldCloudPriorityAndEnabledReaderMigrateWithoutReenablingDisabledSources() throws {
        let suite = "LyricsXCloudMigration-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["Apple Music 云端（实验）", "QQMusic", "Apple Music"], forKey: "sourceOrder")
        defaults.set(["Apple Music"], forKey: "disabledSources")
        defaults.set(true, forKey: "appleMusicCloudEnabled")
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.sourceOrder.first == "Apple Music")
        #expect(preferences.sourceOrder.filter { $0.hasPrefix("Apple Music") }.count == 1)
        #expect(!preferences.disabledSources.contains("Apple Music") && preferences.appleMusicCloudEnabled)
        preferences.setSource("Apple Music", enabled: false)
        #expect(Preferences(defaults: defaults).disabledSources.contains("Apple Music"))
    }
    @Test func disabledLegacyCloudRemainsOffAfterTheStableNameMigration() throws {
        let suite = "LyricsXStableCloudMigration-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "appleMusicCloudEnabled")
        defaults.set(["Apple Music 云端（实验）", "Musixmatch"], forKey: "disabledSources")
        let preferences = Preferences(defaults: defaults)
        #expect(!preferences.appleMusicCloudEnabled)
        #expect(preferences.disabledSources == ["Musixmatch"])
        #expect(!Preferences(defaults: defaults).appleMusicCloudEnabled)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LYRICSX_CLOUD_SETTINGS_QA"] == "1"))
    func nativeExperimentalCardShowsControlsWithoutStartingAWebSession() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXCloudSettingsQA-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(repository: CloudSettingsRepository(), preferences: Preferences(defaults: defaults))
        defer { model.stop() }
        let host = NSHostingView(rootView: AppleMusicCloudSettingsView(model: model).padding(20).frame(width: 720))
        host.frame = .init(x: 0, y: 0, width: 720, height: 540)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host; window.orderFrontRegardless()
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(180))
        #expect(!AppleMusicCloudSession.shared.hasLoadedPage)
        if let path = ProcessInfo.processInfo.environment["LYRICSX_CLOUD_QA_DIR"] {
            let directory = URL(fileURLWithPath: path, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for enabled in [false, true] {
                model.preferences.setSource(AppleMusicCloudLyricsSource.name, enabled: enabled)
                try await Task.sleep(for: .milliseconds(120))
                host.layoutSubtreeIfNeeded()
                let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                try #require(bitmap.representation(using: .png, properties: [:]))
                    .write(to: directory.appendingPathComponent(enabled ? "experimental-enabled.png" : "experimental-default-off.png"))
            }
        }
        #expect(!AppleMusicCloudSession.shared.hasLoadedPage)
    }
}
