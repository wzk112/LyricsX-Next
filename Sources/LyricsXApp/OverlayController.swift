import AppKit
import SwiftUI
import Observation
import QuartzCore
import LyricsXCore

final class DraggableOverlayPanel: NSPanel {
    var contentDragEnabled = true
    var onDragActivity: ((Bool) -> Void)?
    func shouldDrag(at point: NSPoint) -> Bool {
        let controls = NSRect(x: frame.width - 154, y: frame.height - 48, width: 154, height: 48)
        return contentDragEnabled && !controls.contains(point)
    }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, shouldDrag(at: event.locationInWindow) {
            // The fixed header controls own clicks; all other content can drag.
            onDragActivity?(true)
            performDrag(with: event)
            onDragActivity?(false)
            return
        }
        super.sendEvent(event)
    }
}

@MainActor
final class OverlayController: NSObject, NSWindowDelegate {
    let panel: DraggableOverlayPanel
    let controlPanel: NSPanel
    private let background = OverlayGlassBackground()
    private let content: NSHostingView<OverlayView>
    private let root = NSView()
    private let viewport: OverlayViewport
    private let presentation = OverlayPresentation()
    private let controls: NSHostingView<OverlayControlStrip>
    private unowned let model: AppModel
    private let pointerLocation: () -> NSPoint
    private let frameAutosaveName: String?
    private var lastVisible = false
    private var controlsVisible = false
    private var controlsDetached = false
    private var hoverHidden = false
    private var lastSize = NSSize.zero
    private var explicitShowWhilePaused = false
    private var wasPlaying = false
    private var stopped = false
    private var dragging = false
    private var resizing = false
    private var restoring = true
    private var anchorTop: NSPoint?
    private var lastSizingConfiguration: [Double] = []
    private var resizeGeneration = 0
    private var sizingDocument: UUID?
    private var sizingDocumentRevision: UInt64?
    private var sizingIndex: Int?
    private var sizingConversion = ""
    private var desiredSize = NSSize.zero
    private var localPointerMonitor: Any?
    private var globalPointerMonitor: Any?
    private var pointerRefresh: DispatchWorkItem?
    private var pointerTrackingArea: NSTrackingArea?
    private var screenObserver: NSObjectProtocol?
    private var accessibilityObserver: NSObjectProtocol?

    var isRenderingLyrics: Bool { lastVisible && !hoverHidden && !(presentation.held?.compact ?? model.overlayUsesCompactPresentation) }
    // A compact intro still needs an accurate wake-up for the first lyric.
    var needsPreciseLyricTicks: Bool { lastVisible && !hoverHidden && model.session.document?.isSynced == true && !model.session.documentIsPlaceholder }
    var controlsView: NSView { controls }
    var lyricHostingView: NSView { content }
    private var positionDefaultsKey: String? { frameAutosaveName.map { "LyricsX.OverlayPosition.\($0)" } }
    private var topDefaultsKey: String? { frameAutosaveName.map { "LyricsX.OverlayTop.\($0)" } }
    private var centerDefaultsKey: String? { frameAutosaveName.map { "LyricsX.OverlayCenter.\($0)" } }

