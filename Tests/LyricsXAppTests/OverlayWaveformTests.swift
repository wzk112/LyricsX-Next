import AppKit
import Testing
import LyricsXCore
@testable import LyricsXApp

private struct WaveformQARepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> {
        .init { $0.finish() }
    }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

@Test func stereoSpectrumKeepsAntiphaseAudioAndSilenceAtZero() {
    let analyzer = WaveformSpectrumAnalyzer()
    let left = (0..<WaveformSpectrumAnalyzer.sampleCount).map { index in
        Float(sin(2 * .pi * 440 * Double(index) / 48_000) * 0.5)
    }
    let inverted = left.map { -$0 }
    let inPhase = analyzer.bands(left: left, right: left, sampleRate: 48_000)
    let antiphase = analyzer.bands(left: left, right: inverted, sampleRate: 48_000)
    let silence = analyzer.bands(left: Array(repeating: 0, count: left.count),
        right: Array(repeating: 0, count: left.count), sampleRate: 48_000)
    #expect(inPhase.count == 24 && antiphase.count == 24)
    #expect((antiphase.max() ?? 0) > 0.1)
    #expect(zip(inPhase, antiphase).allSatisfy { pair in abs(pair.0 - pair.1) < 0.0001 })
    #expect(silence.allSatisfy { $0 == 0 })
}

@Test func stereoRingPreservesBothChannelsAndFreshness() throws {
    let ring = WaveformSampleRing()
    let interleaved: [Float] = [1, -1, 2, -2, 3, -3]
    interleaved.withUnsafeBufferPointer { ring.appendInterleaved($0.baseAddress!, frames: 3) }
    let first = try #require(ring.latest(3))
    #expect(first.left == [1, 2, 3] && first.right == [-1, -2, -3])
    let left: [Float] = [4, 5], right: [Float] = [-4, -5]
    left.withUnsafeBufferPointer { a in
        right.withUnsafeBufferPointer { b in
            ring.appendPlanar(a.baseAddress!, b.baseAddress!, frames: 2)
        }
    }
    let second = try #require(ring.latest(3))
    #expect(second.left == [3, 4, 5] && second.right == [-3, -4, -5])
    #expect(second.writes > first.writes)
}

@Test func lowFrequencyAppearsLeftOfHighFrequency() throws {
    let analyzer = WaveformSpectrumAnalyzer()
    func peakIndex(_ frequency: Double) throws -> Int {
        let samples = (0..<WaveformSpectrumAnalyzer.sampleCount).map { index in
            Float(sin(2 * .pi * frequency * Double(index) / 48_000) * 0.5)
        }
        let bands = analyzer.bands(left: samples, right: samples, sampleRate: 48_000)
        return try #require(bands.indices.max(by: { bands[$0] < bands[$1] }))
    }
    let bass = try peakIndex(100)
    let treble = try peakIndex(4_000)
    #expect(bass < treble)
    let bands = (0..<WaveformSpectrumAnalyzer.bandCount).map { Float($0) / 23 }
    let points = OverlayWaveformGeometry.points(for: bands, width: 568, height: 18)
    #expect(points[bass].x < points[treble].x)
}

@Test func silenceIsFlatAndFullAmplitudeStaysInside18PointSurface() {
    let silent = OverlayWaveformGeometry.points(for: Array(repeating: 0, count: 24),
        width: 568, height: 18)
    #expect(silent.count == 24)
    #expect(silent.allSatisfy { $0.y == 2.5 })
    #expect(zip(silent, silent.dropFirst()).allSatisfy { $0.0.x < $0.1.x })
    let low = OverlayWaveformGeometry.amplitude(for: 0.07, height: 18)
    let high = OverlayWaveformGeometry.amplitude(for: 0.52, height: 18)
    #expect(OverlayWaveformGeometry.amplitude(for: 0, height: 18) == 0)
    #expect(low > 4 && high > 11)
    #expect(high > low)
    let full = OverlayWaveformGeometry.points(for: Array(repeating: 1, count: 24),
        width: 568, height: 18)
    #expect(full.allSatisfy { $0.y - 1 >= 1 && $0.y + 1 < 18 })
    #expect(full.allSatisfy { $0.x - 1 >= 0 && $0.x + 1 <= 568 })
}

