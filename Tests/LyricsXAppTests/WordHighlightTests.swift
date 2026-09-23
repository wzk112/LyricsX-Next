import AppKit
import CoreImage
import SwiftUI
import Testing
import LyricsXCore
@testable import LyricsXApp

@Test func heldNotesEmphasizeTheWholeCueAnywhereInTheLine() {
    let held = WordCue(text: "Stay", start: 2, end: 5)
    let middle = LyricEmphasisFrame(cue: held, time: 3.6, options: .init())
    #expect(middle.glow > 0.5 && middle.scale > 1.04 && middle.scale < 1.08)
    #expect(LyricEmphasisFrame(cue: held, time: 1, options: .init()).scale >= 0.98)
    for time in [1.0, 2.0, 5.0, 8.0] {
        #expect(LyricEmphasisFrame(cue: held, time: time, options: .init()).glow == 0)
    }
    let fast = WordCue(text: "字", start: 2, end: 2.2)
    #expect(LyricEmphasisFrame(cue: fast, time: 2.1, options: .init()).glow == 0)
    #expect(LyricEmphasisFrame(cue: .init(text: "slow", start: 0, end: 1), time: 0.55, options: .init()).glow > 0.3)
    let instant = WordCue(text: "!", start: 2, end: 2)
    let instantaneous = LyricEmphasisFrame(cue: instant, time: 2, options: .init())
    #expect(instantaneous.progress == 1 && instantaneous.scale == 1 && instantaneous.glow == 0)
    // A seek directly to the past or future is determined solely by the cue.
    #expect(middle == LyricEmphasisFrame(cue: held, time: 3.6, options: .init()))
}

@Test func wordEffectsRespectIndependentSwitchesAndReduceMotion() {
    let word = WordCue(text: "光", start: 0, end: 3)
    let staticStyle = LyricEmphasisFrame(cue: word, time: 1.5, options: .init(lift: false, glow: false, hdr: true))
    #expect(staticStyle.scale == 1 && staticStyle.lift == 0 && staticStyle.glow == 0 && staticStyle.progress == 0.5)
    let reduced = LyricEmphasisFrame(cue: word, time: 1.5, options: .init(hdr: true, reduced: true))
    #expect(reduced == staticStyle)
    #expect(!LyricEmphasisOptions(glow: false, hdr: true).usesHDR)
    #expect(!LyricEmphasisOptions(hdr: true, reduced: true).usesHDR)
    #expect(LyricEmphasisOptions(hdr: true).usesHDR)
}

@Test func wrappedWordsRevealOnceAcrossAllVisualRuns() {
    #expect(LyricEmphasisFrame.reveal(progress: 0.5, offset: 0, width: 60, total: 100) == 5.0 / 6)
    #expect(LyricEmphasisFrame.reveal(progress: 0.5, offset: 60, width: 40, total: 100) == 0)
    #expect(LyricEmphasisFrame.reveal(progress: 0.8, offset: 60, width: 40, total: 100) == 0.5)
}

@Test func lyricFragmentsPreserveGraphemesPunctuationAndRepeatedWords() {
    let text = "光，光 e\u{301} 👩🏽‍🚀 stay stay!"
    let words = [WordCue(text: "光", start: 0, end: 0.4), .init(text: "光", start: 0.4, end: 2.5),
                 .init(text: "e\u{301}", start: 2.5, end: 3), .init(text: "👩🏽‍🚀", start: 3, end: 4),
                 .init(text: "stay", start: 4, end: 4.5), .init(text: "stay", start: 4.5, end: 7)]
    let line = LyricLine(id: 0, time: 0, text: text, words: words)
    let fragments = TimedLyricFragment.make(line: line, text: text)
    #expect(fragments.map(\.text).joined() == text)
    #expect(fragments.compactMap(\.cue) == words)
    #expect(TimedLyricFragment.make(line: line, text: "另一种显示").allSatisfy { $0.cue == nil })
    let plain = LyricLine(id: 0, time: 0, text: "普通行级歌词")
    #expect(TimedLyricFragment.make(line: plain, text: plain.text).allSatisfy { $0.cue == nil })
}