    init(model: AppModel, frameAutosaveName: String? = "LyricsXModernOverlay",
         pointerLocation: @escaping () -> NSPoint = { NSEvent.mouseLocation }) {
        self.model = model
        self.pointerLocation = pointerLocation
        self.frameAutosaveName = frameAutosaveName
        panel = DraggableOverlayPanel(contentRect: NSRect(x: 0, y: 0, width: model.preferences.overlayWidth, height: 174),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        controlPanel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 134, height: 34),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let viewport = OverlayViewport(width: model.preferences.overlayWidth)
        self.viewport = viewport
        content = NSHostingView(rootView: OverlayView(model: model, viewport: viewport, presentation: presentation))
        controls = NSHostingView(rootView: OverlayControlStrip(model: model))
        super.init()
        for window in [panel as NSPanel, controlPanel] {
            window.isFloatingPanel = true
            window.level = .floating
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.hidesOnDeactivate = false
            window.isMovableByWindowBackground = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isReleasedWhenClosed = false
        }
        panel.delegate = self
        panel.onDragActivity = { [weak self] dragging in
            guard let self else { return }
            if dragging { self.cancelResize() }
            self.dragging = dragging
            self.refreshAppearance()
            if !dragging { self.saveFrame(); self.updateSizing() }
        }
        root.frame = NSRect(origin: .zero, size: panel.frame.size)
        background.frame = root.bounds.insetBy(dx: 6, dy: 6)
        background.autoresizingMask = [.width, .height]
        content.frame = root.bounds
        content.autoresizingMask = []
        content.sizingOptions = []
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.clear.cgColor
        root.wantsLayer = true
        root.layer?.masksToBounds = true
        root.addSubview(background)
        root.addSubview(content)
        panel.contentView = root
        // Draggable lyrics and controls share a single window/render surface.
        // Only click-through mode needs a second window that can receive clicks.
        root.addSubview(controls)
        controls.frame = inlineControlFrame
        controls.autoresizingMask = [.minXMargin, .minYMargin]
        controls.isHidden = true
        panel.addChildWindow(controlPanel, ordered: .above)
        panel.setAccessibilityLabel("悬浮歌词")
        controlPanel.setAccessibilityLabel("悬浮歌词控制")
        controlPanel.setAccessibilityParent(panel)
        panel.setAccessibilityChildren([content])
        let restoredPosition: Bool
        // Migrate the previous center/origin using the saved frame's top edge.
        // All later sizes share a persistent top-center anchor.
        let restoredLegacyFrame = frameAutosaveName.map { panel.setFrameUsingName($0) } ?? false
        if let key = topDefaultsKey, let value = UserDefaults.standard.string(forKey: key) {
            anchorTop = NSPointFromString(value)
            restoredPosition = true
        } else if let key = centerDefaultsKey, let value = UserDefaults.standard.string(forKey: key) {
            let center = NSPointFromString(value)
            anchorTop = NSPoint(x: center.x, y: center.y + panel.frame.height / 2)
            restoredPosition = true
        } else if let key = positionDefaultsKey,
           let value = UserDefaults.standard.string(forKey: key) {
            panel.setFrameOrigin(NSPointFromString(value))
            restoredPosition = true
        } else {
            restoredPosition = restoredLegacyFrame
        }
        if !restoredPosition, let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - panel.frame.width / 2, y: screen.visibleFrame.minY + 90))
        }
        if anchorTop == nil { anchorTop = NSPoint(x: panel.frame.midX, y: panel.frame.maxY) }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.restoreOnScreen() }
        }
        accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.sync() } }
        restoreOnScreen()
        observeConfiguration()
        restoring = false
    }

    private func observeConfiguration() {
        guard !stopped else { return }
        withObservationTracking {
            sync()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeConfiguration() }
        }
    }

    func stop() {
        presentation.stop()
        cancelResize()
        stopped = true
        resizeGeneration += 1
        stopPointerTracking()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let accessibilityObserver { NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver) }
        controlPanel.orderOut(nil); panel.orderOut(nil)
    }

    func setUserVisible(_ visible: Bool) {
        explicitShowWhilePaused = visible && model.preferences.hideWhenPaused && !model.session.isPlaying
        sync()
    }

    private func sync() {
        presentation.update(model: model)
        let prefs = model.preferences
        if model.session.isPlaying && !wasPlaying { explicitShowWhilePaused = false }
        wasPlaying = model.session.isPlaying
        let autoHidden = prefs.hideWhenPaused && !model.session.isPlaying && !explicitShowWhilePaused
        let visible = prefs.overlayVisible && !autoHidden && model.session.track != nil
        if visible != lastVisible {
            if !visible { cancelResize() }
            lastVisible = visible
            if visible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
        }
        panel.contentDragEnabled = !prefs.overlayLocked && !prefs.overlayClickThrough
        if panel.ignoresMouseEvents != prefs.overlayClickThrough { panel.ignoresMouseEvents = prefs.overlayClickThrough }
        setControlsDetached(prefs.overlayClickThrough)
        background.configure(appearance: prefs.overlayAppearance, transparency: prefs.overlayTransparency,
                             frostAmount: prefs.overlayFrostAmount,
                             reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
                             reduceMotion: prefs.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        updateSizing()
        if visible { startPointerTracking() } else { stopPointerTracking() }
        refreshAppearance()
    }

    private func startPointerTracking() {
        guard localPointerMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        localPointerMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.schedulePointerRefresh()
            return event
        }
        globalPointerMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.schedulePointerRefresh()
        }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect], owner: self)
        root.addTrackingArea(area)
        pointerTrackingArea = area
        panel.acceptsMouseMovedEvents = true
        controlPanel.acceptsMouseMovedEvents = true
    }

    @objc func mouseEntered(_ event: NSEvent) { schedulePointerRefresh() }
    @objc func mouseExited(_ event: NSEvent) { schedulePointerRefresh() }
    @objc func mouseMoved(_ event: NSEvent) { schedulePointerRefresh() }

    private func schedulePointerRefresh() {
        guard lastVisible, !stopped, pointerRefresh == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pointerRefresh = nil
            guard self.lastVisible, !self.stopped else { return }
            self.refreshAppearance()
        }
        pointerRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04, execute: work)
    }

    private func stopPointerTracking() {
        if let localPointerMonitor { NSEvent.removeMonitor(localPointerMonitor) }
        if let globalPointerMonitor { NSEvent.removeMonitor(globalPointerMonitor) }
        localPointerMonitor = nil; globalPointerMonitor = nil
        if let pointerTrackingArea { root.removeTrackingArea(pointerTrackingArea) }
        pointerTrackingArea = nil
        pointerRefresh?.cancel(); pointerRefresh = nil
    }

    func refreshAppearance(at point: NSPoint? = nil) {
        let point = point ?? pointerLocation()
        let prefs = model.preferences
        let inside = panel.frame.contains(point) || (controlsDetached && controlsVisible && controlPanel.frame.contains(point))
        let hidden = lastVisible && prefs.hideOverlayOnHover && prefs.overlayLocked && inside
        let rendering = lastVisible && !hidden
        if viewport.rendering != rendering { viewport.rendering = rendering }
        if hoverHidden != hidden {
            hoverHidden = hidden
            NSAnimationContext.runAnimationGroup { context in
                context.duration = prefs.reduceMotion ? 0 : 0.16
                content.animator().alphaValue = hidden ? 0 : 1
                background.animator().alphaValue = hidden ? 0 : 1
            }
        }
        let showControls = lastVisible && (inside || dragging)
        if showControls != controlsVisible {
            controlsVisible = showControls
            if showControls {
                controls.isHidden = false
                controls.alphaValue = 0
                if controlsDetached {
                    positionControlPanel()
                    controlPanel.orderFrontRegardless()
                }
            }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = prefs.reduceMotion || dragging || !lastVisible ? 0 : 0.16
                controls.animator().alphaValue = showControls ? 1 : 0
            } completionHandler: { [weak self] in
                Task { @MainActor in
                    guard let self, !self.controlsVisible else { return }
                    self.controls.isHidden = true
                    self.controlPanel.orderOut(nil)
                }
            }
            if prefs.reduceMotion || !lastVisible, !showControls {
                controls.isHidden = true
                controlPanel.orderOut(nil)
            }
            panel.setAccessibilityChildren(showControls ? [content, controls] : [content])
        }
    }

    private var inlineControlFrame: NSRect {
        NSRect(x: root.bounds.width - 148, y: root.bounds.height - 42, width: 134, height: 34)
    }

    private func setControlsDetached(_ detached: Bool) {
        guard detached != controlsDetached else { return }
        controlsDetached = detached
        controls.removeFromSuperview()
        if detached {
            controls.frame = NSRect(origin: .zero, size: NSSize(width: 134, height: 34))
            controls.autoresizingMask = [.width, .height]
            controlPanel.contentView = controls
            positionControlPanel()
            if controlsVisible && lastVisible { controlPanel.orderFrontRegardless() }
        } else {
            controlPanel.contentView = nil
            controlPanel.orderOut(nil)
            controls.frame = inlineControlFrame
            controls.autoresizingMask = [.minXMargin, .minYMargin]
            root.addSubview(controls)
        }
    }

    private func updateSizing() {
        guard !stopped, !dragging else { return }
        let p = model.preferences
        let maximum = p.overlayLayoutWidth
        // Size the snapshot actually being drawn. During the short handover,
        // the live session can already be waiting while old lyrics fade out.
        let display = presentation.held ?? OverlayDisplaySnapshot(model: model, at: ProcessInfo.processInfo.systemUptime)
        let mode = display.mode
        // No observation of the display clock: only a line/setting change can
        // request a new size. Retarget native animation immediately in either direction.
        let document = display.document
        let index = display.index
        let configuration = [maximum, p.fontSize, p.translationFontSize,
            p.nextLineFontSize, Double(OverlaySecondaryMode.allCases.firstIndex(of: p.overlaySecondaryMode) ?? 0),
            p.overlayAdaptiveSize ? 1 : 0, Double(mode.rawValue), p.showTranslation ? 1 : 0,
            p.overlayPrimarySpacing, p.overlaySecondarySpacing]
        let changed = configuration != lastSizingConfiguration
        let replaced = display.documentRevision != sizingDocumentRevision
        if replaced, let document { OverlayTextMeasure.invalidateLayoutText(for: document.id) }
        if changed || replaced || document?.id != sizingDocument || index != sizingIndex || p.conversion != sizingConversion {
            if mode == .waiting { desiredSize = NSSize(width: maximum, height: OverlayPresentationMode.waitingHeight) }
            else if mode == .song { desiredSize = NSSize(width: maximum, height: OverlaySongCardLayout(width: maximum).height) }
            else if p.overlayAdaptiveSize, let document, let index {
                desiredSize = OverlayTextMeasure.desiredSize(document: document, index: index, preferences: p, maximumWidth: maximum)
            } else { desiredSize = NSSize(width: maximum, height: OverlayLayoutMetrics.height(preferences: p)) }
            sizingDocumentRevision = display.documentRevision
            sizingDocument = document?.id; sizingIndex = index; sizingConversion = p.conversion
        }
        lastSizingConfiguration = configuration
        let size = desiredSize
        let canvas = NSSize(width: maximum, height: max(size.height,
            max(OverlaySongCardLayout(width: maximum).height, OverlayLayoutMetrics.height(preferences: p))))
        if content.frame.size != canvas { content.setFrameSize(canvas) }
        positionContent()
        guard size != lastSize else { return }
        lastSize = size
        viewport.width = size.width
        let target = anchoredFrame(size: size)
        resizeGeneration += 1
        let generation = resizeGeneration
        resizing = true
        let animate = !restoring && panel.isVisible && !p.reduceMotion && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animate ? (size.width > panel.frame.width || size.height > panel.frame.height ? 0.34 : 0.48) : 0
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0, 0.18, 1)
            if animate { panel.animator().setFrame(target, display: true) }
            else { panel.setFrame(target, display: true) }
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.resizeGeneration == generation, !self.stopped else { return }
                self.resizing = false
                self.positionContent(); self.positionControlPanel()
            }
        }
        if !animate { resizing = false }
        positionContent(); positionControlPanel()
    }

    private func anchoredFrame(size: NSSize) -> NSRect {
        let top = anchorTop ?? NSPoint(x: panel.frame.midX, y: panel.frame.maxY)
        let screen = NSScreen.screens.first { $0.frame.contains(top) } ?? NSScreen.main
        return OverlayAnchor(topCenter: top).frame(size: size, in: screen?.visibleFrame ?? panel.frame)
    }

    private func cancelResize() {
        guard resizing else { return }
        resizeGeneration += 1
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            panel.animator().setFrame(panel.frame, display: true)
        }
        resizing = false
        lastSize = panel.frame.size
    }

    func restoreOnScreen() {
        cancelResize()
        let frame = anchoredFrame(size: panel.frame.size)
        let wasResizing = resizing; resizing = true
        if frame != panel.frame { panel.setFrame(frame, display: true) }
        resizing = wasResizing
        if let anchorTop, !NSScreen.screens.contains(where: { $0.frame.contains(anchorTop) }) {
            self.anchorTop = NSPoint(x: frame.midX, y: frame.maxY)
            if !restoring { saveFrame() }
        }
        positionContent(); positionControlPanel()
    }

    private func positionContent() {
        // Move the persistent maximum-size canvas; never resize its bounds for
        // animated window frames. SwiftUI typography and HDR surfaces survive.
        let origin = NSPoint(x: (root.bounds.width - content.frame.width) / 2,
                             y: root.bounds.height - content.frame.height)
        if content.frame.origin != origin { content.setFrameOrigin(origin) }
    }

    func windowDidResize(_ notification: Notification) {
        schedulePointerRefresh()
        positionContent(); positionControlPanel()
    }

    private func positionControlPanel() {
        let origin = NSPoint(x: panel.frame.maxX - 148, y: panel.frame.maxY - 42)
        if controlPanel.frame.origin != origin { controlPanel.setFrameOrigin(origin) }
    }

    func windowDidMove(_ notification: Notification) {
        schedulePointerRefresh()
        // Inline controls are part of this window, so dragging needs no second
        // window update, timer, animation, or end-of-drag position correction.
        if !dragging && !resizing && !restoring { saveFrame() }
    }

    private func saveFrame() {
        guard !restoring else { return }
        anchorTop = NSPoint(x: panel.frame.midX, y: panel.frame.maxY)
        if let key = topDefaultsKey, let anchorTop { UserDefaults.standard.set(NSStringFromPoint(anchorTop), forKey: key) }
        if let frameAutosaveName { panel.saveFrame(usingName: frameAutosaveName) }
        if let key = positionDefaultsKey { UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: key) }
    }

}

