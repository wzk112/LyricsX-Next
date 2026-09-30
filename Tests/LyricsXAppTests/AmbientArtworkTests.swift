import AppKit
import Testing
@testable import LyricsXApp

@Suite(.serialized) @MainActor
struct AmbientArtworkTests {
    @Test func backdropIsBoundedReusedAndReplacedWhenArtworkChanges() async throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmap = try #require(CGContext(data: nil, width: 640, height: 640, bitsPerComponent: 8,
            bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        bitmap.setFillColor(NSColor.systemBlue.cgColor)
        bitmap.fill(CGRect(x: 0, y: 0, width: 640, height: 640))
        let source = try #require(bitmap.makeImage())
        let artwork = NSImage(cgImage: source, size: .init(width: 640, height: 640))
        let key = AmbientArtworkKey(artwork: artwork, size: .init(width: 2048, height: 1440))
        let renderer = AmbientArtworkRenderer()
        let start = ProcessInfo.processInfo.systemUptime
        let first = try #require(await renderer.render(source, key: key))
        let cold = ProcessInfo.processInfo.systemUptime - start
        #expect(max(first.width, first.height) <= 384)
        for _ in 0..<100 {
            let reused = try #require(await renderer.render(source, key: key))
            #expect(first === reused)
        }
        bitmap.setFillColor(NSColor.systemRed.cgColor)
        bitmap.fill(CGRect(x: 0, y: 0, width: 640, height: 640))
        let changed = try #require(bitmap.makeImage())
        let replacement = try #require(await renderer.render(changed, key: key))
        #expect(first !== replacement)
        let resizedKey = AmbientArtworkKey(artwork: artwork, size: .init(width: 1100, height: 700))
        let resized = try #require(await renderer.render(source, key: resizedKey))
        let displayed = AmbientBackdrop(image: first, key: key)
        #expect(!AmbientBackdrop(image: resized, key: resizedKey).animatesReplacement(of: displayed, reduced: false),
                "The same cover must not fade again when its backdrop raster is resized")
        let nextArtwork = NSImage(cgImage: changed, size: .init(width: 640, height: 640))
        let next = AmbientBackdrop(image: replacement,
            key: AmbientArtworkKey(artwork: nextArtwork, size: key.size))
        #expect(next.animatesReplacement(of: displayed, reduced: false))
        #expect(!next.animatesReplacement(of: displayed, reduced: true))
        #expect(AmbientArtworkKey(artwork: artwork, size: .init(width: 1001, height: 701)) ==
                AmbientArtworkKey(artwork: artwork, size: .init(width: 1002, height: 702)))
        print("Ambient CPU raster: first=\(cold * 1000) ms; cached reuse=100; output=\(first.width)x\(first.height)")
    }

    @Test func liveResizeObservationIsWindowScopedAndStopsAfterDetachment() async throws {
        let first = NSWindow(contentRect: .init(x: 0, y: 0, width: 400, height: 300),
                             styleMask: [.borderless], backing: .buffered, defer: false)
        let second = NSWindow(contentRect: .init(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        first.isReleasedWhenClosed = false; second.isReleasedWhenClosed = false
        defer { first.close(); second.close() }
        let reader = WindowLiveResizeReader.ResizeView()
        var events: [Bool] = []
        reader.changed = { events.append($0) }
        first.contentView?.addSubview(reader)
        await Task.yield()
        NotificationCenter.default.post(name: NSWindow.willStartLiveResizeNotification, object: first)
        NotificationCenter.default.post(name: NSWindow.willStartLiveResizeNotification, object: first)
        NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: second)
        #expect(events.last == true)
        NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: first)
        #expect(Array(events.suffix(2)) == [true, false])
        reader.removeFromSuperview()
        let count = events.count
        NotificationCenter.default.post(name: NSWindow.willStartLiveResizeNotification, object: first)
        #expect(events.count == count)
        second.contentView?.addSubview(reader)
        await Task.yield()
        NotificationCenter.default.post(name: NSWindow.willStartLiveResizeNotification, object: second)
        #expect(events.last == true)
        reader.stop(); reader.changed = nil
    }
}
