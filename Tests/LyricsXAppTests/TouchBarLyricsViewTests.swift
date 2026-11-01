import AppKit
import Testing
import LyricsXCore
@testable import LyricsXApp

@Suite @MainActor struct TouchBarLyricsViewTests {
    @Test func highlightingUsesOffsetAndSeeksWithoutReshaping() {
        let view = TouchBarLyricsView(frame: .init(x: 0, y: 0, width: 500, height: 30))
        let line = LyricLine(id: 0, time: 10, text: "Hello world", words: [
            .init(text: "Hello", start: 10, end: 12), .init(text: "world", start: 12, end: 14),
        ])
        view.update(line: line, text: line.text, position: 10.5, effectiveOffsetMilliseconds: 500, isPlaying: true)
        let halfway = view.currentFrame()
        let first = view.timedSpans.filter { $0.cue.text == "Hello" }
        #expect(abs(halfway.highlights.reduce(0) { $0 + $1.width } - first.reduce(0) { $0 + $1.width } * 0.5) < 0.01)
        #expect(view.requiresAnimation)
        view.update(line: line, text: line.text, position: 11, effectiveOffsetMilliseconds: 0, isPlaying: false)
        #expect(view.currentFrame() == halfway)
        #expect(!view.requiresAnimation)
        view.update(line: line, text: line.text, position: 0, effectiveOffsetMilliseconds: 0, isPlaying: false)
        #expect(view.currentFrame().highlights.isEmpty)
        #expect(view.shapingCount == 1)
    }

    @Test func unicodeRemainsWholeAndUnmatchedTextGetsNoTiming() {
        let text = "光，e\u{301} 👩🏽‍🚀 مرحبا!"
        let line = LyricLine(id: 0, time: 0, text: text, words: [
            .init(text: "光", start: 0, end: 1), .init(text: "e\u{301}", start: 1, end: 2),
            .init(text: "👩🏽‍🚀", start: 2, end: 3), .init(text: "مرحبا", start: 3, end: 4),
        ])
        let view = TouchBarLyricsView(frame: .init(x: 0, y: 0, width: 500, height: 30))
        view.update(line: line, text: text, position: 4, effectiveOffsetMilliseconds: 0, isPlaying: false)
        #expect(view.renderedText == text)
        #expect(Set(view.timedSpans.map(\.cue.text)) == Set(line.words.map(\.text)))
        #expect(view.timedSpans.contains { $0.cue.text == "مرحبا" && $0.rightToLeft })
        #expect(view.currentFrame().highlights.allSatisfy { $0.x.isFinite && $0.width > 0 })
        view.update(line: line, text: "Unrelated replacement", position: 4, effectiveOffsetMilliseconds: 0, isPlaying: true)
        #expect(view.timedSpans.isEmpty)
        #expect(view.currentFrame().highlights.isEmpty)
        view.update(line: nil, text: "No lyrics — Song title", position: 100, effectiveOffsetMilliseconds: 0, isPlaying: true)
        #expect(!view.requiresAnimation)
        #expect(view.currentFrame().highlights.isEmpty)
    }

    @Test func scrollingFollowsRealCuesAndIsBoundedAfterSeeking() {
        let spans = [TouchBarTimedSpan(cue: .init(text: "first", start: 0, end: 2), x: 0, width: 100,
            rightToLeft: false, cueOffset: 0, cueWidth: 100),
            TouchBarTimedSpan(cue: .init(text: "last", start: 2, end: 4), x: 900, width: 100,
            rightToLeft: false, cueOffset: 0, cueWidth: 100)]
        let early = TouchBarLyricFrame(spans: spans, contentWidth: 1000, viewportWidth: 300, time: 0, lineStart: 0)
        let late = TouchBarLyricFrame(spans: spans, contentWidth: 1000, viewportWidth: 300, time: 4, lineStart: 0)
        #expect(early.translation == 0)
        #expect(late.translation == -700)
        let plain = TouchBarLyricFrame(spans: [], contentWidth: 1000, viewportWidth: 300, time: 5, lineStart: 0)
        #expect(plain.translation == -98 && plain.highlights.isEmpty)
        let invalid = TouchBarLyricFrame(spans: spans, contentWidth: 1000, viewportWidth: 0, time: .nan, lineStart: 0)
        #expect(invalid.translation.isFinite)
    }

    @Test func completedWordsAndFullyScrolledLinesStopFrameAnimation() {
        let view = TouchBarLyricsView(frame: .init(x: 0, y: 0, width: 120, height: 30))
        let timed = LyricLine(id: 0, time: 0, text: "A final held word", words: [
            .init(text: "A final held word", start: 2, end: 5),
        ])
        view.update(line: timed, text: timed.text, position: 1, effectiveOffsetMilliseconds: 0, isPlaying: true)
        #expect(view.requiresAnimation)
        view.update(line: timed, text: timed.text, position: 4.5, effectiveOffsetMilliseconds: 500, isPlaying: true)
        #expect(!view.requiresAnimation)
        #expect(!view.currentFrame().highlights.isEmpty)
        // A backward seek must resume the visual clock immediately.
        view.update(line: timed, text: timed.text, position: 3, effectiveOffsetMilliseconds: 0, isPlaying: true)
        #expect(view.requiresAnimation)
        let plain = LyricLine(id: 1, time: 10, text: "A long line without word timestamps keeps its text plain while scrolling")
        view.update(line: plain, text: plain.text, position: 10, effectiveOffsetMilliseconds: 0, isPlaying: true)
        #expect(view.requiresAnimation)
        view.update(line: plain, text: plain.text, position: 1000, effectiveOffsetMilliseconds: 0, isPlaying: true)
        #expect(!view.requiresAnimation)
        #expect(view.currentFrame().highlights.isEmpty)
    }

