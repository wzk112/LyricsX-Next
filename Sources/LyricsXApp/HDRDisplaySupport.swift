import AppKit
import Observation
import SwiftUI

struct HDRDisplayCapability: Equatable, Identifiable {
    let id: UInt32
    let name: String
    let potential: Double
    let current: Double
    let builtIn: Bool
    // Potential headroom reports output capability even before EDR is active.
    // Current headroom describes available brightness, not panel certification.
    var supported: Bool { potential.isFinite && potential > 1 }
    var renderHeadroom: Double { supported ? potential : 1 }
    var currentHeadroom: Double { current.isFinite ? min(renderHeadroom, max(1, current)) : 1 }
    // Rendering uses potential headroom. Current headroom fluctuates when
    // another window closes or EDR content changes; it is settings-only data.
    func hasSameRenderOutput(as other: Self?) -> Bool {
        guard let other else { return false }
        return supported == other.supported && renderHeadroom == other.renderHeadroom
    }
    var status: String { supported ? "支持" : "不支持" }
    var explanation: String {
        guard supported else { return "系统未报告扩展亮度余量，此屏幕自动使用增强后的普通辉光。" }
        return "系统报告可输出 EDR 高亮，不代表 XDR 等级或固定峰值亮度。" + (currentHeadroom <= 1 ? " 当前未启用高亮或亮度余量不足。" : " 实际亮度由屏幕和系统决定。")
    }

    @MainActor init(screen: NSScreen) {
        id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        name = screen.localizedName
        potential = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
        current = screen.maximumExtendedDynamicRangeColorComponentValue
        builtIn = CGDisplayIsBuiltin(id) != 0
    }
    init(id: UInt32 = 0, name: String = "Display", potential: Double, current: Double,
         builtIn: Bool = false) {
        self.id = id; self.name = name; self.potential = potential; self.current = current
        self.builtIn = builtIn
    }
}

@Observable @MainActor final class HDRDisplayMonitor: NSObject {
    private(set) var displays: [HDRDisplayCapability] = []
    @ObservationIgnored private var observing = false
    override init() { super.init(); refresh() }
    func start() {
        guard !observing else { return }
        observing = true
        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersDidChange), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        refresh()
    }
    @objc nonisolated private func screenParametersDidChange() {
        Task { @MainActor [weak self] in
            guard let self, self.observing else { return }
            self.refresh()
        }
    }
    func refresh() {
        let updated = NSScreen.screens.map(HDRDisplayCapability.init(screen:))
        if displays != updated { displays = updated }
    }
    func stop() { NotificationCenter.default.removeObserver(self); observing = false }
}

private struct LyricHDRSupportKey: EnvironmentKey { static let defaultValue = false }
private struct LyricHDRHeadroomKey: EnvironmentKey { static let defaultValue = 1.0 }
extension EnvironmentValues {
    var lyricHDRHeadroom: Double {
        get { self[LyricHDRHeadroomKey.self] }
        set { self[LyricHDRHeadroomKey.self] = newValue }
    }
    var lyricHDRSupported: Bool {
        get { self[LyricHDRSupportKey.self] }
        set { self[LyricHDRSupportKey.self] = newValue }
    }
}

/// A missing screen during order/activation is not an SDR display. Keep the
/// last confirmed output until the same window resolves again; a confirmed SDR
/// display still takes effect immediately.
struct HDRWindowOutput: Equatable {
    private(set) var capability: HDRDisplayCapability?
    private(set) var revision: UInt64 = 0
    mutating func refresh(_ resolved: HDRDisplayCapability?, redraw: Bool = false) {
        if let resolved, !resolved.hasSameRenderOutput(as: capability) { capability = resolved }
        if redraw { revision &+= 1 }
    }
}

private struct LyricHDRRevisionKey: EnvironmentKey { static let defaultValue: UInt64 = 0 }
/// TextRenderer filters carry extended pixels, but do not reliably propagate
/// their colors' content-headroom metadata through opacity/blur render passes.
/// Aggregate the real lyric emitters at the final SwiftUI output boundary.
struct LyricHDRContentHeadroomKey: PreferenceKey {
    static let defaultValue = 1.0
    static func reduce(value: inout Double, nextValue: () -> Double) { value = max(value, nextValue()) }
}

enum LyricHDROutputRequest {
    static func headroom(requested: Bool, visible: Bool, content: Double, capability: HDRDisplayCapability?) -> Double {
        guard requested, visible, let capability, capability.supported, content.isFinite else { return 1 }
        return min(capability.renderHeadroom, max(1, content))
    }
}

extension EnvironmentValues {
    var lyricHDRRevision: UInt64 {
        get { self[LyricHDRRevisionKey.self] }
        set { self[LyricHDRRevisionKey.self] = newValue }
    }
}

/// One reader per surface, never per lyric or display frame.
private struct WindowHDRReader: NSViewRepresentable {
    let visible: Bool
    let changed: (HDRWindowOutput) -> Void
    func makeNSView(context: Context) -> HDRWindowReaderView {
        let view = HDRWindowReaderView()
        view.changed = changed
        view.contentVisible = visible
        return view
    }
    func updateNSView(_ view: HDRWindowReaderView, context: Context) {
        view.changed = changed
        view.contentVisible = visible
    }
    static func dismantleNSView(_ view: HDRWindowReaderView, coordinator: ()) { view.stop(); view.changed = nil }
}

