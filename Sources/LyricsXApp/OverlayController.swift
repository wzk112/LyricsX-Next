import AppKit
import SwiftUI
import Observation
import QuartzCore
import LyricsXCore

final class DraggableOverlayPanel: OverlayMaterialPanel {
    var contentDragEnabled = true
    var onDragActivity: ((Bool) -> Void)?
    var onDragAnchor: ((NSPoint) -> Void)?
    private var pointerOffset: NSPoint?
    func shouldDrag(at point: NSPoint) -> Bool {
        let controls = NSRect(x: frame.width - 154, y: frame.height - 48, width: 154, height: 48)
        return contentDragEnabled && !controls.contains(point)
    }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, shouldDrag(at: event.locationInWindow) {
            // AppKit performDrag owns the whole frame, including its initial
            // size. Track the pointer anchor instead so live lyric resizing
            // and movement use one writer rather than competing frame loops.
            let pointer = convertPoint(toScreen: event.locationInWindow)
            pointerOffset = NSPoint(x: pointer.x - frame.midX, y: pointer.y - frame.maxY)
            onDragActivity?(true)
            return
        }
        if let offset = pointerOffset, event.type == .leftMouseDragged || event.type == .leftMouseUp {
            // Use the delivered event in the same coordinate space as mouse
            // down. The global pointer may already be elsewhere when this
            // background/nonactivating window processes a queued drag.
            let pointer = convertPoint(toScreen: event.locationInWindow)
            onDragAnchor?(NSPoint(x: pointer.x - offset.x, y: pointer.y - offset.y))
            if event.type == .leftMouseUp { finishContentDrag() }
            return
        }
        super.sendEvent(event)
    }
    private func finishContentDrag() {
        guard pointerOffset != nil else { return }
        pointerOffset = nil
        onDragActivity?(false)
    }
    override func orderOut(_ sender: Any?) {
        finishContentDrag()
        super.orderOut(sender)
    }
}

