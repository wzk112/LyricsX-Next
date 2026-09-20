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
            #expect(GuideContent.updates(after: "2.0.34").count == 10)
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
        let current = ["font34", "color34", "word34", "theme34", "search34", "settings34", "guide34", "overlay34", "playback34", "compatibility34"]
        #expect(GuideContent.latestBaseline == "2.0.28")
        #expect(GuideContent.updates(after: "2.0.28").map(\.id) == current)
        #expect(GuideContent.updates(after: "2.0.33").map(\.id) == current)
        #expect(GuideContent.updates(after: nil).count == 10)
        #expect(GuideContent.tutorial.count == 14)
        #expect(Set(GuideContent.tutorial.map(\.id)).count == GuideContent.tutorial.count)
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
}
