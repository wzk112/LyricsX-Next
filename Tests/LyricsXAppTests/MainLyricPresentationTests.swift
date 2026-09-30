import AppKit
import Observation
import Testing
import LyricsXCore
@testable import LyricsXApp

private struct PendingMainRepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> {
        .init { _ in }
    }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

@Suite @MainActor struct MainLyricPresentationTests {
    private func fixture(_ body: @MainActor (AppModel) async throws -> Void) async throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(repository: PendingMainRepository(), preferences: Preferences(defaults: defaults))
        defer { model.stop() }
        model.mainWindowVisible = true
        model.bridge.onSnapshot?(.init(track: .init(playerID: "test", playerName: "Test", title: "First"),
                                      position: 2, isPlaying: false))
        model.session.use(.init(lines: [.init(id: 0, time: 0, text: "First lyric")]), persist: false)
        model.updateMainLyricSelection()
        // Allow the production observation to commit the ready old document.
        for _ in 0..<3 { await Task.yield() }
        model.mainLyricPresentation.update(model: model)
        try await body(model)
    }

    @Test func cachedDocumentReplacesFrozenLyricsWithoutAnIntermediateTitle() async throws {
        try await fixture { model in
            model.bridge.onSnapshot?(.init(track: .init(playerID: "test", playerName: "Test", title: "Second"),
                                          position: 0, isPlaying: true))
            let held = try #require(model.mainLyricPresentation.held)
            #expect(held.track?.title == "First" && held.document?.lines.first?.text == "First lyric")
            #expect(held.position == 2 && held.index == 0)
            let second = LyricsDocument(lines: [.init(id: 0, time: 5, text: "Second lyric")])
            model.session.use(second, persist: false)
            for _ in 0..<6 { await Task.yield() }
            #expect(model.mainLyricPresentation.held == nil)
            #expect(model.session.document?.id == second.id)
            #expect(model.mainLyricIndex == nil, "The prelude must not highlight the first line early")
            let readyArrival = MainLyricSnapshot(model: model).arrivalIdentity
            model.session.use(.init(lines: [.init(id: 0, time: 5, text: "Better second lyric")]), persist: false)
            #expect(MainLyricSnapshot(model: model).arrivalIdentity == readyArrival,
                    "Candidate upgrades must not replay the song's arrival animation")
        }
    }

    @Test func rapidSkipsShareDeadlineAndSlowSearchShowsTheLatestWaitingSong() async throws {
        try await fixture { model in
            let presentation = MainLyricPresentation(); defer { presentation.stop() }
            presentation.update(model: model, at: 10)
            for index in 0..<3 {
                model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Skip \(index)"),
                                          position: 0, isPlaying: false))
                model.updateMainLyricSelection()
                presentation.update(model: model, at: 10.01 + Double(index) * 0.05)
                #expect(presentation.held?.track?.title == "First")
            }
            presentation.finishIfDue(model: model, at: 10.169)
            #expect(presentation.held != nil)
            presentation.finishIfDue(model: model, at: 10.171)
            #expect(presentation.held == nil)
            #expect(model.session.track?.title == "Skip 2" && model.session.isSearching)
            presentation.update(model: model, at: 10.18)
            #expect(presentation.held == nil, "The same search must not restart a hold after expiry")
        }
    }

    @Test func hidingReducingMotionStoppingOrSearchFailureClearsTheHold() async throws {
        try await fixture { model in
            @MainActor func change(_ title: String) throws {
                model.session.use(.init(lines: [.init(id: 0, time: 0, text: title + " lyric")]), persist: false)
                model.updateMainLyricSelection()
                model.mainLyricPresentation.update(model: model)
                model.bridge.onSnapshot?(.init(track: .init(playerID: "test", playerName: "Test", title: title),
                                              position: 0, isPlaying: false))
                if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    #expect(model.mainLyricPresentation.held != nil)
                }
            }
            try change("Second")
            model.mainWindowVisible = false
            for _ in 0..<4 { await Task.yield() }
            #expect(model.mainLyricPresentation.held == nil)
            model.mainWindowVisible = true
            try change("Third")
            model.preferences.reduceMotion = true
            for _ in 0..<4 { await Task.yield() }
            #expect(model.mainLyricPresentation.held == nil)
            model.preferences.reduceMotion = false
            try change("Fourth")
            model.session.suppressLyrics()
            for _ in 0..<4 { await Task.yield() }
            #expect(model.mainLyricPresentation.held == nil)
            try change("Fifth")
            model.stop()
            try await Task.sleep(for: .milliseconds(180))
            #expect(model.mainLyricPresentation.held == nil)
        }
    }

    @Test func displaySnapshotsDoNotSubscribeTheViewportToEveryPlayingClockTick() async throws {
        try await fixture { model in
            model.session.accept(.init(track: model.session.track, position: 2, isPlaying: true), shouldSearch: true)
            // An Observation callback is synchronous on mutation. Restrict the
            // check to position-only ticks which do not cross a line boundary.
            final class Flag: @unchecked Sendable { var value = false }
            let clockInvalidated = Flag()
            withObservationTracking { _ = MainLyricSnapshot(model: model) }
            onChange: { clockInvalidated.value = true }
            model.session.tick(now: ProcessInfo.processInfo.systemUptime + 0.1)
            #expect(!clockInvalidated.value)
        }
    }
}
