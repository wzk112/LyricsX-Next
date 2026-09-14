import SwiftUI
import AppKit

@main
struct LyricsXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()
    var body: some Scene {
        Window("LyricsX Next", id: "main") {
            MainView(model: model).hdrDisplayScope(requested: model.preferences.lyricEmphasis.usesHDR).onAppear { delegate.configure(model) }
        }
        .defaultSize(width: 1040, height: 720)
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.disabled)
        .commands { LyricsXCommands(model: model) }
        Settings {
            PreferencesView(model: model)
        }
        Window("动效预览", id: "preview") { LyricsPreviewView(preferences: model.preferences) }
            .defaultSize(width: 760, height: 480)
        MenuBarExtra(isInserted: $model.preferences.showMenuBarIcon) { MenuBarContent(model: model) } label: {
            HStack(spacing: 5) {
                Image(systemName: "quote.bubble")
                if model.preferences.showMenubarLyrics && model.preferences.combinedMenubarLyrics {
                    MenuBarLyricLabel(model: model)
                }
            }
        }
        MenuBarExtra(isInserted: Binding(get: {
            model.preferences.showMenubarLyrics && (!model.preferences.combinedMenubarLyrics || !model.preferences.showMenuBarIcon)
        }, set: { if !$0 { model.preferences.showMenubarLyrics = false } })) {
            MenuBarContent(model: model)
        } label: { MenuBarLyricLabel(model: model) }
    }
}

private struct LyricsXCommands: Commands {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("搜索歌词…") { openWindow(id: "main"); NSApp.activate(); model.showSearch = true }.keyboardShortcut("f")
            Button("导入歌词…") { model.importLyrics() }.keyboardShortcut("i")
            Button("导出歌词…") { model.exportLyrics() }.keyboardShortcut("e")
            Button("导出纯文本…") { model.exportLyrics(plain: true) }
        }
        CommandMenu("播放") {
            Button(model.session.isPlaying ? "暂停" : "播放") { model.playPause() }.keyboardShortcut(.space, modifiers: [])
            Button("下一首") { model.skip(next: true) }.keyboardShortcut(.rightArrow, modifiers: .command)
            Button("上一首") { model.skip(next: false) }.keyboardShortcut(.leftArrow, modifiers: .command)
            Divider()
            Button("歌词提前 0.2 秒") { model.session.adjustOffset(by: 200) }.keyboardShortcut(.upArrow, modifiers: [.command, .option])
            Button("歌词延后 0.2 秒") { model.session.adjustOffset(by: -200) }.keyboardShortcut(.downArrow, modifiers: [.command, .option])
        }
        CommandGroup(after: .toolbar) {
            Divider()
            Toggle("显示菜单栏图标", isOn: $model.preferences.showMenuBarIcon)
            Toggle("显示菜单栏歌词", isOn: $model.preferences.showMenubarLyrics)
            Button("打开 LyricsX Next") { openWindow(id: "main"); NSApp.activate() }
        }
    }
}

