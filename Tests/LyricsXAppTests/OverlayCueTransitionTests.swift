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
        #expect(exit.frame(at: 10.341) == nil)
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

    @Test func latePlaybackTicksDoNotSkipThePreviewPositionOrExtendFastCues() throws {
        for interval in [0.08, 0.3, 3.0] {
            let first = cue(0, interval: interval), next = cue(1, interval: interval)
            let delay = min(0.12, interval * 0.3)
            let state = OverlayCueTransition().updating(to: first, lyricTime: 0, at: 10, animated: true)
                .updating(to: next, lyricTime: next.line.time + delay, at: 10 + interval + delay, animated: true)
            let start = 10 + interval + delay
            let initial = OverlayMotionFrame.make(time: state.layoutTime(at: start, fallback: 0),
                plan: state.motionPlan, distance: state.promotionDistance, nextScale: 0.5, reduced: false)
            #expect(initial.offset == 70 && initial.scale == 0.5)
            #expect(!state.needsFrames(at: 10 + interval * 2, reduced: false))
            let repeated = state.updating(to: next, lyricTime: next.line.time + delay + 0.01, at: start + 0.01, animated: true)
            #expect(repeated.layoutTime(at: start + 0.01, fallback: 0) > next.line.time)
            #expect(repeated.motionPlan == state.motionPlan)
        }
    }

    @Test func anInterruptedPromotionDepartsFromItsActualScreenPose() throws {
        let first = cue(0, interval: 0.2), second = cue(1, interval: 0.2), third = cue(2, interval: 0.2)
        let moving = OverlayCueTransition().updating(to: first, lyricTime: 0, at: 10, animated: true)
            .updating(to: second, lyricTime: 0.21, at: 10.21, animated: true)
        let expected = OverlayMotionFrame.make(time: moving.layoutTime(at: 10.24, fallback: 0.4),
            plan: moving.motionPlan, distance: moving.promotionDistance, nextScale: 0.5, reduced: false)
        let interrupted = moving.updating(to: third, lyricTime: 0.4, at: 10.24, animated: true)
        #expect(try #require(interrupted.departure).pose == expected)
    }

    @Test func plainTextKeepsItsSurfaceButWordTimingAndIncrementalTextKeepTheirClock() {
        let plain = cue(0).line
        let settled = cue(0).plan?.withoutEntry(text: plain.text)
        #expect(OverlayInkClock.time(line: plain, text: plain.text, arrival: settled, sampledTime: 0.3) == plain.time)
        #expect(OverlayInkClock.time(line: plain, text: plain.text, arrival: cue(0).plan, sampledTime: 0.3) == 0.3)
        let timed = LyricLine(id: 0, time: 0, text: "Stay", words: [.init(text: "Stay", start: 0, end: 2)])
        #expect(OverlayInkClock.time(line: timed, text: timed.text, arrival: nil, sampledTime: 0.3) == 0.3)
    }

    @Test func arrivalAndDepartureSettleWithoutAnEndVelocityJump() throws {
        let plan = try #require(cue(0).plan)
        let before = OverlayMotionFrame.make(time: 0.6399, plan: plan, distance: 70, nextScale: 0.5, reduced: false)
        #expect(abs(before.offset) / 0.0001 < 0.3)
        #expect(before.blur / 0.0001 < 0.02)
        let state = OverlayCueTransition().updating(to: cue(0), lyricTime: 0, at: 10, animated: true)
            .updating(to: cue(1), lyricTime: 3, at: 13, animated: true)
        let exit = try #require(state.departure)
        let last = try #require(exit.frame(at: 13 + exit.duration - 0.0001))
        #expect(last.opacity / 0.0001 < 0.01)
        #expect(exit.frame(at: 13 + exit.duration + 0.0001) == nil)
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
