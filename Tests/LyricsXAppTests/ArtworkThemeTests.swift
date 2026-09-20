import AppKit
import Testing
import LyricsXCore
@testable import LyricsXApp

private struct ThemeRepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}
@Suite @MainActor struct ArtworkThemeTests {
    private func image(_ red: Double, _ green: Double, _ blue: Double, whiteBorder: Bool = false) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 256,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); context.fill(.init(x: 0, y: 0, width: 64, height: 64))
        context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
        context.fill(whiteBorder ? .init(x: 12, y: 12, width: 40, height: 40) : .init(x: 0, y: 0, width: 64, height: 64))
        return try #require(context.makeImage())
    }
    private func components(_ hex: String) -> [Double] {
        let value = UInt32(hex, radix: 16)!
        return [Double(value >> 16 & 255), Double(value >> 8 & 255), Double(value & 255)].map { $0 / 255 }
    }
    @Test func extractionKeepsHueIgnoresBordersAndGuaranteesBrightReadableInk() throws {
        for (r, g, b) in [(1.0,0.0,0.0), (0.0,0.2,1.0), (0.0,0.6,0.2)] {
            let theme = ArtworkThemeExtractor.extract(try image(r,g,b, whiteBorder: true))
            let sung = components(theme.sung), dim = components(theme.unsung)
            #expect(sung.min()! >= 0.71)
            #expect(zip(sung, dim).allSatisfy { $0 > $1 * 2 })
            #expect(theme.accent == ArtworkThemeExtractor.extract(try image(r,g,b)).accent)
        }
        #expect(ArtworkThemeExtractor.extract(try image(0,0,0)) == .neutral)
        #expect(ArtworkThemeExtractor.extract(try image(1,1,1)) == .neutral)
        #expect(ArtworkThemeExtractor.extract(try image(0.5,0.5,0.5)) == .neutral)
    }
    @Test func automaticPaletteNeverOverwritesManualSettingsAndLateArtCannotWin() async throws {
        let suite = "LyricsXThemeTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let p = Preferences(defaults: defaults)
        p.lyricPrimaryColor = "12ABCD"; p.sungWordColor = "F12345"
        let model = AppModel(repository: ThemeRepository(), preferences: p)
        defer { model.stop() }
        #expect(!p.followArtworkColors)
        p.followArtworkColors = true
        #expect(p.typography.primaryHex == "FFFFFF")
        model.artwork = NSImage(cgImage: try image(1,0,0), size: .zero)
        model.artwork = nil
        let blue = try image(0,0.2,1)
        model.artwork = NSImage(cgImage: blue, size: .zero)
        try await Task.sleep(for: .milliseconds(450))
        #expect(p.artworkTheme == ArtworkThemeExtractor.extract(blue))
        #expect(p.typography.wordColors != nil)
        p.followArtworkColors = false
        #expect(p.typography.primaryHex == "12ABCD" && p.sungWordColor == "F12345")
        let loaded = Preferences(defaults: defaults)
        #expect(loaded.lyricPrimaryColor == "12ABCD" && loaded.artworkTheme == nil)
        p.followArtworkColors = true
        model.artwork = nil
        try await Task.sleep(for: .milliseconds(400))
        #expect(p.artworkTheme == nil && p.typography.primaryHex == "FFFFFF")
    }
}
