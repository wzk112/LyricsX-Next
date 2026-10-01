import AppKit
import SwiftUI
import Testing
@testable import LyricsXApp

private final class GuideOwnerWindow: NSWindow {
    var orderFrontCount = 0
    override func makeKeyAndOrderFront(_ sender: Any?) {
        orderFrontCount += 1
        super.makeKeyAndOrderFront(sender)
    }
}

// CLI test runners do not reliably receive compositor visibility even when
// their windows are ordered on screen. Inject only that signal; the guide,
// ScrollView, geometry callback, session and cancellation remain production.
private final class GuideVisibilityTestWindow: NSWindow {
    override var occlusionState: NSWindow.OcclusionState { isVisible ? .visible : [] }
}

@Observable @MainActor private final class GuideMotionFlags {
    var appReduced = false
}

private struct GuideMotionTestHost: View {
    let demo: GuideDemoSession
    let flags: GuideMotionFlags
    var body: some View {
        ScrollView {
            GuideLiveDemo(kind: "liveGlass", reduced: flags.appReduced, viewportHeight: 450, session: demo)
                .frame(height: 330)
        }.coordinateSpace(name: "guideContent")
    }
}

@Suite @MainActor struct FeatureGuideTests {
    private func fixture(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "LyricsXGuideTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }
    @Test func freshInstallIsDetectedBeforePreferencesWriteMigrationKeys() throws {
        try fixture { defaults in
            let history = GuideHistory(defaults: defaults, version: "2.0.34")
            _ = Preferences(defaults: defaults)
            #expect(history.pending == .tutorial)
            // Closing early is still a presentation; next launch must stay quiet.
            history.didPresent()
            #expect(GuideHistory(defaults: defaults, version: "2.0.34").pending == nil)
        }
    }
    @Test func legacyInstallUpgradeAndSkippedVersionsNeverBecomeANewInstall() throws {
        try fixture { defaults in
            defaults.set(1, forKey: "fixedOverlayWidthVersion")
            let legacy = GuideHistory(defaults: defaults, version: "2.0.34")
            #expect(legacy.pending == .update(previous: nil))
            legacy.didPresent()
            let update = GuideHistory(defaults: defaults, version: "2.0.38")
            #expect(update.pending == .update(previous: "2.0.34"))
            update.didPresent()
            #expect(GuideHistory(defaults: defaults, version: "2.0.38").pending == nil)
            // Reinstalling an already presented version is not another first run.
            #expect(GuideHistory(defaults: defaults, version: "2.0.34").pending == nil)
        }
    }
    @Test func correctedIntroductionAppearsOnceForUsersWhoSawTheWithdrawnBuild() throws {
        try fixture { defaults in
            defaults.set("2.0.34", forKey: "guideLastVersion")
            defaults.set(["2.0.34"], forKey: "guidePresentedVersions")
            let corrected = GuideHistory(defaults: defaults, version: "2.0.34", revision: "complete-2")
            #expect(corrected.pending == .update(previous: "2.0.34"))
            #expect(GuideContent.updates(after: "2.0.34").count == 17)
            corrected.didPresent()
            #expect(GuideHistory(defaults: defaults, version: "2.0.34", revision: "complete-2").pending == nil)
            let nextRevision = GuideHistory(defaults: defaults, version: "2.0.34", revision: "future-content")
            #expect(nextRevision.pending == .update(previous: "2.0.34"))
            nextRevision.didPresent()
            // Going back to an already seen introduction must remain quiet.
            #expect(GuideHistory(defaults: defaults, version: "2.0.34", revision: "complete-2").pending == nil)
        }
    }
    @Test func versionJumpContainsOnlyInterveningReleaseNotes() {
        let release39 = GuideContent.release39Pages.map(\.id)
        let newest = ["waveform38", "overlay38", "mainMotion38", "performanceFlexbar38"]
        let latest = newest + ["glassHDR37", "glassColor36"]
        let current = ["glass35", "appearance35", "motion35", "highlight35", "upgrade35"]
        #expect(GuideContent.latestBaseline == "2.0.39")
        #expect(GuideContent.updates(after: "2.0.37").map(\.id) == GuideContent.release40Pages.map(\.id) + release39 + newest)
        #expect(GuideContent.updates(after: "2.0.35").map(\.id) == GuideContent.release40Pages.map(\.id) + release39 + latest)
        #expect(GuideContent.updates(after: "2.0.34").map(\.id) == GuideContent.release40Pages.map(\.id) + release39 + latest + current)
        #expect(GuideContent.updates(after: "2.0.28").count == 27)
        #expect(GuideContent.updates(after: nil).count == 27)
        #expect(GuideContent.tutorial.count == 16)
        #expect(Set(GuideContent.tutorial.map(\.id)).count == GuideContent.tutorial.count)
        #expect(GuideContent.tutorial.contains { $0.id == "waveform" && $0.illustration == "releaseWaveform38" })
        #expect(GuideContent.tutorial.contains { $0.id == "flexbar" && $0.illustration == "releaseFlexbar38" })
        #expect(GuideContent.updates(after: "2.0.37").suffix(4).map(\.illustration) == [
            "releaseWaveform38", "releaseOverlay38", "livePlayer", "releaseFlexbar38"])
        let waveform = GuideContent.updates(after: "2.0.37")[6]
        #expect(waveform.points.joined().contains("默认关闭"))
        #expect(waveform.points.joined().contains("权限"))
    }
    @Test func build273ShowsOnlyCurrentUpdateOnce() throws {
        try fixture { defaults in
            defaults.set("2.0.37", forKey: "guideLastVersion")
            defaults.set(["2.0.37:glass-hdr-37"], forKey: "guidePresentedEditions")
            let history = GuideHistory(defaults: defaults, version: "2.0.38")
            #expect(history.pending == .update(previous: "2.0.37"))
            #expect(GuideContent.updates(after: "2.0.37").map(\.id)
                == GuideContent.release40Pages.map(\.id) + GuideContent.release39Pages.map(\.id) + ["waveform38", "overlay38", "mainMotion38", "performanceFlexbar38"])
            history.didPresent()
            #expect(GuideHistory(defaults: defaults, version: "2.0.38").pending == nil)
            #expect(defaults.stringArray(forKey: "guidePresentedEditions")?
                .contains("2.0.38:\(GuideContent.revision)") == true)
        }
    }
    @Test func build274ShowsOnlyNewChangesAndAppearsOnce() throws {
        #expect(GuideContent.release39Pages.map(\.id) == ["position39", "hotkeys39", "colors39", "transitions39"])
        #expect(GuideContent.displayUpdates(after: "2.0.38").map(\.id) == GuideContent.release40Pages.map(\.id) + GuideContent.release39Pages.map(\.id))
        #expect(GuideContent.displayUpdates(after: nil).count == 27)
        #expect(!GuideContent.displayUpdates(after: "2.0.38").contains { $0.id == "waveform38" || $0.id == "performanceFlexbar38" })
        #expect(GuideContent.release39Pages.allSatisfy { $0.points.joined().contains("设置") || $0.subtitle.contains("设置") })
        try fixture { defaults in
            defaults.set("2.0.38", forKey: "guideLastVersion")
            defaults.set(["2.0.38:waveform-visuals-38"], forKey: "guidePresentedEditions")
            let repaired = GuideHistory(defaults: defaults, version: "2.0.39")
            #expect(repaired.pending == .update(previous: "2.0.38"))
            repaired.didPresent()
            #expect(GuideHistory(defaults: defaults, version: "2.0.39").pending == nil)
        }
    }
    @Test func build275IntroducesOnlyPositionAndSpacingOnceAndKeepsSettings() throws {
        #expect(GuideContent.release40Pages.map(\.id) == ["position40", "spacing40"])
        #expect(GuideContent.displayUpdates(after: "2.0.39").map(\.id) == ["position40", "spacing40"])
        try fixture { defaults in
            defaults.set("2.0.39", forKey: "guideLastVersion")
            defaults.set(["2.0.39:playback-controls-39"], forKey: "guidePresentedEditions")
            let prefs = Preferences(defaults: defaults)
            prefs.mainLyricPosition = .custom
            prefs.mainLyricCustomPercent = 12
            prefs.overlayTextSpacing.primaryLineSpacing = 10
            let update = GuideHistory(defaults: defaults, version: "2.0.40")
            #expect(update.pending == .update(previous: "2.0.39"))
            update.didPresent()
            #expect(GuideHistory(defaults: defaults, version: "2.0.40").pending == nil)
            let restored = Preferences(defaults: defaults)
            #expect(restored.mainLyricPosition == .custom && restored.mainLyricCustomPercent == 12)
            #expect(restored.overlayTextSpacing.primaryLineSpacing == 10)
        }
    }
    @Test func spacingDemonstrationUsesActualMultilineLyricsAndBothAuxiliaryRows() throws {
        let demo = GuideDemoSession(reduced: true, spacingDemo: true)
        defer { demo.stop() }
        let document = try #require(demo.model.session.document)
        #expect(document.lines[0].text.contains("\n") && document.lines[0].translation?.contains("\n") == true)
        #expect(demo.model.preferences.overlaySecondaryMode == .both)
        let original = demo.height
        demo.model.preferences.overlayTextSpacing.primaryLineSpacing = 10
        demo.model.preferences.overlayTextSpacing.translationLineSpacing = 6
        #expect(demo.height > original + 16)
        demo.nextTrack()
        #expect(demo.model.session.document?.lines[0].text.contains("\n") == true)
    }
    @Test func build269ShowsInterveningUpdatesOnce() throws {
        try fixture { defaults in
            defaults.set("2.0.35", forKey: "guideLastVersion")
            defaults.set(["2.0.35:glass-35"], forKey: "guidePresentedEditions")
            let history = GuideHistory(defaults: defaults, version: "2.0.38", revision: GuideContent.revision)
            #expect(history.pending == .update(previous: "2.0.35"))
            #expect(GuideContent.updates(after: "2.0.35").map(\.id) == GuideContent.release40Pages.map(\.id) + GuideContent.release39Pages.map(\.id) + [
                "waveform38", "overlay38", "mainMotion38", "performanceFlexbar38", "glassHDR37", "glassColor36"])
            history.didPresent()
            #expect(GuideHistory(defaults: defaults, version: "2.0.38", revision: GuideContent.revision).pending == nil)
        }
    }
    @Test func correctedGlassPolicyIntroductionAppearsOnceForBuild270() throws {
        try fixture { defaults in
            defaults.set("2.0.36", forKey: "guideLastVersion")
            defaults.set(["2.0.36:glass-color-36"], forKey: "guidePresentedEditions")
            let history = GuideHistory(defaults: defaults, version: "2.0.36")
            #expect(history.pending == .update(previous: "2.0.36"))
            history.didPresent()
            #expect(GuideHistory(defaults: defaults, version: "2.0.36").pending == nil)
        }
    }
    @Test func manualGuideDoesNotConsumeAutomaticReceiptAndCloseReleasesPreviews() throws {
        _ = NSApplication.shared
        try fixture { defaults in
            let history = GuideHistory(defaults: defaults, version: "2.0.34")
            let controller = FeatureGuideController(history: history)
            controller.show(.tutorial)
            #expect(controller.window?.isVisible == true)
            #expect(history.pending == .tutorial)
            controller.close()
            #expect(controller.window == nil)
            controller.showAutomaticIfNeeded()
            #expect(controller.window?.isVisible == true)
            #expect(history.pending == nil)
            controller.close()
            controller.showAutomaticIfNeeded()
            #expect(controller.window == nil)
        }
    }

    @Test func closingGuideKeepsAndRestoresTheWindowThatOpenedIt() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXGuideTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = GuideOwnerWindow(contentRect: .init(x: 0, y: 0, width: 500, height: 400),
                                     styleMask: [.titled, .closable], backing: .buffered, defer: false)
        owner.isReleasedWhenClosed = false
        owner.makeKeyAndOrderFront(nil)
        defer { owner.close() }

        let controller = FeatureGuideController(history: GuideHistory(defaults: defaults, version: "2.0.34"))
        controller.show(.update(previous: "2.0.33"))
        #expect(controller.window?.isVisible == true)
        #expect(owner.isVisible)
        controller.close()
        #expect(controller.window == nil)
        await Task.yield()
        #expect(owner.isVisible)
        #expect(owner.orderFrontCount == 2)
    }

    @Test func scheduledAutomaticGuideWaitsForAHostWindowAndPresentsOnce() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXGuideTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = GuideOwnerWindow(contentRect: .init(x: 0, y: 0, width: 500, height: 400),
                                     styleMask: [.titled, .closable], backing: .buffered, defer: false)
        owner.isReleasedWhenClosed = false
        owner.orderFrontRegardless()
        defer { owner.close() }

        let history = GuideHistory(defaults: defaults, version: "2.0.34")
        let controller = FeatureGuideController(history: history)
        controller.scheduleAutomaticPresentation()
        for _ in 0..<20 where controller.window == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(controller.window?.isVisible == true)
        #expect(history.pending == nil)
        controller.close()
        controller.scheduleAutomaticPresentation()
        try await Task.sleep(for: .milliseconds(30))
        #expect(controller.window == nil)
    }
    @Test func publishedBuild258UpgradesOnceAndManualReplayKeepsHistory() async throws {
        let suite = "LyricsXGuideTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("2.0.34", forKey: "guideLastVersion")
        defaults.set(["2.0.34:complete-2"], forKey: "guidePresentedEditions")
        let history = GuideHistory(defaults: defaults, version: "2.0.35")
        #expect(history.pending == .update(previous: "2.0.34"))
        let controller = FeatureGuideController(history: history)
        defer { controller.close() }
        controller.scheduleAutomaticPresentation()
        for _ in 0..<150 where controller.window == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(controller.window?.isVisible == true)
        #expect(history.pending == nil)
        controller.close()
        #expect(GuideHistory(defaults: defaults, version: "2.0.35").pending == nil)
        controller.show(.update(previous: GuideContent.latestBaseline))
        #expect(controller.window?.isVisible == true)
        #expect(defaults.string(forKey: "guideLastVersion") == "2.0.35")
    }

    @Test func liveGuideUsesIsolatedProductionSessionAndCleansUp() throws {
        let standard = UserDefaults.standard.dictionaryRepresentation() as NSDictionary
        weak var releasedModel: AppModel?
        var demo: GuideDemoSession? = GuideDemoSession(reduced: true)
        let model = try #require(demo?.model)
        releasedModel = model
        #expect(!model.preferences.overlayWaveformEnabled)
        let suite = try #require(demo?.suite)
        #expect(model.session.document?.hasWordTiming == true)
        #expect(model.session.document?.lines.count == 2)
        demo?.nextTrack()
        #expect(model.session.track?.title == "更长的歌名，也保持播放控件的位置")
        demo?.stop()
        #expect(UserDefaults(suiteName: suite)?.persistentDomain(forName: suite)?.isEmpty != false)
        #expect(standard == UserDefaults.standard.dictionaryRepresentation() as NSDictionary)
        demo = nil
        // The local model reference is intentionally still alive here; stop
        // must already have removed windows, timers and temporary settings.
        #expect(releasedModel?.overlay == nil)
    }

    @Test func releaseVisualUsesBundledRendererImageAndProductionWaveformFade() throws {
        let image = try #require(GuideFlexbarAsset.image)
        #expect(image.size == CGSize(width: 720, height: 60))
        #expect(GuideWaveformCurve.sampleBands.count == WaveformSpectrumAnalyzer.bandCount)
        let stops = OverlayWaveformEdgeFade.locations(width: 470).map { CGFloat(truncating: $0) }
        #expect(stops.count == OverlayWaveformEdgeFade.alphas.count)
        #expect(OverlayWaveformEdgeFade.alphas.first == 0)
        #expect(OverlayWaveformEdgeFade.alphas.last == 0)
        #expect(stops.first == 0 && stops.last == 1)
    }

    @Test func liveDemoOutlastsPlayerStaleTimeoutAndLoopsWithoutReplacingLyrics() {
        let demo = GuideDemoSession(reduced: false)
        defer { demo.stop() }
        let start = ProcessInfo.processInfo.systemUptime
        demo.selectTrack(now: start)
        let documentRevision = demo.model.session.documentRevision
        for offset in [0.5, 3.5, 6.5, 11.9, 12.5, 18.5] {
            demo.tick(now: start + offset)
            let expected = offset.truncatingRemainder(dividingBy: 12)
            #expect(abs(demo.model.session.position - expected) < 0.001)
            #expect(demo.model.session.currentLineIndex == (expected < 6 ? 0 : 1))
            #expect(demo.model.session.documentRevision == documentRevision)
            #expect(!demo.model.session.isSearching)
        }
    }

    @Test func liveDemoReactsToAppMotionChangesWithoutReplacingItsSession() async throws {
        _ = NSApplication.shared; NSApp.finishLaunching()
        let demo = GuideDemoSession(reduced: false)
        let flags = GuideMotionFlags()
        let window = GuideVisibilityTestWindow(contentRect: .init(x: 100, y: 100, width: 600, height: 450),
                                               styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: GuideMotionTestHost(demo: demo, flags: flags))
        window.orderFrontRegardless()
        NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: window)
        defer { window.close(); demo.stop() }
        let documentID = demo.model.session.document?.id
        func awaitState(_ condition: () -> Bool) async throws {
            for _ in 0..<100 where !condition() {
                NSApp.updateWindows()
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(condition())
        }
        try await awaitState { demo.model.session.position >= 0.15 }
        flags.appReduced = true
        try await awaitState { demo.model.preferences.reduceMotion && !demo.model.session.isPlaying }
        #expect(demo.model.session.position == 0)
        try await Task.sleep(for: .milliseconds(120))
        #expect(demo.model.session.position == 0)
        flags.appReduced = false
        try await awaitState { !demo.model.preferences.reduceMotion && demo.model.session.position >= 0.1 }
        #expect(demo.model.session.document?.id == documentID)
    }

    @Test func guideTaskKeyChangesForEitherMotionSetting() {
        let normal = GuideDemoTaskState(active: true, appReduced: false, systemReduced: false)
        #expect(normal != GuideDemoTaskState(active: true, appReduced: true, systemReduced: false))
        #expect(normal != GuideDemoTaskState(active: true, appReduced: false, systemReduced: true))
        #expect(GuideDemoTaskState(active: true, appReduced: true, systemReduced: false)
                == GuideDemoTaskState(active: true, appReduced: false, systemReduced: true))
    }

    @Test func guideDemoActuallyAdvancesInsideAnOrdinaryScrollViewAndStopsWhenHidden() async throws {
        _ = NSApplication.shared; NSApp.finishLaunching()
        let demo = GuideDemoSession(reduced: false)
        let window = GuideVisibilityTestWindow(contentRect: .init(x: 100, y: 100, width: 600, height: 450),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView:
            ScrollView { GuideLiveDemo(kind: "liveGlass", reduced: false, viewportHeight: 450, session: demo)
                .frame(height: 330) }.coordinateSpace(name: "guideContent"))
        window.orderFrontRegardless()
        NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: window)
        defer { window.close(); demo.stop() }
        for _ in 0..<100 where demo.model.session.position < 0.3 {
            NSApp.updateWindows()
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(demo.model.session.position >= 0.3, "The guide must advance its real lyric session without a scroll-target layout")
        window.orderOut(nil)
        NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: window)
        try await Task.sleep(for: .milliseconds(100))
        let paused = demo.model.session.position
        try await Task.sleep(for: .milliseconds(150))
        #expect(demo.model.session.position == paused, "Hidden guide should stop ticking")
        window.orderFrontRegardless()
        NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: window)
        try await Task.sleep(for: .milliseconds(200))
        #expect(demo.model.session.position > paused)
    }

}