@Test func spectrumEdgeFadeStopsStayMirroredAndOrderedAtEveryWidth() {
    let alphas = OverlayWaveformEdgeFade.alphas
    #expect(alphas.count == 12)
    for index in alphas.indices {
        #expect(abs(alphas[index] - alphas[alphas.count - 1 - index]) < 0.0001)
    }
    #expect(alphas[2] == 0.15625)
    #expect(alphas[3] == 0.5)
    #expect(alphas[4] == 0.84375)

    for width: CGFloat in [0, 1, 8, 10, 11, 20, 268, 568, 948, 2_000] {
        let locations = OverlayWaveformEdgeFade.locations(width: width).map(\.doubleValue)
        #expect(locations.count == alphas.count)
        #expect(locations.allSatisfy { (0...1).contains($0) })
        #expect(zip(locations, locations.dropFirst()).allSatisfy { $0.0 <= $0.1 })
        for index in locations.indices {
            #expect(abs(locations[index] + locations[locations.count - 1 - index] - 1) < 0.0001)
        }
        #expect(OverlayWaveformEdgeFade.fadeWidth(width: width) >= 0)
        #expect(OverlayWaveformEdgeFade.fadeWidth(width: width) <= max(0, width - 10) * 0.2 + 0.0001)
    }
    #expect(OverlayWaveformEdgeFade.fadeWidth(width: 268) == 32)
    #expect(abs(OverlayWaveformEdgeFade.fadeWidth(width: 568) - 56.8) < 0.0001)
    #expect(OverlayWaveformEdgeFade.fadeWidth(width: 948) == 80)
}

@MainActor @Test func spectrumEdgeFadeUsesOneMaskAcrossWhiteAndArtworkInk() throws {
    for width in [268.0, 568.0, 948.0] {
        let view = OverlayWaveformView(frame: NSRect(x: 0, y: 0, width: width, height: 18))
        view.layoutSubtreeIfNeeded()
        let container = try #require(view.layer?.sublayers?.first)
        let mask = try #require(container.mask as? CAGradientLayer)
        let locations = try #require(mask.locations).map(\.doubleValue)
        let fade = OverlayWaveformEdgeFade.fadeWidth(width: width)
        #expect(locations.count == OverlayWaveformEdgeFade.alphas.count)
        #expect(mask.colors?.count == locations.count)
        #expect(abs(locations[1] * width - 5) < 0.01)
        #expect(abs(locations[5] * width - 5 - fade) < 0.01)
        #expect(abs((1 - locations[10]) * width - 5) < 0.01)
        #expect(container.sublayers?.count == 3)
        #expect((container.sublayers?.last as? CAGradientLayer)?.mask is CAShapeLayer)
        #expect(mask.frame.size == view.bounds.size)
        let stroke = try #require(container.sublayers?[1] as? CAShapeLayer)
        let gradient = try #require(container.sublayers?.last as? CAGradientLayer)
        let bands = [Float](repeating: 0.3, count: WaveformSpectrumAnalyzer.bandCount)
        view.injectTestBands(bands, style: .monochrome, lightGlass: false, theme: .neutral)
        #expect(!stroke.isHidden && gradient.isHidden)
        view.injectTestBands(bands, style: .artwork, lightGlass: false, theme: .neutral)
        #expect(stroke.isHidden && !gradient.isHidden)
        let originalPathWidth = try #require(stroke.path).boundingBoxOfPath.width
        view.setFrameSize(.init(width: width + 100, height: 18))
        view.layoutSubtreeIfNeeded()
        #expect(abs(try #require(stroke.path).boundingBoxOfPath.width - originalPathWidth - 100) < 0.01)
    }
}

