import Carbon
import AppKit

@MainActor
final class GlobalHotkeys {
    private var handler: EventHandlerRef?
    private var keys: [EventHotKeyRef] = []
    private let model: AppModel
    init(model: AppModel) {
        self.model = model
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(model).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, data in
            guard let event, let data else { return noErr }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let model = Unmanaged<AppModel>.fromOpaque(data).takeUnretainedValue()
            MainActor.assumeIsolated {
                if id.id == 1 { model.setOverlayVisible(!model.preferences.overlayVisible) }
                if id.id == 2 { model.showMainWindow?() }
            }
            return noErr
        }, 1, &event, pointer, &handler)
        for (key, id) in [(UInt32(kVK_ANSI_L), UInt32(1)), (UInt32(kVK_ANSI_O), UInt32(2))] {
            var ref: EventHotKeyRef?
            RegisterEventHotKey(key, UInt32(cmdKey | optionKey), EventHotKeyID(signature: 0x4C585832, id: id), GetApplicationEventTarget(), 0, &ref)
            if let ref { keys.append(ref) }
        }
    }
    isolated deinit { stop() }
    func stop() { for key in keys { UnregisterEventHotKey(key) }; keys = []; if let handler { RemoveEventHandler(handler) }; handler = nil }
}
