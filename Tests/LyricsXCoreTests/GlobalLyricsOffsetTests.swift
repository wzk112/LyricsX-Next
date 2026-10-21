import Foundation
import Testing
@testable import LyricsXCore

private actor OffsetRepository: LyricsRepository {
    let stream = AsyncThrowingStream<LyricCandidate, Error>.makeStream()
    var saved: [LyricsDocument] = []
    nonisolated func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { stream.stream }
    func save(_ document: LyricsDocument, for track: Track) async throws { saved.append(document) }
    func yield(_ document: LyricsDocument) { stream.continuation.yield(.init(document: document, score: 80)) }
}

@Suite @MainActor struct GlobalLyricsOffsetTests {
    let track = Track(playerID: "test", playerName: "Test", title: "Offset", duration: 60)
    var document: LyricsDocument {
        .init(lines: [.init(id: 7, time: 0, text: "First"),
                      .init(id: 21, time: 10, text: "Next", words: [.init(text: "Next", start: 10, end: 11)])],
              offsetMilliseconds: 200)
    }

    @Test func combinedOffsetUsesTheSameBoundaryForLinesWordsAndSeeks() {
        var doc = document
        doc.lines[1].id = 21
        #expect(doc.effectiveOffsetMilliseconds(globalOffsetMilliseconds: 300) == 500)
        #expect(doc.index(at: 9.499, globalOffsetMilliseconds: 300) == 0)
        #expect(doc.lineID(at: 9.5, globalOffsetMilliseconds: 300) == 21)
        #expect(doc.lyricTime(for: 10, globalOffsetMilliseconds: 300) == 10.5)
        #expect(doc.seekPosition(for: doc.lines[1], globalOffsetMilliseconds: 300) == 9.5)
        #expect(doc.seekPosition(for: doc.lines[1], globalOffsetMilliseconds: -700) == 10.5)
        #expect(doc.seekPosition(for: doc.lines[0], globalOffsetMilliseconds: 300) == 0)
        #expect(doc.offsetMilliseconds == 200)
    }

    @Test func globalChangesKeepSearchAndDocumentIntactAndOnlySingleSongEditsPersist() async throws {
        let repository = OffsetRepository()
        let session = LyricsSession(repository: repository)
        defer { session.stop() }
        session.accept(.init(track: track, position: 9.5, isPlaying: false))
        let generation = session.searchGeneration
        session.setGlobalOffset(300)
        #expect(session.isSearching && session.searchGeneration == generation)
        await repository.yield(document)
        for _ in 0..<100 where session.document == nil { try await Task.sleep(for: .milliseconds(5)) }
        #expect(session.currentLineIndex == 1)
        let revision = session.documentRevision
        session.setGlobalOffset(-300)
        #expect(session.currentLineIndex == 0 && session.position == 9.5 && !session.isPlaying)
        #expect(session.documentRevision == revision && session.document?.offsetMilliseconds == 200)
        #expect(session.isSearching && session.searchGeneration == generation)
        #expect(await repository.saved.isEmpty)
        session.adjustOffset(by: 100)
        session.resetOffset()
        for _ in 0..<100 {
            if await repository.saved.count == 2 { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(await repository.saved.map(\.offsetMilliseconds) == [300, 0])
        #expect(session.globalOffsetMilliseconds == -300 && session.effectiveOffsetMilliseconds == -300)
        let resetRevision = session.documentRevision
        session.setGlobalOffset(0)
        #expect(session.documentRevision == resetRevision && session.position == 9.5)
    }

    @Test func globalOffsetSurvivesTrackAndVersionChangesAndDoesNotGivePlainTextATimeline() {
        let session = LyricsSession(repository: OffsetRepository())
        defer { session.stop() }
        session.setGlobalOffset(500)
        for name in ["First", "Second"] {
            session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: name), position: 9.5, isPlaying: false), shouldSearch: false)
            session.use(document, persist: false)
            #expect(session.currentLineIndex == 1 && session.globalOffsetMilliseconds == 500)
            var other = document; other.offsetMilliseconds = -500
            session.use(other, persist: false)
            #expect(session.currentLineIndex == 0)
        }
        session.use(.init(plainText: "Untimed"), persist: false)
        session.setGlobalOffset(1000)
        #expect(session.currentLineIndex == nil && session.document?.isSynced == false)
        session.suppressLyrics()
        #expect(session.globalOffsetMilliseconds == 1000)
    }

    @Test func corruptOffsetsCannotOverflowOrMoveThePlayerClock() {
        let session = LyricsSession(repository: OffsetRepository())
        defer { session.stop() }
        session.setGlobalOffset(.max)
        #expect(session.globalOffsetMilliseconds == 300_000)
        session.use(.init(lines: document.lines, offsetMilliseconds: .max), persist: false)
        #expect(session.effectiveOffsetMilliseconds == .max)
        session.setGlobalOffset(.min)
        #expect(session.globalOffsetMilliseconds == -300_000)
        session.use(.init(lines: document.lines, offsetMilliseconds: .min), persist: false)
        #expect(session.effectiveOffsetMilliseconds == .min)
        #expect(session.position == 0)
    }
}
