import Testing
import Foundation
import LyricsXCore
@testable import LyricsXApp

@MainActor struct MainLyricScrollMotionTests {
    private let lines = (0..<30).map { LyricLine(id: $0, time: Double($0) * 2, text: "Line \($0)") }

    @Test func sequentialCuesAnimateOnceButSeeksDoNotSweepThroughHiddenRows() {
        var state = MainLyricFollowState()
        #expect(state.request(index: nil, lines: lines, animated: true)?.duration == nil)
        #expect(state.request(index: 0, lines: lines, animated: true)?.duration == nil)
        #expect(state.request(index: 1, lines: lines, animated: true)?.duration != nil)
        #expect(state.request(index: 1, lines: lines, animated: true) == nil)
        let seek = state.request(index: 20, lines: lines, animated: true)
        #expect(seek?.index == 20 && seek?.duration == nil)
        #expect(state.request(index: 21, lines: lines, animated: true)?.duration != nil)
        #expect(state.request(index: 2, lines: lines, animated: true)?.duration == nil)
    }

    @Test func visibilityAndBrowsingReturnCancelOldScrollWithoutQueuingAnother() {
        var state = MainLyricFollowState()
        _ = state.request(index: 5, lines: lines, animated: false)
        _ = state.request(index: 6, lines: lines, animated: true)
        let returned = state.request(index: 6, lines: lines, animated: true, force: true)
        #expect(returned?.index == 6 && returned?.duration == nil)
        #expect(state.request(index: 6, lines: lines, animated: true) == nil)
        #expect(state.request(index: 6, lines: lines, animated: true, force: true, returning: true)?.duration == 0.36)
        #expect(state.request(index: 6, lines: lines, animated: false, force: true, returning: true)?.duration == nil)
    }

    @Test func searchPreviewFollowsShortCuesCapsLongCuesAndResetsForAnotherDocument() {
        let lines = [0.0, 0.1, 0.2, 5, 6, 7, 8, 9, 10].enumerated().map {
            LyricLine(id: $0.offset, time: $0.element, text: "Line \($0.offset)")
        }
        let first = LyricsDocument(lines: lines)
        var state = SearchLyricFollowState()
        #expect(state.request(document: first, index: 0, reduced: false)?.duration == nil)
        let short = state.request(document: first, index: 1, reduced: false)
        #expect(short?.duration != nil && short!.duration! < 0.1)
        #expect(state.request(document: first, index: 2, reduced: false)?.duration == 0.35)
        #expect(state.request(document: first, index: 8, reduced: false)?.duration == nil)
        var second = first; second.id = UUID()
        let switched = state.request(document: second, index: 8, reduced: false)
        #expect(switched?.index == 8 && switched?.duration == nil)
        #expect(state.request(document: second, index: 7, reduced: true)?.duration == nil)
    }

    @Test func onlyNearbyRowsChangeVisualStateOnTheNextCue() {
        let changed = (0..<300).filter {
            MainLyricRowAppearance(index: $0, current: 100, browsing: false, reduced: false)
                != MainLyricRowAppearance(index: $0, current: 101, browsing: false, reduced: false)
        }
        #expect(changed.count <= 6)
        #expect(changed.contains(100) && changed.contains(101))
        #expect(MainLyricRowAppearance(index: 0, current: nil, browsing: false, reduced: false).active == false)
    }
}
