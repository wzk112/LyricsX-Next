import AppKit
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
        // Paused playback cannot finish a pose whose wall clock was cleared.
        let pausedPose = OverlayMotionFrame.make(time: changed.layoutTime(at: 50, fallback: 3.05),
            plan: changed.motionPlan, distance: changed.promotionDistance, nextScale: 0.5, reduced: false)
        #expect(pausedPose == .init())
    }

    private func cue(_ index: Int, interval: Double = 3, prefix: Bool = false,
                     height: Double = 40) -> OverlayCueSnapshot {
        let line = LyricLine(id: index, time: Double(index) * interval, text: "Line \(index)")
        return .init(document: document, index: index, line: line, text: line.text,
            plan: .init(start: line.time, duration: min(0.84, interval * 0.8), stablePrefixCount: prefix ? 3 : 0, layoutTail: ""),
            height: height, fontSize: 26, previewText: "Line \(index + 1)", previewCenter: 90, previewScale: 0.5)
    }
    @Test func changingLineSpacingSettlesAnExistingDepartureEvenForSingleRows() throws {
        var first = cue(0)
        first.lineSpacing = 6
        let second = cue(1)
        let moving = OverlayCueTransition().updating(to: first, lyricTime: 2.9, at: 10, animated: true)
            .updating(to: second, lyricTime: 3, at: 10.1, animated: true)
        #expect(try #require(moving.departure).cue.lineSpacing == 6)
        var changed = second
        changed.lineSpacing = 10
        let settled = moving.updating(to: changed, lyricTime: 3.05, at: 10.15, animated: true)
        #expect(settled.departure == nil && settled.promotionDistance == nil)
        #expect(!settled.needsFrames(at: 10.15, reduced: false))
    }

    @Test func departureStartsImmediatelyMovesUpAndEndsEvenWhenPlaybackPauses() throws {
        let first = cue(0), second = cue(1)
        var state = OverlayCueTransition().updating(to: first, lyricTime: 2.9, at: 10, animated: true)
        #expect(state.departure == nil && state.promotionDistance == nil)
        state = state.updating(to: second, lyricTime: 3, at: 10.1, animated: true)
        let exit = try #require(state.departure)
        #expect(state.promotionDistance == 70 && exit.cue == first)
        #expect(abs(exit.duration - 0.20) < 0.0001)
        #expect(exit.frame(at: 10.1)?.opacity == 1)
        let halfway = try #require(exit.frame(at: 10.2))
        #expect(abs(halfway.offset + 1.4) < 0.0001)
        #expect(abs(halfway.blur - 0.35) < 0.0001)
        #expect(abs(halfway.opacity - 0.5) < 0.0001)
        #expect(exit.frame(at: exit.startedAt + exit.duration + 0.0001) == nil)
        // Lyric time has stopped, but the layout still reaches its resting pose.
        #expect(state.layoutTime(at: 10.8, fallback: 3) > 3.64)
        #expect(state.needsFrames(at: 10.2, reduced: false))
        #expect(!state.needsFrames(at: 10.8, reduced: false))
        state = state.updating(to: second, lyricTime: 3, at: 10.8, animated: true)
        #expect(state.departure?.startedAt == 10.1) // No deadline restart.
        #expect(state.departure?.frame(at: 10.8) == nil)
    }

    @Test @MainActor func centeredBlockHeightChangesKeepFirstFrameAtTheOldScreenPosition() throws {
        // The new target canvas is centered in the old-height panel on the
        // first spring frame. Exercise both the fixed and adaptive heights.
        for (oldBlock, newBlock, oldPrimary, newPrimary, previewCenter) in [
            (100.0, 40.0, 40.0, 40.0, 80.0), // next preview disappears
            (140.0, 40.0, 80.0, 40.0, 116.0) // two-line primary to one line
        ] {
            for oldWindow in [200.0, oldBlock + OverlayLyricsWindowLayout.centeredChromeHeight] {
                var old = cue(0, height: oldPrimary)
                old.blockHeight = oldBlock
                old.centered = true
                old = .init(document: old.document, index: old.index, line: old.line, text: old.text,
                    plan: old.plan, height: old.height, fontSize: old.fontSize,
                    previewText: "Line 1", previewCenter: previewCenter,
                    previewScale: old.previewScale, fontName: old.fontName,
                    blockHeight: oldBlock, centered: true)
                var new = cue(1, height: newPrimary)
                new.blockHeight = newBlock
                new.centered = true
                let state = OverlayCueTransition().updating(to: old, lyricTime: 2.9, at: 10, animated: true)
                    .updating(to: new, lyricTime: 3, at: 10.1, animated: true)
                let departure = try #require(state.departure)
                let distance = try #require(state.promotionDistance)
                let oldBlockTop = (oldWindow - oldBlock) / 2
                let newBlockTopAtFirstFrame = (oldWindow - newBlock) / 2
                let oldPreviewY = oldBlockTop + previewCenter
                let incomingY = newBlockTopAtFirstFrame + newPrimary / 2 + distance
                let oldPrimaryY = oldBlockTop + oldPrimary / 2
                let departingY = newBlockTopAtFirstFrame + oldPrimary / 2 + departure.originShift
                #expect(abs(incomingY - oldPreviewY) < 0.001)
                #expect(abs(departingY - oldPrimaryY) < 0.001)
                #expect(departure.originShift == (newBlock - oldBlock) / 2)
            }
        }
    }

    @Test func departureDistanceAndBlurRemainSubtleForShortAndTallLines() throws {
        for (height, expectedDistance) in [(10.0, 2.0), (40.0, 2.8), (100.0, 4.0)] {
            let exit = OverlayCueDeparture(cue: cue(0, height: height), time: 3,
                startedAt: 10, duration: 0.2, pose: .init())
            let nearEnd = try #require(exit.frame(at: 10.199))
            #expect(nearEnd.offset < 0)
            #expect(abs(nearEnd.offset) <= expectedDistance)
            #expect(abs(nearEnd.offset) > expectedDistance * 0.99)
            #expect(nearEnd.blur > 0 && nearEnd.blur < 0.7)
            #expect(exit.frame(at: exit.startedAt + exit.duration + 0.0001) == nil)
        }
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
                #expect(abs(exit.duration - 0.0288) < 0.0001)
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

@Suite(.enabled(if: ProcessInfo.processInfo.environment["LYRICSX_CUE_DEPARTURE_QA"] == "1"))
@MainActor struct OverlayCueDepartureVisualQA {
    private struct Repository: LyricsRepository {
        func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> {
            .init { $0.finish() }
        }
        func save(_ document: LyricsDocument, for track: Track) async throws {}
    }

    @Test func captureActualOverlayControllerAcrossCueBoundary() async throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: "/tmp/lyricsx-cue-departure-qa", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "LyricsXCueDepartureQA-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlayVisible = true
        prefs.hideWhenPaused = false
        prefs.hideOverlayOnHover = false
        prefs.overlayWidth = 620
        prefs.overlayAppearance = .glass
        prefs.overlayTheme = .dark
        prefs.overlaySecondaryMode = .next
        prefs.reduceMotion = false
        let model = AppModel(repository: Repository(), preferences: prefs)
        let track = Track(playerID: "cue.qa", playerName: "Fixture", title: "Cue transition")
        model.session.accept(.init(track: track, position: 2.85, isPlaying: false), shouldSearch: false)
        model.session.use(LyricsDocument(lines: [
            .init(id: 0, time: 0, text: "Hold this light"),
            .init(id: 1, time: 3, text: "Let it go"),
            .init(id: 2, time: 6, text: "A softer next line")
        ]), persist: false)
        let overlay = OverlayController(model: model, frameAutosaveName: nil,
            pointerLocation: { NSPoint(x: -10000, y: -10000) })
        defer { overlay.stop(); model.stop() }
        overlay.panel.orderFrontRegardless()
        try await Task.sleep(for: .milliseconds(700))
        let root = try #require(overlay.panel.contentView)
        func capture(_ name: String) throws {
            root.layoutSubtreeIfNeeded()
            let bitmap = try #require(root.bitmapImageRepForCachingDisplay(in: root.bounds))
            root.cacheDisplay(in: root.bounds, to: bitmap)
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: directory.appendingPathComponent(name + ".png"))
        }
        try capture("before")
        model.session.seek(to: 3)
        #expect(model.session.currentLineIndex == 1)
        for (name, delay) in [("20ms", 20), ("60ms", 40), ("120ms", 60), ("220ms", 100)] {
            try await Task.sleep(for: .milliseconds(delay))
            try capture(name)
        }
    }
}
