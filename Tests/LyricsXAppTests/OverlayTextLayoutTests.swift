import AppKit
import SwiftUI
import Testing
import LyricsXCore
@testable import LyricsXApp

@Suite @MainActor struct OverlayTextLayoutTests {
    @Test func measuredRowsMatchDrawnRowsWithoutEmptySpaceAboveSingleLines() throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlaySecondaryMode = .none; prefs.fontSize = 26
        prefs.lyricGlow = false; prefs.lyricWordLift = false
        let samples = ["A short line", "When we follow all the stars together we can find our way home", "让晚风带着我们的故事穿过城市的每一条街道和每一个灯火闪耀的夜晚", "Top line\nBottom line",
            "Don’t look for me, I’m just a story you’ve been told", "Don’t try to make yourself remember, darling"]
        for name in ["", "Georgia", "Menlo-Regular", "HelveticaNeue", "PingFangSC-Regular", "PingFangSC-Semibold"] {
          prefs.lyricFontName = name
          for width in [260.0, 552, 560, 568, 940] {
            for text in samples {
                let doc = LyricsDocument(lines: [.init(id: 0, time: 0, text: text)])
                let layout = OverlayTextMeasure.primaryLayout(document: doc, index: 0, preferences: prefs, canvasWidth: width)
                let view = OverlayLyricsContent(preferences: prefs, document: doc, index: 0, lyricTime: { 5 }, adaptiveCanvasWidth: width)
                    .frame(width: width).padding(.vertical, 12).background(.black)
                let renderer = ImageRenderer(content: view); renderer.scale = 1
                let image = try #require(renderer.cgImage)
                let context = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(image, in: .init(x: 0, y: 0, width: image.width, height: image.height))
                let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
                var bands: [Int] = [], inkBefore = false
                for y in 0..<image.height {
                    let ink = (0..<image.width).contains { bytes[y * context.bytesPerRow + $0 * 4] > 64 }
                    if ink && !inkBefore { bands.append(y) }
                    inkBefore = ink
                }
                #expect(bands.count == layout.rows, "text=\(text), width=\(width), rows=\(layout.rows), bands=\(bands)")
                #expect((bands.first ?? 100) < 32) // No unused whole line above the ink.
                #expect(layout.fontSize <= prefs.fontSize && layout.fontSize >= prefs.fontSize * 0.6)
            }
          }
        }
    }
}