@MainActor @Test func waveformAddsSameBottomSpaceInAllOverlayPresentations() {
    let bases: [CGFloat] = [OverlayPresentationMode.waitingHeight,
        OverlaySongCardLayout(width: 320).height,
        OverlaySongCardLayout(width: 620).height,
        OverlaySongCardLayout(width: 1000).height,
        160, 218]
    for base in bases {
        #expect(OverlayWaveformLayout.totalHeight(content: base, enabled: false) == base)
        #expect(OverlayWaveformLayout.contentHeight(base: base, enabled: true) == base - 22)
        #expect(OverlayWaveformLayout.totalHeight(content: base, enabled: true) == base + 2)
    }
    for width in [320.0, 620.0, 1000.0] {
        let card = OverlaySongCardLayout(width: width, title: "Some Song", artist: "Artist")
        let row = card.height - 36
        #expect(card.baseHeight(waveformEnabled: false) == row + 36)
        #expect(OverlaySongCardLayout.waveformTopPadding
            + OverlaySongCardLayout.waveformBottomPadding == 18)
        #expect(abs(OverlayWaveformLayout.totalHeight(content:
            card.baseHeight(waveformEnabled: true), enabled: true) - (row + 54)) < 0.001)
    }
    #expect(OverlayWaveformLayout.contentHeight(base: OverlayPresentationMode.waitingHeight,
        enabled: true) == 74)
    #expect(OverlayLayoutMetrics.chromeHeight - OverlayWaveformLayout.reclaimedContentHeight == 58)
    let view = OverlayWaveformView(frame: NSRect(x: 0, y: 0, width: 568, height: 18))
    view.configure(enabled: false, visible: true, playing: true, reducedMotion: false,
        bundleID: "com.apple.Music", style: .monochrome, lightGlass: false,
        theme: nil, frameRateLimit: 0)
    #expect(view.isHidden)
    view.configure(enabled: true, visible: false, playing: true, reducedMotion: false,
        bundleID: "com.apple.Music", style: .monochrome, lightGlass: false,
        theme: nil, frameRateLimit: 0)
    #expect(view.isHidden)
    view.configure(enabled: true, visible: true, playing: true, reducedMotion: true,
        bundleID: "com.apple.Music", style: .monochrome, lightGlass: false,
        theme: nil, frameRateLimit: 0)
    #expect(view.isHidden)
}

@Test func waveformCaptureGateStopsWhenAnyLifecycleConditionFails() {
    #expect(OverlayWaveformCaptureGate.allows(enabled: true, visible: true,
        playing: true, reducedMotion: false, bundleID: "com.apple.Music"))
    let cases: [(Bool, Bool, Bool, Bool, String?)] = [
        (false, true, true, false, "com.apple.Music"),
        (true, false, true, false, "com.apple.Music"),
        (true, true, false, false, "com.apple.Music"),
        (true, true, true, true, "com.apple.Music"),
        (true, true, true, false, nil),
        (true, true, true, false, "")
    ]
    for (enabled, visible, playing, reduced, source) in cases {
        #expect(!OverlayWaveformCaptureGate.allows(enabled: enabled, visible: visible,
            playing: playing, reducedMotion: reduced, bundleID: source))
    }
}

@Test func noPCMRetryOnlyAtPlaybackSourceOrWakeBoundary() {
    var policy = WaveformRetryPolicy()
    let music = "com.apple.Music", spotify = "com.spotify.client"
    policy.observe(enabled: true, playing: true, source: music)
    policy.failed(source: music, reason: .noPCM)
    for _ in 0..<5 {
        policy.observe(enabled: true, playing: true, source: music)
        #expect(!policy.allows(source: music))
    }
    policy.observe(enabled: true, playing: false, source: music)
    #expect(!policy.allows(source: music))
    policy.observe(enabled: true, playing: true, source: music)
    #expect(policy.allows(source: music))
    policy.failed(source: music, reason: .noPCM)
    policy.wake()
    #expect(policy.allows(source: music))
    policy.failed(source: music, reason: .noPCM)
    policy.observe(enabled: true, playing: true, source: spotify)
    #expect(policy.allows(source: spotify))
    policy.observe(enabled: true, playing: true, source: music)
    #expect(policy.allows(source: music))
}

@Test func samePlayerTrackRevisionRetriesNoPCMOncePerSongWithoutPollingStorm() {
    var policy = WaveformRetryPolicy()
    let music = "com.apple.Music"
    policy.observe(enabled: true, playing: true, source: music, trackRevision: 41)
    policy.failed(source: music, reason: .noPCM)
    for _ in 0..<20 {
        policy.observe(enabled: true, playing: true, source: music, trackRevision: 41)
        #expect(!policy.allows(source: music))
    }
    for revision: UInt64 in [42, 43, 44] {
        policy.observe(enabled: true, playing: true, source: music, trackRevision: revision)
        #expect(policy.allows(source: music))
        policy.failed(source: music, reason: .noPCM)
        for _ in 0..<20 {
            policy.observe(enabled: true, playing: true, source: music, trackRevision: revision)
            #expect(!policy.allows(source: music))
        }
    }
}

