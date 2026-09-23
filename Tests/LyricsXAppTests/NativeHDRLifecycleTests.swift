import AppKit
import SwiftUI
import CoreImage
import CoreVideo
import ScreenCaptureKit
import Testing
import LyricsXCore
@testable import LyricsXApp

@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["LYRICSX_HDR_FOCUS_QA"] == "1"))
@MainActor struct NativeHDRLifecycleTests {
    private final class FixtureDelegate: NSObject, NSApplicationDelegate {
        func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
        func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { .terminateCancel }
    }
    private struct Repository: LyricsRepository {
        func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
        func save(_ document: LyricsDocument, for track: Track) async throws {}
    }
    @Test func nativeHDRSurvivesOverlayAndMainVisibilityChanges() async throws {
        _ = NSApplication.shared
        let delegate = FixtureDelegate(), oldDelegate = NSApp.delegate
        NSApp.delegate = delegate
        defer { NSApp.delegate = oldDelegate; withExtendedLifetime(delegate) {} }
        NSApp.finishLaunching()
        let suite = "LyricsXHDRQA-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlayVisible = true; prefs.hideWhenPaused = false; prefs.hideOverlayOnHover = false
        prefs.lyricHDR = true; prefs.lyricHDRBrightness = 3.5; prefs.overlayTheme = .light
        let model = AppModel(repository: Repository(), preferences: prefs)
        let playing = ProcessInfo.processInfo.environment["LYRICSX_HDR_PLAYING_QA"] == "1"
        let position = playing ? 450.0 : 1.6
        model.session.accept(.init(track: .init(playerID: "fixture", playerName: "Fixture", title: "HDR focus test"),
            position: position, isPlaying: playing), shouldSearch: false)
        let line = LyricLine(id: 0, time: 0, text: "Stay in the light", translation: "保持文字清晰",
            words: [.init(text: "Stay", start: 0.1, end: playing ? 1000 : 3.2)])
        model.session.use(.init(lines: [line]), persist: false)
        var pointer = NSPoint(x: -10000, y: -10000)
        let overlay = OverlayController(model: model, frameAutosaveName: nil,
            pointerLocation: { pointer })
        let displayFrame = try #require(overlay.panel.screen ?? NSScreen.screens.first).visibleFrame
        overlay.panel.setFrameOrigin(.init(x: displayFrame.midX - overlay.panel.frame.width / 2,
            y: displayFrame.midY - overlay.panel.frame.height / 2))
        // Clear glass reveals the desktop. Hold that input constant so hiding
        // the main fixture cannot change the measured halo's background.
        let backdrop = NSPanel(contentRect: overlay.panel.frame.insetBy(dx: -20, dy: -20),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        backdrop.isReleasedWhenClosed = false
        backdrop.hidesOnDeactivate = false
        backdrop.isOpaque = true
        backdrop.backgroundColor = NSColor(white: 0.35, alpha: 1)
        backdrop.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        let main = NSWindow(contentRect: .init(x: displayFrame.minX + 60, y: displayFrame.minY + 60, width: 450, height: 180),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        main.isReleasedWhenClosed = false
        main.level = .statusBar
        overlay.panel.level = .statusBar
        let words = LyricTypography().adaptedForGlass(dark: false).wordColors
        main.contentView = NSHostingView(rootView:
            WordHighlight(line: line, time: position, active: true, text: line.text,
                effects: .init(lift: false, glow: true, hdr: true, hdrBrightness: 3.5))
                .environment(\.lyricWordColors, words).font(.system(size: 36, weight: .semibold))
                .padding(30).frame(width: 450, height: 180).background(.gray)
                .hdrDisplayScope(requested: true))
        defer { overlay.stop(); model.stop(); main.close(); backdrop.close() }
        func settle() async throws {
            for _ in 0..<60 {
                NSApp.updateWindows()
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        var peaks: [String: [Float]] = [:]
        var overlayPeaks: [String: Float] = [:]
        func sample(_ label: String, overlayHDR: Bool = true, stable: Bool = true) async throws {
            print("HDR PHASE \(label): active=\(NSApp.isActive) mainKey=\(main.isKeyWindow)")
            for (name, window) in [("overlay", overlay.panel as NSWindow), ("main", main)] {
                print("\(name) headroom=\(window.screen?.maximumExtendedDynamicRangeColorComponentValue ?? 0) potential=\(window.screen?.maximumPotentialExtendedDynamicRangeColorComponentValue ?? 0)")
                func layers(_ layer: CALayer, depth: Int) {
                    print("\(name) \(depth) \(type(of: layer)) range=\(layer.preferredDynamicRange.rawValue) headroom=\(layer.contentsHeadroom) format=\(layer.contentsFormat.rawValue) contents=\(layer.contents.map { String(describing: type(of: $0)) } ?? "nil")")
                    for child in layer.sublayers ?? [] { layers(child, depth: depth + 1) }
                }
                if ProcessInfo.processInfo.environment["LYRICSX_HDR_LAYER_QA"] == "1",
                   let root = window.contentView?.layer { layers(root, depth: 0) }
                func readers(_ view: NSView) -> [HDRWindowReaderView] {
                    (view as? HDRWindowReaderView).map { [$0] } ?? view.subviews.flatMap(readers)
                }
                if ProcessInfo.processInfo.environment["LYRICSX_HDR_PIXEL_QA"] == "1", window.isVisible, !window.isMiniaturized {
                    try #require(CGPreflightScreenCaptureAccess())
                    let shareable = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
                    let screen = try #require(window.screen)
                    let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
                    let display = try #require(shareable.displays.first { $0.displayID == displayID })
                    let config = SCStreamConfiguration()
                    config.captureDynamicRange = .hdrCanonicalDisplay
                    config.pixelFormat = kCVPixelFormatType_64RGBAHalf
                    config.showsCursor = false
                    let frame = window.frame
                    config.sourceRect = CGRect(x: frame.minX - screen.frame.minX, y: screen.frame.maxY - frame.maxY,
                        width: frame.width, height: frame.height)
                    config.width = Int(frame.width * screen.backingScaleFactor)
                    config.height = Int(frame.height * screen.backingScaleFactor)
                    let image = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(display: display, excludingWindows: []), configuration: config)
                    if let directory = ProcessInfo.processInfo.environment["LYRICSX_HDR_CAPTURE_DIR"] {
                        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                        let bitmap = NSBitmapImageRep(cgImage: image)
                        try bitmap.representation(using: .png, properties: [:])?.write(to:
                            URL(fileURLWithPath: directory).appendingPathComponent("\(label)-\(name).png"))
                    }
                    let space = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
                    let context = CIContext(options: [.workingColorSpace: space, .outputColorSpace: space])
                    var pixels = [Float](repeating: 0, count: image.width * image.height * 4)
                    pixels.withUnsafeMutableBytes {
                        context.render(CIImage(cgImage: image), toBitmap: $0.baseAddress!, rowBytes: image.width * 16,
                            bounds: CGRect(x: 0, y: 0, width: image.width, height: image.height), format: .RGBAf, colorSpace: space)
                    }
                    // Measure central lyric pixels, excluding native glass
                    // edges and controls which can themselves contain EDR.
                    var peak: Float = 0
                    for y in Int(Double(image.height) * 0.22)..<Int(Double(image.height) * 0.78) {
                        for x in Int(Double(image.width) * 0.15)..<Int(Double(image.width) * 0.85) {
                            let i = (y * image.width + x) * 4
                            peak = max(peak, pixels[i], pixels[i + 1], pixels[i + 2])
                        }
                    }
                    print("NATIVE LYRIC HDR PIXEL \(label) \(name): \(peak)")
                    if name == "overlay" { overlayPeaks[label] = peak }
                    if name == "overlay" && !overlayHDR {
                        #expect(peak <= 1.05, "The control capture must be ordinary SDR lyric ink")
                    } else {
                        if stable { peaks[name, default: []].append(peak) }
                        if name == "main" || prefs.lyricHDRBrightness >= 2.5 {
                            #expect(peak > 1.05, "Native compositor lost the HDR emitter")
                        }
                    }
                }
                let bindings = window.contentView.map(readers) ?? []
                #expect(!bindings.isEmpty)
                for binding in bindings {
                    #expect(binding.observing)
                    #expect(binding.output.capability?.supported == window.screen.map { HDRDisplayCapability(screen: $0).supported })
                    let expectedEDR = window.isVisible && !window.isMiniaturized && (name == "main" || overlayHDR)
                    let expected = expectedEDR ? (name == "main" ? 3.5 : prefs.lyricHDRBrightness) : 1
                    #expect(binding.edrSurface.layer.wantsExtendedDynamicRangeContent == (expected > 1))
                    #expect(binding.edrSurface.requestedHeadroom == expected)
                    print("INDEPENDENT EDR \(label) \(name): request=\(binding.edrSurface.requestedHeadroom) submissions=\(binding.edrSurface.presentationCount)")
                }
            }
        }
        // Begin without ever showing the main window, then test both orders.
        backdrop.orderFrontRegardless(); overlay.panel.orderFrontRegardless()
        try await settle(); try await Task.sleep(for: .seconds(3))
        try await sample("overlay-only-cold-start")
        main.makeKeyAndOrderFront(nil)
        try await settle(); try await sample("key")

        main.miniaturize(nil); try await settle(); try await sample("minimized")
        main.deminiaturize(nil); main.makeKeyAndOrderFront(nil); try await settle(); try await sample("restored")
        main.orderOut(nil); try await settle(); try await sample("main-hidden")
        // Wait through the display-headroom ramp, not just a single rendered
        // frame. Captured float pixels alone did not reveal the old failure.
        try await Task.sleep(for: .seconds(4)); try await sample("main-hidden-settled")
        main.close(); try await settle(); try await sample("main-closed")
        prefs.lyricHDR = false; try await settle(); try await sample("overlay-hdr-off", overlayHDR: false)
        prefs.lyricHDR = true; try await settle(); try await sample("overlay-hdr-on-again")
        prefs.overlayLocked = true; prefs.hideOverlayOnHover = true
        try await settle()
        pointer = NSPoint(x: overlay.panel.frame.midX, y: overlay.panel.frame.midY)
        overlay.refreshAppearance(at: pointer); try await settle()
        #expect(overlay.lyricHostingView.alphaValue == 1, "HDR host must not flatten through an AppKit alpha fade")
        #expect(!overlay.isRenderingLyrics)
        try await sample("hover-hidden", overlayHDR: false)
        pointer = NSPoint(x: -10000, y: -10000)
        overlay.refreshAppearance(at: pointer); try await settle()
        #expect(overlay.lyricHostingView.alphaValue == 1)
        try await sample("hover-revealed")
        #expect(!overlay.panel.isKeyWindow)
        for values in peaks.values {
            #expect(try #require(values.max()) - #require(values.min()) < 0.1,
                "Visibility changes should not collapse the native HDR output")
        }
        // Exercise the combinations that a cold, single-material window misses.
        // A native glass surface can retain a cached appearance even while its
        // public appearance/style properties already report the new settings.
        for (style, theme) in [(OverlayAppearance.frosted, InterfaceTheme.dark),
                               (.frosted, .light), (.glass, .light),
                               (.frosted, .system), (.glass, .dark)] {
            prefs.overlayAppearance = style; prefs.overlayTheme = theme
            try await settle(); try await sample("material-\(style)-\(theme)")
            for _ in 0..<3 {
                pointer = NSPoint(x: overlay.panel.frame.midX, y: overlay.panel.frame.midY)
                overlay.refreshAppearance(at: pointer)
                try await Task.sleep(for: .milliseconds(40))
                pointer = NSPoint(x: -10000, y: -10000)
                overlay.refreshAppearance(at: pointer)
                try await Task.sleep(for: .milliseconds(40))
            }
            try await settle(); try await sample("interrupted-hover-\(style)-\(theme)")
            prefs.overlayVisible = false; try await settle()
            prefs.overlayVisible = true; try await settle()
            try await sample("ordered-back-\(style)-\(theme)")
        }
        func readers(_ view: NSView) -> [HDRWindowReaderView] {
            (view as? HDRWindowReaderView).map { [$0] } ?? view.subviews.flatMap(readers)
        }
        let surfaces = readers(overlay.lyricHostingView).map(\.edrSurface)
        #expect(!surfaces.isEmpty)
        let submissions = surfaces.map(\.presentationCount)
        try await Task.sleep(for: .seconds(2))
        #expect(surfaces.map(\.presentationCount) == submissions,
            "Stable lyrics must not continuously submit transparent Metal drawables")
        // Change the existing live overlay while its main window stays closed.
        // Rebuilding a fresh ImageRenderer for each value misses stale settings.
        for theme in [InterfaceTheme.light, .dark] {
            prefs.overlayAppearance = .frosted; prefs.overlayTheme = theme
            for (index, value) in [1.0, 1.6, 2.5, 4.0, 2.0, 1.0].enumerated() {
                prefs.lyricHDRBrightness = value
                try await settle()
                try await sample("brightness-\(theme)-\(index)", overlayHDR: value > 1, stable: false)
            }
            if ProcessInfo.processInfo.environment["LYRICSX_HDR_PIXEL_QA"] == "1" {
                let values = try (0..<6).map { try #require(overlayPeaks["brightness-\(theme)-\($0)"]) }
                #expect(values[3] > values[2] && values[2] > values[1] && values[1] > values[0])
                #expect(values[4] < values[3] && values[5] < values[4])
                #expect(abs(values[0] - values[5]) < 0.03, "Returning to 1× must restore ordinary brightness")
            }
        }
    }
}
