import AppKit
import SwiftUI
import CoreImage
import CoreVideo
import ScreenCaptureKit
import Testing
import LyricsXCore
@testable import LyricsXApp

@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["LYRICSX_HDR_PARITY_QA"] == "1"))
@MainActor struct NativeHDRParityTests {
    private final class Delegate: NSObject, NSApplicationDelegate {
        func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
        func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { .terminateCancel }
    }
    private struct Repository: LyricsRepository {
        func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
        func save(_ document: LyricsDocument, for track: Track) async throws {}
    }
    @Test func compareProductionMainAndGlassOutput() async throws {
        _ = NSApplication.shared
        let delegate = Delegate(), previous = NSApp.delegate
        NSApp.delegate = delegate
        defer { NSApp.delegate = previous; withExtendedLifetime(delegate) {} }
        NSApp.finishLaunching()
        let suite = "LyricsXHDRParity-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.hideWhenPaused = false; prefs.hideOverlayOnHover = false
        prefs.appTheme = .dark; prefs.overlayTheme = .dark
        prefs.lyricHDR = true; prefs.lyricHDRBrightness = 4
        prefs.fontSize = 32; prefs.mainLyricFontSize = 32
        let model = AppModel(repository: Repository(), preferences: prefs)
        model.session.accept(.init(track: .init(playerID: "fixture", playerName: "Fixture", title: "HDR parity"),
                                   position: 1.6, isPlaying: false), shouldSearch: false)
        model.session.use(.init(lines: [.init(id: 0, time: 0, text: "Stay in the light", translation: "同一时刻的长音",
                                             words: [.init(text: "Stay", start: 0.1, end: 3.2)])]), persist: false)
        let overlay = OverlayController(model: model, frameAutosaveName: nil, pointerLocation: { .init(x: -10000, y: -10000) })
        let screen = try #require(overlay.panel.screen)
        try #require(HDRDisplayCapability(screen: screen).supported, "Native HDR QA requires an EDR display")
        let bounds = screen.visibleFrame
        overlay.panel.setFrameOrigin(.init(x: bounds.maxX - overlay.panel.frame.width - 10, y: bounds.maxY - overlay.panel.frame.height - 10))
        let main = NSWindow(contentRect: .init(x: bounds.minX + 10, y: bounds.minY + 10, width: 1000, height: 600),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        main.isReleasedWhenClosed = false
        main.contentView = NSHostingView(rootView: MainView(model: model).preferredColorScheme(.dark).hdrDisplayScope(requested: true))
        main.level = .statusBar; overlay.panel.level = .statusBar
        main.orderFrontRegardless(); overlay.panel.orderFrontRegardless()
        defer { overlay.stop(); model.stop(); main.close() }
        try #require(!main.frame.intersects(overlay.panel.frame), "Fixture windows must not cover each other")
        try #require(CGPreflightScreenCaptureAccess())
        func settle() async throws { for _ in 0..<100 { NSApp.updateWindows(); try await Task.sleep(for: .milliseconds(10)) } }
        func capture(_ window: NSWindow, name: String, label: String) async throws -> Float {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
            let display = try #require(content.displays.first { $0.displayID == id })
            let config = SCStreamConfiguration()
            config.captureDynamicRange = .hdrCanonicalDisplay; config.pixelFormat = kCVPixelFormatType_64RGBAHalf; config.showsCursor = false
            let frame = window.frame
            config.sourceRect = .init(x: frame.minX - screen.frame.minX, y: screen.frame.maxY - frame.maxY, width: frame.width, height: frame.height)
            config.width = Int(frame.width * screen.backingScaleFactor); config.height = Int(frame.height * screen.backingScaleFactor)
            let image = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(display: display, excludingWindows: []), configuration: config)
            let dir = URL(fileURLWithPath: "/tmp/lyricsx-hdr-parity")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(label)-\(name).png"))
            let space = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
            let context = CIContext(options: [.workingColorSpace: space, .outputColorSpace: space])
            var pixels = [Float](repeating: 0, count: image.width * image.height * 4)
            pixels.withUnsafeMutableBytes { context.render(CIImage(cgImage: image), toBitmap: $0.baseAddress!, rowBytes: image.width * 16, bounds: .init(x: 0, y: 0, width: image.width, height: image.height), format: .RGBAf, colorSpace: space) }
            var peak: Float = 0
            for y in Int(Double(image.height) * 0.22)..<Int(Double(image.height) * 0.78) {
                for x in Int(Double(image.width) * (name == "main" ? 0.38 : 0.15))..<Int(Double(image.width) * 0.9) {
                    let i = (y * image.width + x) * 4
                    peak = max(peak, pixels[i], pixels[i + 1], pixels[i + 2])
                }
            }
            print("PRODUCTION HDR \(label) \(name) peak=\(peak) current=\(screen.maximumExtendedDynamicRangeColorComponentValue)")
            return peak
        }
        for (style, separated, theme) in [(OverlayAppearance.glass, false, false),
                                           (.frosted, false, false), (.glass, true, false), (.glass, false, true)] {
            prefs.overlayAppearance = style
            prefs.separateWordColors = separated
            prefs.followArtworkColors = theme
            prefs.artworkTheme = .init(accent: "DDAA00", sung: "FFEEDD", unsung: "776655", secondary: "CCBBAA")
            var peaks: [(Float, Float)] = []
            for brightness in [1.0, 2.5, 4.0, 1.0] {
                prefs.lyricHDRBrightness = brightness
                try await settle()
                model.mainWindowVisible = true
                try await settle()
                let label = "\(style)-separate-\(separated)-theme-\(theme)-\(brightness)"
                peaks.append((try await capture(main, name: "main", label: label), try await capture(overlay.panel, name: "overlay", label: label)))
            }
            #expect(peaks[2].0 > peaks[0].0 && peaks[2].1 > peaks[0].1)
            for (mainPeak, overlayPeak) in peaks {
                #expect(abs(mainPeak - overlayPeak) / max(mainPeak, overlayPeak) < 0.1,
                    "Glass and separate-word palettes must not compress the HDR emitter")
            }
            #expect(abs(peaks[3].1 - peaks[0].1) < 0.03, "Returning to 1× restores SDR ink")
        }
    }
}
