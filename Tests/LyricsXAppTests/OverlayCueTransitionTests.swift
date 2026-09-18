import Foundation
import Testing
import LyricsXCore
@testable import LyricsXApp

@Suite struct OverlayCueTransitionTests {
    private let document = UUID()
    @Test func changingFontCancelsGeometryFromThePreviousFont() {
        let first = cue(0), second = cue(1)
        let initial = OverlayCueTransition().updating(to: first, lyricTime: 2.9, at: 10, animated: true)
        let moving = initial.updating(to: second, lyricTime: 3, at: 10.1, animated: true)
        #expect(moving.departure != nil)
        var replacement = second
        replacement.fontName = "Georgia"
        let changed = moving.updating(to: replacement, lyricTime: 3.05, at: 10.15, animated: true)
        #expect(changed.departure == nil && changed.promotionDistance == nil)
        #expect(!changed.needsFrames(at: 10.15, reduced: false))
    }

    private func cue(_ index: Int, interval: Double = 3, prefix: Bool = false) -> OverlayCueSnapshot {
        let line = LyricLine(id: index, time: Double(index) * interval, text: "Line \(index)")
        return .init(document: document, index: index, line: line, text: line.text,
            plan: .init(start: line.time, duration: min(0.84, interval * 0.8), stablePrefixCount: prefix ? 3 : 0, layoutTail: ""),
            height: 40, fontSize: 26, previewText: "Line \(index + 1)", previewCenter: 90, previewScale: 0.5)
    }

    @Test func departureStartsImmediatelyMovesUpAndEndsEvenWhenPlaybackPauses() throws {
        let first = cue(0), second = cue(1)
        var state = OverlayCueTransition().updating(to: first, lyricTime: 2.9, at: 10, animated: true)
        #expect(state.departure == nil && state.promotionDistance == nil)
        state = state.updating(to: second, lyricTime: 3, at: 10.1, animated: true)
        let exit = try #require(state.departure)
        #expect(state.promotionDistance == 70 && exit.cue == first)
        #expect(exit.frame(at: 10.1)?.opacity == 1)
        let halfway = try #require(exit.frame(at: 10.18))
        #expect(halfway.offset < 0 && halfway.blur > 0 && halfway.opacity < 1)
        #expect(exit.frame(at: 10.261) == nil)
        // Lyric time has stopped, but the layout still reaches its resting pose.
        #expect(state.layoutTime(at: 10.8, fallback: 3) > 3.64)
        #expect(state.needsFrames(at: 10.2, reduced: false))
        #expect(!state.needsFrames(at: 10.8, reduced: false))
        state = state.updating(to: second, lyricTime: 3, at: 10.8, animated: true)
        #expect(state.departure?.startedAt == 10.1) // No deadline restart.
        #expect(state.departure?.frame(at: 10.8) == nil)
    }

    @Test func rapidCuesReplaceOneDepartureAndOldCompletionsCannotRemoveTheNewOne() throws {
        var state = OverlayCueTransition()
        for index in 0..<100 {
            let next = cue(index, interval: 0.08)
            let oldToken = state.departure?.startedAt
            state = state.updating(to: next, lyricTime: next.line.time, at: 10 + next.line.time, animated: true)
            if index > 0 {
                let exit = try #require(state.departure)
                #expect(exit.cue.index == index - 1 && exit.duration < 0.08)
                #expect(exit.frame(at: exit.startedAt + 0.08) == nil)
                if let oldToken { state.finishDeparture(startedAt: oldToken) }
                #expect(state.departure?.cue.index == index - 1)
            }
        }
    }

    @Test func seeksReplacementsHiddenViewsAndPrefixGrowthDoNotInventAnOldRow() {
        let initial = OverlayCueTransition().updating(to: cue(0), lyricTime: 0, at: 0, animated: true)
        #expect(initial.updating(to: cue(5), lyricTime: 15, at: 1, animated: true).departure == nil)
        #expect(initial.updating(to: cue(1), lyricTime: 4, at: 1, animated: true).departure == nil)
        #expect(initial.updating(to: cue(1), lyricTime: 3, at: 1, animated: false).departure == nil)
        #expect(initial.updating(to: cue(1, prefix: true), lyricTime: 3, at: 1, animated: true).departure == nil)
        let otherDocument = OverlayCueTransitionTests().cue(1)
        #expect(initial.updating(to: otherDocument, lyricTime: 3, at: 1, animated: true).departure == nil)
        #expect(OverlayCueTransition().updating(to: cue(1), lyricTime: 3, at: 1, animated: true).promotionDistance == nil)
    }

    @Test func normalArrivalIsGentlerButHighSpeedMotionStillFinishesOnTime() {
        let plan = cue(0).plan
        let first = OverlayMotionFrame.make(time: 0, plan: plan, distance: 70, nextScale: 0.5, reduced: false)
        let early = OverlayMotionFrame.make(time: 0.16, plan: plan, distance: 70, nextScale: 0.5, reduced: false)
        #expect(early.offset > 35 && early.offset < first.offset)
        #expect(OverlayMotionFrame.make(time: 0.64, plan: plan, distance: 70, nextScale: 0.5, reduced: false) == .init())
        let fast = cue(0, interval: 0.08).plan
        #expect(OverlayMotionFrame.make(time: 0.08, plan: fast, distance: 70, nextScale: 0.5, reduced: false) == .init())
    }

    @Test func untranslatedPreviewPromotesAcrossScriptsAndProviderWhitespace() {
        for text in ["  Another night in the city  ", "\u{3000}星の光をたどって\u{3000}",
                     " Une lumière dans la nuit\n", "  별빛을 따라 걸어가 ", "  ضوء في السماء ", "\tСвет над городом "] {
            let line = LyricLine(id: 1, time: 3, text: text)
            let preview = OverlaySecondaryMode.either.content(translation: nil, next: text).next
            let first = OverlayCueSnapshot(document: document, index: 0, line: cue(0).line, text: "First",
                plan: cue(0).plan, height: 40, fontSize: 26, previewText: preview, previewCenter: 90, previewScale: 0.5)
            let next = OverlayCueSnapshot(document: document, index: 1, line: line, text: text,
                plan: cue(1).plan, height: 40, fontSize: 26, previewText: nil, previewCenter: nil, previewScale: 0.5)
            let state = OverlayCueTransition().updating(to: first, lyricTime: 2.9, at: 10, animated: true)
                .updating(to: next, lyricTime: 3.05, at: 10.15, animated: true)
            #expect(state.promotionDistance == 70, "Untranslated preview should promote: \(text)")
        }
    }
}
