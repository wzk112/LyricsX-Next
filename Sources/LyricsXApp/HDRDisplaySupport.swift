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

/// One reader per window, not per lyric or frame. Moving onto SDR immediately
/// selects ordinary glow, even when another connected display supports HDR.
private struct WindowHDRReader: NSViewRepresentable {
    let changed: (HDRDisplayCapability?) -> Void
    func makeNSView(context: Context) -> Reader { Reader() }
    func updateNSView(_ view: Reader, context: Context) { view.changed = changed }
    static func dismantleNSView(_ view: Reader, coordinator: ()) { view.stop(); view.changed = nil }

    @MainActor final class Reader: NSView {
        var changed: ((HDRDisplayCapability?) -> Void)?
        private var capability: HDRDisplayCapability?
        private var observing = false
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow(); stop()
            guard let window else { return }
            observing = true
            NotificationCenter.default.addObserver(self, selector: #selector(displayDidChange), name: NSWindow.didChangeScreenNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(displayDidChange), name: NSWindow.didChangeOcclusionStateNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(displayDidChange), name: NSApplication.didChangeScreenParametersNotification, object: nil)
            refresh()
            // Attachment can precede orderFront and screen assignment.
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window, self.window === window else { return }
                self.refresh()
            }
        }
        @objc nonisolated private func displayDidChange() {
            Task { @MainActor [weak self] in
                guard let self, self.observing else { return }
                self.refresh()
            }
        }
        private func refresh() {
            let value = window?.screen.map { HDRDisplayCapability(screen: $0) }
            guard capability != value else { return }
            capability = value
            // Avoid publishing SwiftUI state during native view attachment.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.observing, self.capability == value else { return }
                self.changed?(value)
            }
        }
        func stop() { NotificationCenter.default.removeObserver(self); observing = false; capability = nil }
    }
}

private struct HDRDisplayScope: ViewModifier {
    let requested: Bool
    @State private var capability: HDRDisplayCapability?
    func body(content: Content) -> some View {
        content.environment(\.lyricHDRSupported, capability?.supported == true)
            .environment(\.lyricHDRHeadroom, capability?.renderHeadroom ?? 1)
            .allowedDynamicRange(requested && capability?.supported == true ? .high : .standard)
            .background(WindowHDRReader { capability = $0 }.frame(width: 0, height: 0))
    }
}
extension View {
    func hdrDisplayScope(requested: Bool) -> some View { modifier(HDRDisplayScope(requested: requested)) }
}
