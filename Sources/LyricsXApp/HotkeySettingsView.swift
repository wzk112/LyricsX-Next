import SwiftUI
import AppKit
import Carbon

struct HotkeySettingsView: View {
    let settings: HotkeyPreferences
    @State private var recordingAction: HotkeyAction?

    var body: some View {
        SettingsCard(title: "快捷键") {
            ForEach(HotkeyAction.allCases) { action in
                SettingRow(title: action.title, detail: action.detail) {
                    HStack(spacing: 8) {
                        Button { recordingAction = action } label: {
                            Text(settings.shortcut(for: action)?.display ?? "未设置")
                                .monospaced().frame(minWidth: 70)
                        }
                        .help("录制全局快捷键")
                        .accessibilityLabel("\(action.title)快捷键，\(settings.shortcut(for: action)?.display ?? "未设置")；点击录制")
                        Button { settings.set(nil, for: action) } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(settings.shortcut(for: action) == nil)
                        .help("清除并禁用此快捷键")
                        .accessibilityLabel("清除\(action.title)快捷键")
                    }
                }
                if let error = settings.registrationErrors[action] {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.orange).padding(.horizontal, 14).padding(.bottom, 10)
                }
            }
            SettingRow(title: "恢复默认", detail: "全局快捷键在其他应用中也生效；清除后不会占用该组合。") {
                Button("恢复默认") { settings.restoreDefaults() }
            }
            SettingRow(title: "搜索歌词", detail: "仅在 LyricsX Next 内打开当前歌曲的版本搜索。") { Text("⌘F").monospaced() }
        }
        .sheet(item: $recordingAction) { action in
            HotkeyRecordingSheet(settings: settings, action: action)
        }
    }
}

private struct HotkeyRecordingSheet: View {
    let settings: HotkeyPreferences
    let action: HotkeyAction
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置\(action.title)快捷键").font(.title3.bold())
            Text("按下新的组合键，包含至少两个修饰键及 ⌘ 或 ⌃。按 Esc 取消，按 Delete 清除。").foregroundStyle(.secondary)
            Text("等待按键…").monospaced().frame(maxWidth: .infinity).padding(20)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                .background(HotkeyRecorder { event in
                    guard !event.isARepeat else { return }
                    let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
                    if event.keyCode == UInt16(kVK_Escape), modifiers.isEmpty { dismiss(); return }
                    if [UInt16(kVK_Delete), UInt16(kVK_ForwardDelete)].contains(event.keyCode), modifiers.isEmpty {
                        settings.set(nil, for: action); dismiss(); return
                    }
                    if let message = settings.set(HotkeyShortcut(event: event), for: action) { error = message }
                    else { dismiss() }
                })
            if let error { Text(error).font(.callout).foregroundStyle(.orange) }
            HStack {
                Button("清除快捷键") { settings.set(nil, for: action); dismiss() }
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(24).frame(width: 410)
        .onAppear { settings.isRecording = true }
        .onDisappear { settings.isRecording = false }
    }
}

private struct HotkeyRecorder: NSViewRepresentable {
    var capture: (NSEvent) -> Void
    func makeNSView(context: Context) -> HotkeyCaptureView { HotkeyCaptureView(capture: capture) }
    func updateNSView(_ view: HotkeyCaptureView, context: Context) { view.capture = capture }
    static func dismantleNSView(_ view: HotkeyCaptureView, coordinator: ()) { view.stop() }
}

@MainActor
private final class HotkeyCaptureView: NSView {
    var capture: (NSEvent) -> Void
    private var monitor: Any?
    init(capture: @escaping (NSEvent) -> Void) { self.capture = capture; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stop()
        guard window != nil else { return }
        // The local monitor catches command keys before app menus consume them.
        // It only sees events in this recording sheet's active window.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let captured = MainActor.assumeIsolated {
                guard let self, let window = self.window, window.isKeyWindow,
                      event.window === window else { return false }
                self.capture(event)
                return true
            }
            return captured ? nil : event
        }
    }
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
    isolated deinit { stop() }
}
