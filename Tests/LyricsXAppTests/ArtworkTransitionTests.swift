import AppKit
import SwiftUI
import Testing
import LyricsXCore
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

@MainActor @Test func artworkReplacementKeepsPixelsUntilDecodedAndPublishesMatchingPalette() async throws {
    struct Repository: LyricsRepository {
        func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
        func save(_ document: LyricsDocument, for track: Track) async throws {}
    }
    let suite = "LyricsXTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(repository: Repository(), preferences: Preferences(defaults: defaults))
    defer { model.stop() }
    func image(_ color: CGColor) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 256,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(color); context.fill(.init(x: 0, y: 0, width: 64, height: 64))
        return try #require(context.makeImage())
    }
    let red = try image(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    let blue = try image(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
    let bytes = try #require(NSBitmapImageRep(cgImage: blue).representation(using: .png, properties: [:]))
    model.artwork = NSImage(cgImage: red, size: .zero)
    let previous = model.artwork
    model.bridge.onSnapshot?(.init(track: .init(playerID: "test", playerName: "Test", title: "Replacement", artworkData: bytes), position: 0, isPlaying: false))
    #expect(model.artwork === previous) // No blank cover update before decode.
    for _ in 0..<100 where model.artwork === previous { try await Task.sleep(for: .milliseconds(10)) }
    #expect(model.artwork != nil && model.artwork !== previous)
    #expect(model.preferences.artworkTheme == ArtworkThemeExtractor.extract(blue))
    try await Task.sleep(for: .milliseconds(400))
    #expect(model.artwork != nil) // Cancelled handover cannot erase the new image.
}

@Test func changingOnlyCurrentEDRHeadroomDoesNotRebuildTheRenderEnvironment() {
    let first = HDRDisplayCapability(potential: 4, current: 2)
    let fluctuation = HDRDisplayCapability(potential: 4, current: 1)
    #expect(first.hasSameRenderOutput(as: fluctuation))
    let sdrMatches = first.hasSameRenderOutput(as: HDRDisplayCapability(potential: 1, current: 1))
    let differentPotentialMatches = first.hasSameRenderOutput(as: HDRDisplayCapability(potential: 3, current: 1))
    #expect(sdrMatches == false)
    #expect(differentPotentialMatches == false)
}
