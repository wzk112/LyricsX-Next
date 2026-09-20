import Foundation
import SwiftUI
import Testing
import LyricsXCore
import LyricsXServices
@testable import LyricsXApp

@Test func exactPrefixGrowthPreservesOldCharactersAndReservesOnlyItsOwnChain() throws {
    let strings = ["G", "Go", "Go slowly", "Go slowly now", "A new line", "A new line"]
    let lines = strings.enumerated().map { LyricLine(id: $0, time: Double($0) * 0.08, text: $1) }
    let first = try #require(LyricLinePresentation.make(lines: lines, index: 0))
    #expect(first.stablePrefixCount == 0 && "G" + first.layoutTail == "Go slowly now")
    for index in 1...3 {
        let value = try #require(LyricLinePresentation.make(lines: lines, index: index))
        #expect(value.stablePrefixCount == strings[index - 1].count)
        #expect(strings[index] + value.layoutTail == "Go slowly now")
    }
    #expect(LyricLinePresentation.make(lines: lines, index: 4)?.stablePrefixCount == 0)
    #expect(LyricLinePresentation.make(lines: lines, index: 5)?.stablePrefixCount == 0)
}

@Test func incrementalComparisonUsesWholeGraphemesAndDoesNotCrossPauses() throws {
    let lines = [LyricLine(id: 0, time: 0, text: "👩🏽‍🚀光"), .init(id: 1, time: 0.1, text: "👩🏽‍🚀光e\u{301}"),
                 .init(id: 2, time: 4, text: "👩🏽‍🚀光e\u{301}再见"), .init(id: 3, time: 5, text: "")]
    let second = try #require(LyricLinePresentation.make(lines: lines, index: 1))
    #expect(second.stablePrefixCount == 2 && second.layoutTail.isEmpty)
    #expect(LyricLinePresentation.make(lines: lines, index: 2)?.stablePrefixCount == 0)
    #expect(LyricLinePresentation.make(lines: lines, index: 3) == nil)
}

