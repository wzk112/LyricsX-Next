import AppKit
import Testing
import LyricsXCore
@testable import LyricsXApp

private actor ControlledArtworkLoader {
    private var requests: [UInt8: CheckedContinuation<CGImage?, Never>] = [:]
    func load(_ data: Data?) async -> CGImage? {
        guard let key = data?.first else { return nil }
        return await withCheckedContinuation { requests[key] = $0 }
    }
    func contains(_ key: UInt8) -> Bool { requests[key] != nil }
    func finish(_ key: UInt8, image: CGImage?) { requests.removeValue(forKey: key)?.resume(returning: image) }
}

@Suite @MainActor struct ArtworkHandoverTests {
    private struct Repository: LyricsRepository {
        func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
        func save(_ document: LyricsDocument, for track: Track) async throws {}
    }
    private func image(_ color: CGColor) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8,
            bytesPerRow: 32, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(color); context.fill(.init(x: 0, y: 0, width: 8, height: 8))
        return try #require(context.makeImage())
    }
    private func wait(_ loader: ControlledArtworkLoader, for key: UInt8) async throws {
        for _ in 0..<100 where !(await loader.contains(key)) { try await Task.sleep(for: .milliseconds(5)) }
        #expect(await loader.contains(key))
    }
    private func publish(_ model: AppModel, title: String, bytes: UInt8? = nil) {
        model.bridge.onSnapshot?(.init(track: .init(playerID: "test", playerName: "Test", title: title,
            artworkData: bytes.map { Data([$0]) }), position: 0, isPlaying: false))
    }
    private func fixture(_ body: (AppModel, ControlledArtworkLoader) async throws -> Void) async throws {
        let suite = "LyricsXTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let loader = ControlledArtworkLoader()
        let model = AppModel(repository: Repository(), preferences: Preferences(defaults: defaults),
            artworkLoader: { data, _ in await loader.load(data) })
        defer { model.stop() }
        try await body(model, loader)
    }

    @Test func lateMetadataAndSameTrackBytesShareOneHoldWithoutDefaultCover() async throws {
        try await fixture { model, loader in
            let red = try image(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            let blue = try image(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
            model.artwork = NSImage(cgImage: red, size: .zero)
            let previous = model.artwork
            publish(model, title: "Replacement")
            #expect(model.artwork === previous && model.artworkLoading)
            try await Task.sleep(for: .milliseconds(400))
            publish(model, title: "Replacement", bytes: 1)
            await loader.finish(0, image: nil)
            try await wait(loader, for: 1)
            #expect(model.artwork === previous && model.artworkLoading)
            await loader.finish(1, image: blue)
            for _ in 0..<100 where model.artwork === previous { try await Task.sleep(for: .milliseconds(5)) }
            #expect(model.artwork != nil && model.artwork !== previous && !model.artworkLoading)
            try await Task.sleep(for: .milliseconds(550))
            #expect(model.artwork != nil && model.preferences.artworkTheme == ArtworkThemeExtractor.extract(blue))
        }
    }

    @Test func slowDecodeDropsOldPixelsAndCancelledRequestCannotOverwriteLatest() async throws {
        try await fixture { model, loader in
            let red = try image(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            let blue = try image(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
            model.artwork = NSImage(cgImage: red, size: .zero)
            publish(model, title: "Slow", bytes: 1)
            try await wait(loader, for: 1)
            try await Task.sleep(for: .seconds(ArtworkHandover.graceDuration + 0.1))
            #expect(model.artwork == nil && model.artworkLoading) // Quiet loading surface, no wrong old cover.
            publish(model, title: "Latest", bytes: 2)
            try await wait(loader, for: 2)
            await loader.finish(1, image: red) // Deliberately ignores cancellation in the test loader.
            try await Task.sleep(for: .milliseconds(40))
            #expect(model.artwork == nil && model.artworkLoading)
            await loader.finish(2, image: blue)
            for _ in 0..<100 where model.artwork == nil { try await Task.sleep(for: .milliseconds(5)) }
            let current = try #require(model.artwork?.cgImage(forProposedRect: nil, context: nil, hints: nil))
            #expect(current === blue && !model.artworkLoading)
        }
    }

    @Test func missingArtworkExpiresAcrossRapidSkipsAndFailedDecodeSettles() async throws {
        try await fixture { model, loader in
            model.artwork = NSImage(cgImage: try image(CGColor(red: 1, green: 0, blue: 0, alpha: 1)), size: .zero)
            publish(model, title: "No artwork 1")
            try await Task.sleep(for: .milliseconds(450))
            publish(model, title: "No artwork 2")
            try await Task.sleep(for: .milliseconds(450))
            #expect(model.artwork == nil && !model.artworkLoading)
            publish(model, title: "Invalid artwork", bytes: 3)
            try await wait(loader, for: 3)
            #expect(model.artworkLoading)
            await loader.finish(3, image: nil)
            for _ in 0..<100 where model.artworkLoading { try await Task.sleep(for: .milliseconds(5)) }
            #expect(model.artwork == nil && !model.artworkLoading)
        }
    }
}

@Test func artworkGraceCannotBeExtendedByMetadataOrRapidSkips() {
    var hold = ArtworkHandover()
    #expect(hold.begin(at: 10) == 10.8)
    #expect(hold.begin(at: 10.6) == 10.8)
    #expect(hold.begin(at: 20) == 10.8)
    hold.finish()
    #expect(hold.begin(at: 20) == 20.8)
}