@Test func setupFailureDoesNotAutoRetryOnPlaybackOrWake() {
    var policy = WaveformRetryPolicy()
    let source = "com.apple.Music"
    policy.observe(enabled: true, playing: true, source: source)
    policy.failed(source: source, reason: .setup)
    policy.observe(enabled: true, playing: false, source: source)
    policy.observe(enabled: true, playing: true, source: source)
    policy.observe(enabled: true, playing: true, source: source, trackRevision: 2)
    policy.observe(enabled: true, playing: true, source: "com.spotify.client", trackRevision: 3)
    policy.wake()
    #expect(!policy.allows(source: source))
    #expect(!policy.allows(source: "com.spotify.client"))
    policy.manualRetry()
    #expect(policy.allows(source: source))
}

@Suite(.enabled(if: ProcessInfo.processInfo.environment["LYRICSX_WAVEFORM_QA"] == "1"))
@MainActor struct OverlayWaveformVisualQA {
    @Test func captureRealControllerWithLongTranslationAndNextLine() async throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: "/tmp/lyricsx-waveform-qa", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let features: [Float] = [0.03, 0.08, 0.2, 0.44, 0.24, 0.05,
            0.02, 0.16, 0.51, 0.3, 0.09, 0.02,
            0.04, 0.12, 0.39, 0.18, 0.05, 0.03,
            0.21, 0.46, 0.22, 0.06, 0.03, 0.01]
        let theme = ArtworkTheme(accent: "DD697D", sung: "F6B8C2", unsung: "85515A", secondary: "AAC6E5")
        for width in [320.0, 620.0, 1000.0] {
            for mode in [OverlaySecondaryMode.both, .next] {
              for light in [false, true] {
                let suite = "LyricsXWaveformQA-" + UUID().uuidString
                let defaults = try #require(UserDefaults(suiteName: suite))
                defer { defaults.removePersistentDomain(forName: suite) }
                let prefs = Preferences(defaults: defaults)
                prefs.overlayWidth = width
                prefs.overlayAdaptiveSize = true
                prefs.overlayWaveformEnabled = true
                prefs.overlaySecondaryMode = mode
                prefs.overlayAppearance = light ? .frosted : .glass
                prefs.overlayTheme = light ? .light : .dark
                prefs.hideWhenPaused = false
                prefs.reduceMotion = true
                let model = AppModel(repository: WaveformQARepository(), preferences: prefs)
                model.session.accept(.init(track: .init(playerID: "qa.player", playerName: "QA",
                    title: "Long bilingual lyric"), position: 1, isPlaying: false), shouldSearch: false)
                let document = LyricsDocument(lines: [
                    .init(id: 0, time: 0,
                        text: "Long lyric, first row\ncomplete second row",
                        translation: "这一段较长的双语歌词要在狭窄悬浮窗里保留两行，并为文字柔光留出空间"),
                    .init(id: 1, time: 8,
                        text: "The following line is also long enough to wrap across the available canvas",
                        translation: "下一句同样会换行")])
                model.session.use(document, persist: false)
                let overlay = OverlayController(model: model, frameAutosaveName: nil,
                    pointerLocation: { NSPoint(x: -10000, y: -10000) })
                defer { overlay.stop(); model.stop() }
                overlay.panel.orderFrontRegardless()
                try await Task.sleep(for: .milliseconds(120))
                let expected = ceil(OverlayWaveformLayout.totalHeight(content:
                    OverlayTextMeasure.height(document: document, index: 0, preferences: prefs,
                        maximumWidth: width), enabled: true))
                #expect(abs(overlay.panel.frame.height - expected) <= 1)
                let root = try #require(overlay.panel.contentView)
                let waveform = try #require(root.subviews.compactMap { $0 as? OverlayWaveformView }.first)
                #expect(waveform.frame.minY == 6 && waveform.frame.height == 18)
                func capture(_ name: String) throws -> NSBitmapImageRep {
                    waveform.injectTestBands(features, style: .monochrome, lightGlass: light, theme: theme)
                    root.layoutSubtreeIfNeeded()
                    let bitmap = try #require(root.bitmapImageRepForCachingDisplay(in: root.bounds))
                    root.cacheDisplay(in: root.bounds, to: bitmap)
                    let png = try #require(bitmap.representation(using: .png, properties: [:]))
                    try png.write(to: directory.appendingPathComponent(name + ".png"))
                    return bitmap
                }
                _ = try capture("native-long-\(Int(width))-\(mode.rawValue)-\(light ? "light" : "dark")")
                if mode == .both {
                    model.session.use(.init(plainText: "Instrumental"), persist: false)
                    try await Task.sleep(for: .milliseconds(120))
                    #expect(model.overlayPresentationMode == .song)
                    #expect(abs(overlay.panel.frame.height - ceil(OverlayWaveformLayout.totalHeight(
                        content: OverlaySongCardLayout(width: width,
                            title: model.session.track?.title, artist: model.session.track?.artist)
                            .baseHeight(waveformEnabled: true),
                        enabled: true))) <= 1)
                    _ = try capture("native-song-\(Int(width))-\(light ? "light" : "dark")")
                    if width == 320 || width == 620 {
                        let title = width == 320 ? "A Long Song Title With Featured Musicians" : "Some Song"
                        let artist = "Artist and Orchestra"
                        model.session.accept(.init(track: .init(playerID: "qa.player", playerName: "QA",
                            title: title, artist: artist), position: 1, isPlaying: false), shouldSearch: false)
                        model.session.use(.init(plainText: "Instrumental"), persist: false)
                        model.artwork = NSImage(size: .init(width: 64, height: 64), flipped: false) { rect in
                            NSColor(srgbRed: 0.35, green: 0.52, blue: 0.75, alpha: 1).setFill()
                            rect.fill()
                            return true
                        }
                        try await Task.sleep(for: .milliseconds(120))
                        #expect(model.overlayPresentationMode == .song)
                        #expect(abs(overlay.panel.frame.height - OverlayWaveformLayout.totalHeight(
                            content: OverlaySongCardLayout(width: width, title: title, artist: artist)
                                .baseHeight(waveformEnabled: true),
                            enabled: true)) <= 1)
                        #expect(waveform.frame.minY == 6 && waveform.frame.height == 18)
                        let bitmap = try capture("native-song-\(Int(width))-title-artist-\(light ? "light" : "dark")")
                        if width == 620 {
                            let image = try #require(bitmap.cgImage)
                            let context = try #require(CGContext(data: nil, width: image.width,
                                height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                            let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
                            var top = image.height, bottom = 0
                            for y in 0..<image.height {
                                for x in 0..<image.width {
                                    let i = y * context.bytesPerRow + x * 4
                                    if Int(bytes[i + 2]) > Int(bytes[i]) + 35,
                                       Int(bytes[i + 2]) > Int(bytes[i + 1]) + 15,
                                       bytes[i + 2] > 150 {
                                        top = min(top, y); bottom = max(bottom, y)
                                    }
                                }
                            }
                            #expect(top < bottom)
                            let scale = CGFloat(image.width) / width
                            let glassTopToArtwork = CGFloat(top) / scale - 6
                            let artworkToWave = CGFloat(image.height) / scale - waveform.frame.maxY
                                - CGFloat(bottom + 1) / scale
                            // This measures the surface edge, not the visible
                            // audio line inside its 18pt view.
                            #expect(abs(glassTopToArtwork - 15.5) <= 1.5)
                            #expect(abs(artworkToWave - 8.5) <= 1.5)
                        }
                    }
                    model.session.use(.init(lines: [.init(id: 0, time: 30, text: "A later lyric")]), persist: false)
                    model.session.seek(to: 0)
                    try await Task.sleep(for: .milliseconds(120))
                    #expect(model.overlayPresentationMode == .waiting)
                    #expect(abs(overlay.panel.frame.height - OverlayWaveformLayout.totalHeight(
                        content: OverlayPresentationMode.waitingHeight, enabled: true)) <= 1)
                    _ = try capture("native-waiting-\(Int(width))-\(light ? "light" : "dark")")
                }
              }
            }
        }
    }
    @Test func nativeSongCardBalancesArtworkAgainstTheVisibleWaveLine() async throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: "/tmp/lyricsx-waveform-song-spacing-qa", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Mid/low feature levels put the visible line inside the wave surface;
        // comparing against silence isolates it from the glass and artwork.
        let features = (0..<24).map { index in Float(0.18 + 0.04 * sin(Double(index) * 0.7)) }
        let silence = [Float](repeating: 0, count: 24)
        let longTitle = "A Long Song Title With Featured Musicians Across The Night And Into Another Long Chorus Of Lights"
        for width in [320.0, 620.0, 1000.0] {
            for (variant, title, artist) in [
                ("short", "Some Song", "Artist and Orchestra"),
                ("long", longTitle, "Artist and Orchestra"),
                ("no-artist", "Some Song", "")
            ] {
                for light in [false, true] {
                    let suite = "LyricsXSongSpacingQA-" + UUID().uuidString
                    let defaults = try #require(UserDefaults(suiteName: suite))
                    defer { defaults.removePersistentDomain(forName: suite) }
                    let prefs = Preferences(defaults: defaults)
                    prefs.overlayVisible = true; prefs.hideWhenPaused = false; prefs.hideOverlayOnHover = false
                    prefs.overlayWidth = width; prefs.overlayAdaptiveSize = true
                    prefs.overlayWaveformEnabled = true; prefs.reduceMotion = true
                    prefs.overlayAppearance = light ? .frosted : .glass
                    prefs.overlayTheme = light ? .light : .dark
                    let model = AppModel(repository: WaveformQARepository(), preferences: prefs)
                    model.session.accept(.init(track: .init(playerID: "qa.player", playerName: "QA",
                        title: title, artist: artist), position: 1, isPlaying: false),
                        shouldSearch: false)
                    model.session.use(.init(plainText: "Instrumental"), persist: false)
                    model.artwork = NSImage(size: .init(width: 64, height: 64), flipped: false) { rect in
                        NSColor(srgbRed: 0.35, green: 0.52, blue: 0.75, alpha: 1).setFill()
                        rect.fill(); return true
                    }
                    let overlay = OverlayController(model: model, frameAutosaveName: nil,
                        pointerLocation: { NSPoint(x: -10000, y: -10000) })
                    overlay.panel.orderFrontRegardless()
                    try await Task.sleep(for: .milliseconds(90))
                    let root = try #require(overlay.panel.contentView)
                    let wave = try #require(root.subviews.compactMap { $0 as? OverlayWaveformView }.first)
                    let card = OverlaySongCardLayout(width: width, title: title, artist: artist)
                    #expect(abs(overlay.panel.frame.height - OverlayWaveformLayout.totalHeight(
                        content: card.baseHeight(waveformEnabled: true), enabled: true)) <= 1)
                    func capture(_ bands: [Float]) throws -> NSBitmapImageRep {
                        wave.injectTestBands(bands, style: .monochrome, lightGlass: light, theme: .neutral)
                        root.layoutSubtreeIfNeeded()
                        let bitmap = try #require(root.bitmapImageRepForCachingDisplay(in: root.bounds))
                        root.cacheDisplay(in: root.bounds, to: bitmap)
                        return bitmap
                    }
                    let blank = try capture(silence)
                    let active = try capture(features)
                    let name = "song-\(Int(width))-\(variant)-\(light ? "light" : "dark")"
                    let png = try #require(active.representation(using: .png, properties: [:]))
                    try png.write(to: directory.appendingPathComponent(name + ".png"))
                    func pixels(_ bitmap: NSBitmapImageRep) throws -> [UInt8] {
                        let image = try #require(bitmap.cgImage)
                        let context = try #require(CGContext(data: nil, width: image.width,
                            height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
                        return Array(UnsafeBufferPointer(start: bytes, count: context.bytesPerRow * image.height))
                    }
                    let before = try pixels(blank), after = try pixels(active)
                    let pixelWidth = active.pixelsWide, pixelHeight = active.pixelsHigh
                    let scale = Double(pixelWidth) / width
                    var artTop = pixelHeight, artBottom = 0, artLeft = pixelWidth, artRight = 0
                    for y in 0..<pixelHeight {
                        for x in 0..<pixelWidth {
                            let offset = (y * pixelWidth + x) * 4
                            if Int(after[offset + 2]) > Int(after[offset]) + 35,
                               Int(after[offset + 2]) > Int(after[offset + 1]) + 15,
                               after[offset + 2] > 150 {
                                artTop = min(artTop, y); artBottom = max(artBottom, y)
                                artLeft = min(artLeft, x); artRight = max(artRight, x)
                            }
                        }
                    }
                    #expect(artTop < artBottom && artLeft < artRight)
                    let sampleX = (artLeft + artRight) / 2
                    let lower = max(artBottom + 1, pixelHeight - Int(23 * scale))
                    let upper = pixelHeight - Int(10 * scale)
                    var strongestRow = lower, strongestDifference = 0
                    for y in lower..<upper {
                        var difference = 0
                        for x in max(0, sampleX - 5)..<min(pixelWidth, sampleX + 6) {
                            let offset = (y * pixelWidth + x) * 4
                            for channel in 0..<3 {
                                difference += abs(Int(after[offset + channel]) - Int(before[offset + channel]))
                            }
                        }
                        if difference > strongestDifference { strongestDifference = difference; strongestRow = y }
                    }
                    #expect(strongestDifference > 30, "No visible wave line in \(name)")
                    let topGap = Double(artTop) / scale - 6
                    let lowerGap = Double(strongestRow - artBottom - 1) / scale
                    print("SONG GAP \(name): top=\(topGap)pt bottom=\(lowerGap)pt")
                    #expect(abs(topGap - lowerGap) <= 3, "\(name): top \(topGap)pt, bottom \(lowerGap)pt")
                    overlay.stop(); model.stop()
                }
            }
        }
    }
    @Test func captureNativeGlassWithInjectedAudioFeatures() throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: "/tmp/lyricsx-waveform-qa", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Test-only feature frame spanning the measured quiet and loud bands;
        // broad synthetic humps saturated the geometry cap and hid its range.
        let features: [Float] = [0.04, 0.09, 0.24, 0.55, 0.31, 0.08,
            0.02, 0.15, 0.43, 0.58, 0.36, 0.12,
            0.03, 0.06, 0.26, 0.48, 0.22, 0.05,
            0.02, 0.18, 0.34, 0.14, 0.04, 0.01]
        let theme = ArtworkTheme(accent: "DD697D", sung: "F6B8C2", unsung: "85515A", secondary: "AAC6E5")
        for width in [320.0, 620.0] {
            for mode in ["song", "lyrics"] {
                let base: CGFloat = mode == "song"
                    ? OverlaySongCardLayout(width: width).baseHeight(waveformEnabled: true) : 160
                for light in [false, true] {
                    for style in OverlayWaveformStyle.allCases {
                        let height = OverlayWaveformLayout.totalHeight(content: base, enabled: true)
                        let frame = NSRect(x: 0, y: 0, width: width, height: height)
                        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
                        window.isReleasedWhenClosed = false
                        window.isOpaque = false
                        window.backgroundColor = .clear
                        window.appearance = NSAppearance(named: light ? .aqua : .darkAqua)
                        let root = NSView(frame: frame)
                        root.wantsLayer = true
                        let glass = OverlayGlassBackground(frame: root.bounds.insetBy(dx: 6, dy: 6))
                        glass.configure(appearance: light ? .frosted : .glass,
                            transparency: 0.2, frostAmount: 0.68,
                            reduceTransparency: false, reduceMotion: true,
                            theme: light ? .light : .dark)
                        root.addSubview(glass)
                        let title = NSTextField(labelWithString: mode == "song" ? "歌曲信息卡片 · 当前播放器" : "当前歌词\n下一句预览")
                        title.textColor = light ? .black : .white
                        title.alignment = .center
                        title.font = .systemFont(ofSize: mode == "song" ? 20 : 26, weight: .semibold)
                        let contentHeight = OverlayWaveformLayout.contentHeight(base: base, enabled: true)
                        title.frame = NSRect(x: 25, y: 32, width: width - 50, height: contentHeight - 34)
                        root.addSubview(title)
                        let waveform = OverlayWaveformView(frame: NSRect(x: 26, y: 6, width: width - 52, height: 18))
                        root.addSubview(waveform)
                        waveform.injectTestBands(features, style: style, lightGlass: light, theme: theme)
                        window.contentView = root
                        window.orderFrontRegardless()
                        root.layoutSubtreeIfNeeded()
                        let bitmap = try #require(root.bitmapImageRepForCachingDisplay(in: root.bounds))
                        root.cacheDisplay(in: root.bounds, to: bitmap)
                        let png = try #require(bitmap.representation(using: .png, properties: [:]))
                        try png.write(to: directory.appendingPathComponent("\(mode)-\(Int(width))-\(light ? "light" : "dark")-\(style.rawValue).png"))
                        window.close()
                    }
                }
            }
        }
    }
}
