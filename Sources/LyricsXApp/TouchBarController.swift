import AppKit
import CoreGraphics
import Observation
import LyricsXCore

/// Native Touch Bar and its desktop preview use the same views and session clock.
/// Only an actually visible surface schedules frames; the Control Strip icon is static.
@Observable @MainActor
final class TouchBarController: NSObject, NSTouchBarDelegate, NSWindowDelegate {
    private(set) var status = "未启用"
    private(set) var isRunning = false
    private(set) var isRefreshing = false
    @ObservationIgnored private weak var model: AppModel?
    @ObservationIgnored private let systemBridge = TouchBarSystemBridge()
    @ObservationIgnored private let managesSystemTouchBar: Bool
    @ObservationIgnored private let visibilityOverride: (() -> Bool)?
    @ObservationIgnored private let currentSessionIsActive: () -> Bool
    @ObservationIgnored private var nativeBar: NSTouchBar?
    @ObservationIgnored private var nativeContent: TouchBarContentView?
    @ObservationIgnored private var trayItem: NSCustomTouchBarItem?
    @ObservationIgnored private var trayInstalled = false
    @ObservationIgnored private var visibilityObservation: NSKeyValueObservation?
    @ObservationIgnored private var ticker: PlaybackTicker?
    @ObservationIgnored private var previewWindow: NSWindow?
    @ObservationIgnored private var previewContent: TouchBarContentView?
    @ObservationIgnored private var appObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var workspaceObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var sleeping = false
    @ObservationIgnored private var displaySleeping = false
    @ObservationIgnored private var sessionInactive = false
    @ObservationIgnored private var generation: UInt64 = 0

    private static let contentID = NSTouchBarItem.Identifier("com.wzk112.lyricsxnext.touchbar.content")
    private static let trayID = NSTouchBarItem.Identifier("com.wzk112.lyricsxnext.touchbar.tray")

    init(managesSystemTouchBar: Bool = true, visibilityOverride: (() -> Bool)? = nil,
         sessionActivity: (() -> Bool)? = nil) {
        self.managesSystemTouchBar = managesSystemTouchBar
        self.visibilityOverride = visibilityOverride
        self.currentSessionIsActive = sessionActivity ?? Self.sessionIsOnConsole
        super.init()
    }

