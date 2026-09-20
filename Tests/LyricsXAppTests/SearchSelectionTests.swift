import Foundation
import Testing
import LyricsXCore
@testable import LyricsXApp

private actor SelectionRepository: LyricsRepository {
    var saved: [UUID] = []
    nonisolated func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws { saved.append(document.id) }
}
@MainActor private final class SelectionFixture {
    let suite = "LyricsXSearchTests-" + UUID().uuidString
    let defaults: UserDefaults
    let repository = SelectionRepository()
    let model: AppModel
    init() {
        defaults = UserDefaults(suiteName: suite)!
        model = AppModel(repository: repository, preferences: Preferences(defaults: defaults))
    }
    isolated deinit { model.stop(); defaults.removePersistentDomain(forName: suite) }
}
@Suite @MainActor struct SearchSelectionTests {
    @Test func changingVersionsKeepsSearchOpenAndUpdatesTheLiveDocumentWithoutSeeking() async throws {
        let fixture = SelectionFixture()
        let model = fixture.model
        let track = Track(playerID: "test", playerName: "Test", title: "Current song")
        model.session.accept(.init(track: track, position: 12, isPlaying: false), shouldSearch: false)
        model.mainWindowVisible = true; model.showSearch = true
        let first = LyricCandidate(document: .init(lines: [.init(id: 0, time: 0, text: "First version")]), score: 90)
        let second = LyricCandidate(document: .init(lines: [.init(id: 0, time: 0, text: "Beginning"), .init(id: 1, time: 10, text: "Second version", translation: "Another translation")]), score: 85)
        #expect(model.applySearchCandidate(first, forTrackID: track.id))
        #expect(model.showSearch && model.session.document?.id == first.id)
        #expect(model.applySearchCandidate(second, forTrackID: track.id))
        #expect(model.showSearch && model.session.document?.id == second.id)
        #expect(model.mainLyricIndex == 1 && model.session.position == 12 && !model.session.isPlaying)
        for _ in 0..<100 {
            if await fixture.repository.saved.count == 2 { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(await fixture.repository.saved == [first.id, second.id])
    }
    @Test func aStaleSearchCannotApplyToAnotherSongOrAnEmptyPlayer() {
        let fixture = SelectionFixture(); let model = fixture.model
        let first = Track(playerID: "test", playerName: "Test", title: "First")
        let next = Track(playerID: "test", playerName: "Test", title: "Next")
        let candidate = LyricCandidate(document: .init(lines: [.init(id: 0, time: 0, text: "Old result")]), score: 90)
        model.session.accept(.init(track: next, position: 0, isPlaying: false), shouldSearch: false)
        model.showSearch = true
        #expect(!model.applySearchCandidate(candidate, forTrackID: first.id))
        #expect(model.session.document == nil && model.showSearch)
        model.session.accept(.init(track: nil, position: 0, isPlaying: false), shouldSearch: false)
        #expect(!model.applySearchCandidate(candidate, forTrackID: nil))
        #expect(model.session.document == nil && model.showSearch)
    }
    @Test func applyingToAnExcludedSongSurvivesSubsequentPlayerSnapshots() async throws {
        let fixture = SelectionFixture(); let model = fixture.model
        let track = Track(playerID: "test", playerName: "Test", title: "Previously incorrect lyrics")
        model.bridge.onSnapshot?(.init(track: track, position: 2, isPlaying: false))
        model.markWrongLyrics()
        #expect(model.lyricsBlocked && model.session.document == nil)
        let candidate = LyricCandidate(document: .init(lines: [.init(id: 0, time: 0, text: "Correct version")]), score: 90)
        // The old path reproduced the report: the next snapshot cleared it.
        model.session.use(candidate.document, persist: false)
        model.bridge.onSnapshot?(.init(track: track, position: 2, isPlaying: false))
        #expect(model.session.document == nil)
        #expect(model.applySearchCandidate(candidate, forTrackID: track.id))
        for position in 3...12 {
            model.bridge.onSnapshot?(.init(track: track, position: Double(position), isPlaying: false))
            await Task.yield()
            #expect(model.session.document?.id == candidate.id)
        }
        #expect(!model.lyricsBlocked)
        #expect(!Preferences(defaults: fixture.defaults).blockedTracks.contains(track.cacheIdentity))
        model.markWrongLyrics()
        model.bridge.onSnapshot?(.init(track: track, position: 13, isPlaying: false))
        #expect(model.lyricsBlocked && model.session.document == nil)
    }
    @Test func manualAlbumExceptionDoesNotEnableOtherSongsAndCanBeRevoked() async throws {
        let fixture = SelectionFixture(); let model = fixture.model
        let track = Track(playerID: "test", playerName: "Test", title: "Chosen song", artist: "Artist", album: "Album")
        let other = Track(playerID: "test", playerName: "Test", title: "Other song", artist: track.artist, album: track.album)
        model.bridge.onSnapshot?(.init(track: track, position: 0, isPlaying: false))
        model.toggleAlbumSuppression()
        #expect(model.albumSuppressed && model.lyricsBlocked)
        let document = LyricsDocument(lines: [.init(id: 0, time: 0, text: "Manual lyrics")])
        #expect(model.applyLyrics(document, forTrackID: track.id))
        model.bridge.onSnapshot?(.init(track: track, position: 2, isPlaying: false))
        #expect(model.session.document?.id == document.id && !model.lyricsBlocked && model.albumSuppressed)
        #expect(Preferences(defaults: fixture.defaults).manualLyricOverrides[track.cacheIdentity] != nil)
        model.bridge.onSnapshot?(.init(track: other, position: 0, isPlaying: false))
        #expect(model.lyricsBlocked && model.session.document == nil)
        model.bridge.onSnapshot?(.init(track: track, position: 0, isPlaying: false))
        #expect(!model.lyricsBlocked)
        model.toggleAlbumSuppression() // Allow the album again.
        model.toggleAlbumSuppression() // Explicitly exclude the album, including its old exception.
        #expect(model.lyricsBlocked && model.preferences.manualLyricOverrides.isEmpty)
    }
}