@Test func everyFastLineGetsItsOwnImmediateClockDrivenArrival() throws {
    let lines = (0..<80).map { LyricLine(id: $0, time: Double($0) * 0.08, text: "line \($0)") }
    for index in lines.indices.dropLast() {
        let plan = try #require(LyricLinePresentation.make(lines: lines, index: index))
        let initial = plan.frame(at: lines[index].time + 0.002)
        #expect(initial.offset > 0 && initial.opacity > 0.8 && initial.opacity < 1)
        #expect(initial.blur < 1)
        if index < lines.count - 1 { #expect(plan.frame(at: lines[index + 1].time) == .init()) }
        #expect(plan.frame(at: lines[index].time + 2) == .init())
        // Seeking back re-evaluates the same curve, without another task.
        #expect(plan.frame(at: lines[index].time + 0.002) == initial)
    }
}

@Test func nextRowMovesFromItsOldPositionAndSettlesBeforeTheNextCue() throws {
    let lines = [LyricLine(id: 0, time: 0, text: "First"), .init(id: 1, time: 3, text: "Next"),
                 .init(id: 2, time: 3.1, text: "Next grows"), .init(id: 3, time: 6, text: "Last")]
    let plan = try #require(LyricLinePresentation.make(lines: lines, index: 1))
    let initial = OverlayMotionFrame.make(time: 3, plan: plan, distance: 90, nextScale: 0.5, reduced: false)
    #expect(initial.offset == 90 && initial.scale == 0.5 && initial.opacity == 0.85)
    let intermediate = OverlayMotionFrame.make(time: 3.04, plan: plan, distance: 90, nextScale: 0.5, reduced: false)
    #expect(intermediate.offset < initial.offset && intermediate.scale > initial.scale)
    #expect(OverlayMotionFrame.make(time: 3.1, plan: plan, distance: 90, nextScale: 0.5, reduced: false) == .init())
    let growth = LyricLinePresentation.make(lines: lines, index: 2)
    #expect(OverlayMotionFrame.make(time: 3.11, plan: growth, distance: 90, nextScale: 0.5, reduced: false) == .init())
    #expect(initial.auxiliaryOpacity(top: 84, primaryHeight: 72, reduced: false) == 0)
    #expect(OverlayMotionFrame().auxiliaryOpacity(top: 84, primaryHeight: 72, reduced: false) == 1)
}

@Test func drawingFramesReuseTextMeasurementUntilTheProposalChanges() {
    var cache = LyricSizeCache(), measurements = 0
    for _ in 0..<600 {
        let size = cache.size(proposal: .init(width: 500, height: nil)) {
            measurements += 1
            return CGSize(width: 500, height: 72)
        }
        #expect(size.height == 72)
    }
    #expect(measurements == 1)
    _ = cache.size(proposal: .init(width: 300, height: nil)) { measurements += 1; return .init(width: 300, height: 108) }
    #expect(measurements == 2)
}

@Test func auxiliaryRowsArriveSmoothlyAndFinishBeforeTheNextFastCue() throws {
    for interval in [0.08, 0.2, 3.0] {
        let lines = [LyricLine(id: 0, time: 0, text: "First"), .init(id: 1, time: interval, text: "Next")]
        let plan = try #require(LyricLinePresentation.make(lines: lines, index: 0))
        let duration = min(0.46, plan.duration)
        let first = OverlayAuxiliaryFrame.make(time: 0, plan: plan, changed: true, reduced: false)
        #expect(first.opacity == 0 && first.offset > 0 && first.blur > 0)
        let half = OverlayAuxiliaryFrame.make(time: duration / 2, plan: plan, changed: true, reduced: false)
        #expect(half.opacity > 0 && half.opacity < 1 && abs(half.opacity - 0.5) > 0.1)
        #expect(half.offset < first.offset && half.blur < first.blur)
        #expect(OverlayAuxiliaryFrame.make(time: interval, plan: plan, changed: true, reduced: false) == .init())
        #expect(OverlayAuxiliaryFrame.make(time: 0, plan: plan, changed: false, reduced: false) == .init())
        #expect(OverlayAuxiliaryFrame.make(time: 0, plan: plan, changed: true, reduced: true) == .init())
        let growth = plan.withoutEntry(text: "First")
        #expect(OverlayAuxiliaryFrame.make(time: 0, plan: growth, changed: true, reduced: false) == .init())
    }
}

@Test func promotedRowHasAMovingBlurPulseAndSettlesWithoutLingering() throws {
    let plan = try #require(LyricLinePresentation.make(lines: [.init(id: 0, time: 0, text: "First"), .init(id: 1, time: 3, text: "Next")], index: 0))
    let first = OverlayMotionFrame.make(time: 0, plan: plan, distance: 80, nextScale: 0.5, reduced: false)
    let middle = OverlayMotionFrame.make(time: 0.29, plan: plan, distance: 80, nextScale: 0.5, reduced: false)
    #expect(first.blur == 0.45 && middle.blur > first.blur && middle.blur < 2)
    #expect(abs(middle.offset - 40) > 5 && middle.offset < first.offset)
    #expect(OverlayMotionFrame.make(time: 0.64, plan: plan, distance: 80, nextScale: 0.5, reduced: false) == .init())
    #expect(OverlayMotionFrame.make(time: 0, plan: plan, distance: 80, nextScale: 0.5, reduced: true) == .init())
}

@Test func lyricAndTranslationChangesDoNotRestartTheSongHeaderTransition() {
    let first = OverlayContentIdentity(track: "song", document: UUID(), primary: "First", translation: "第一句", next: "Next")
    var changed = first
    changed.primary = "Next"; changed.translation = "下一句"; changed.next = "Later"
    #expect(first.songScope == changed.songScope)
    changed.document = UUID()
    #expect(first.songScope == changed.songScope)
    changed.track = "another song"
    #expect(first.songScope != changed.songScope)
    changed = first; changed.compact = true
    #expect(first.songScope == changed.songScope)
    let compact = changed.songScope
    changed.primary = "Loading lyrics"
    #expect(compact == changed.songScope)
}

/// Optional local verification: never copies lyric contents or private paths
/// into fixtures, logs, build products or the release.
@Test func localRapidLyricsUseTheProductionParserAndCadence() throws {
    guard let paths = ProcessInfo.processInfo.environment["LYRICSX_LOCAL_TIMELINE_FIXTURES"] else { return }
    for path in paths.components(separatedBy: ":") {
        let document = try LyricsCodec.read(URL(fileURLWithPath: path))
        #expect(document.lines.count > 1)
        let first = document.seekPosition(for: document.lines[0])
        let end = document.seekPosition(for: document.lines.last!) + 1
        func countSeen(adaptive: Bool) -> Int {
            var seen = Set<Int>(), time = first
            while time < end {
                if let index = document.index(at: time) { seen.insert(index) }
                time += adaptive ? LyricTickCadence.milliseconds(playing: true, visible: true, document: document, position: time) / 1_000 : 0.1
            }
            return seen.count
        }
        let old = countSeen(adaptive: false), improved = countSeen(adaptive: true)
        let growing = document.lines.indices.filter {
            (LyricLinePresentation.make(lines: document.lines, index: $0)?.stablePrefixCount ?? 0) > 0
        }.count
        #expect(improved >= old)
        print("Local timing diagnostic: lines=\(document.lines.count), prefix-growth=\(growing), old-visible=\(old), adaptive-visible=\(improved)")
    }
}

@Test func refreshCadenceCatchesFastLineBoundariesAndStillThrottlesHiddenPlayback() {
    let fast = LyricsDocument(title: "Fast", lines: (0..<20).map { .init(id: $0, time: Double($0) * 0.08, text: "\($0)") })
    #expect(LyricTickCadence.milliseconds(playing: true, visible: true, document: fast, position: 0) <= 16)
    #expect(LyricMotion.followResponse(lines: fast.lines, index: 0) < fast.lines[1].time - fast.lines[0].time)
    #expect(LyricTickCadence.milliseconds(playing: true, visible: true, document: fast, position: 0.075) == 8)
    #expect(LyricTickCadence.milliseconds(playing: true, visible: false, document: fast, position: 0) == 250)
    #expect(LyricTickCadence.milliseconds(playing: false, visible: true, document: fast, position: 0) == 500)
    let slow = LyricsDocument(title: "Slow", lines: [.init(id: 0, time: 0, text: "one"), .init(id: 1, time: 5, text: "two")])
    #expect(LyricTickCadence.milliseconds(playing: true, visible: true, document: slow, position: 4.99) < 12)
    #expect(LyricTickCadence.milliseconds(playing: true, visible: true, document: slow, position: 7) == 100)
    #expect(LyricMotion.followResponse(lines: slow.lines, index: 0) == LyricMotion.response)
}

@Test func displayFramesStopDuringLongGapsButWakeBeforeTheNextCue() {
    let line = LyricLine(id: 0, time: 0, text: "Stay here", words: [
        .init(text: "Stay", start: 0, end: 2), .init(text: "here", start: 4, end: 5)
    ])
    #expect(LyricRenderTimelineActivity.needsFrames(line: line, time: 1, arrival: nil))
    #expect(!LyricRenderTimelineActivity.needsFrames(line: line, time: 3, arrival: nil))
    #expect(LyricRenderTimelineActivity.needsFrames(line: line, time: 3.95, arrival: nil))
    #expect(!LyricRenderTimelineActivity.needsFrames(line: line, time: 6, arrival: nil))
}

@Test func interruptedTrackArrivalsRestAndIgnoreObsoleteCompletions() {
    var clock = LyricArrivalClock()
    clock.start(at: 10)
    #expect(clock.frame(at: 10.2).opacity < 1)
    clock.cancel()
    #expect(clock.frame(at: 10.21) == .init() && clock.startedAt == nil)
    clock.start(at: 11)
    let old = clock.finishedToken(at: 12)
    clock.start(at: 12)
    clock.finish(old)
    #expect(clock.startedAt == 12 && clock.frame(at: 12.1).blur > 0)
    clock.finish(clock.finishedToken(at: 13))
    #expect(clock.startedAt == nil && clock.frame(at: 13) == .init())
    // Many quick switches retain only the latest clock; no queued arrivals.
    for index in 0..<100 { clock.start(at: Double(index) * 0.08) }
    #expect(clock.frame(at: 9) == .init())
}

@Test func overlayContentChangesUseBoundedNonlinearBlurWithoutBlurringEachSuffix() {
    let base = OverlayContentIdentity(track: "one", document: UUID(), primary: "Light", translation: "光", next: "Next")
    #expect(OverlayBlurStyle.change(from: base, to: base, incremental: false, lineDuration: 3).radius == 0)
    var changed = base
    for field in 0..<6 {
        changed = base
        switch field {
        case 0: changed.track = "two"
        case 1: changed.document = UUID()
        case 2: changed.primary = "Another line"
        case 3: changed.translation = "新的翻译"
        case 4: changed.next = "A different next line"
        default: changed.compact = true
        }
        let style = OverlayBlurStyle.change(from: base, to: changed, incremental: false, lineDuration: 3)
        #expect(style.radius > 0 && style.radius <= 3 && style.duration <= 0.52)
        #expect(style.blur(elapsed: 0) == style.radius)
        #expect(style.blur(elapsed: style.duration) == 0)
        let half = style.blur(elapsed: style.duration / 2)
        #expect(abs(half - style.radius / 2) > 0.1) // Not a linear fade.
        #expect(style.blur(elapsed: style.duration * 0.1) > half)
        #expect(half > style.blur(elapsed: style.duration * 0.9))
    }
    changed = base; changed.primary = "Light comes alive"
    #expect(OverlayBlurStyle.change(from: base, to: changed, incremental: true, lineDuration: 0.08).radius == 0)
    changed.primary = "A different fast line"
    let fast = OverlayBlurStyle.change(from: base, to: changed, incremental: false, lineDuration: 0.08)
    #expect(fast.duration < 0.08 && fast.radius < 0.5)
    var clock = LyricArrivalClock()
    clock.start(at: 2, duration: fast.duration)
    #expect(clock.finishedToken(at: 2.08) == 2)
}