struct OverlayView: View {
    @Bindable var model: AppModel
    var viewport: OverlayViewport
    var presentation: OverlayPresentation?
    @State private var windowVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        let maximum = model.preferences.overlayLayoutWidth
        let display = presentation?.held ?? OverlayDisplaySnapshot(model: model, at: ProcessInfo.processInfo.systemUptime)
        let compact = display.compact
        let card = OverlaySongCardLayout(width: maximum)
        let height = presentationHeight(maximum: maximum, display: display)
        let transition = contentTransition(display: display)
        VStack(spacing: 0) {
            if display.mode == .waiting {
                songHeader(display: display)
                Spacer(minLength: 4)
                HStack(spacing: 6) {
                    ForEach(0..<3) { _ in Circle().fill(.white.opacity(0.94)).frame(width: 5, height: 5) }
                }.shadow(color: .black.opacity(0.85), radius: 2, y: 1)
                    .accessibilityElement(children: .ignore).accessibilityLabel("等待歌词")
                Spacer(minLength: 10)
            } else if compact {
                HStack(spacing: card.spacing) {
                    Group {
                        if let artwork = display.artwork {
                            Image(nsImage: artwork).resizable().scaledToFill()
                        } else {
                            ZStack { Color.white.opacity(0.08); Image(systemName: "music.note").font(.system(size: 18)) }
                        }
                    }.frame(width: card.artwork, height: card.artwork).clipShape(.rect(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(display.track?.title ?? "LyricsX Next")
                            .font(.system(size: card.title, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.85)
                        if let artist = display.track?.artist, !artist.isEmpty {
                            Text(artist).font(.system(size: card.artist, weight: .medium)).lineLimit(1).opacity(0.8)
                        }
                    }.shadow(color: .black.opacity(0.8), radius: 2, y: 1)
                }.frame(maxWidth: card.contentWidth, alignment: .center)
            } else {
                songHeader(display: display)
                Spacer(minLength: 4)
                ZStack {
                    if let doc = display.document, let index = display.index {
                        OverlayLyricsContent(preferences: model.preferences, document: doc, index: index,
                                             lyricTime: { doc.lyricTime(for: presentation?.held?.position ?? model.session.position) },
                                             renderTime: { doc.lyricTime(for: presentation?.held?.position ?? model.session.presentationPosition()) },
                                             playing: display.playing && windowVisible && viewport.rendering,
                                             visible: windowVisible && viewport.rendering,
                                             adaptiveCanvasWidth: model.preferences.overlayAdaptiveSize ? maximum - 60 : nil)
                    } else { Text(placeholder) }
                }.font(.system(size: model.preferences.fontSize, weight: .semibold))
                    .shadow(color: .black.opacity(0.8), radius: 1.5, y: 1)
                    .shadow(color: .black.opacity(0.35), radius: 5, y: 1)
                Spacer(minLength: 10)
            }
        }.padding(.horizontal, 24).padding(.vertical, 12)
            .foregroundStyle(.white)
            .padding(6)
            .frame(width: maximum, height: display.mode == .waiting ? OverlayPresentationMode.waitingHeight : compact ? card.height : height)
            .modifier(transition)
            .hdrDisplayScope(requested: model.preferences.lyricEmphasis.usesHDR)
            .environment(\.lyricFrameRateLimit, model.preferences.overlayFrameRate.limit)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(WindowVisibilityReader { windowVisible = $0 }.frame(width: 0, height: 0))
    }
    private func songHeader(display: OverlayDisplaySnapshot) -> some View {
        HStack(spacing: 6) {
            Text(display.track?.title ?? "LyricsX Next").lineLimit(1)
            if let artist = display.track?.artist, !artist.isEmpty { Text("· " + artist).lineLimit(1).opacity(0.85) }
            Spacer(minLength: 4)
            Color.clear.frame(width: 126, height: 30)
        }.font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.92))
            .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
            .frame(width: max(260, viewport.width - 60), height: 30)
    }
    private func contentTransition(display: OverlayDisplaySnapshot) -> OverlayContentTransition {
        let p = model.preferences, compact = display.compact
        let identity = OverlayContentIdentity(track: display.track?.id,
            primary: display.mode == .waiting ? "•••" : compact ? display.track?.artist ?? "" : placeholder,
            compact: compact, artwork: display.mode == .song ? display.artwork.map(ObjectIdentifier.init) : nil)
        return OverlayContentTransition(identity: identity.songScope,
            reduced: reduceMotion || p.reduceMotion, visible: windowVisible && viewport.rendering, preparingSince: presentation?.preparingSince)
    }
    private func presentationHeight(maximum: Double, display: OverlayDisplaySnapshot) -> Double {
        guard model.preferences.overlayAdaptiveSize, let document = display.document,
              let index = display.index else { return OverlayLayoutMetrics.height(preferences: model.preferences) }
        return OverlayTextMeasure.height(document: document, index: index, preferences: model.preferences, maximumWidth: maximum)
    }
    private var placeholder: String {
        if model.lyricsBlocked { return "已停用此歌曲歌词" }
        if model.session.document?.isInstrumental == true { return "纯音乐" }
        if model.session.document?.isSynced == false { return "此歌词暂无时间轴" }
        if model.session.phase == .loading { return "正在寻找歌词…" }
        if model.session.document != nil { return "•••" }
        return model.session.track == nil ? "未在播放" : "还没有找到歌词"
    }
}