    private static func sessionIsOnConsole() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any],
              let onConsole = session[kCGSessionOnConsoleKey as String] as? Bool else { return true }
        return onConsole
    }

    func start(model: AppModel) {
        guard !isRunning else { return }
        self.model = model
        // An inactive-session launch notification arrives before didFinishLaunching,
        // so it can precede AppModel.start(). Read the public initial state as well.
        sessionInactive = !currentSessionIsActive()
        isRunning = true
        generation &+= 1
        let token = generation
        ticker = PlaybackTicker { [weak self] in self?.tick() }
        if managesSystemTouchBar {
            for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
                appObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    Task { @MainActor in
                        guard let self, self.generation == token else { return }
                        self.synchronizePlayback()
                    }
                })
            }
            let center = NSWorkspace.shared.notificationCenter
            for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification,
                         NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
                workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                    let name = notification.name
                    Task { @MainActor in
                        guard let self, self.isRunning, self.generation == token else { return }
                        switch name {
                        case NSWorkspace.screensDidSleepNotification: self.displaySleeping = true
                        case NSWorkspace.screensDidWakeNotification: self.displaySleeping = false
                        case NSWorkspace.sessionDidResignActiveNotification: self.sessionInactive = true
                        case NSWorkspace.sessionDidBecomeActiveNotification: self.sessionInactive = false
                        default: break
                        }
                        self.synchronizePlayback()
                    }
                })
            }
        }
        observePresentation()
    }

    private var suspended: Bool { sleeping || displaySleeping || sessionInactive }
    private var hasVisibleSurface: Bool {
        guard isRunning, !suspended else { return false }
        return (previewWindow?.isVisible == true && previewWindow?.occlusionState.contains(.visible) == true)
            || (model?.preferences.touchBarEnabled == true && (visibilityOverride?() ?? nativeBar?.isVisible ?? false))
    }

    private func observePresentation() {
        guard isRunning, let model else { return }
        let token = generation
        withObservationTracking {
            _ = model.preferences.touchBarEnabled
            _ = model.preferences.touchBarBackgroundEnabled
            _ = model.preferences.conversion
            _ = model.session.track
            _ = model.session.documentRevision
            _ = model.session.globalOffsetMilliseconds
            _ = model.session.currentLineIndex
            _ = model.session.isPlaying
            _ = model.session.isSearching
            _ = model.artwork
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.isRunning, self.generation == token else { return }
                self.observePresentation()
            }
        }
        synchronizePlayback()
    }

    func synchronizePlayback() {
        guard isRunning else { return }
        reconcilePresentation()
        render()
        updateRefresh()
    }

    private func makeNativeBar() -> NSTouchBar {
        if let nativeBar { return nativeBar }
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [Self.contentID]
        bar.principalItemIdentifier = Self.contentID
        nativeBar = bar
        let token = generation
        visibilityObservation = bar.observe(\.isVisible, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                self.visibilityChanged()
            }
        }
        return bar
    }

    private func reconcilePresentation() {
        guard let model else { return }
        guard model.preferences.touchBarEnabled, !suspended else {
            removeSystemPresentation()
            status = model.preferences.touchBarEnabled ? "已暂停，唤醒后恢复" : "未启用"
            return
        }
        let bar = makeNativeBar()
        if managesSystemTouchBar {
            if NSApp.isActive {
                removeTray()
                systemBridge.dismiss(bar)
                if NSApp.touchBar !== bar { NSApp.touchBar = bar }
            } else if model.preferences.touchBarBackgroundEnabled && systemBridge.isAvailable {
                if NSApp.touchBar === bar { NSApp.touchBar = nil }
                if !trayInstalled {
                    let item = trayItem ?? makeTrayItem()
                    trayInstalled = systemBridge.install(item: item)
                }
            } else {
                if NSApp.touchBar === bar { NSApp.touchBar = nil }
                removeTray()
                systemBridge.dismiss(bar)
            }
        }
        if model.preferences.touchBarBackgroundEnabled && !systemBridge.isAvailable {
            status = "前台歌词已启用；当前系统不支持后台入口"
        } else if trayInstalled {
            status = "已添加后台入口；点按 Touch Bar 控制条中的歌词图标展开"
        } else {
            status = "已启用；有 Touch Bar 时在应用前台显示，也可打开屏幕预览"
        }
    }

    private func makeTrayItem() -> NSCustomTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: Self.trayID)
        let button = NSButton(image: NSImage(systemSymbolName: "quote.bubble", accessibilityDescription: "显示歌词")!, target: self, action: #selector(presentFromControlStrip))
        item.view = button
        trayItem = item
        return item
    }

    @objc private func presentFromControlStrip() {
        guard isRunning, !suspended, model?.preferences.touchBarEnabled == true,
              model?.preferences.touchBarBackgroundEnabled == true, trayInstalled else { return }
        let bar = makeNativeBar()
        if !systemBridge.present(bar, itemIdentifier: Self.trayID) {
            status = "后台展开不可用；请切回 LyricsX Next 使用前台歌词"
        }
        visibilityChanged()
    }

    private func removeTray() {
        if trayInstalled, let trayItem { systemBridge.remove(item: trayItem) }
        trayInstalled = false
    }

    private func removeSystemPresentation() {
        guard managesSystemTouchBar else { return }
        removeTray()
        if let nativeBar {
            systemBridge.dismiss(nativeBar)
            if NSApp.touchBar === nativeBar { NSApp.touchBar = nil }
        }
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == Self.contentID else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        let content = TouchBarContentView()
        configureActions(content)
        item.view = content
        nativeContent = content
        render()
        return item
    }

    private func configureActions(_ content: TouchBarContentView) {
        content.onPrevious = { [weak self] in self?.model?.skip(next: false) }
        content.onPlayPause = { [weak self] in self?.model?.playPause() }
        content.onNext = { [weak self] in self?.model?.skip(next: true) }
    }

    private func render() {
        guard let model, !suspended else { return }
        let session = model.session
        let position = session.presentationPosition()
        var line: LyricLine?
        if let document = session.document, document.isSynced, !document.isInstrumental, !session.documentIsPlaceholder,
           let index = document.index(at: position, globalOffsetMilliseconds: session.globalOffsetMilliseconds),
           document.lines.indices.contains(index), FlexbarSnapshot.isDisplayableLyric(document.lines[index].text) {
            line = document.lines[index]
        }
        let title = session.track.map { $0.artist.isEmpty ? $0.title : "\($0.title) · \($0.artist)" } ?? "LyricsX Next · 等待播放"
        let text = line.map { model.preferences.text($0.text) } ?? title
        for content in [nativeContent, previewContent].compactMap({ $0 }) {
            content.update(line: line, text: text, position: position, offset: session.effectiveOffsetMilliseconds,
                           playing: session.isPlaying, artwork: model.artwork, hasTrack: session.track != nil)
        }
    }

    /// Also used by deterministic visibility/lifecycle tests without Touch Bar hardware.
    func visibilityChanged() {
        guard isRunning else { return }
        render()
        updateRefresh()
    }

    private func updateRefresh() {
        let shouldRefresh = hasVisibleSurface && model?.session.isPlaying == true && model?.session.document?.isSynced == true
        if shouldRefresh {
            ticker?.start()
            ticker?.scheduleEarlier(refreshInterval())
        } else { ticker?.stop() }
        isRefreshing = ticker?.running == true
    }

    private func tick() -> Double? {
        guard hasVisibleSurface, let model, model.session.isPlaying, model.session.document?.isSynced == true else {
            isRefreshing = false
            return nil
        }
        render()
        return refreshInterval()
    }

    private func refreshInterval() -> Double {
        guard let model else { return 250 }
        if nativeContent?.lyrics.requiresAnimation == true || previewContent?.lyrics.requiresAnimation == true { return 1000 / 30 }
        return FlexbarCueCadence.milliseconds(document: model.session.document, position: model.session.presentationPosition(), globalOffsetMilliseconds: model.session.globalOffsetMilliseconds)
    }

    func showPreview() {
        guard isRunning else { return }
        if previewWindow == nil {
            let content = TouchBarContentView()
            configureActions(content)
            let caption = NSTextField(labelWithString: "当前歌曲的 Touch Bar 控件预览 · 非实体触控条画面")
            caption.font = .systemFont(ofSize: 12)
            caption.textColor = .secondaryLabelColor
            let stack = NSStackView(views: [content, caption])
            stack.orientation = .vertical
            stack.spacing = 14
            stack.edgeInsets = .init(top: 18, left: 18, bottom: 16, right: 18)
            let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 736, height: 100), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Touch Bar 预览"
            window.isReleasedWhenClosed = false
            window.contentView = stack
            NSLayoutConstraint.activate([
                content.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 18),
                content.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -18)
            ])
            window.delegate = self
            window.center()
            previewContent = content
            previewWindow = window
        }
        previewWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        visibilityChanged()
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === previewWindow else { return }
        previewContent = nil
        previewWindow = nil
        updateRefresh()
    }

    func windowDidChangeOcclusionState(_ notification: Notification) { visibilityChanged() }

    func sleep() { sleeping = true; synchronizePlayback() }
    func wake() { sleeping = false; synchronizePlayback() }

    func stop() {
        generation &+= 1
        isRunning = false
        ticker?.stop(); ticker = nil; isRefreshing = false
        removeSystemPresentation()
        visibilityObservation?.invalidate(); visibilityObservation = nil
        nativeBar = nil; nativeContent = nil; trayItem = nil
        previewWindow?.close(); previewWindow = nil; previewContent = nil
        for token in appObservers { NotificationCenter.default.removeObserver(token) }
        for token in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        appObservers.removeAll(); workspaceObservers.removeAll()
        sleeping = false; displaySleeping = false; sessionInactive = false
        model = nil
        status = "未启用"
    }
}

