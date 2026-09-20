import AppKit
import Testing
import LyricsXCore
@testable import LyricsXApp

@Suite @MainActor struct ArtworkDecoderTests {
    private struct Repository: LyricsRepository {
        func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
        func save(_ document: LyricsDocument, for track: Track) async throws {}
    }
    private func png(_ color: NSColor, side: Int = 16) throws -> Data {
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        color.setFill(); NSRect(x: 0, y: 0, width: side, height: side).fill()
        NSGraphicsContext.restoreGraphicsState()
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }
    @Test func thumbnailIsBoundedAndInvalidInputsAreRejected() async throws {
        let decoder = ArtworkDecoder()
        let image = try #require(await decoder.decode(png(.red, side: 1800)))
        #expect(image.width == 640 && image.height == 640)
        #expect(await decoder.decode(Data("not an image".utf8)) == nil)
        #expect(await decoder.load(data: nil, url: URL(string: "file:///not-an-artwork")) == nil)
    }
    @Test func rapidSkipsAndSameIdentityPayloadReplacementPublishOnlyLatestPixels() async throws {
        let model = AppModel(repository: Repository())
        defer { model.stop() }
        let red = try png(.red, side: 1800), blue = try png(.blue)
        for index in 0..<12 {
            model.bridge.onSnapshot?(.init(track: .init(playerID: "test", playerName: "Test", title: "Track \(index)", artworkData: red), position: 0, isPlaying: false))
        }
        model.bridge.onSnapshot?(.init(track: .init(playerID: "test", playerName: "Test", title: "Track 11", artworkData: blue), position: 0, isPlaying: false))
        for _ in 0..<200 where model.artwork == nil { try await Task.sleep(for: .milliseconds(10)) }
        let image = try #require(model.artwork?.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let pixel = try #require(NSBitmapImageRep(cgImage: image).colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB))
        #expect(pixel.blueComponent > 0.9 && pixel.redComponent < 0.1)
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.artwork?.cgImage(forProposedRect: nil, context: nil, hints: nil) === image)
    }
    @Test func stopCancelsPendingPublication() async throws {
        let model = AppModel(repository: Repository())
        model.bridge.onSnapshot?(.init(track: .init(playerID: "test", playerName: "Test", title: "Stopped", artworkData: try png(.red)), position: 0, isPlaying: false))
        model.stop()
        try await Task.sleep(for: .milliseconds(80))
        #expect(model.artwork == nil)
    }
}
