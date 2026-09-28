import Testing
import Foundation
import AppKit
import SwiftUI
import LyricsXCore
@testable import LyricsXApp

private struct IdleRepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

@Test @MainActor func menuOnlyLyricClockWakesAtCueDeadlines() throws {
    let suite = "LyricsXTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let prefs = Preferences(defaults: defaults)
    prefs.showMenubarLyrics = true
    let model = AppModel(repository: IdleRepository(), preferences: prefs)
    defer { model.stop() }
    let document = LyricsDocument(lines: stride(from: 0, through: 30, by: 3).map {
        .init(id: $0, time: Double($0), text: "Line \($0)")
    })
    let track = Track(playerID: "test", playerName: "Test", title: "Test", duration: 35)
    let now = ProcessInfo.processInfo.systemUptime
    model.session.accept(.init(track: track, position: 1, isPlaying: true, sampledAt: now), now: now, shouldSearch: false)
    model.session.use(document, persist: false)
    #expect(model.lyricClockInterval() == 250)
    model.mainWindowVisible = true
    #expect(model.lyricClockInterval() < 250)
    model.mainWindowVisible = false
    model.session.accept(.init(track: track, position: 2.96, isPlaying: true, sampledAt: now + 1), now: now + 1)
    let deadline = model.lyricClockInterval()
    #expect(deadline > 40 && deadline < 42)
    #expect(document.index(at: 2.96 + deadline / 1_000) == 1)

    func estimatedWakeups(_ cadence: (Double) -> Double) -> Int {
        var position = 0.0, count = 0
        while position < 30 {
            let interval = cadence(position)
            #expect(interval >= 8)
            position += interval / 1_000
            count += 1
        }
        return count
    }
    let old = estimatedWakeups { LyricTickCadence.milliseconds(playing: true, visible: true,
                                                                document: document, position: $0) }
    let menu = estimatedWakeups { FlexbarCueCadence.milliseconds(document: document, position: $0) }
    print("30-second cue timer estimate: animation=\(old), menu=\(menu)")
    #expect(menu < old / 2, "30-second cue fixture: old \(old) timer wakes, menu \(menu)")
}

@Test @MainActor func playingIndicatorUsesStaticBarsWhenAppReducesMotion() {
    let date = Date(timeIntervalSinceReferenceDate: 0.3)
    for index in 0..<4 {
        #expect(PlayingIndicator.barHeight(playing: true, reducedMotion: true, at: date, index: index) == 5.5)
        #expect(PlayingIndicator.barHeight(playing: false, reducedMotion: false, at: date, index: index) == 5.5)
    }
    #expect(PlayingIndicator.barHeight(playing: true, reducedMotion: false, at: date, index: 0) > 5.5)
}

@Test @MainActor func pendingMenuTimerMovesForwardForPlayerCorrectionAndSeek() throws {
    for seek in [false, true] {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.showMenubarLyrics = true
        let model = AppModel(repository: IdleRepository(), preferences: prefs)
        defer { model.stop() }
        let track = Track(playerID: "test", playerName: "Test", title: "Test", duration: 10)
        let document = LyricsDocument(lines: [
            .init(id: 0, time: 0, text: "First"), .init(id: 1, time: 0.25, text: "Second")
        ])
        let now = ProcessInfo.processInfo.systemUptime
        model.session.accept(.init(track: track, position: 0, isPlaying: true, sampledAt: now), now: now, shouldSearch: false)
        model.session.use(document, persist: false)
        model.startLyricClock() // 250 ms is pending.
        #expect(model.session.currentLineIndex == 0)
        let originalDeadline = try #require(model.lyricClockNextFireAt)
        if seek {
            model.applyLocalSeek(0.22) // Exercise scheduling without commanding the user's player.
        } else {
            let sample = PlaybackSnapshot(track: track, position: 0.22, isPlaying: true,
                                          sampledAt: ProcessInfo.processInfo.systemUptime)
            model.bridge.onSnapshot?(sample)
        }
        let earlierDeadline = try #require(model.lyricClockNextFireAt)
        #expect(earlierDeadline < originalDeadline - 0.1,
                "A near-boundary cue must replace the pending 250 ms timer")
    }
}

@Test @MainActor func lyricDocumentArrivalChangesMenuDeadline() throws {
    let suite = "LyricsXTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let prefs = Preferences(defaults: defaults)
    prefs.showMenubarLyrics = true
    let model = AppModel(repository: IdleRepository(), preferences: prefs)
    defer { model.stop() }
    let track = Track(playerID: "test", playerName: "Test", title: "Test", duration: 10)
    let now = ProcessInfo.processInfo.systemUptime
    model.session.accept(.init(track: track, position: 0, isPlaying: true, sampledAt: now), now: now, shouldSearch: false)
    model.startLyricClock()
    #expect(model.lyricClockInterval() == 250)
    let document = LyricsDocument(lines: [
        .init(id: 0, time: 0, text: "First"), .init(id: 1, time: 0.08, text: "Second")
    ])
    model.session.use(document, persist: false)
    #expect(model.lyricClockInterval() < 81,
            "A new document must expose its next cue deadline immediately")
}

@Test @MainActor func unchangedMenuDeadlineDoesNotRestartPendingTimer() throws {
    var wakes = 0
    let ticker = PlaybackTicker { wakes += 1; return 250 }
    ticker.start()
    defer { ticker.stop() }
    let originalDeadline = try #require(ticker.nextFireAt)
    for _ in 0..<20 { ticker.scheduleEarlier(250) }
    #expect(wakes == 1)
    #expect(ticker.nextFireAt == originalDeadline)
    ticker.scheduleEarlier(20)
    #expect(try #require(ticker.nextFireAt) < originalDeadline - 0.1,
            "An earlier cue deadline should replace the 250 ms timer")
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
    let monitor = HDRDisplayMonitor()
    monitor.start()
    defer { monitor.stop() }
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    let view = LyricFrameView()
    window.contentView = view
    let hdrHost = NSHostingView(rootView: Text("EDR").hdrDisplayScope(requested: true))
    hdrHost.frame = view.bounds
    view.addSubview(hdrHost)
    hdrHost.layoutSubtreeIfNeeded()
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
    monitor.stop()
    await Task.detached {
        NotificationCenter.default.post(name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }.value
    #expect(!view.deliveringFrames)
}