private final class OverlayHeaderHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
final class OverlayController: NSObject, NSWindowDelegate {
    let panel: DraggableOverlayPanel
    let controlPanel: NSPanel
    private let background = OverlayGlassBackground()
    private let waveform = OverlayWaveformView(frame: .zero)
    private let content: NSHostingView<OverlayThemedRoot<OverlayView>?>
    private let header: OverlayHeaderHostingView<OverlayThemedRoot<OverlayPinnedSongHeader>?>
    private let root = NSView()
    private let viewport: OverlayViewport
    private let presentation = OverlayPresentation()
    private let controls: NSHostingView<OverlayThemedRoot<OverlayControlStrip>?>
    private unowned let model: AppModel
    private let pointerLocation: () -> NSPoint
    private let frameAutosaveName: String?
    private var lastVisible = false
    private var controlsVisible = false
    private var controlsFadeGeneration: UInt64 = 0
    private var motionReductionActive = false
    private var controlsDetached = false
    private var hoverHidden = false
    private var windowVisibilityGeneration: UInt64 = 0
    private var windowVisibilityTarget = false
    private var windowFadeActive = false
    private var lastSize = NSSize.zero
    private var resizeTarget: NSRect?
    private var explicitShowWhilePaused = false
    private var wasPlaying = false
    private var waveformSuspended = false
    private var stopped = false
    private var dragging = false
    private var resizing = false
    private var restoring = true
    private var anchorTop: NSPoint?
    private var lastSizingConfiguration: [Double] = []
    private(set) var resizeGeneration = 0
    private var resizeSettlement: Task<Void, Never>?
    private lazy var frameMotion = OverlayWindowMotion(window: panel)
    private var sizingDocument: UUID?
    private var sizingDocumentRevision: UInt64?
    private var sizingIndex: Int?
    private var sizingConversion = ""
    private var sizingFont = ""
    private var sizingSongTitle = ""
    private var sizingSongArtist = ""
    private var desiredSize = NSSize.zero
    private var centersVisibleContent = false
    private var showsPinnedHeader = false
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
    var pinnedHeaderView: NSView { header }
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
        // AppKit may resolve glass activity while the hosting tree attaches.
        // Set the optical appearance before any views enter the window.
        panel.keepsGlassAppearanceActive = !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        controlPanel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 134, height: 34),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let viewport = OverlayViewport(width: model.preferences.overlayWidth)
        self.viewport = viewport
        content = NSHostingView(rootView: OverlayThemedRoot(preferences: model.preferences,
            content: OverlayView(model: model, viewport: viewport, presentation: presentation)))
        header = OverlayHeaderHostingView(rootView: OverlayThemedRoot(preferences: model.preferences,
            content: OverlayPinnedSongHeader(model: model, presentation: presentation)))
        controls = NSHostingView(rootView: OverlayThemedRoot(preferences: model.preferences,
            content: OverlayControlStrip(model: model)))
        super.init()
        waveform.onStatusChange = { [weak model] status in
            guard let model, model.preferences.overlayWaveformStatus != status else { return }
            model.preferences.overlayWaveformStatus = status
        }
        viewport.contentSizeChanged = { [weak self] _ in
            guard let self, !self.stopped else { return }
            // A SwiftUI task may arrive after the session has already moved to
            // another cue. Reconcile against the latest snapshot, never replay
            // an old view's height over a newer controller request.
            self.updateSizing()
        }
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
            self.dragging = dragging
            if dragging {
                self.moveDraggedWindow(to: NSPoint(x: self.panel.frame.midX, y: self.panel.frame.maxY))
            }
            self.refreshAppearance()
            if !dragging { self.saveFrame(); self.updateSizing() }
        }
        panel.onDragAnchor = { [weak self] point in self?.moveDraggedWindow(to: point) }
        root.frame = NSRect(origin: .zero, size: panel.frame.size)
        background.frame = root.bounds.insetBy(dx: 6, dy: 6)
        background.alphaValue = 1
        panel.alphaValue = 0
        controlPanel.alphaValue = 0
        background.autoresizingMask = [.width, .height]
        content.frame = root.bounds
        content.autoresizingMask = []
        content.sizingOptions = []
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.clear.cgColor
        header.sizingOptions = []
        header.wantsLayer = true
        header.layer?.backgroundColor = NSColor.clear.cgColor
        root.wantsLayer = true
        root.layer?.masksToBounds = true
        root.addSubview(background)
        root.addSubview(content)
        root.addSubview(header)
        root.addSubview(waveform)
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
        panel.setAccessibilityChildren([content, header])
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
        guard !stopped else { return }
        waveform.stop()
        windowVisibilityGeneration &+= 1
        windowFadeActive = false
        controlsFadeGeneration &+= 1
        presentation.stop()
        cancelResize()
        stopped = true
        lastVisible = false; controlsVisible = false; viewport.rendering = false
        viewport.contentSizeChanged = nil
        resizeSettlement?.cancel()
        resizeGeneration += 1
        stopPointerTracking()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let accessibilityObserver { NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver) }
        screenObserver = nil; accessibilityObserver = nil
        panel.onDragActivity = nil; panel.onDragAnchor = nil; panel.delegate = nil
        panel.alphaValue = 0; controlPanel.alphaValue = 0
        controlPanel.orderOut(nil); panel.orderOut(nil)
        // Hosted SwiftUI roots own the model. Ordering a window out alone does
        // not break model → controller → host → model, or release display links.
        content.rootView = nil; header.rootView = nil; controls.rootView = nil
        panel.setAccessibilityChildren([])
        panel.removeChildWindow(controlPanel)
        controlPanel.contentView = nil; panel.contentView = nil
        controls.removeFromSuperview(); content.removeFromSuperview()
        waveform.removeFromSuperview()
        controlPanel.close(); panel.close()
    }

    func setUserVisible(_ visible: Bool) {
        explicitShowWhilePaused = visible && model.preferences.hideWhenPaused && !model.session.isPlaying
        sync()
    }

    func suspendWaveform() { waveformSuspended = true; waveform.stop() }
    func resumeWaveform() { waveformSuspended = false; waveform.wakeForRecovery(); sync() }
    func retryWaveform() { waveform.retry(); updateWaveform() }

    private func sync() {
        guard !stopped else { return }
        presentation.update(model: model)
        let prefs = model.preferences
        if model.session.isPlaying && !wasPlaying { explicitShowWhilePaused = false }
        wasPlaying = model.session.isPlaying
        let autoHidden = prefs.hideWhenPaused && !model.session.isPlaying && !explicitShowWhilePaused
        let visible = prefs.overlayVisible && !autoHidden && model.session.track != nil
        let showing = visible && !lastVisible
        if visible != lastVisible {
            if !visible { cancelResize() }
            lastVisible = visible
        }
        panel.contentDragEnabled = !prefs.overlayLocked && !prefs.overlayClickThrough
        if panel.ignoresMouseEvents != prefs.overlayClickThrough { panel.ignoresMouseEvents = prefs.overlayClickThrough }
        setControlsDetached(prefs.overlayClickThrough)
        // Set activity policy before AppKit resolves any new appearance/style.
        // Reading glass also has an explicit ink palette and must not silently
        // switch to an inactive/adaptive material when the main window closes.
        panel.keepsGlassAppearanceActive = !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        let appearance = prefs.overlayEffectiveTheme.appearance
        for window in [panel as NSPanel, controlPanel] {
            if window.appearance?.name != appearance?.name { window.appearance = appearance }
        }
        // Scope the actual drawing surfaces too, including detached controls.
        // The setting must not depend on activation or a future lyric update.
        for view in [content, header, controls] as [NSView] {
            if view.appearance?.name != appearance?.name { view.appearance = appearance }
        }
        background.configure(appearance: prefs.overlayAppearance, transparency: prefs.overlayMaterialTransparency,
                             frostAmount: prefs.overlayFrostAmount,
                             reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
                             reduceMotion: prefs.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                             theme: prefs.overlayEffectiveTheme)
        let reducedMotion = prefs.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reducedMotion && !motionReductionActive { settleReducedMotion() }
        motionReductionActive = reducedMotion
        updateSizing()
        // Finish geometry while still hidden, then expose one coherent frame.
        if showing && !panel.isVisible { panel.orderFrontRegardless() }
        // AppKit can order a child panel forward with its parent even before
        // the controls have ever been detached into that panel.
        if !controlsDetached && controlPanel.isVisible { controlPanel.orderOut(nil) }
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
        guard !stopped else { return }
        let point = point ?? pointerLocation()
        let prefs = model.preferences
        let inside = panel.frame.contains(point) || (controlsDetached && controlsVisible && controlPanel.frame.contains(point))
        let hidden = lastVisible && !dragging && prefs.hideOverlayOnHover && prefs.overlayLocked && inside
        let presenting = lastVisible && !hidden
        let reducedMotion = prefs.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        hoverHidden = hidden
        if presenting {
            background.isHidden = false
            if !viewport.rendering { viewport.rendering = true }
            updateWaveform()
        } else {
            let source = model.session.track?.playerID
            waveform.freezeVisualForFade(enabled: prefs.overlayWaveformEnabled,
                playing: model.session.isPlaying, source: source,
                trackRevision: model.session.trackRevision)
        }
        transitionWindow(to: presenting, reducedMotion: reducedMotion)
        // Detached controls are a separate interactive window. Hover hiding
        // keeps its unlock/restore affordance available while the lyric panel
        // fades; inline controls naturally share the panel compositor fade.
        let showControls = lastVisible && (inside || dragging)
        if showControls != controlsVisible {
            controlsVisible = showControls
            controlsFadeGeneration &+= 1
            let fadeGeneration = controlsFadeGeneration
            if !showControls && !windowVisibilityTarget && windowFadeActive && !reducedMotion {
                // Manual and pause dismissal fade the entire surface, so the
                // control contents stay intact until that active fade ends.
                // A completed hover fade already targets a transparent panel;
                // its detached controls need their own dismissal on pause.
                panel.setAccessibilityChildren([content, header])
                return
            }
            if showControls {
                let wasHidden = controls.isHidden
                controls.isHidden = false
                if wasHidden { controls.alphaValue = 0 }
                if controlsDetached {
                    positionControlPanel()
                    controlPanel.alphaValue = hidden ? 1 : panel.alphaValue
                    controlPanel.orderFrontRegardless()
                }
            }
            let animateControls = !reducedMotion && !dragging && controls.window?.isVisible == true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animateControls ? 0.16 : 0
                controls.animator().alphaValue = showControls ? 1 : 0
            } completionHandler: { [weak self] in
                Task { @MainActor in
                    guard let self, !self.stopped,
                          self.controlsFadeGeneration == fadeGeneration, !self.controlsVisible else { return }
                    self.controls.isHidden = true
                    self.controlPanel.orderOut(nil)
                }
            }
            if !animateControls && !showControls {
                // An inline strip's parent may already be ordered out after
                // hover hiding. Hidden hosts have no fade cycle to complete.
                controls.alphaValue = 0
                controls.isHidden = true
                controlPanel.orderOut(nil)
            }
            panel.setAccessibilityChildren(showControls ? [content, header, controls] : [content, header])
        }
    }

    private func transitionWindow(to visible: Bool, reducedMotion: Bool) {
        guard visible != windowVisibilityTarget else {
            if reducedMotion && windowFadeActive {
                windowVisibilityGeneration &+= 1
                finishWindowTransition(visible: visible)
            } else if !visible && !lastVisible && !windowFadeActive { panel.orderOut(nil) }
            return
        }
        windowVisibilityTarget = visible
        windowVisibilityGeneration &+= 1
        let generation = windowVisibilityGeneration
        if visible {
            background.isHidden = false
            if !controlsVisible {
                controls.alphaValue = 0
                controls.isHidden = true
                controlPanel.orderOut(nil)
            }
            if !panel.isVisible { panel.orderFrontRegardless() }
        }
        let animate = !reducedMotion && !restoring && panel.isVisible
        guard animate else { finishWindowTransition(visible: visible); return }
        windowFadeActive = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = visible ? 1 : 0
            if controlPanel.isVisible && (visible || !lastVisible) {
                controlPanel.animator().alphaValue = visible ? 1 : 0
            }
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, !self.stopped, self.windowVisibilityGeneration == generation else { return }
                self.finishWindowTransition(visible: visible)
            }
        }
    }

    private func finishWindowTransition(visible: Bool) {
        windowFadeActive = false
        panel.alphaValue = visible ? 1 : 0
        let retainedHoverControls = !visible && lastVisible && hoverHidden && controlsDetached && controlsVisible
        controlPanel.alphaValue = visible || retainedHoverControls ? 1 : 0
        if visible {
            background.isHidden = false
            if !viewport.rendering { viewport.rendering = true }
            updateWaveform()
        } else {
            if viewport.rendering { viewport.rendering = false }
            waveform.stop()
            if !controlsVisible {
                controls.alphaValue = 0
                controls.isHidden = true
            }
            if !lastVisible { panel.orderOut(nil) }
            if !retainedHoverControls { controlPanel.orderOut(nil) }
        }
    }

    private func updateWaveform() {
        let prefs = model.preferences
        waveform.configure(enabled: prefs.overlayWaveformEnabled,
            visible: lastVisible && !hoverHidden && !waveformSuspended,
            playing: model.session.isPlaying,
            reducedMotion: prefs.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            bundleID: model.session.track?.playerID,
            style: prefs.overlayWaveformStyle,
            lightGlass: prefs.overlayEffectiveTheme.resolvedScheme == .light,
            theme: prefs.artworkTheme,
            frameRateLimit: prefs.overlayFrameRate.limit,
            trackRevision: model.session.trackRevision)
    }

    private var inlineControlFrame: NSRect {
        NSRect(x: root.bounds.width - 148, y: root.bounds.height - 42, width: 134, height: 34)
    }

    private func setControlsDetached(_ detached: Bool) {
        guard detached != controlsDetached else { return }
        controlsFadeGeneration &+= 1
        // Moving the hosting view between windows invalidates its old fade
        // completion. Commit the latest target before the old host releases it;
        // an alpha-zero view must not remain hittable in the new host.
        controls.layer?.removeAnimation(forKey: "opacity")
        controls.alphaValue = controlsVisible ? 1 : 0
        controls.isHidden = !controlsVisible
        controlsDetached = detached
        controls.removeFromSuperview()
        if detached {
            controls.frame = NSRect(origin: .zero, size: NSSize(width: 134, height: 34))
            controls.autoresizingMask = [.width, .height]
            controlPanel.contentView = controls
            positionControlPanel()
            if controlsVisible && lastVisible {
                controlPanel.alphaValue = hoverHidden ? 1 : panel.alphaValue
                controlPanel.orderFrontRegardless()
            }
            else { controlPanel.orderOut(nil) }
        } else {
            controlPanel.contentView = nil
            controlPanel.orderOut(nil)
            controls.frame = inlineControlFrame
            controls.autoresizingMask = [.minXMargin, .minYMargin]
            root.addSubview(controls)
        }
    }

    private func settleReducedMotion() {
        resizeSettlement?.cancel(); resizeSettlement = nil
        frameMotion.finish()
        resizing = false
        positionContent(); positionControlPanel()
        windowVisibilityGeneration &+= 1
        if windowFadeActive { finishWindowTransition(visible: windowVisibilityTarget) }
        background.isHidden = false
        controlsFadeGeneration &+= 1
        controls.layer?.removeAnimation(forKey: "opacity")
        controls.alphaValue = controlsVisible ? 1 : 0
        controls.isHidden = !controlsVisible
        if !controlsVisible { controlPanel.orderOut(nil) }
        else if controlsDetached && lastVisible && !controlPanel.isVisible { controlPanel.orderFrontRegardless() }
    }

    private func updateSizing() {
        guard !stopped else { return }
        // A hosted view can report its new size before observation calls sync.
        // Establish the departing-lyric handover before accepting that size.
        presentation.update(model: model)
        let p = model.preferences
        let maximum = p.overlayLayoutWidth
        // Size the snapshot actually being drawn. During the short handover,
        // the live session can already be waiting while old lyrics fade out.
        let display = presentation.held ?? OverlayDisplaySnapshot(model: model, at: ProcessInfo.processInfo.systemUptime)
        let mode = display.mode
        // Keep one positioning rule through waiting/card/lyric changes.
        // Switching rules before the native resize moved the host instantly.
        centersVisibleContent = !p.overlayWaveformEnabled
        showsPinnedHeader = mode == .lyrics
        // No observation of the display clock: only a line/setting change can
        // request a new size. Retarget native animation immediately in either direction.
        let document = display.document
        let index = display.index
        let card = OverlaySongCardLayout(width: maximum, title: display.track?.title,
            artist: display.track?.artist)
        let configuration = [maximum, p.fontSize, p.translationFontSize,
            p.nextLineFontSize, Double(OverlaySecondaryMode.allCases.firstIndex(of: p.overlaySecondaryMode) ?? 0),
            p.overlayAdaptiveSize ? 1 : 0, Double(mode.rawValue), p.showTranslation ? 1 : 0,
            p.overlayPrimarySpacing, p.overlaySecondarySpacing]
            + [p.overlayWaveformEnabled ? 1 : 0]
        let changed = configuration != lastSizingConfiguration
        let replaced = display.documentRevision != sizingDocumentRevision
        if replaced, let document { OverlayTextMeasure.invalidateLayoutText(for: document.id) }
        if changed || replaced || document?.id != sizingDocument || index != sizingIndex || p.conversion != sizingConversion || p.lyricFontName != sizingFont
            || mode == .song && (card.displayedTitle != sizingSongTitle || card.displayedArtist != sizingSongArtist) {
            if mode == .waiting { desiredSize = NSSize(width: maximum, height: OverlayPresentationMode.waitingHeight) }
            else if mode == .song { desiredSize = NSSize(width: maximum,
                height: card.baseHeight(waveformEnabled: p.overlayWaveformEnabled)) }
            else { desiredSize = NSSize(width: maximum, height: OverlayLyricsWindowLayout.baseHeight(
                document: document, index: index, preferences: p, maximumWidth: maximum)) }
            desiredSize.height = OverlayWaveformLayout.totalHeight(content: desiredSize.height,
                enabled: p.overlayWaveformEnabled)
            sizingDocumentRevision = display.documentRevision
            sizingDocument = document?.id; sizingIndex = index; sizingConversion = p.conversion
            sizingFont = p.lyricFontName
            sizingSongTitle = card.displayedTitle; sizingSongArtist = card.displayedArtist
        }
        lastSizingConfiguration = configuration
        applySize(desiredSize, cardHeight: card.baseHeight(waveformEnabled: p.overlayWaveformEnabled))
    }

    private func applySize(_ measuredSize: NSSize, cardHeight: Double) {
        // AppKit rounds window dimensions to whole points. Comparing its
        // settled frame to fractional text metrics restarts an identical
        // animation on subsequent observations, especially during playback.
        let size = NSSize(width: ceil(measuredSize.width), height: ceil(measuredSize.height))
        let p = model.preferences
        let maximum = size.width
        let canvas = NSSize(width: maximum, height: max(size.height,
            OverlayWaveformLayout.totalHeight(content:
                max(cardHeight, OverlayLayoutMetrics.height(preferences: p)),
                enabled: p.overlayWaveformEnabled)))
        if content.frame.size != canvas { content.setFrameSize(canvas) }
        positionContent()
        // A requested size is not evidence that the native animation arrived.
        let target = anchoredFrame(size: size)
        if !resizing, panel.frame == target {
            // A drag changed the anchor, not the size. Adopt its resting frame
            // without starting an identical resize on the next playback tick.
            lastSize = size; resizeTarget = target; viewport.width = size.width
            return
        }
        guard size != lastSize || resizeTarget != target || (!resizing && panel.frame != target) else { return }
        lastSize = size
        resizeTarget = target
        viewport.width = size.width
        resizeGeneration += 1
        let generation = resizeGeneration
        resizeSettlement?.cancel()
        resizing = true
        let animate = !restoring && panel.isVisible && panel.screen != nil && !hoverHidden && !p.reduceMotion && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let duration = animate ? (size.width > panel.frame.width || size.height > panel.frame.height ? 0.34 : 0.48) : 0
        let logicalTopCenter = anchorTop ?? NSPoint(x: panel.frame.midX, y: panel.frame.maxY)
        frameMotion.start(to: target, logicalTopCenter: logicalTopCenter,
                          visibleFrame: dragging ? nil : visibleFrame(for: logicalTopCenter),
                          duration: duration, frameRateLimit: p.overlayFrameRate.limit,
                          constrainToVisibleFrame: !dragging) { [weak self] in
            guard let self, self.resizeGeneration == generation, !self.stopped else { return }
            self.resizing = false
            self.positionContent(); self.positionControlPanel()
        }
        if !animate { resizing = false }
        positionContent(); positionControlPanel()
        if animate {
            // Native animation completion can be delayed when a window is
            // occluded. A single cancellable deadline also settles that case.
            resizeSettlement = Task { @MainActor [weak self] in
                // A retargeted spring carries velocity; allow it to settle
                // naturally before this occlusion-only fail-safe snaps home.
                do { try await Task.sleep(for: .seconds(max(1.2, duration * 3))) } catch { return }
                guard let self, !self.stopped, self.resizeGeneration == generation else { return }
                self.frameMotion.finish()
                self.resizing = false
                self.positionContent(); self.positionControlPanel()
            }
        }
    }

    private func anchoredFrame(size: NSSize) -> NSRect {
        let top = anchorTop ?? NSPoint(x: panel.frame.midX, y: panel.frame.maxY)
        if dragging {
            return NSRect(x: top.x - size.width / 2, y: top.y - size.height, width: size.width, height: size.height)
        }
        guard let bounds = visibleFrame(for: top) else {
            // Display reconfiguration can temporarily have no screen. The old
            // panel frame is not a screen bound: clamping to it freezes growth.
            return NSRect(x: top.x - size.width / 2, y: top.y - size.height, width: size.width, height: size.height)
        }
        return OverlayAnchor(topCenter: top).frame(size: size, in: bounds)
    }

    private func visibleFrame(for top: NSPoint) -> NSRect? {
        (NSScreen.screens.first { $0.frame.contains(top) } ?? NSScreen.main)?.visibleFrame
    }

    private func cancelResize() {
        resizeSettlement?.cancel(); resizeSettlement = nil
        guard resizing else { return }
        resizeGeneration += 1
        frameMotion.cancel()
        resizing = false
        lastSize = panel.frame.size
        resizeTarget = nil
    }

    private func moveDraggedWindow(to point: NSPoint) {
        guard dragging, !stopped else { return }
        anchorTop = point
        if let size = resizeTarget?.size { resizeTarget = anchoredFrame(size: size) }
        frameMotion.moveTopCenter(to: point)
    }

    func restoreOnScreen() {
        guard !stopped, !dragging else { return }
        // EDR/brightness changes also send screen-parameter notifications.
        // Cancelling here strands an in-flight expansion at its intermediate
        // height until an unrelated hover/visibility update retries sizing.
        // Keep a valid target running; retarget only when the screen geometry
        // actually changed, using the current lyric rather than the old frame.
        if let anchorTop, !NSScreen.screens.contains(where: { $0.frame.contains(anchorTop) }) {
            let size = desiredSize == .zero ? panel.frame.size : desiredSize
            let frame = anchoredFrame(size: size)
            self.anchorTop = NSPoint(x: frame.midX, y: frame.maxY)
            if !restoring, let key = topDefaultsKey, let anchorTop = self.anchorTop {
                UserDefaults.standard.set(NSStringFromPoint(anchorTop), forKey: key)
            }
        }
        updateSizing()
        positionContent(); positionControlPanel()
    }

    private func positionContent() {
        let backgroundFrame = root.bounds.insetBy(dx: 6, dy: 6)
        if background.frame != backgroundFrame { background.frame = backgroundFrame }
        background.synchronizeGeometry()
        // Move the persistent maximum-size canvas; never resize its bounds for
        // animated window frames. SwiftUI typography and HDR surfaces survive.
        let visualTop = centersVisibleContent && desiredSize != .zero
            ? (root.bounds.height + desiredSize.height) / 2 : root.bounds.height
        let origin = NSPoint(x: (root.bounds.width - content.frame.width) / 2,
                             y: visualTop - content.frame.height)
        if content.frame.origin != origin { content.setFrameOrigin(origin) }
        // The lyrics canvas follows the panel center through a spring. Its
        // song header is a separate sibling, pinned to the actual glass top.
        let headerFrame = NSRect(x: 30, y: root.bounds.height - 48,
            width: max(260, root.bounds.width - 60), height: 30)
        if header.frame != headerFrame { header.frame = headerFrame }
        header.isHidden = !showsPinnedHeader
        let waveformFrame = NSRect(x: 26, y: 6, width: max(0, root.bounds.width - 52), height: 18)
        if waveform.frame != waveformFrame { waveform.frame = waveformFrame }
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
        guard !restoring, !stopped else { return }
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
    @State private var revealedSearchingHeader: UInt64?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        let lightGlass = colorScheme == .light
        let ink = lightGlass ? Color(white: 0.16) : Color.white
        let maximum = model.preferences.overlayLayoutWidth
        let display = presentation?.held ?? OverlayDisplaySnapshot(model: model, at: ProcessInfo.processInfo.systemUptime)
        let compact = display.compact
        let waveformEnabled = model.preferences.overlayWaveformEnabled
        let centeredLyrics = display.mode == .lyrics && !waveformEnabled
        let card = OverlaySongCardLayout(width: maximum, title: display.track?.title,
            artist: display.track?.artist)
        let height = presentationHeight(maximum: maximum, display: display)
        let baseHeight = display.mode == .waiting ? OverlayPresentationMode.waitingHeight
            : compact ? card.baseHeight(waveformEnabled: waveformEnabled) : height
        let renderedSize = NSSize(width: maximum,
            height: OverlayWaveformLayout.totalHeight(content: baseHeight,
                enabled: waveformEnabled))
        let transition = contentTransition(display: display)
        let searchingHeader = OverlaySearchingHeaderRequest(trackRevision: display.trackRevision,
            delayed: display.mode == .waiting && display.searching)
        let showsHeader = !searchingHeader.delayed || revealedSearchingHeader == display.trackRevision
        let modeAnimation: Animation? = reduceMotion || model.preferences.reduceMotion ? nil
            : .timingCurve(0.22, 0, 0.18, 1, duration: 0.36)
        VStack(spacing: 0) {
            if display.mode == .lyrics && waveformEnabled {
                // The persistent sibling paints the title. This slot keeps
                // the waveform-on lyric body at its established position.
                Color.clear.frame(width: max(260, viewport.width - 60), height: 30)
            } else if display.mode == .waiting && showsHeader {
                // The header has its own old/new surface so a real song
                // change crossfades through one bounded blur. Keeping it out
                // of the body transition avoids stacking that blur when the
                // lyrics document arrives a moment after the metadata.
                ZStack(alignment: .leading) {
                    OverlaySongHeader(display: display, width: max(260, viewport.width - 60))
                        .id(display.trackRevision)
                        .transition(.artworkBlur)
                }
                .frame(width: max(260, viewport.width - 60), height: 30, alignment: .leading)
                .animation(reduceMotion || model.preferences.reduceMotion ? nil
                    : .easeInOut(duration: 0.45), value: display.trackRevision)
            }
            Group {
                if display.mode == .waiting {
                    VStack(spacing: 0) {
                        Spacer(minLength: 4)
                        HStack(spacing: 6) {
                            ForEach(0..<3) { _ in Circle().fill(ink.opacity(0.94)).frame(width: 5, height: 5) }
                        }
                        .shadow(color: .black.opacity(lightGlass ? 0.12 : 0.85), radius: 2, y: 1)
                        .accessibilityElement(children: .ignore).accessibilityLabel("等待歌词")
                        Spacer(minLength: model.preferences.overlayWaveformEnabled ? 0 : 10)
                    }
                } else if compact {
                    OverlaySongCardTransition(display: display, layout: card, lightGlass: lightGlass,
                        animated: windowVisible && viewport.rendering && !reduceMotion && !model.preferences.reduceMotion)
                } else if centeredLyrics {
                    lyricBody(display: display, maximum: maximum, lightGlass: lightGlass,
                        centerVisibleContent: true)
                } else {
                    VStack(spacing: 0) {
                        Spacer(minLength: 4)
                        lyricBody(display: display, maximum: maximum, lightGlass: lightGlass,
                            centerVisibleContent: false)
                        Spacer(minLength: model.preferences.overlayWaveformEnabled ? 0 : 10)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // This local animation survives the arrival modifier's isolation
            // of its display-rate blur from ancestor layout animations.
            .animation(modeAnimation, value: display.mode)
            .modifier(transition)
        }
            // Cached instrumental/no-lyrics results can replace the initial
            // waiting frame almost immediately. Delay that waiting header so
            // the same title is not first flashed at the top and then redrawn
            // in the centered song card. A genuine longer search still reveals
            // its header, while mode changes receive one smooth layout handoff.
            .animation(modeAnimation, value: display.mode)
            .animation(modeAnimation, value: showsHeader)
            .padding(.horizontal, 24)
            .padding(.top, waveformEnabled && display.mode == .song
                ? OverlaySongCardLayout.waveformTopPadding : 12)
            .padding(.bottom, waveformEnabled && display.mode == .song
                ? OverlaySongCardLayout.waveformBottomPadding : waveformEnabled ? 0 : 12)
            .foregroundStyle(ink)
            .padding(6)
            .frame(width: maximum, height: OverlayWaveformLayout.contentHeight(base: baseHeight,
                enabled: waveformEnabled))
            .padding(.bottom, waveformEnabled ? OverlayWaveformLayout.additionalHeight : 0)
            // Keep the NSHostingView itself at alpha 1. AppKit's host-wide
            // fade sits outside SwiftUI's HDR output declaration and can cache
            // the restored lyric as SDR. Fade inside the HDR scope instead.
            .hdrDisplayScope(requested: model.preferences.lyricEmphasis.usesHDR,
                visible: windowVisible && viewport.rendering)
            .environment(\.lyricFrameRateLimit, model.preferences.overlayFrameRate.limit)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // SwiftUI and the controller observe the session independently.
            // Commit the height of the content that actually rendered as well
            // as the controller's prediction, including first appearance.
            .task(id: renderedSize) { @MainActor in
                guard !Task.isCancelled else { return }
                viewport.contentSizeChanged?(renderedSize)
            }
            .task(id: searchingHeader) { @MainActor in
                guard searchingHeader.delayed else {
                    revealedSearchingHeader = nil
                    return
                }
                revealedSearchingHeader = nil
                do { try await Task.sleep(for: .seconds(OverlaySearchingHeaderRequest.revealDelay)) }
                catch { return }
                guard !Task.isCancelled else { return }
                revealedSearchingHeader = searchingHeader.trackRevision
            }
            .background(WindowVisibilityReader { windowVisible = $0 }.frame(width: 0, height: 0))
    }
    private func lyricBody(display: OverlayDisplaySnapshot, maximum: Double,
                           lightGlass: Bool, centerVisibleContent: Bool) -> some View {
        ZStack {
            if let doc = display.document, let index = display.index {
                OverlayLyricsContent(preferences: model.preferences, document: doc, index: index,
                    lyricTime: { doc.lyricTime(for: presentation?.held?.position ?? model.session.position) },
                    renderTime: { doc.lyricTime(for: presentation?.held?.position ?? model.session.presentationPosition()) },
                    playing: display.playing && windowVisible && viewport.rendering,
                    visible: windowVisible && viewport.rendering,
                    adaptiveCanvasWidth: model.preferences.overlayAdaptiveSize ? maximum - 60 : nil,
                    centerVisibleContent: centerVisibleContent)
            } else { Text(placeholder) }
        }
        .font(.system(size: model.preferences.fontSize, weight: .semibold))
        // A soft local backing protects dark ink over desktop detail without
        // a fuzzy white outline of a subpixel rim.
        .shadow(color: lightGlass ? .white.opacity(0.65) : .black.opacity(0.98),
            radius: lightGlass ? 3 : 1.1)
        .shadow(color: lightGlass ? .white.opacity(0.24)
            : .black.opacity(model.preferences.overlayAppearance == .glass ? 0.7 : 0.35), radius: 5, y: 1)
    }
    private func contentTransition(display: OverlayDisplaySnapshot) -> OverlayContentTransition {
        let p = model.preferences
        // A song revision changes once per real player transition. Artist,
        // album, artwork, loading mode, and lyrics may arrive later without
        // replaying the title/card transition.
        let identity = OverlayContentIdentity(track: display.track.map { _ in String(display.trackRevision) })
        return OverlayContentTransition(identity: identity.songScope,
            reduced: reduceMotion || p.reduceMotion, visible: windowVisible && viewport.rendering,
            preparingSince: presentation?.preparingSince, animatesArrival: display.mode != .song)
    }
    private func presentationHeight(maximum: Double, display: OverlayDisplaySnapshot) -> Double {
        OverlayLyricsWindowLayout.baseHeight(document: display.document, index: display.index,
            preferences: model.preferences, maximumWidth: maximum)
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

/// A revision owns the whole departing row; image refinements animate locally.
/// The two rows retain their own intrinsic positions while fading through the
/// same fixed card width, including a short-to-long-title change.
struct OverlaySongCardTransition: View {
    let display: OverlayDisplaySnapshot
    let layout: OverlaySongCardLayout
    let lightGlass: Bool
    let animated: Bool
    var body: some View {
        ZStack {
            OverlaySongCard(display: display, layout: layout, lightGlass: lightGlass, animated: animated)
                .id(display.trackRevision)
                .transition(animated ? .artworkBlur : .identity)
        }
        .animation(animated ? .easeInOut(duration: 0.45) : nil, value: display.trackRevision)
    }
}

private struct OverlaySongCard: View {
    let display: OverlayDisplaySnapshot
    let layout: OverlaySongCardLayout
    let lightGlass: Bool
    let animated: Bool
    var body: some View {
        // The model owns the bounded metadata/decode hold across revisions.
        // Local state is destroyed by the whole-row track transition and
        // cannot bridge the very nil frame it was intended to hide.
        let artwork = display.artwork
        HStack(spacing: layout.spacing) {
            ZStack {
                if let artwork {
                    Image(nsImage: artwork).resizable().scaledToFill()
                        .id(ObjectIdentifier(artwork))
                        .transition(animated ? .artworkBlur : .identity)
                } else {
                    ZStack {
                        Color.white.opacity(0.08)
                        // Late metadata can arrive after the bounded hold.
                        // A real song without pixels uses a quiet tile, so a
                        // default note never flashes before its actual cover.
                        if display.track == nil && !display.artworkLoading {
                            Image(systemName: "music.note").font(.system(size: 18))
                        }
                    }
                        .transition(animated ? .opacity : .identity)
                }
            }
            .frame(width: layout.artwork, height: layout.artwork)
            .clipShape(.rect(cornerRadius: 9))
            .animation(animated ? .easeInOut(duration: 0.45) : nil, value: artwork.map(ObjectIdentifier.init))
            VStack(alignment: .leading, spacing: 4) {
                Text(display.track?.title ?? "LyricsX Next")
                    .font(.system(size: layout.title, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.85)
                if let artist = display.track?.artist, !artist.isEmpty {
                    Text(artist).font(.system(size: layout.artist, weight: .medium)).lineLimit(1).opacity(0.8)
                }
            }.shadow(color: .black.opacity(lightGlass ? 0.12 : 0.8), radius: 2, y: 1)
        }.frame(maxWidth: layout.contentWidth, alignment: .center)
    }
}

private struct OverlayPinnedSongHeader: View {
    let model: AppModel
    let presentation: OverlayPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        let display = presentation.held ?? OverlayDisplaySnapshot(model: model,
            at: ProcessInfo.processInfo.systemUptime)
        ZStack(alignment: .leading) {
            if display.mode == .lyrics {
                OverlaySongHeader(display: display, width: model.preferences.overlayLayoutWidth - 60)
                    .id(display.trackRevision)
                    .transition(.artworkBlur)
            }
        }
        .animation(reduceMotion || model.preferences.reduceMotion ? nil
            : .easeInOut(duration: 0.45), value: display.trackRevision)
    }
}

private struct OverlaySongHeader: View {
    let display: OverlayDisplaySnapshot
    let width: Double
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        HStack(spacing: 6) {
            Text(display.track?.title ?? "LyricsX Next").lineLimit(1)
            if let artist = display.track?.artist, !artist.isEmpty { Text("· " + artist).lineLimit(1).opacity(0.85) }
            Spacer(minLength: 4)
            Color.clear.frame(width: 126, height: 30)
        }.font(.system(size: 11, weight: .medium))
            .foregroundStyle(colorScheme == .light
                ? Color(white: 0.16) : .white.opacity(0.92))
            .shadow(color: .black.opacity(colorScheme == .light ? 0.10 : 0.6), radius: 1, y: 1)
            .frame(width: max(260, width), height: 30)
    }
}

private struct OverlaySearchingHeaderRequest: Hashable {
    static let revealDelay = 0.32
    let trackRevision: UInt64
    let delayed: Bool
}

private struct OverlayControlStrip: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        let lightGlass = colorScheme == .light
        let controlInk = lightGlass ? Color(white: 0.18) : Color.white
        HStack(spacing: 2) {
            SymbolButton(symbol: "arrow.up.left.and.arrow.down.right", help: "打开主窗口", inactiveOpacity: 0.92, ink: controlInk) { model.showMainWindow?() }
            SymbolButton(symbol: model.preferences.overlayLocked ? "lock.fill" : "lock.open", help: model.preferences.overlayLocked ? "解锁并恢复拖动" : "锁定位置", active: model.preferences.overlayLocked, inactiveOpacity: 0.92, ink: controlInk) {
                model.setOverlayLocked(!model.preferences.overlayLocked)
            }
            SymbolButton(symbol: model.preferences.overlayClickThrough ? "cursorarrow.slash" : "cursorarrow.rays", help: model.preferences.overlayClickThrough ? "关闭点击穿透" : "开启点击穿透", active: model.preferences.overlayClickThrough, inactiveOpacity: 0.92, ink: controlInk) {
                model.setOverlayClickThrough(!model.preferences.overlayClickThrough)
            }
            SymbolButton(symbol: "xmark", help: "隐藏悬浮歌词", inactiveOpacity: 0.92, ink: controlInk) { model.setOverlayVisible(false) }
        }
        .shadow(color: .black.opacity(lightGlass ? 0.12 : 0.65), radius: 1, y: 1)
        .padding(2)
        .background(reduceTransparency ? Color(white: lightGlass ? 0.91 : 0.16)
            : lightGlass ? .white.opacity(0.24)
            : .black.opacity(model.preferences.overlayAppearance == .glass
                ? 0.16 + 0.12 * (1 - model.preferences.overlayGlassTintTransparency)
                : max(0.52, 1 - model.preferences.overlayTransparency)), in: .capsule)
        .glassEffect(.clear, in: .capsule)
        .overlay { Capsule().strokeBorder(.white.opacity(lightGlass ? 0.25 : 0.16), lineWidth: 0.5).allowsHitTesting(false) }
    }
}
