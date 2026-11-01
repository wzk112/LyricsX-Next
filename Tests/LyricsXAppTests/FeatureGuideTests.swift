import AppKit
import SwiftUI
import Testing
import LyricsXCore
@testable import LyricsXApp

private struct GuideTouchBarIdleRepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

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
            #expect(GuideContent.updates(after: "2.0.34").count == 26)
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
        #expect(GuideContent.latestBaseline == "2.0.42")
        #expect(GuideContent.updates(after: "2.0.37").map(\.id) == GuideContent.release43Pages.map(\.id) + GuideContent.release42Pages.map(\.id) + GuideContent.release41Pages.map(\.id) + GuideContent.release40Pages.map(\.id) + release39 + newest)
        #expect(GuideContent.updates(after: "2.0.35").map(\.id) == GuideContent.release43Pages.map(\.id) + GuideContent.release42Pages.map(\.id) + GuideContent.release41Pages.map(\.id) + GuideContent.release40Pages.map(\.id) + release39 + latest)
        #expect(GuideContent.updates(after: "2.0.34").map(\.id) == GuideContent.release43Pages.map(\.id) + GuideContent.release42Pages.map(\.id) + GuideContent.release41Pages.map(\.id) + GuideContent.release40Pages.map(\.id) + release39 + latest + current)
        #expect(GuideContent.updates(after: "2.0.28").count == 36)
        #expect(GuideContent.updates(after: nil).count == 36)
        #expect(GuideContent.tutorial.count == 17)
        #expect(Set(GuideContent.tutorial.map(\.id)).count == GuideContent.tutorial.count)
        #expect(GuideContent.tutorial.contains { $0.id == "waveform" && $0.illustration == "releaseWaveform38" })
        #expect(GuideContent.tutorial.contains { $0.id == "flexbar" && $0.illustration == "releaseFlexbar38" })
        #expect(GuideContent.updates(after: "2.0.37").suffix(4).map(\.illustration) == [
            "releaseWaveform38", "releaseOverlay38", "livePlayer", "releaseFlexbar38"])
        let waveform = GuideContent.releases.first { $0.page.id == "waveform38" }!.page
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
                == GuideContent.release43Pages.map(\.id) + GuideContent.release42Pages.map(\.id) + GuideContent.release41Pages.map(\.id) + GuideContent.release40Pages.map(\.id) + GuideContent.release39Pages.map(\.id) + ["waveform38", "overlay38", "mainMotion38", "performanceFlexbar38"])
            history.didPresent()
            #expect(GuideHistory(defaults: defaults, version: "2.0.38").pending == nil)
            #expect(defaults.stringArray(forKey: "guidePresentedEditions")?
                .contains("2.0.38:\(GuideContent.revision)") == true)
        }
    }
    @Test func build274ShowsOnlyNewChangesAndAppearsOnce() throws {
        #expect(GuideContent.release39Pages.map(\.id) == ["position39", "hotkeys39", "colors39", "transitions39"])
        #expect(GuideContent.displayUpdates(after: "2.0.38").map(\.id) == GuideContent.release43Pages.map(\.id) + GuideContent.release42Pages.map(\.id) + GuideContent.release41Pages.map(\.id) + GuideContent.release40Pages.map(\.id) + GuideContent.release39Pages.map(\.id))
        #expect(GuideContent.displayUpdates(after: nil).count == 36)
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
        #expect(GuideContent.displayUpdates(after: "2.0.39").map(\.id) == GuideContent.release43Pages.map(\.id) + GuideContent.release42Pages.map(\.id) + GuideContent.release41Pages.map(\.id) + ["position40", "spacing40"])
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
    @Test func build278HistoryRemainsValidWhenUpgradingPastIt() throws {
        #expect(GuideContent.release42Pages.map(\.id) == ["globalOffset42", "startup42"])
        #expect(GuideContent.displayUpdates(after: "2.0.41").map(\.id)
            == GuideContent.release43Pages.map(\.id) + ["globalOffset42", "startup42"])
        try fixture { defaults in
            defaults.set("2.0.41", forKey: "guideLastVersion")
            defaults.set(["2.0.41:music-search-41"], forKey: "guidePresentedEditions")
            let preferences = Preferences(defaults: defaults)
            preferences.mainLyricCustomPercent = 17
            preferences.overlayVisible = false
            preferences.appleMusicCloudEnabled = true
            let history = GuideHistory(defaults: defaults, version: "2.0.42", revision: "global-offset-42")
            #expect(history.pending == .update(previous: "2.0.41"))
            history.didPresent()
            #expect(GuideHistory(defaults: defaults, version: "2.0.42", revision: "global-offset-42").pending == nil)
            let restored = Preferences(defaults: defaults)
            #expect(restored.mainLyricCustomPercent == 17 && !restored.overlayVisible && restored.appleMusicCloudEnabled)
            defaults.set(["2.0.42:startup-42-preview1"], forKey: "guidePresentedEditions")
            let fromPreview = GuideHistory(defaults: defaults, version: "2.0.42", revision: "global-offset-42")
            #expect(fromPreview.pending == .update(previous: "2.0.42"))
            fromPreview.didPresent()
            #expect(GuideHistory(defaults: defaults, version: "2.0.42", revision: "global-offset-42").pending == nil)
        }
    }

    @Test func build279IntroducesTouchBarOnceWithoutEnablingItOrChangingExistingSettings() throws {
        let current = ["touchBar43", "backgroundTouchBar43"]
        #expect(GuideContent.revision == "touch-bar-43")
        #expect(GuideContent.release43Pages.map(\.id) == current)
        #expect(GuideContent.displayUpdates(after: "2.0.42").map(\.id) == current)
        #expect(GuideContent.displayUpdates(after: "2.0.43").map(\.id) == current)
        #expect(GuideContent.displayUpdates(after: "2.0.41").map(\.id) == current + ["globalOffset42", "startup42"])
        #expect(GuideContent.release43Pages.allSatisfy { $0.subtitle.contains("设置 → 开发者选项 → MacBook Pro Touch Bar") && $0.points.joined().contains("默认关闭") })
        #expect(GuideContent.tutorial.contains { $0.id == "touchbar" && $0.illustration == "touchBar43" })
        for previous in ["2.0.42", "2.0.40"] {
            try fixture { defaults in
                defaults.set(previous, forKey: "guideLastVersion")
                defaults.set([previous + ":" + (previous == "2.0.42" ? "global-offset-42" : "lyrics-layout-40")], forKey: "guidePresentedEditions")
                let preferences = Preferences(defaults: defaults)
                preferences.globalOffsetMilliseconds = 250
                preferences.overlayVisible = false
                preferences.flexbarEnabled = true
                let history = GuideHistory(defaults: defaults)
                #expect(history.pending == .update(previous: previous))
                history.didPresent()
                #expect(GuideHistory(defaults: defaults).pending == nil)
                let restored = Preferences(defaults: defaults)
                #expect(!restored.touchBarEnabled && !restored.touchBarBackgroundEnabled)
                #expect(restored.globalOffsetMilliseconds == 250 && !restored.overlayVisible && restored.flexbarEnabled)
                let presented = defaults.stringArray(forKey: "guidePresentedEditions") ?? []
                history.didPresent()
                #expect(defaults.stringArray(forKey: "guidePresentedEditions") == presented)
                #expect(presented.contains("2.0.43:touch-bar-43"))
            }
        }
        try fixture { defaults in
            let history = GuideHistory(defaults: defaults)
            let preferences = Preferences(defaults: defaults)
            #expect(history.pending == .tutorial)
            #expect(!preferences.touchBarEnabled && !preferences.touchBarBackgroundEnabled)
            history.didPresent()
            #expect(GuideHistory(defaults: defaults).pending == nil)
        }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let plist = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: root.appendingPathComponent("Resources/Info.plist")), format: nil) as? [String: Any])
        #expect(plist["CFBundleShortVersionString"] as? String == GuideContent.version)
        #expect(plist["CFBundleVersion"] as? String == "279")
        #expect(plist["LyricsXReleaseVersion"] == nil)
        #expect(plist["LSMinimumSystemVersion"] as? String == "26.0")
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LYRICSX_RELEASE_QA"] == "1"))
    func releaseIntroductionRendersAndAutomaticReplayStaysQuiet() async throws {
        _ = NSApplication.shared
        let suite = "LyricsXPreviewQA-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("2.0.42", forKey: "guideLastVersion")
        defaults.set(["2.0.42:global-offset-42"], forKey: "guidePresentedEditions")
        let controller = FeatureGuideController(history: GuideHistory(defaults: defaults))
        let preferences = Preferences(defaults: defaults)
        let model = AppModel(repository: GuideTouchBarIdleRepository(), preferences: preferences)
        controller.preferences = preferences; controller.model = model
        defer { controller.close(); model.stop() }
        controller.showAutomaticIfNeeded()
        let window = try #require(controller.window)
        #expect(window.isVisible)
        #expect(!preferences.touchBarEnabled && !preferences.touchBarBackgroundEnabled)
        #expect(!model.touchBar.isRunning)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let out = root.appendingPathComponent("outputs/release-2.0.43/guide", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        func nativeContent(in view: NSView) -> TouchBarContentView? {
            if let content = view as? TouchBarContentView { return content }
            return view.subviews.lazy.compactMap { nativeContent(in: $0) }.first
        }
        for page in 0..<2 {
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                window.setContentSize(.init(width: 920, height: 900))
                window.contentView = NSHostingView(rootView: FeatureGuideView(mode: .update(previous: "2.0.42"), initialPage: page,
                    preferences: preferences, model: model, close: { controller.close() }))
                window.appearance = NSAppearance(named: appearance)
                try await Task.sleep(for: .milliseconds(150))
                let view = try #require(window.contentView)
                view.layoutSubtreeIfNeeded()
                let native = try #require(nativeContent(in: view))
                #expect(native.lyrics.renderedText == GuideTouchBarExample.line.text)
                #expect(!native.lyrics.requiresAnimation)
                let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try #require(bitmap.representation(using: .png, properties: [:]))
                    .write(to: out.appendingPathComponent("page-\(page + 1)-" + appearance.rawValue + ".png"))
            }
        }
        #expect(!preferences.touchBarEnabled && !preferences.touchBarBackgroundEnabled && !model.touchBar.isRunning)
        controller.close()
        controller.showAutomaticIfNeeded()
        #expect(controller.window == nil)
        let presented = defaults.stringArray(forKey: "guidePresentedEditions")
        controller.show(.update(previous: GuideContent.latestBaseline))
        #expect(controller.window?.isVisible == true)
        controller.close()
        #expect(defaults.stringArray(forKey: "guidePresentedEditions") == presented)
    }

    @Test func build276IntroducesAllChangesOnceWithoutEnablingCloudOrLosingSettings() throws {
        let ids = ["cloud41", "search41", "players41", "overlay41", "waveform41"]
        #expect(GuideContent.displayUpdates(after: "2.0.40").map(\.id) == GuideContent.release43Pages.map(\.id) + GuideContent.release42Pages.map(\.id) + ids)
        #expect(GuideContent.displayUpdates(after: "2.0.39").map(\.id) == GuideContent.release43Pages.map(\.id) + GuideContent.release42Pages.map(\.id) + ids + ["position40", "spacing40"])
        #expect(GuideContent.release41Pages.allSatisfy { $0.subtitle.contains("设置") })
        try fixture { defaults in
            defaults.set("2.0.40", forKey: "guideLastVersion")
            defaults.set(["2.0.40:lyrics-layout-40"], forKey: "guidePresentedEditions")
            let preferences = Preferences(defaults: defaults)
            preferences.mainLyricCustomPercent = 17
            preferences.overlayShowSongInfo = false
            let history = GuideHistory(defaults: defaults, version: "2.0.41")
            #expect(history.pending == .update(previous: "2.0.40"))
            history.didPresent()
            #expect(GuideHistory(defaults: defaults, version: "2.0.41").pending == nil)
            let restored = Preferences(defaults: defaults)
            #expect(!restored.appleMusicCloudEnabled)
            #expect(!restored.overlayShowSongInfo)
            #expect(restored.mainLyricCustomPercent == 17)
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
            #expect(GuideContent.updates(after: "2.0.35").map(\.id) == GuideContent.release43Pages.map(\.id) + GuideContent.release42Pages.map(\.id) + GuideContent.release41Pages.map(\.id) + GuideContent.release40Pages.map(\.id) + GuideContent.release39Pages.map(\.id) + [
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
