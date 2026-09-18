import AppKit
import SwiftUI
import Testing
@testable import LyricsXApp

@Suite @MainActor struct ArtworkTransitionTests {
    @Test func transientMissingCoverDoesNotFlashAndCancelledClearCannotEraseReplacement() async throws {
        _ = NSApplication.shared
        func image(_ color: NSColor) -> NSImage {
            NSImage(size: .init(width: 64, height: 64), flipped: false) { rect in
                color.setFill(); rect.fill(); return true
            }
        }
        let red = image(.red), blue = image(.blue)
        let host = NSHostingView(rootView: CoverArtwork(artwork: red, animated: true))
        host.frame = .init(x: 0, y: 0, width: 180, height: 180)
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host; window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        func center() throws -> NSColor {
            host.layoutSubtreeIfNeeded()
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            return try #require(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB))
        }
        try await Task.sleep(for: .milliseconds(700))
        #expect(try center().redComponent > 0.8)
        host.rootView = CoverArtwork(artwork: nil, animated: true)
        try await Task.sleep(for: .milliseconds(80))
        #expect(try center().redComponent > 0.8)
        host.rootView = CoverArtwork(artwork: blue, animated: true)
        try await Task.sleep(for: .milliseconds(800))
        #expect(try center().blueComponent > 0.8)
        host.rootView = CoverArtwork(artwork: red, animated: false)
        try await Task.sleep(for: .milliseconds(50))
        #expect(try center().redComponent > 0.8)
    }
}