@MainActor final class HDRWindowReaderView: NSView {
    var changed: ((HDRWindowOutput) -> Void)?
    var contentVisible = true {
        didSet {
            guard contentVisible != oldValue else { return }
            if contentVisible { recover() }
            else { recovery?.cancel(); recovery = nil }
        }
    }
    private(set) var output = HDRWindowOutput()
    private(set) var observing = false
    private var generation: UInt64 = 0
    private var recovery: Task<Void, Never>?
    private var publication: Task<Void, Never>?
    private var published: HDRWindowOutput?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stop()
        output = HDRWindowOutput()
        guard let window else { return }
        observing = true
        for name in [NSWindow.didChangeScreenNotification, NSWindow.didChangeOcclusionStateNotification,
                     NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                     NSWindow.didBecomeMainNotification, NSWindow.didResignMainNotification,
                     NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(displayDidChange(_:)), name: name, object: window)
        }
        for name in [NSApplication.didChangeScreenParametersNotification,
                     NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(displayDidChange(_:)), name: name, object: nil)
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.activeSpaceDidChangeNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(displayDidChange(_:)), name: name, object: nil)
        }
        recover()
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        recover()
    }
    @objc nonisolated private func displayDidChange(_ notification: Notification) {
        let screenParameters = notification.name == NSApplication.didChangeScreenParametersNotification
        Task { @MainActor [weak self] in
            guard let self, self.observing else { return }
            // Headroom changes also post screen-parameter notifications. Do
            // not turn our own HDR request into a redraw/re-request feedback
            // loop. Real screen-capability changes still publish immediately.
            if screenParameters { self.refresh() }
            else { self.recover() }
        }
    }
    private func resolvedScreen() -> NSScreen? {
        guard let window else { return nil }
        if let screen = window.screen { return screen }
        // A nonactivating panel can temporarily lose screen assignment while
        // another window changes focus. Use its own frame, never NSScreen.main
        // (which may belong to the newly focused window on an SDR monitor).
        return NSScreen.screens.compactMap { screen -> (NSScreen, CGFloat)? in
            let rect = window.frame.intersection(screen.frame)
            guard !rect.isNull, rect.width > 0, rect.height > 0 else { return nil }
            return (screen, rect.width * rect.height)
        }.max { $0.1 < $1.1 }?.0
    }
    func recover() {
        guard observing else { return }
        recovery?.cancel()
        refresh()
        let token = generation
        // Ordering and wake notifications can precede WindowServer's new
        // display assignment. Two bounded checks, no permanent polling.
        recovery = Task { @MainActor [weak self] in
            for delay in [180, 500] {
                do { try await Task.sleep(for: .milliseconds(delay)) } catch { return }
                guard let self, self.observing, self.generation == token else { return }
                self.refresh(redraw: delay == 180)
            }
        }
    }
    private func refresh(redraw: Bool = false) {
        let capability = resolvedScreen().map(HDRDisplayCapability.init(screen:))
        // Request a new display list after focus/restore without replacing the
        // hosting view, resetting the lyric clock, or toggling HDR off and on.
        output.refresh(capability, redraw: redraw && contentVisible && window?.isVisible == true && window?.isMiniaturized == false)
        guard published != output else { return }
        publication?.cancel()
        let token = generation
        publication = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled, let self, self.observing, self.generation == token else { return }
            self.published = self.output
            self.changed?(self.output)
        }
    }
    func stop() {
        generation &+= 1
        observing = false
        recovery?.cancel(); recovery = nil
        publication?.cancel(); publication = nil
        published = nil
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}

private struct HDRDisplayScope: ViewModifier {
    let requested: Bool
    let visible: Bool
    @State private var output = HDRWindowOutput()
    @State private var contentHeadroom = 1.0
    func body(content: Content) -> some View {
        let headroom = LyricHDROutputRequest.headroom(requested: requested, visible: visible,
            content: contentHeadroom, capability: output.capability)
        content.environment(\.lyricHDRSupported, output.capability?.supported == true)
            .environment(\.lyricHDRRevision, requested ? output.revision : 0)
            .environment(\.lyricHDRHeadroom, output.capability?.renderHeadroom ?? 1)
            .allowedDynamicRange(requested && output.capability?.supported == true ? .high : .standard)
            .onPreferenceChange(LyricHDRContentHeadroomKey.self) { contentHeadroom = $0 }
            .background(alignment: .topLeading) {
                if headroom > 1 {
                    // Declare content metadata outside the lyric's filter and
                    // hover-opacity passes. Black introduces no bright pixel.
                    // Nonzero coverage prevents SwiftUI pruning the declaration.
                    // Only this subpixel marker renews on wake; never the text,
                    // its layout, the cue clock, or the native glass surface.
                    Color(.sRGBLinear, white: 0, opacity: 0.01).headroom(headroom)
                        .frame(width: 0.25, height: 0.25)
                        .allowedDynamicRange(.high)
                        .id(output.revision)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .background(WindowHDRReader(visible: visible) { output = $0 }.frame(width: 0, height: 0))
    }
}
extension View {
    func hdrDisplayScope(requested: Bool, visible: Bool = true) -> some View {
        modifier(HDRDisplayScope(requested: requested, visible: visible))
    }
}
