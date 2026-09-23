import AppKit
import ScreenCaptureKit
import Testing
import LyricsXCore
@testable import LyricsXApp

@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["LYRICSX_WINDOW_QA"] == "1"))
@MainActor struct NativeOverlayMotionTests {
    private final class RecordingDelegate: NSObject, SCRecordingOutputDelegate {
        nonisolated func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {}
        nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) { print("Resize recording failed: \(error)") }
        nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) { print("Resize recording finished") }
    }
    private final class Delegate: NSObject, NSApplicationDelegate {
        func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
        func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { .terminateCancel }
    }
    private struct Repository: LyricsRepository {
        func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
        func save(_ document: LyricsDocument, for track: Track) async throws {}
    }
    @Test func clearGlassExpandsAndContractsThroughVisibleIntermediateHeights() async throws {
        _ = NSApplication.shared
        let delegate = Delegate(), previous = NSApp.delegate
        NSApp.delegate = delegate
        defer { NSApp.delegate = previous; withExtendedLifetime(delegate) {} }
        NSApp.finishLaunching()
        let name = "LyricsXMotionQA-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let prefs = Preferences(defaults: defaults)
        prefs.overlayVisible = true; prefs.hideWhenPaused = false
        prefs.hideOverlayOnHover = false; prefs.reduceMotion = false
        prefs.overlayAppearance = .glass; prefs.overlaySecondaryMode = .translation
        let model = AppModel(repository: Repository(), preferences: prefs)
        model.session.accept(.init(track: .init(playerID: "fixture", playerName: "Fixture", title: "Resize fixture"),
            position: 0, isPlaying: false), shouldSearch: false)
        let doc = LyricsDocument(lines: [
            .init(id: 0, time: 0, text: ""),
            .init(id: 1, time: 10, text: "A longer lyric needs two lines\nThe glass must grow smoothly", translation: "第一行翻译\n第二行翻译"),
            .init(id: 2, time: 20, text: "Short", translation: "短句")])
        model.session.use(doc, persist: false)
        let overlay = OverlayController(model: model, frameAutosaveName: nil,
            pointerLocation: { .init(x: -10000, y: -10000) })
        overlay.panel.level = .statusBar
        overlay.panel.orderFrontRegardless()
        defer { overlay.stop(); model.stop() }
        let top = overlay.panel.frame.maxY
        let captureRect = NSRect(x: overlay.panel.frame.minX - 20, y: top - 260,
            width: overlay.panel.frame.width + 40, height: 280)
        let backdrop = NSPanel(contentRect: captureRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        backdrop.isReleasedWhenClosed = false; backdrop.hidesOnDeactivate = false
        backdrop.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        backdrop.backgroundColor = NSColor(srgbRed: 0.15, green: 0.45, blue: 0.75, alpha: 1)
        backdrop.orderFrontRegardless()
        defer { backdrop.close() }
        var stream: SCStream?
        let recorder = RecordingDelegate()
        if let path = ProcessInfo.processInfo.environment["LYRICSX_RESIZE_RECORDING"] {
            try #require(CGPreflightScreenCaptureAccess())
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            let screen = try #require(overlay.panel.screen)
            let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
            let display = try #require(content.displays.first { $0.displayID == displayID })
            let config = SCStreamConfiguration()
            config.sourceRect = CGRect(x: captureRect.minX - screen.frame.minX, y: screen.frame.maxY - captureRect.maxY,
                width: captureRect.width, height: captureRect.height)
            config.width = Int(captureRect.width * 2); config.height = Int(captureRect.height * 2)
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            config.showsCursor = false; config.capturesAudio = false
            let recordingConfig = SCRecordingOutputConfiguration()
            recordingConfig.outputURL = URL(fileURLWithPath: path)
            let capture = SCStream(filter: SCContentFilter(display: display, excludingWindows: []), configuration: config, delegate: nil)
            try capture.addRecordingOutput(SCRecordingOutput(configuration: recordingConfig, delegate: recorder))
            try await capture.startCapture()
            stream = capture
        }
        try await Task.sleep(for: .milliseconds(350))
        for position in [10.0, 20, 0, 10] {
            let initial = overlay.panel.frame.height
            let started = ProcessInfo.processInfo.systemUptime
            model.session.seek(to: position)
            var changes: [(Double, Double)] = []
            var previousHeight = initial
            for _ in 0..<100 {
                NSApp.updateWindows()
                try await Task.sleep(for: .milliseconds(8))
                let frame = overlay.panel.frame
                if frame.height != previousHeight {
                    changes.append((ProcessInfo.processInfo.systemUptime - started, frame.height))
                    previousHeight = frame.height
                }
                #expect(abs(frame.maxY - top) <= 1)
                let root = try #require(overlay.panel.contentView)
                let background = try #require(root.subviews.first as? OverlayGlassBackground)
                let glass = try #require(background.subviews.first as? NSGlassEffectView)
                #expect(glass.frame == background.bounds)
                #expect(abs(background.frame.height - (frame.height - 12)) <= 1)
            }
            let last = overlay.panel.frame.height
            print("RESIZE \(position): \(initial) -> \(last), frames=\(changes)")
            #expect(abs(last - initial) > 10)
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                #expect(changes.count >= 8, "A terminal snap must not pass as animated resize")
                #expect(try #require(changes.last).0 - #require(changes.first).0 > 0.15)
                #expect(changes.allSatisfy { $0.1 >= min(initial, last) && $0.1 <= max(initial, last) })
            }
        }
        if let stream { try await stream.stopCapture(); try await Task.sleep(for: .milliseconds(200)) }
        withExtendedLifetime(recorder) {}
    }
}