@MainActor final class TouchBarContentView: NSView {
    let lyrics = TouchBarLyricsView()
    let artwork = NSImageView()
    private let controls = NSSegmentedControl()
    private var lastPlaying: Bool?
    var onPrevious: (() -> Void)?
    var onPlayPause: (() -> Void)?
    var onNext: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        artwork.imageScaling = .scaleProportionallyUpOrDown
        controls.segmentCount = 3
        controls.trackingMode = .momentary
        controls.segmentStyle = .rounded
        controls.target = self; controls.action = #selector(controlPressed)
        for (index, symbol) in ["backward.end.fill", "play.fill", "forward.end.fill"].enumerated() {
            controls.setImage(NSImage(systemSymbolName: symbol, accessibilityDescription: ["上一首", "播放或暂停", "下一首"][index]), forSegment: index)
            controls.setWidth(30, forSegment: index)
        }
        controls.setAccessibilityLabel("播放控制")
        for view in [artwork, controls, lyrics] { view.translatesAutoresizingMaskIntoConstraints = false; addSubview(view) }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 30),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 250),
            artwork.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2), artwork.centerYAnchor.constraint(equalTo: centerYAnchor),
            artwork.widthAnchor.constraint(equalToConstant: 28), artwork.heightAnchor.constraint(equalToConstant: 28),
            controls.leadingAnchor.constraint(equalTo: artwork.trailingAnchor, constant: 6), controls.centerYAnchor.constraint(equalTo: centerYAnchor),
            controls.widthAnchor.constraint(equalToConstant: 104),
            lyrics.leadingAnchor.constraint(equalTo: controls.trailingAnchor, constant: 8), lyrics.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            lyrics.topAnchor.constraint(equalTo: topAnchor), lyrics.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var intrinsicContentSize: NSSize { .init(width: NSView.noIntrinsicMetric, height: 30) }

    func update(line: LyricLine?, text: String, position: Double, offset: Int, playing: Bool, artwork image: NSImage?, hasTrack: Bool) {
        if artwork.image !== image { artwork.image = image }
        if lastPlaying != playing {
            controls.setImage(NSImage(systemSymbolName: playing ? "pause.fill" : "play.fill", accessibilityDescription: playing ? "暂停" : "播放"), forSegment: 1)
            lastPlaying = playing
        }
        controls.isEnabled = hasTrack
        lyrics.update(line: line, text: text, position: position, effectiveOffsetMilliseconds: offset, isPlaying: playing)
    }

    @objc private func controlPressed() {
        switch controls.selectedSegment {
        case 0: onPrevious?()
        case 1: onPlayPause?()
        case 2: onNext?()
        default: break
        }
    }
}