@Suite @MainActor struct WordHighlightRenderingTests {
    @Test func effectsPreferencesDefaultToAutomaticHDRAndKeepExplicitOptOut() throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        #expect(prefs.lyricWordLift && prefs.lyricGlow && prefs.lyricHDR)
        prefs.lyricHDR = false
        #expect(!Preferences(defaults: defaults).lyricHDR)
        prefs.lyricWordLift = false; prefs.lyricGlow = false; prefs.lyricHDR = true; prefs.lyricHDRBrightness = 3.2
        let restored = Preferences(defaults: defaults)
        #expect(!restored.lyricWordLift && !restored.lyricGlow && restored.lyricHDR)
        #expect(!restored.lyricEmphasis.usesHDR && restored.lyricHDRBrightness == 3.2)
    }

    @Test func nativeTextRendererKeepsLayoutAndAddsVisibleBloom() throws {
        let plain = try render(time: 1.6, effects: .init(lift: false, glow: false))
        let bloom = try render(time: 1.6, effects: .init(lift: false, glow: true))
        let before = try render(time: 0, effects: .init())
        let after = try render(time: 4, effects: .init())
        #expect(plain.width == bloom.width && before.width == after.width)
        #expect(plain.height == bloom.height && before.height == after.height)
        #expect(try energy(bloom) > energy(plain) * 1.10)
        if let directory = ProcessInfo.processInfo.environment["LYRICSX_GLOW_QA"] {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            for (name, image) in [("ordinary", plain), ("sdr-glow", bloom)] {
                let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name + ".png"))
            }
            for width in [500.0, 680.0] {
                for scheme in [ColorScheme.light, .dark] {
                    let preview = LyricGlowPicker(enabled: .constant(true))
                        .frame(width: width).background(.background).environment(\.colorScheme, scheme)
                    let renderer = ImageRenderer(content: preview); renderer.scale = 2
                    let image = try #require(renderer.cgImage)
                    let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
                    try data.write(to: URL(fileURLWithPath: directory)
                        .appendingPathComponent("picker-\(Int(width))-\(scheme).png"))
                }
            }
        }
        #expect(try energy(after) > energy(before) * 1.5)
    }

    @Test func hdrInkCarriesExtendedRangeAndDefaultStaysSDR() {
        let resolved = HeldNoteRenderer.hdrWhite(brightness: 1.6).resolveHDR(in: EnvironmentValues())
        #expect(resolved.linearRed > 1.5 && resolved.headroom == 1.6)
        #expect(!LyricEmphasisOptions().usesHDR)
    }

    @Test func compactOverlayHaloReducesBloomWithoutRemovingHDRInk() throws {
        let full = try render(time: 1.6, effects: .init(lift: false, hdr: true, hdrBrightness: 3))
        let compact = try render(time: 1.6, effects: .init(lift: false, hdr: true, hdrBrightness: 3, compactHalo: true))
        let ordinary = try render(time: 1.6, effects: .init(lift: false))
        #expect(compact.width == full.width && compact.height == full.height)
        #expect(try energy(compact) < energy(full))
        #expect(try energy(compact) > energy(ordinary))
    }

    @Test func hdrRenderingProducesExtendedBrightnessOnlyWhenEnabled() throws {
        let sdr = try render(time: 1.6, effects: .init(lift: false, glow: true))
        let hdr = try render(time: 1.6, effects: .init(lift: false, glow: true, hdr: true))
        func peak(_ image: CGImage) -> Float {
            let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
            let context = CIContext(options: [.workingColorSpace: space, .outputColorSpace: space])
            var pixels = [Float](repeating: 0, count: image.width * image.height * 4)
            pixels.withUnsafeMutableBytes { buffer in
                context.render(CIImage(cgImage: image), toBitmap: buffer.baseAddress!, rowBytes: image.width * 16,
                               bounds: CGRect(x: 0, y: 0, width: image.width, height: image.height), format: .RGBAf, colorSpace: space)
            }
            return stride(from: 0, to: pixels.count, by: 4).map { pixels[$0] }.max() ?? 0
        }
        let colored = try render(time: 1.6, effects: .init(lift: false, glow: true, hdr: true, hdrBrightness: 3.5),
            wordColors: .init(sung: LyricTypography.color("00F1FF"), unsung: .gray, plain: .white))
        // The blue channel of cyan should still exceed SDR white.
        let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        var values = [Float](repeating: 0, count: colored.width * colored.height * 4)
        let ci = CIContext(options: [.workingColorSpace: colorSpace, .outputColorSpace: colorSpace])
        values.withUnsafeMutableBytes { ci.render(CIImage(cgImage: colored), toBitmap: $0.baseAddress!, rowBytes: colored.width * 16,
            bounds: CGRect(x: 0, y: 0, width: colored.width, height: colored.height), format: .RGBAf, colorSpace: colorSpace) }
        let bluePeak = stride(from: 2, to: values.count, by: 4).map { values[$0] }.max() ?? 0
        print("Cyan HDR peak: \(bluePeak)")
        #expect(bluePeak > 1.1)
        let sdrPeak = peak(sdr), hdrPeak = peak(hdr)
        print("Rendered lyric luminance: SDR=\(sdrPeak), HDR=\(hdrPeak)")
        #expect(sdrPeak <= 1.01)
        #expect(hdrPeak > 1.1)
        let unsupported = try render(time: 1.6, effects: .init(lift: false, glow: true, hdr: true), hdrSupported: false)
        #expect(peak(unsupported) <= 1.01)
        #expect(abs(try energy(unsupported) - energy(sdr)) < 0.01)
        let limited = try render(time: 1.6, effects: .init(lift: false, glow: true, hdr: true, hdrBrightness: 3.2), hdrHeadroom: 1.2)
        #expect(peak(limited) > 1 && peak(limited) <= 1.21)
        let boosted = try render(time: 1.6, effects: .init(lift: false, glow: true, hdr: true, hdrBrightness: 3.2))
        #expect(peak(boosted) > hdrPeak * 1.4)
    }

    @Test func incrementalLayoutKeepsExistingInkStillAndFutureTextInvisible() throws {
        let lines = ["光", "光慢", "光慢亮"].enumerated().map {
            LyricLine(id: $0, time: Double($0) * 0.08, text: $1)
        }
        func columns(_ index: Int) throws -> [Double] {
            let line = lines[index]
            let plan = try #require(LyricLinePresentation.make(lines: lines, index: index))
            let view = WordHighlight(line: line, time: 1, active: true, text: line.text,
                                     effects: .init(lift: false, glow: false), arrival: plan.withoutEntry(text: line.text))
                .font(.system(size: 38)).foregroundStyle(.white)
                .frame(width: 350, height: 130).background(.black).environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            let image = try #require(renderer.cgImage)
            let bitmap = NSBitmapImageRep(cgImage: image)
            return (0..<image.width).map { x in
                (0..<image.height).reduce(0) { $0 + (bitmap.colorAt(x: x, y: $1)?.redComponent ?? 0) }
            }
        }
        let first = try columns(0), second = try columns(1), full = try columns(2)
        let left = try #require(first.firstIndex(where: { $0 > 0.2 }))
        let right = try #require(first.lastIndex(where: { $0 > 0.2 }))
        #expect(second.firstIndex(where: { $0 > 0.2 }) == left)
        #expect(full.firstIndex(where: { $0 > 0.2 }) == left)
        for x in left...right {
            #expect(abs(first[x] - second[x]) < 0.1)
            #expect(abs(first[x] - full[x]) < 0.1)
        }
        #expect(second.reduce(0, +) > first.reduce(0, +) * 1.4)
        #expect(full.reduce(0, +) > second.reduce(0, +) * 1.2)
    }

    @Test func customRendererAlignsWithNativeTextOnOneAndTwoLines() throws {
        for text in ["让光停留在这一刻", "让光停留在这一刻\n慢慢亮起来"] {
            func ink(custom: Bool) throws -> CGRect {
                let view = Group {
                    if custom {
                        WordHighlight(line: .init(id: 0, time: 0, text: text), time: 5, active: true,
                                      text: text, effects: .init(lift: false, glow: false))
                    } else { Text(text) }
                }.font(.system(size: 28)).multilineTextAlignment(.center).foregroundStyle(.white)
                    .frame(width: 350, height: 160).background(.black).environment(\.colorScheme, .dark)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 1
                let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
                var left = 350, right = 0, top = 160, bottom = 0
                for y in 0..<160 {
                    for x in 0..<350 where (bitmap.colorAt(x: x, y: y)?.redComponent ?? 0) > 0.2 {
                        left = min(left, x); right = max(right, x); top = min(top, y); bottom = max(bottom, y)
                    }
                }
                return CGRect(x: left, y: top, width: right - left, height: bottom - top)
            }
            let plain = try ink(custom: false), custom = try ink(custom: true)
            print("Native ink=\(plain), rendered ink=\(custom)")
            #expect(abs(plain.midX - custom.midX) <= 1)
            #expect(abs(plain.midY - custom.midY) <= 1)
        }
    }

    @Test func activeTextKeepsOriginInMainAndOverlayAlignments() throws {
        for alignment in [TextAlignment.leading, .center] {
            for direction in [LayoutDirection.leftToRight, .rightToLeft] {
                for text in ["大願成就 コンコン", "A longer sentence that wraps naturally onto another line and stays aligned"] {
                    func bounds(custom: Bool) throws -> CGRect {
                        let view = Group {
                            if custom {
                                WordHighlight(line: .init(id: 0, time: 0, text: text, words: [.init(text: text, start: 0, end: 1)]), time: 5, active: true,
                                text: text, effects: .init(lift: false, glow: false))
                            } else { Text(text) }
                        }.font(.system(size: 30, weight: .bold)).tracking(-0.4)
                        .multilineTextAlignment(alignment)
                        .fixedSize(horizontal: false, vertical: true).foregroundStyle(.white)
                        .frame(width: 350, alignment: .leading).padding(30).background(.black).environment(\.colorScheme, .dark)
                        .environment(\.layoutDirection, direction)
                        let renderer = ImageRenderer(content: view); renderer.scale = 1
                        let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
                        var left = bitmap.pixelsWide, right = 0, top = bitmap.pixelsHigh, bottom = 0
                        for y in 0..<bitmap.pixelsHigh {
                            for x in 0..<bitmap.pixelsWide where (bitmap.colorAt(x: x, y: y)?.redComponent ?? 0) > 0.3 {
                                left = min(left, x); right = max(right, x); top = min(top, y); bottom = max(bottom, y)
                            }
                        }
                        return .init(x: left, y: top, width: right-left, height: bottom-top)
                    }
                    let native = try bounds(custom: false), active = try bounds(custom: true)
                    print("Alignment \(alignment) \(direction): native=\(native), active=\(active)")
                    #expect(abs(native.minX - active.minX) <= 1)
                    #expect(abs(native.minY - active.minY) <= 1 && abs(native.height - active.height) <= 1)
                }
            }
        }
    }


    @Test func twoPrimaryLinesLeaveSeparateSpaceForTranslationAndNext() throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlaySecondaryMode = .both
        prefs.lyricGlow = false; prefs.lyricWordLift = false
        let doc = LyricsDocument(lines: [.init(id: 0, time: 0, text: "MMMM\nMMMM", translation: "MMMM"),
                                         .init(id: 1, time: 10, text: "MMMM")])
        for (width, font) in [(320.0, 26.0), (620.0, 44.0), (1000.0, 32.0)] {
            prefs.fontSize = font
            let height = OverlayLayoutMetrics.height(preferences: prefs) - OverlayLayoutMetrics.chromeHeight
            let view = OverlayLyricsContent(preferences: prefs, document: doc, index: 0, lyricTime: { 5 })
                .frame(width: width - 60, height: height).background(.black).environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
            var bands: [ClosedRange<Int>] = [], begin: Int?
            for y in 0...bitmap.pixelsHigh {
                let ink = y < bitmap.pixelsHigh && (0..<bitmap.pixelsWide).contains {
                    (bitmap.colorAt(x: $0, y: y)?.redComponent ?? 0) > 0.25
                }
                if ink, begin == nil { begin = y }
                if !ink, let start = begin { bands.append(start...(y - 1)); begin = nil }
            }
            #expect(bands.count == 4)
            if bands.count == 4 {
                #expect(bands[2].lowerBound - bands[1].upperBound >= 7)
                #expect(bands[3].lowerBound - bands[2].upperBound >= 5)
            }
        }
    }

    @Test func promotionKeepsThePreviewPixelsWhileThePreviousLineBeginsItsDeparture() throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlaySecondaryMode = .next; prefs.fontSize = 28; prefs.nextLineFontSize = 14
        let doc = LyricsDocument(lines: [.init(id: 0, time: 0, text: "FIRST WORD"),
            .init(id: 1, time: 3, text: "SECOND WORD"), .init(id: 2, time: 6, text: "THIRD WORD")])
        func render(index: Int, time: Double) throws -> NSBitmapImageRep {
            let height = OverlayLayoutMetrics.height(preferences: prefs) - OverlayLayoutMetrics.chromeHeight
            let old = OverlayCueSnapshot(document: doc.id, index: 0, line: doc.lines[0], text: doc.lines[0].text,
                plan: LyricLinePresentation.make(lines: doc.lines, index: 0), height: 80, fontSize: 28,
                previewText: doc.lines[1].text, previewCenter: 80 + prefs.overlayPrimarySpacing + 20, previewScale: 0.5)
            let history = index == 0 ? OverlayCueTransition() : OverlayCueTransition().updating(to: old, lyricTime: 2.99, at: 99.99, animated: true)
            let view = OverlayLyricsContent(preferences: prefs, document: doc, index: index, lyricTime: { time },
                animationTime: { 100 }, transition: history)
                .frame(width: 500, height: height).background(.black).environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: view); renderer.scale = 1
            return NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
        }
        let before = try render(index: 0, time: 2.99), after = try render(index: 1, time: 3.12)
        var oldInk = 0.0, remainingOldInk = 0.0, nextDifference = 0.0
        for y in 0..<before.pixelsHigh {
            for x in 0..<before.pixelsWide {
                let a = before.colorAt(x: x, y: y)?.redComponent ?? 0
                let b = after.colorAt(x: x, y: y)?.redComponent ?? 0
                if y < 80 { oldInk += a; remainingOldInk += b }
                else { nextDifference += abs(a - b) }
            }
        }
        #expect(oldInk > 100 && abs(oldInk - remainingOldInk) < 1)
        #expect(nextDifference < 1)
    }

    @Test func fullAdaptiveCardFitsDoubleRowsAndKeepsBottomBreathingRoom() throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlayAdaptiveSize = true; prefs.overlaySecondaryMode = .both
        prefs.lyricGlow = false; prefs.lyricWordLift = false
        let model = AppModel(repository: RenderingFixtureRepository(), preferences: prefs)
        defer { model.stop() }
        model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "HEADER"), position: 2, isPlaying: false), shouldSearch: false)
        let doc = LyricsDocument(lines: [.init(id: 0, time: 0, text: "MMMM\nMMMM", translation: "MMMM\nMMMM"),
                                         .init(id: 1, time: 10, text: "MMMM\nMMMM")])
        model.session.use(doc, persist: false)
        for (width, font) in [(320.0, 26.0), (620.0, 42.0), (1000.0, 32.0)] {
            prefs.overlayWidth = width; prefs.fontSize = font
            let height = OverlayTextMeasure.height(document: doc, index: 0, preferences: prefs, maximumWidth: width)
            let view = OverlayView(model: model, viewport: .init(width: width))
                .frame(width: width, height: height).background(.black).environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: view); renderer.scale = 1
            let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
            var bands: [ClosedRange<Int>] = [], begin: Int?
            for y in 0...bitmap.pixelsHigh {
                let ink = y < bitmap.pixelsHigh && (0..<bitmap.pixelsWide).contains {
                    (bitmap.colorAt(x: $0, y: y)?.redComponent ?? 0) > 0.3
                }
                if ink, begin == nil { begin = y }
                if !ink, let start = begin { bands.append(start...(y - 1)); begin = nil }
            }
            print("Full overlay \(width) x \(height): ink bands=\(bands)")
            #expect(bands.count == 7) // Header, two primary, two translation, two next.
            let last = try #require(bands.last)
            #expect(bitmap.pixelsHigh - last.upperBound >= 20)
            if bands.count == 7 {
                #expect(bands[3].lowerBound - bands[2].upperBound >= 7)
                #expect(bands[5].lowerBound - bands[4].upperBound >= 5)
            }
        }
    }

    @Test func adaptiveOneToTwoLinePromotionPreservesPreviewPixels() throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlaySecondaryMode = .next; prefs.fontSize = 28; prefs.nextLineFontSize = 14
        let doc = LyricsDocument(lines: [.init(id: 0, time: 0, text: "FIRST WORD"),
            .init(id: 1, time: 3, text: "SECOND\nWORD"), .init(id: 2, time: 6, text: "THIRD WORD")])
        func render(index: Int, time: Double) throws -> NSBitmapImageRep {
            let old = OverlayCueSnapshot(document: doc.id, index: 0, line: doc.lines[0], text: doc.lines[0].text,
                plan: LyricLinePresentation.make(lines: doc.lines, index: 0), height: 40, fontSize: 28,
                previewText: doc.lines[1].text, previewCenter: 40 + prefs.overlayPrimarySpacing + 20, previewScale: 0.5)
            let history = index == 0 ? OverlayCueTransition() : OverlayCueTransition().updating(to: old, lyricTime: 2.99, at: 99.99, animated: true)
            let view = OverlayLyricsContent(preferences: prefs, document: doc, index: index,
                lyricTime: { time }, adaptiveCanvasWidth: 500, animationTime: { 100 }, transition: history)
                .frame(width: 500).frame(height: 240, alignment: .top).background(.black).environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: view); renderer.scale = 1
            return NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
        }
        let before = try render(index: 0, time: 2.99), after = try render(index: 1, time: 3.12)
        var oldInk = 0.0, oldRemaining = 0.0, nextDifference = 0.0
        for y in 0..<before.pixelsHigh {
            for x in 0..<before.pixelsWide {
                let a = before.colorAt(x: x, y: y)?.redComponent ?? 0
                let b = after.colorAt(x: x, y: y)?.redComponent ?? 0
                if y < 40 { oldInk += a; oldRemaining += b }
                else { nextDifference += abs(a - b) }
            }
        }
        #expect(oldInk > 100 && abs(oldInk - oldRemaining) < 1)
        #expect(nextDifference < 1)
    }

    @Test func characterAnimationStartsWithoutChangingTheRestingTextAnchor() throws {
        let before = NSBitmapImageRep(cgImage: try render(time: 0.1 - 0.00001, effects: .init(glow: false)))
        let after = NSBitmapImageRep(cgImage: try render(time: 0.1 + 0.00001, effects: .init(glow: false)))
        var difference = 0.0, beforeInk = 0.0, afterInk = 0.0, beforeX = 0.0, afterX = 0.0
        for y in 0..<before.pixelsHigh {
            for x in 0..<before.pixelsWide {
                let a = before.colorAt(x: x, y: y)?.redComponent ?? 0
                let b = after.colorAt(x: x, y: y)?.redComponent ?? 0
                difference += abs(a - b)
                beforeInk += a; afterInk += b; beforeX += a * Double(x); afterX += b * Double(x)
            }
        }
        // Native run/slice antialiasing can differ slightly; the visual origin
        // must stay within 0.03 pixels and changed ink within 1.5 percent.
        #expect(abs(beforeX / beforeInk - afterX / afterInk) < 0.03)
        #expect(difference / beforeInk < 0.015)

    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LYRICSX_GLOW_MOTION_QA"] != nil))
    func renderSmoothCharacterMotionPreview() throws {
        let directory = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["LYRICSX_GLOW_MOTION_QA"]))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for frame in 0..<270 {
            let image = try render(time: Double(frame) / 60, effects: .init(), hdrSupported: false)
            let bitmap = NSBitmapImageRep(cgImage: image)
            let data = try #require(bitmap.representation(using: .png, properties: [:]))
            try data.write(to: directory.appendingPathComponent(String(format: "%04d.png", frame)))
        }
    }

    @Test func darkGlassInkKeepsTheKaraokeWipeAndSeparateHalo() throws {
        let palette = LyricTypography(primaryHex: "000000").adaptedForGlass(dark: false)
        let words = try #require(palette.wordColors)
        let plainEffects = LyricEmphasisOptions(lift: false, glow: false)
        let before = try render(time: 0, effects: plainEffects, wordColors: words, background: .white)
        let plain = try render(time: 1.6, effects: plainEffects, wordColors: words, background: .white)
        let after = try render(time: 4, effects: plainEffects, wordColors: words, background: .white)
        let coverage = NSBitmapImageRep(cgImage: try render(time: 1.6, effects: plainEffects,
            wordColors: words, background: .clear))
        #expect(try energy(before) > energy(plain))
        #expect(try energy(plain) > energy(after))
        for hdr in [false, true] {
            let glow = try render(time: 1.6, effects: .init(lift: false, glow: true, hdr: hdr),
                                  wordColors: words, background: .white)
            let a = NSBitmapImageRep(cgImage: plain), b = NSBitmapImageRep(cgImage: glow)
            var darkCore = 0, changedHalo = 0, washedCore = 0
            for y in 0..<a.pixelsHigh {
                for x in 0..<a.pixelsWide {
                    let p = a.colorAt(x: x, y: y)?.redComponent ?? 1
                    let q = b.colorAt(x: x, y: y)?.redComponent ?? 1
                    if p < 0.025 && q < 0.035 { darkCore += 1 }
                    if p < 0.025 && (coverage.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.999 && q - p > 0.01 { washedCore += 1 }
                    if p > 0.995 && abs(q - p) > 0.004 { changedHalo += 1 }
                }
            }
            #expect(darkCore > 60, "The glow must not wash out the black glyph core")
            #expect(washedCore == 0)
            #expect(changedHalo > 30, "The halo must extend beyond the glyph")
            if let directory = ProcessInfo.processInfo.environment["LYRICSX_GLOW_QA"] {
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                let data = try #require(b.representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("dark-ink-\(hdr ? "edr" : "sdr").png"))
            }
        }
    }

    @Test func lightGlassHDRHaloExceedsWhiteWithoutBrighteningTheDarkGlyphCore() throws {
        for seed in ["000000", "FFFFFF", "F03868", "1020C0"] {
            let words = LyricTypography(primaryHex: seed).adaptedForGlass(dark: false).wordColors
            let glyph = try linearPixels(render(time: 1.6, effects: .init(lift: false, glow: false),
                wordColors: words, background: .clear))
            for background in [Color.white, Color(.sRGBLinear, white: 0.65, opacity: 1)] {
                func pixels(_ effects: LyricEmphasisOptions, headroom: Double = 4) throws -> [Float] {
                    try linearPixels(render(time: 1.6, effects: effects, hdrHeadroom: headroom,
                                            wordColors: words, background: background))
                }
                let plain = try pixels(.init(lift: false, glow: false))
                let sdr = try pixels(.init(lift: false, glow: true))
                let hdr = try pixels(.init(lift: false, glow: true, hdr: true, hdrBrightness: 3.5))
                let limited = try pixels(.init(lift: false, glow: true, hdr: true, hdrBrightness: 3.5), headroom: 1)
                let channels = stride(from: 0, to: hdr.count, by: 4).flatMap { [$0, $0 + 1, $0 + 2] }
                #expect(channels.map { sdr[$0] }.max()! <= 1.01)
                #expect(channels.map { hdr[$0] }.max()! > 1.1, "No EDR halo for \(seed)")
                print("Light ink \(seed): SDR peak=\(channels.map { sdr[$0] }.max()!), EDR peak=\(channels.map { hdr[$0] }.max()!)")
                #expect(channels.map { limited[$0] }.max()! <= 1.01)
                for index in stride(from: 0, to: hdr.count, by: 4) {
                    // Check opaque sung cores, not antialiased boundary pixels
                    // that intentionally blend with the surrounding halo.
                    let core = glyph[index + 3] > 0.999 &&
                        plain[index] * 0.2126 + plain[index + 1] * 0.7152 + plain[index + 2] * 0.0722 < 0.035
                    if core { #expect((0..<3).allSatisfy { hdr[index + $0] - plain[index + $0] < 0.015 }) }
                }
            }
        }
    }

    @Test func lowHeadroomHDRRetainsTheOrdinaryHaloInsteadOfMakingItWeaker() throws {
        let words = LyricTypography().adaptedForGlass(dark: true).wordColors
        let plain = try linearPixels(render(time: 1.6, effects: .init(lift: false, glow: false), wordColors: words))
        let sdr = try linearPixels(render(time: 1.6, effects: .init(lift: false, glow: true), wordColors: words))
        let hdr = try linearPixels(render(time: 1.6, effects: .init(lift: false, glow: true, hdr: true, hdrBrightness: 3.5),
            hdrHeadroom: 1.2, wordColors: words))
        var sdrHalo = 0.0, hdrHalo = 0.0
        for i in stride(from: 0, to: plain.count, by: 4) where plain[i] < 0.02 {
            sdrHalo += Double(sdr[i]); hdrHalo += Double(hdr[i])
        }
        print("LOW HEADROOM HALO SDR=\(sdrHalo), HDR=\(hdrHalo)")
        #expect(hdrHalo >= sdrHalo * 0.95, "Enabling HDR must retain a visible halo when macOS has little headroom")
        #expect(stride(from: 0, to: hdr.count, by: 4).map { hdr[$0] }.max()! > 1.02)
    }

    private func linearPixels(_ image: CGImage) throws -> [Float] {
        let space = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
        let context = CIContext(options: [.workingColorSpace: space, .outputColorSpace: space])
        var pixels = [Float](repeating: 0, count: image.width * image.height * 4)
        pixels.withUnsafeMutableBytes {
            context.render(CIImage(cgImage: image), toBitmap: $0.baseAddress!, rowBytes: image.width * 16,
                bounds: CGRect(x: 0, y: 0, width: image.width, height: image.height), format: .RGBAf, colorSpace: space)
        }
        return pixels
    }

    private func render(time: Double, effects: LyricEmphasisOptions, hdrSupported: Bool = true, hdrHeadroom: Double = 4, wordColors: LyricWordColors? = nil, background: Color = .black) throws -> CGImage {
        let line = LyricLine(id: 0, time: 0, text: "Stay 光", words: [
            .init(text: "Stay", start: 0.1, end: 3.2), .init(text: "光", start: 3.2, end: 4)
        ])
        let view = WordHighlight(line: line, time: time, active: true, text: line.text, effects: effects)
            .environment(\.lyricWordColors, wordColors)
            .environment(\.lyricHDRSupported, hdrSupported)
            .environment(\.lyricHDRHeadroom, hdrHeadroom)
            .font(.system(size: 38, weight: .semibold)).foregroundStyle(.white)
            .padding(24).frame(width: 350, height: 130).background(background)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.colorMode = .extendedLinear
        renderer.allowedDynamicRange = effects.usesHDR ? .high : .standard
        return try #require(renderer.cgImage)
    }

    private func energy(_ image: CGImage) throws -> Double {
        var pixels = [Float](repeating: 0, count: image.width * image.height * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
        let context = CIContext(options: [.workingColorSpace: space, .outputColorSpace: space])
        pixels.withUnsafeMutableBytes { buffer in
            context.render(CIImage(cgImage: image), toBitmap: buffer.baseAddress!, rowBytes: image.width * 16,
                           bounds: CGRect(x: 0, y: 0, width: image.width, height: image.height), format: .RGBAf, colorSpace: space)
        }
        return stride(from: 0, to: pixels.count, by: 4).reduce(0) { $0 + Double(pixels[$1]) }
    }
}

private struct RenderingFixtureRepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

@Test func longWordCharactersSwellInSequenceWithoutChangingCueTiming() {
    let cue = WordCue(text: "glowing", start: 0, end: 3)
    let first = LyricEmphasisFrame(cue: cue, time: 0.9, options: .init(), characterPhase: 0)
    let last = LyricEmphasisFrame(cue: cue, time: 0.9, options: .init(), characterPhase: 1)
    #expect(first.scale > last.scale && first.glow > last.glow)
    #expect(first.progress == last.progress && first.progress == cue.progress(at: 0.9))
    for phase in [0.0, 0.5, 1] {
        let dt = 0.0001
        let start = LyricEmphasisFrame(cue: cue, time: 0, options: .init(), characterPhase: phase)
        let next = LyricEmphasisFrame(cue: cue, time: dt, options: .init(), characterPhase: phase)
        let previous = LyricEmphasisFrame(cue: cue, time: 3 - dt, options: .init(), characterPhase: phase)
        let end = LyricEmphasisFrame(cue: cue, time: 3, options: .init(), characterPhase: phase)
        #expect(abs(next.scale - start.scale) / dt < 0.001)
        #expect(abs(end.scale - previous.scale) / dt < 0.001)
        #expect(abs(end.lift - previous.lift) / dt < 0.001)
        #expect(abs(end.glow - previous.glow) / dt < 0.001)
        var old = start
        for step in 1...360 {
            let frame = LyricEmphasisFrame(cue: cue, time: Double(step) / 120, options: .init(), characterPhase: phase)
            #expect(abs(frame.scale - old.scale) < 0.003)
            #expect(frame.scale >= 0.985 && frame.scale < 1.08)
            old = frame
        }
    }
    #expect(LyricEmphasisFrame.separatesCharacters(in: cue, time: 1, options: .init()))
    for text in ["العربية", "नमस्ते", "👩🏽‍🚀"] {
        #expect(!LyricEmphasisFrame.separatesCharacters(in: .init(text: text, start: 0, end: 3), time: 1, options: .init()))
    }
    #expect(!LyricEmphasisFrame.separatesCharacters(in: cue, time: 1, options: .init(reduced: true)))
    #expect(!LyricEmphasisFrame.separatesCharacters(in: cue, time: 4, options: .init()))
}
