import AppKit
import SwiftUI
import Testing
import LyricsXCore
@testable import LyricsXApp

private struct MemoryTestRepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

@Suite(.serialized) @MainActor struct MemoryLifecycleTests {
    @Test func releasingRunningTickerDoesNotLeaveItsTimerAlive() async throws {
        var ticks = 0
        var ticker: PlaybackTicker? = PlaybackTicker { ticks += 1; return 20 }
        weak var reference = ticker
        ticker?.start()
        #expect(ticks == 1)
        ticker = nil
        try await Task.sleep(for: .milliseconds(80))
        #expect(reference == nil)
        #expect(ticks == 1)
        reference?.stop() // cleanup if running against the pre-fix implementation
    }

    @Test func stoppedOverlayReleasesModelAndWindowTrees() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for _ in 0..<8 {
            var model: AppModel? = AppModel(repository: MemoryTestRepository(), preferences: Preferences(defaults: defaults))
            model?.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Lifetime"), position: 0, isPlaying: true), shouldSearch: false)
            model?.session.use(.init(lines: [.init(id: 0, time: 0, text: "Lifetime test", translation: "释放测试")]), persist: false)
            var overlay: OverlayController? = OverlayController(model: model!, frameAutosaveName: nil)
            model?.overlay = overlay
            weak var modelReference = model
            weak var overlayReference = overlay
            weak var contentReference = overlay?.lyricHostingView
            model?.stop()
            model = nil; overlay = nil
            // SwiftUI retires cancelled presentation tasks on a later run loop.
            for _ in 0..<200 where modelReference != nil || contentReference != nil {
                try await Task.sleep(for: .milliseconds(5))
            }
            #expect(modelReference == nil)
            #expect(overlayReference == nil)
            #expect(contentReference == nil)
        }
    }

    @Test func repeatedMetadataRefinementsDoNotAccumulateTrackOrResizeTransactions() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        preferences.overlayVisible = false
        let model = AppModel(repository: MemoryTestRepository(), preferences: preferences)
        let early = Track(playerID: "test", playerName: "Test", persistentID: "stable-item", title: "Song")
        model.bridge.onSnapshot?(.init(track: early, position: 0, isPlaying: true))
        model.session.use(.init(lines: [.init(id: 0, time: 0, text: "A stable lyric")]), persist: false)
        let overlay = OverlayController(model: model, frameAutosaveName: nil)
        model.overlay = overlay
        defer { model.stop() }
        await Task.yield()
        let revision = model.session.trackRevision
        let resizeGeneration = overlay.resizeGeneration
        for index in 0..<200 {
            var refined = early
            refined.artist = "Artist"; refined.album = "Album"; refined.duration = 180
            model.bridge.onSnapshot?(.init(track: refined, position: Double(index) / 10, isPlaying: true))
            if index.isMultiple(of: 20) { await Task.yield() }
        }
        for _ in 0..<20 { await Task.yield() }
        #expect(model.session.trackRevision == revision)
        #expect(overlay.resizeGeneration == resizeGeneration)
    }
    @Test func libraryClosesWithoutKeepingDocumentsOrPublishingLateResults() async throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defaults.set(folder.path, forKey: "ModernLyricsDirectory")
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: folder) }
        let model = AppModel(repository: MemoryTestRepository(), preferences: Preferences(defaults: defaults))
        defer { model.stop() }
        let track = Track(playerID: "test", playerName: "Test", title: "Library lifecycle")
        try await model.store.cache.save(.init(lines: [.init(id: 0, time: 0, text: "Test")]), for: track)
        model.loadLibrary()
        for _ in 0..<100 where model.libraryLoading { try await Task.sleep(for: .milliseconds(5)) }
        #expect(model.library.count == 1)
        model.loadLibrary()
        model.unloadLibrary()
        try await Task.sleep(for: .milliseconds(40))
        #expect(model.library.isEmpty)
        #expect(!model.libraryLoading)
    }

    @Test func mainWindowCallbackDoesNotRetainItsViewModel() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        final class References {
            weak var model: AppModel?
            weak var owner: MainWindowController?
        }
        let references = References()
        // End the synchronous ownership scope and drain AppKit temporaries
        // before checking weak references from the async test's frame.
        let showMain: () -> Void = try autoreleasepool {
            let model = AppModel(repository: MemoryTestRepository(), preferences: Preferences(defaults: defaults))
            let owner = MainWindowController(model: model, frameAutosaveName: nil)
            references.model = model; references.owner = owner
            defer { owner.stop(); model.stop() }
            owner.show()
            let window = try #require(owner.window)
            let host = try #require(window.contentView)
            host.layoutSubtreeIfNeeded()
            let callback = try #require(model.showMainWindow)
            #expect(window.isVisible)
            window.performClose(nil)
            #expect(!window.isVisible && model.showMainWindow != nil)
            callback()
            #expect(window.isVisible && owner.window === window && window.contentView === host)
            // Keeping this callback alive must not keep its owner or model.
            return callback
        }
        for _ in 0..<200 where references.owner != nil || references.model != nil {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(references.owner == nil)
        showMain() // A stored callback is harmless after its weak owner retires.
        #expect(references.owner == nil)
        #expect(references.model == nil)
    }

}
