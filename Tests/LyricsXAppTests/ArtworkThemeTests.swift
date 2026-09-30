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
    private func canvas(_ draw: (CGContext) -> Void) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 256,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.clear(.init(x: 0, y: 0, width: 64, height: 64))
        draw(context)
        return try #require(context.makeImage())
    }
    private func fill(_ context: CGContext, _ red: Double, _ green: Double, _ blue: Double,
                      rect: CGRect = .init(x: 0, y: 0, width: 64, height: 64), alpha: Double = 1) {
        context.setFillColor(CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [red, green, blue, alpha])!)
        context.fill(rect)
    }
    @Test func smallDistinctCoverColorsReachWaveformAndSecondaryWithoutReplacingDominantInk() throws {
        let artwork = try canvas { context in
            fill(context, 1, 0, 0)
            fill(context, 0, 0, 1, rect: .init(x: 10, y: 10, width: 8, height: 8))
            fill(context, 0, 1, 0, rect: .init(x: 28, y: 28, width: 8, height: 8))
            fill(context, 1, 1, 0, rect: .init(x: 46, y: 46, width: 8, height: 8))
        }
        let theme = ArtworkThemeExtractor.extract(artwork)
        #expect(theme.accent == "FF0000")
        #expect(theme.palette.count == 4)
        let colors = theme.waveformColors.map(components)
        #expect(colors.contains { $0[2] > $0[0] + 0.3 && $0[2] > $0[1] + 0.3 })
        #expect(colors.contains { $0[1] > $0[0] + 0.3 && $0[1] > $0[2] + 0.3 })
        #expect(colors.contains { $0[0] > $0[2] + 0.3 && $0[1] > $0[2] + 0.3 })
        #expect(theme.secondary != ArtworkThemeExtractor.extract(try image(1, 0, 0)).secondary)
        #expect(theme.secondaryAccent == theme.palette[1])
        #expect(theme == ArtworkThemeExtractor.extract(artwork))
    }
    @Test func redAndCyanCoverKeepsBothHuesDespiteBlackAndWhitePortrait() throws {
        let theme = ArtworkThemeExtractor.extract(try canvas { context in
            fill(context, 1, 0, 0, rect: .init(x: 0, y: 0, width: 32, height: 64))
            fill(context, 0, 0.78, 0.82, rect: .init(x: 32, y: 0, width: 32, height: 64))
            fill(context, 1, 1, 1, rect: .init(x: 20, y: 8, width: 24, height: 48))
            fill(context, 0, 0, 0, rect: .init(x: 24, y: 24, width: 16, height: 12))
        })
        #expect(theme.accent == "FF0000")
        #expect(theme.palette.count == 2)
        let secondary = components(theme.secondaryAccent)
        #expect(secondary[1] > secondary[0] + 0.5 && secondary[2] > secondary[0] + 0.5)
        let lyricSecondary = components(theme.secondary)
        #expect(lyricSecondary[1] > lyricSecondary[0] + 0.15 && lyricSecondary[2] > lyricSecondary[0] + 0.15)
        #expect(theme.waveformColors.last == theme.secondaryAccent)
    }
    @Test func relatedRedsMergeAcrossHueBoundaryButOrangeRemainsDistinct() throws {
        let artwork = try canvas { context in
            fill(context, 1, 0.06, 0, rect: .init(x: 0, y: 0, width: 32, height: 64))
            fill(context, 1, 0, 0.06, rect: .init(x: 32, y: 0, width: 32, height: 64))
            fill(context, 0, 0.2, 1, rect: .init(x: 24, y: 24, width: 16, height: 16))
        }
        let theme = ArtworkThemeExtractor.extract(artwork)
        #expect(theme.palette.count == 2)
        let accent = components(theme.accent)
        #expect(accent[0] > 0.95 && accent[1] < 0.05 && accent[2] < 0.05)
        let warm = ArtworkThemeExtractor.extract(try canvas { context in
            fill(context, 1, 0, 0, rect: .init(x: 0, y: 0, width: 32, height: 64))
            fill(context, 1, 0.55, 0, rect: .init(x: 32, y: 0, width: 32, height: 64))
        })
        #expect(warm.palette.count == 2)
        #expect(warm.palette.map(components).contains { $0[1] > 0.5 && $0[2] < 0.1 })
    }
    @Test func transparentAndGrayscaleCoversUseHonestColorsAndNoiseDoesNotAddHues() throws {
        let grayscale = try canvas { context in
            fill(context, 1, 1, 1)
            fill(context, 0, 0, 0, rect: .init(x: 16, y: 16, width: 32, height: 32))
        }
        #expect(ArtworkThemeExtractor.extract(grayscale) == .neutral)
        let invisible = try canvas { context in fill(context, 1, 0, 0, alpha: 0.01) }
        #expect(ArtworkThemeExtractor.extract(invisible) == .neutral)
        let translucent = ArtworkThemeExtractor.extract(try canvas { context in
            fill(context, 0, 0.2, 1, rect: .init(x: 16, y: 16, width: 32, height: 32), alpha: 0.4)
        })
        let blue = components(translucent.accent)
        #expect(blue[2] > 0.95 && blue[0] < 0.01 && abs(blue[1] - 0.2) < 0.02)
        #expect(translucent.palette.count == 1)
        let noisy = ArtworkThemeExtractor.extract(try canvas { context in
            fill(context, 1, 0, 0)
            fill(context, 0, 1, 0, rect: .init(x: 30, y: 30, width: 1, height: 1))
        })
        #expect(noisy.palette.count == 1)
        #expect(noisy.waveformColors.count == 2 && noisy.waveformColors[0] == noisy.waveformColors[1])
    }
    @Test func darkWaveformColorsStayVisibleWithoutInventingExtraHues() throws {
        let theme = ArtworkThemeExtractor.extract(try image(0, 0.04, 0.22))
        #expect(theme.palette.count == 1)
        #expect(theme.waveformColors.allSatisfy { LyricTypography.luminance($0) >= 0.215 })
        let ink = components(try #require(theme.palette.first))
        #expect(ink[2] > ink[0] && ink[2] > ink[1])
        #expect(ArtworkTheme.neutral.waveformColors == ["FFFFFF", "BFC7D5", "FFFFFF"])
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
