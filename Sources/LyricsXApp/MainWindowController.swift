import AppKit
import SwiftUI

/// One native owner keeps the player mounted across ordinary closes. A
/// SwiftUI Window scene synchronously flushes the app's scene graph on orderOut;
/// the floating lyrics share that main thread. The player remains SwiftUI, but
/// its window lifecycle is independent of settings, previews and menu scenes.
@MainActor final class MainWindowController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private let frameAutosaveName: String?
    private let makeWindow: @MainActor () -> NSWindow
    private(set) var window: NSWindow?

    init(model: AppModel, frameAutosaveName: String? = "LyricsXMainWindow",
         makeWindow: @escaping @MainActor () -> NSWindow = {
             NSWindow(contentRect: .init(x: 0, y: 0, width: 1040, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
         }) {
        self.model = model
        self.frameAutosaveName = frameAutosaveName
        self.makeWindow = makeWindow
        super.init()
        model.showMainWindow = { [weak self] in self?.show() }
    }
    func show() {
        let window: NSWindow
        if let existing = self.window { window = existing }
        else {
            window = makeWindow()
            self.window = window
            window.identifier = .init("main")
            window.title = "LyricsX Next"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = false
            window.isReleasedWhenClosed = false
            window.tabbingMode = .disallowed
            window.contentMinSize = .init(width: 520, height: 420)
            window.delegate = self
            window.contentView = NSHostingView(rootView: MainWindowPlayerRoot(model: model,
                showMain: { [weak self] in self?.show() }))
            if let frameAutosaveName {
                if !window.setFrameUsingName(frameAutosaveName) { window.center() }
                window.setFrameAutosaveName(frameAutosaveName)
            } else { window.center() }
        }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === window, sender.attachedSheet == nil else { return true }
        sender.orderOut(nil)
        return false
    }
    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        model.mainWindowVisible = false
        window = nil
    }
    func stop() {
        window?.close()
        window = nil
    }
}

private struct MainWindowPlayerRoot: View {
    let model: AppModel
    let showMain: () -> Void
    var body: some View {
        MainView(model: model, showMain: showMain,
            showSettings: { [weak model] in model?.showSettingsWindow?() })
            .preferredColorScheme(model.preferences.appTheme.colorScheme)
            .hdrDisplayScope(requested: model.preferences.lyricEmphasis.usesHDR)
    }
}