    @Test func partiallyTimedTailScrollsWithoutInventingHighlights() {
        let view = TouchBarLyricsView(frame: .init(x: 0, y: 0, width: 120, height: 30))
        let text = "First — a very long untagged lyric suffix with e\u{301} and 👩🏽‍🚀 at the end"
        let line = LyricLine(id: 0, time: 0, text: text, words: [.init(text: "First", start: 0, end: 2)])
        view.update(line: line, text: text, position: 2, effectiveOffsetMilliseconds: 0, isPlaying: true)
        let atCueEnd = view.currentFrame()
        #expect(view.requiresAnimation)
        view.update(line: line, text: text, position: 5, effectiveOffsetMilliseconds: 500, isPlaying: true)
        let scrolling = view.currentFrame()
        #expect(scrolling.translation < atCueEnd.translation)
        #expect(scrolling.highlights == atCueEnd.highlights)
        view.update(line: line, text: text, position: 5.5, effectiveOffsetMilliseconds: 0, isPlaying: false)
        #expect(view.currentFrame() == scrolling && !view.requiresAnimation)
        view.update(line: line, text: text, position: 1000, effectiveOffsetMilliseconds: 0, isPlaying: true)
        #expect(abs(view.currentFrame().translation + view.contentWidth - 110) < 0.01)
        #expect(view.currentFrame().highlights == atCueEnd.highlights && !view.requiresAnimation)
        view.update(line: line, text: text, position: 2, effectiveOffsetMilliseconds: 0, isPlaying: true)
        #expect(view.currentFrame() == atCueEnd && view.requiresAnimation)
        #expect(view.shapingCount == 1)
    }

    @Test func rightToLeftTailAndUntimedLinesScrollTowardTheirLogicalEnd() {
        let span = TouchBarTimedSpan(cue: .init(text: "first", start: 0, end: 2), x: 900, width: 100,
            rightToLeft: true, cueOffset: 0, cueWidth: 100)
        let start = TouchBarLyricFrame(spans: [span], contentWidth: 1000, viewportWidth: 300,
            time: 2, lineStart: 0, untimedTailEndX: 0)
        let end = TouchBarLyricFrame(spans: [span], contentWidth: 1000, viewportWidth: 300,
            time: 1000, lineStart: 0, untimedTailEndX: 0)
        #expect(start.translation == -700 && start.hasPendingScroll)
        #expect(end.translation == 0 && !end.hasPendingScroll)
        #expect(start.highlights == end.highlights)
        let view = TouchBarLyricsView(frame: .init(x: 0, y: 0, width: 120, height: 30))
        let line = LyricLine(id: 0, time: 0, text: "مرحبا هذا سطر عربي طويل بدون توقيت للكلمات يجب أن يبدأ من اليمين")
        view.update(line: line, text: line.text, position: 0, effectiveOffsetMilliseconds: 0, isPlaying: true)
        #expect(view.currentFrame().translation < -100)
        view.update(line: line, text: line.text, position: 1000, effectiveOffsetMilliseconds: 0, isPlaying: true)
        #expect(abs(view.currentFrame().translation) < 0.01 && !view.requiresAnimation)
        #expect(view.currentFrame().highlights.isEmpty)
    }

    @Test func nativeRenderingFitsThirtyPointSurface() throws {
        _ = NSApplication.shared
        let view = TouchBarLyricsView(frame: .init(x: 0, y: 0, width: 500, height: 30))
        let line = LyricLine(id: 0, time: 0, text: "让每一句歌词，都在指尖发光", words: [
            .init(text: "让每一句歌词", start: 0, end: 3), .init(text: "都在指尖发光", start: 3, end: 6),
        ])
        view.update(line: line, text: line.text, position: 2, effectiveOffsetMilliseconds: 0, isPlaying: false)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        #expect(bitmap.pixelsWide >= 500 && bitmap.pixelsHigh >= 30)
        var lit = 0, mint = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                let color = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                if color.greenComponent > 0.3 { lit += 1 }
                if color.greenComponent > color.redComponent + 0.2 { mint += 1 }
            }
        }
        #expect(lit > 100 && mint > 30)
        if ProcessInfo.processInfo.environment["LYRICSX_TOUCHBAR_QA"] == "1" {
            let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            let directory = ProcessInfo.processInfo.environment["LYRICSX_TOUCHBAR_QA_OUTPUT"]
                .map { URL(fileURLWithPath: $0, isDirectory: true) }
                ?? root.appendingPathComponent("outputs/touch-bar-2026-11-02", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try #require(bitmap.representation(using: .png, properties: [:])).write(to: directory.appendingPathComponent("touchbar-native-lyrics.png"))
        }
    }
}
