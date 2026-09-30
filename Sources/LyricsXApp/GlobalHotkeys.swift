import Carbon
import AppKit

/// Kept injectable so registration failures and cleanup can be verified without
/// claiming the test runner's real global shortcuts.
@MainActor
struct HotkeyRegistration {
    var register: (HotkeyShortcut, UInt32) -> (OSStatus, EventHotKeyRef?)
    var unregister: (EventHotKeyRef) -> Void
    static let carbon = HotkeyRegistration(register: { shortcut, id in
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
            EventHotKeyID(signature: GlobalHotkeys.signature, id: id), GetApplicationEventTarget(), 0, &reference)
        return (status, reference)
    }, unregister: { UnregisterEventHotKey($0) })
}

@MainActor
final class GlobalHotkeys {
    static let signature: OSType = 0x4C585832
    private var handler: EventHandlerRef?
    private var keys: [EventHotKeyRef] = []
    private let model: AppModel
    private let registration: HotkeyRegistration
    private var stopped = false
    private var handlerStatus: OSStatus = noErr

    init(model: AppModel, registration: HotkeyRegistration = .carbon, installHandler: Bool = true) {
        self.model = model
        self.registration = registration
        if installHandler {
            var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let pointer = Unmanaged.passUnretained(model).toOpaque()
            handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, data in
                guard let event, let data else { return noErr }
                var id = EventHotKeyID()
                let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                guard status == noErr, id.signature == GlobalHotkeys.signature else { return OSStatus(eventNotHandledErr) }
                let model = Unmanaged<AppModel>.fromOpaque(data).takeUnretainedValue()
                MainActor.assumeIsolated {
                    guard !model.preferences.globalHotkeys.isRecording else { return }
                    if id.id == HotkeyAction.toggleOverlay.eventID { model.setOverlayVisible(!model.preferences.overlayVisible) }
                    if id.id == HotkeyAction.showMainWindow.eventID { model.showMainWindow?() }
                }
                return noErr
            }, 1, &event, pointer, &handler)
        }
        model.preferences.globalHotkeys.onChange = { [weak self] in self?.reload() }
        reload()
    }
    isolated deinit { stop() }

    func reload() {
        guard !stopped else { return }
        unregisterAll()
        let settings = model.preferences.globalHotkeys
        settings.registrationErrors = [:]
        guard !settings.isRecording else { return }
        for action in HotkeyAction.allCases {
            guard let shortcut = settings.shortcut(for: action) else { continue }
            guard handlerStatus == noErr else {
                settings.registrationErrors[action] = "无法启动全局快捷键监听（\(handlerStatus)），请重新启动应用。"
                continue
            }
            let (status, reference) = registration.register(shortcut, action.eventID)
            if status == noErr, let reference { keys.append(reference) }
            else {
                if let reference { registration.unregister(reference) }
                settings.registrationErrors[action] = status == OSStatus(eventHotKeyExistsErr)
                    ? "这个组合可能已被其他应用占用，当前未启用。请更换或清除。"
                    : "无法注册这个快捷键（\(status)），当前未启用。请更换或清除。"
            }
        }
    }
    private func unregisterAll() {
        for key in keys { registration.unregister(key) }
        keys = []
    }
    func stop() {
        guard !stopped else { return }
        stopped = true
        model.preferences.globalHotkeys.onChange = nil
        unregisterAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
}
