import AppKit
import SwiftUI
import Testing
import LyricsXCore
@testable import LyricsXApp

// This suite owns a native AppKit window and captures real cover pixels. Run alone
// with LYRICSX_PLAYER_COLUMN_QA=1, as with the other native window QA suites.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["LYRICSX_PLAYER_COLUMN_QA"] == "1"))
@MainActor struct PlayerColumnWindowTests {
    private struct Repository: LyricsRepository {
        func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> {
            .init { $0.finish() }
        }
        func save(_ document: LyricsDocument, for track: Track) async throws {}
    }

    @Test func coverAndNativeProgressShareBothEdgesAfterResizingAndPlaybackChanges() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXPlayerColumn-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        preferences.reduceMotion = true
        let model = AppModel(repository: Repository(), preferences: preferences)
        let track = Track(playerID: "test", playerName: "Test",
            title: "A very long track title that needs both available metadata lines",
            artist: "A long artist name with multiple performers and collaborators",
            album: "A long album name that must truncate within the shared player column", duration: 240)
        model.session.accept(.init(track: track, position: 30, isPlaying: true), shouldSearch: false)
        model.session.use(.init(lines: (0..<20).map {
            .init(id: $0, time: Double($0) * 5, text: "Native lyric viewport row \($0)")
        }), persist: false)
        model.mainWindowVisible = true
        model.artwork = NSImage(size: .init(width: 128, height: 128), flipped: false) { rect in
            NSColor.red.setFill(); rect.fill(); return true
        }
        let panel = NSPanel(contentRect: .init(x: 40, y: 100, width: 1100, height: 740),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: NowPlayingView(model: model))
        host.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = host
        panel.orderFrontRegardless()
        defer { panel.orderOut(nil); panel.contentView = nil; panel.close(); model.stop() }
        let directory = URL(fileURLWithPath: "/tmp/lyricsx-player-column-qa", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        func descendants<T: NSView>(_ type: T.Type, in view: NSView) -> [T] {
            (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants(type, in: $0) }
        }
        func settle() async throws {
            // The old pause scale also applied with reduced motion. Capture
            // the visible artwork rather than only its proposed frame.
            for _ in 0..<12 {
                NSApp.updateWindows(); host.layoutSubtreeIfNeeded()
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        func coverPixels(_ bitmap: NSBitmapImageRep) throws -> NSRect {
            var minX = bitmap.pixelsWide, maxX = -1, minY = bitmap.pixelsHigh, maxY = -1
            // A solid red source identifies the rendered artwork itself;
            // its shadow, layout proposal and metadata cannot satisfy this.
            let image = try #require(bitmap.cgImage)
            let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
            let context = try #require(CGContext(data: nil, width: bitmap.pixelsWide, height: bitmap.pixelsHigh,
                bitsPerComponent: 8, bytesPerRow: bitmap.pixelsWide * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: .init(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh))
            let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    let offset = (y * bitmap.pixelsWide + x) * 4
                    guard pixels[offset] > 191, pixels[offset + 1] < 38, pixels[offset + 2] < 38 else { continue }
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
            try #require(maxX >= minX && maxY >= minY, "The real cover must appear in the native capture")
            let scaleX = CGFloat(bitmap.pixelsWide) / host.bounds.width
            let scaleY = CGFloat(bitmap.pixelsHigh) / host.bounds.height
            return NSRect(x: CGFloat(minX) / scaleX, y: CGFloat(minY) / scaleY,
                width: CGFloat(maxX - minX + 1) / scaleX, height: CGFloat(maxY - minY + 1) / scaleY)
        }
        try await settle()
        let lyricScroll = try #require(descendants(NSScrollView.self, in: host).first)
        for size in [NSSize(width: 1100, height: 740), .init(width: 1100, height: 440),
                     .init(width: 790, height: 640), .init(width: 790, height: 430),
                     .init(width: 1100, height: 740)] {
            panel.setContentSize(size)
            var playingCover: NSRect?
            for playing in [true, false] {
                model.session.accept(.init(track: track, position: 30, isPlaying: playing))
                model.updateMainLyricSelection()
                try await settle()
                func sliderFrames(_ view: NSView) -> [NSView] {
                    // SwiftUI's mini slider renders its native focus surface
                    // directly instead of installing an NSSlider subclass.
                    let own = String(describing: type(of: view)).contains("FocusRingView")
                        && abs(view.frame.height - 12) < 0.1 ? [view] : []
                    return own + view.subviews.flatMap(sliderFrames)
                }
                let sliders = sliderFrames(host)
                let slider = try #require(sliders.first, "The real playback slider must be hosted")
                #expect(sliders.count == 1)
                let sliderFrame = host.convert(slider.bounds, from: slider)
                let cached = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: cached)
                let bitmap = NSBitmapImageRep(cgImage: try #require(cached.cgImage))
                let cover = try coverPixels(bitmap)
                #expect(abs(cover.minX - sliderFrame.minX) <= 2,
                    "\(size), playing=\(playing): cover left \(cover.minX), slider left \(sliderFrame.minX)")
                #expect(abs(cover.maxX - sliderFrame.maxX) <= 2,
                    "\(size), playing=\(playing): cover right \(cover.maxX), slider right \(sliderFrame.maxX)")
                #expect(abs(cover.width - cover.height) <= 2)
                let columnWidth = min(330, max(220, size.width * 0.31))
                #expect(abs(cover.midX - (28 + columnWidth / 2)) <= 2,
                    "The shared column stays centered inside the existing player pane")
                #expect(descendants(NSScrollView.self, in: host).first === lyricScroll,
                    "Player resizing must retain the lyric viewport")
                if playing { playingCover = cover }
                else {
                    let previous = try #require(playingCover)
                    #expect(abs(cover.minX - previous.minX) <= 1)
                    #expect(abs(cover.maxX - previous.maxX) <= 1,
                        "Pausing must preserve the artwork's visible edges")
                }
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: directory.appendingPathComponent("\(Int(size.width))x\(Int(size.height))-\(playing ? "playing" : "paused").png"))
                print("Player column \(size), playing=\(playing): cover=\(cover), slider=\(sliderFrame)")
            }
        }
        panel.setContentSize(.init(width: 700, height: 600))
        try await settle()
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        #expect(abs(try coverPixels(bitmap).width - 64) <= 2,
            "Compact mode keeps its existing 64pt cover")
        #expect(descendants(NSScrollView.self, in: host).first === lyricScroll,
            "Crossing compact mode must retain the lyric viewport")
    }
}
