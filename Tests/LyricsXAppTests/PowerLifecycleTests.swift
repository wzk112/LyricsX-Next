import Testing
import Foundation
import AppKit
import LyricsXCore
@testable import LyricsXApp

private struct IdleRepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

@Test @MainActor func lyricClockSleepsWhenPausedAndRestartsOnPlaybackObservation() async throws {
    let suite = "LyricsXTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(repository: IdleRepository(), preferences: Preferences(defaults: defaults))
    defer { model.stop() }
    model.startLyricClock()
    #expect(!model.isLyricClockRunning)
    let track = Track(playerID: "test", playerName: "Test", title: "Test", artist: "Test", duration: 100)
    model.session.accept(.init(track: track, position: 1, isPlaying: true), shouldSearch: false)
    try await Task.sleep(for: .milliseconds(20))
    #expect(model.isLyricClockRunning)
    model.session.accept(.init(track: track, position: 2, isPlaying: false), shouldSearch: false)
    try await Task.sleep(for: .milliseconds(20))
    #expect(!model.isLyricClockRunning)
    let position = model.session.position
    try await Task.sleep(for: .milliseconds(50))
    #expect(model.session.position == position)
    model.session.accept(.init(track: track, position: 2, isPlaying: true), shouldSearch: false)
    try await Task.sleep(for: .milliseconds(20))
    #expect(model.isLyricClockRunning)
}

@Test @MainActor func backgroundPowerAndThermalNotificationsDoNotEnterUIActorDirectly() async {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    let view = LyricFrameView()
    window.contentView = view
    defer { view.stop(); window.contentView = nil }
    let names = [ProcessInfo.thermalStateDidChangeNotification,
                 Notification.Name.NSProcessInfoPowerStateDidChange,
                 NSApplication.didChangeScreenParametersNotification]
    await Task.detached {
        for name in names { NotificationCenter.default.post(name: name, object: nil) }
    }.value
    // Let enqueued UI work run; no visible/running surface should be awakened.
    await Task.yield()
    #expect(!view.deliveringFrames)
    #expect(view.requestedFrameRate == 0)
    view.stop()
    await Task.detached {
        NotificationCenter.default.post(name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
    }.value
    #expect(!view.deliveringFrames)
}