private struct MenuBarContent: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text(model.session.track?.title ?? "LyricsX Next").font(.headline)
        if let artist = model.session.track?.artist { Text(artist) }
        Divider()
        Button("打开 LyricsX Next") { openWindow(id: "main"); NSApp.activate() }
        Toggle("悬浮歌词", isOn: Binding(get: { model.preferences.overlayVisible }, set: { model.setOverlayVisible($0) }))
        Toggle("锁定位置", isOn: Binding(get: { model.preferences.overlayLocked }, set: { model.setOverlayLocked($0) }))
        Toggle("歌词区域点击穿透", isOn: Binding(get: { model.preferences.overlayClickThrough }, set: { model.setOverlayClickThrough($0) }))
        Toggle("菜单栏歌词", isOn: $model.preferences.showMenubarLyrics)
        Toggle("菜单栏图标", isOn: $model.preferences.showMenuBarIcon)
        Divider()
        Button(model.session.isPlaying ? "暂停" : "播放") { model.playPause() }
        Button("上一首") { model.skip(next: false) }.disabled(model.session.track == nil)
        Button("下一首") { model.skip(next: true) }.disabled(model.session.track == nil)
        Menu("歌词偏移") {
            Text(String(format: "当前 %+.1f 秒", Double(model.session.document?.offsetMilliseconds ?? 0) / 1000))
            Button("提前 0.1 秒") { model.session.adjustOffset(by: 100) }
            Button("延后 0.1 秒") { model.session.adjustOffset(by: -100) }
            Button("重置偏移") { model.session.resetOffset() }
        }.disabled(model.session.document?.isSynced != true)
        Button("搜索歌词…") { openWindow(id: "main"); NSApp.activate(); model.showSearch = true }
        Button("重新搜索歌词") { model.refreshLyrics() }.disabled(model.session.track == nil || model.lyricsBlocked)
        Menu("歌词") {
            Button("在 Finder 中显示") { model.revealLyrics() }.disabled(model.session.document == nil)
            Button("歌词有误，停用此歌曲歌词") { model.markWrongLyrics() }.disabled(model.session.track == nil)
            Button(model.albumSuppressed ? "恢复此专辑歌词" : "停用此专辑歌词") { model.toggleAlbumSuppression() }.disabled(model.session.track?.album.isEmpty != false)
            if model.lyricsBlocked { Button("恢复此歌曲歌词搜索") { model.restoreLyricsSearch() } }
            Button("写入 Apple Music") { model.writeLyricsToMusic() }
                .disabled(model.session.document == nil || model.session.track?.playerID != "com.apple.Music")
            Divider()
            Button("导入歌词…") { model.importLyrics() }.disabled(model.session.track == nil)
            Button("导出歌词…") { model.exportLyrics() }.disabled(model.session.document == nil)
            Button("导出纯文本…") { model.exportLyrics(plain: true) }.disabled(model.session.document == nil)
        }
        Button("歌词资料库…") { openWindow(id: "main"); NSApp.activate(); model.showLibrary = true }
        Button("设置…") { openSettings(); NSApp.activate() }
        Divider()
        Button("关于 LyricsX Next") { NSApp.orderFrontStandardAboutPanel(nil); NSApp.activate() }
        Button("检查更新…") { model.checkForUpdates() }
        Button("退出 LyricsX Next") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

private struct MenuBarLyricLabel: View {
    let model: AppModel
    var body: some View {
        if let doc = model.session.document, !model.session.documentIsPlaceholder,
           let index = model.session.currentLineIndex, doc.lines.indices.contains(index) {
            Text(String(model.preferences.text(doc.lines[index].text).prefix(36)))
                .help(model.preferences.text(doc.lines[index].text))
        } else { Text(model.session.track?.title ?? "LyricsX Next") }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var hotkeys: GlobalHotkeys?
    func applicationWillFinishLaunching(_ notification: Notification) {
        // LSUIElement prevents a Dock flash during cold launch. Promote only
        // when the persisted preference requests a normal foreground app.
        let show = UserDefaults.standard.object(forKey: "showDockIcon") as? Bool ?? true
        _ = NSApp.setActivationPolicy(show ? .regular : .accessory)
    }
    func configure(_ model: AppModel) {
        guard self.model == nil else { return }
        self.model = model; model.start(); hotkeys = GlobalHotkeys(model: model)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { hotkeys?.stop(); model?.stop() }
    func applicationDidBecomeActive(_ notification: Notification) { model?.dockVisibility.applicationActivated() }
    func applicationDidFinishLaunching(_ notification: Notification) { model?.dockVisibility.applicationActivated() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model?.dockVisibility.applicationActivated()
        guard let show = model?.showMainWindow else { return true }
        show()
        return false // The main window has an explicit owner; skip default reopening.
    }
}