private struct OverlayControlStrip: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        HStack(spacing: 2) {
            SymbolButton(symbol: "arrow.up.left.and.arrow.down.right", help: "打开主窗口", inactiveOpacity: 0.92) { model.showMainWindow?() }
            SymbolButton(symbol: model.preferences.overlayLocked ? "lock.fill" : "lock.open", help: model.preferences.overlayLocked ? "解锁并恢复拖动" : "锁定位置", active: model.preferences.overlayLocked, inactiveOpacity: 0.92) {
                model.setOverlayLocked(!model.preferences.overlayLocked)
            }
            SymbolButton(symbol: model.preferences.overlayClickThrough ? "cursorarrow.slash" : "cursorarrow.rays", help: model.preferences.overlayClickThrough ? "关闭点击穿透" : "开启点击穿透", active: model.preferences.overlayClickThrough, inactiveOpacity: 0.92) {
                model.setOverlayClickThrough(!model.preferences.overlayClickThrough)
            }
            SymbolButton(symbol: "xmark", help: "隐藏悬浮歌词", inactiveOpacity: 0.92) { model.setOverlayVisible(false) }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.65), radius: 1, y: 1)
        .padding(2)
        // A minimum local scrim keeps white controls legible over white pages.
        // Keep this independent from the user's much lighter lyric glass tint.
        .background(reduceTransparency ? Color(white: 0.16) : .black.opacity(max(0.52, 1 - model.preferences.overlayTransparency)), in: .capsule)
        .glassEffect(.clear, in: .capsule)
        .overlay { Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 0.5).allowsHitTesting(false) }
    }
}
