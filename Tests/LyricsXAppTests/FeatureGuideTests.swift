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
            #expect(GuideContent.updates(after: "2.0.34").count == 6)
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
        let latest = ["glassColor36"]
        let current = ["glass35", "appearance35", "motion35", "highlight35", "upgrade35"]
        #expect(GuideContent.latestBaseline == "2.0.35")
        #expect(GuideContent.updates(after: "2.0.35").map(\.id) == latest)
        #expect(GuideContent.updates(after: "2.0.34").map(\.id) == latest + current)
        #expect(GuideContent.updates(after: "2.0.28").count == 16)
        #expect(GuideContent.updates(after: nil).count == 16)
        #expect(GuideContent.tutorial.count == 14)
        #expect(Set(GuideContent.tutorial.map(\.id)).count == GuideContent.tutorial.count)
    }
    @Test func build269ShowsOnlyNewGlassColorUpdateOnce() throws {
        try fixture { defaults in
            defaults.set("2.0.35", forKey: "guideLastVersion")
            defaults.set(["2.0.35:glass-35"], forKey: "guidePresentedEditions")
            let history = GuideHistory(defaults: defaults, version: "2.0.36", revision: GuideContent.revision)
            #expect(history.pending == .update(previous: "2.0.35"))
            #expect(GuideContent.updates(after: "2.0.35").map(\.id) == ["glassColor36"])
            history.didPresent()
            #expect(GuideHistory(defaults: defaults, version: "2.0.36", revision: GuideContent.revision).pending == nil)
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
