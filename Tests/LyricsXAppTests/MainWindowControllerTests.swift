import AppKit
import Testing
@testable import LyricsXApp

@Suite(.serialized) @MainActor struct MainWindowControllerTests {
    @Test func ordinaryCloseAndEveryReopenKeepOnePlayerHost() throws {
        _ = NSApplication.shared
        let suite = "LyricsXNativeWindow-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(preferences: Preferences(defaults: defaults))
        let owner = MainWindowController(model: model, frameAutosaveName: nil)
        defer { owner.stop(); model.stop() }
        owner.show()
        let window = try #require(owner.window)
        let host = try #require(window.contentView)
        #expect(window.isVisible && window.identifier?.rawValue == "main")
        window.performClose(nil)
        #expect(!window.isVisible && window.contentView === host)
        model.showMainWindow?()
        #expect(window.isVisible && owner.window === window && window.contentView === host)
        window.standardWindowButton(.closeButton)?.performClick(nil)
        #expect(!window.isVisible)
        owner.show()
        #expect(owner.window === window && window.contentView === host)
        #expect(window.contentMinSize == .init(width: 520, height: 420))
        // Direct close is used for actual shutdown, and must release ownership
        // instead of being mistaken for a user hide.
        owner.stop()
        #expect(owner.window == nil && !window.isVisible)
    }
}
