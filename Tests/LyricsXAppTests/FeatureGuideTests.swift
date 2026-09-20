import AppKit
import SwiftUI
import Testing
@testable import LyricsXApp

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
    @Test func versionJumpContainsOnlyInterveningReleaseNotes() {
        let current = ["r29", "r30", "r33", "r34", "theme34", "settings34"]
        #expect(GuideContent.latestBaseline == "2.0.28")
        #expect(GuideContent.updates(after: "2.0.28").map(\.id) == current)
        #expect(GuideContent.updates(after: "2.0.33").map(\.id) == current)
        #expect(GuideContent.updates(after: nil).count == 6)
        #expect(GuideContent.tutorial.count == 10)
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
            controller.window?.close()
            #expect(controller.window == nil)
            controller.showAutomaticIfNeeded()
            #expect(controller.window?.isVisible == true)
            #expect(history.pending == nil)
            controller.window?.close()
            controller.showAutomaticIfNeeded()
            #expect(controller.window == nil)
        }
    }
}
