import AppKit
import Carbon
import Observation

/// Carbon virtual key codes stay independent of the current keyboard layout.
enum HotkeyAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case toggleOverlay, showMainWindow
    var id: String { rawValue }
    var title: String { self == .toggleOverlay ? "悬浮歌词" : "主窗口" }
    var detail: String { self == .toggleOverlay ? "显示或隐藏桌面上的悬浮窗。" : "隐藏 Dock 或菜单栏后也可使用。" }
    var eventID: UInt32 { self == .toggleOverlay ? 1 : 2 }
    var defaultShortcut: HotkeyShortcut {
        .init(keyCode: UInt32(self == .toggleOverlay ? kVK_ANSI_L : kVK_ANSI_O), modifiers: UInt32(cmdKey | optionKey))
    }
}

struct HotkeyShortcut: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32
    static let supportedModifiers = UInt32(cmdKey | optionKey | controlKey | shiftKey)

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
    init(event: NSEvent) {
        keyCode = UInt32(event.keyCode)
        var mask: UInt32 = 0
        if event.modifierFlags.contains(.command) { mask |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.option) { mask |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { mask |= UInt32(controlKey) }
        if event.modifierFlags.contains(.shift) { mask |= UInt32(shiftKey) }
        modifiers = mask
    }

    var validationError: String? {
        guard modifiers & ~Self.supportedModifiers == 0,
              modifiers.nonzeroBitCount >= 2,
              modifiers & UInt32(cmdKey | controlKey) != 0 else {
            return "请使用至少两个修饰键，并包含 ⌘ 或 ⌃，避免影响普通输入。"
        }
        guard Self.keyNames[keyCode] != nil else { return "请选择字母、数字、标点、方向键或 F1–F20。" }
        // Spotlight, application switching, lock and logout belong to macOS.
        if (modifiers & UInt32(cmdKey) != 0 && [UInt32(kVK_Space), UInt32(kVK_Tab)].contains(keyCode))
            || (keyCode == UInt32(kVK_ANSI_Q) && modifiers & UInt32(cmdKey) != 0
                && modifiers & UInt32(controlKey | shiftKey) != 0) {
            return "这个组合用于 macOS 系统操作，请选择其他快捷键。"
        }
        return nil
    }

    var display: String {
        var text = ""
        for (mask, symbol) in [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")] {
            if modifiers & UInt32(mask) != 0 { text += symbol }
        }
        return text + keyName
    }
    private var keyName: String {
        if keyCode >= 64 || keyCode == UInt32(kVK_Space) || keyCode == UInt32(kVK_Tab) {
            return Self.keyNames[keyCode] ?? "?"
        }
        // Resolve printable keys using the active layout, with a stable fallback.
        if let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
           let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
            let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
            if let bytes = CFDataGetBytePtr(data) {
                let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
                var deadKeyState: UInt32 = 0
                var count = 0
                var characters = [UniChar](repeating: 0, count: 8)
                let status = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                    UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeyState,
                    characters.count, &count, &characters)
                if status == noErr, count > 0 {
                    let value = String(utf16CodeUnits: characters, count: count)
                    if value.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }), value != " " {
                        return value.uppercased()
                    }
                }
            }
        }
        return Self.keyNames[keyCode] ?? "?"
    }
    private static let keyNames: [UInt32: String] = {
        var names: [UInt32: String] = [:]
        for (code, name) in [(0,"A"),(1,"S"),(2,"D"),(3,"F"),(4,"H"),(5,"G"),(6,"Z"),(7,"X"),(8,"C"),(9,"V"),
            (11,"B"),(12,"Q"),(13,"W"),(14,"E"),(15,"R"),(16,"Y"),(17,"T"),(18,"1"),(19,"2"),(20,"3"),
            (21,"4"),(22,"6"),(23,"5"),(24,"="),(25,"9"),(26,"7"),(27,"−"),(28,"8"),(29,"0"),(30,"]"),
            (31,"O"),(32,"U"),(33,"["),(34,"I"),(35,"P"),(37,"L"),(38,"J"),(39,"'"),(40,"K"),(41,";"),
            (42,"\\"),(43,","),(44,"/"),(45,"N"),(46,"M"),(47,"."),(48,"⇥"),(49,"Space"),(50,"`"),
            (123,"←"),(124,"→"),(125,"↓"),(126,"↑")] { names[UInt32(code)] = name }
        for (index, code) in [122,120,99,118,96,97,98,100,101,109,103,111,105,107,113,106,64,79,80,90].enumerated() {
            names[UInt32(code)] = "F\(index + 1)"
        }
        return names
    }()
}

@Observable @MainActor
final class HotkeyPreferences {
    static let storageKey = "globalHotkeyBindings"
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var onChange: (() -> Void)?
    private(set) var shortcuts: [String: HotkeyShortcut]
    var registrationErrors: [HotkeyAction: String] = [:]
    var isRecording = false { didSet { if isRecording != oldValue { onChange?() } } }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey) {
            let saved = (try? JSONDecoder().decode([String: HotkeyShortcut].self, from: data)) ?? [:]
            var restored: [String: HotkeyShortcut] = [:]
            for action in HotkeyAction.allCases {
                if let shortcut = saved[action.rawValue], shortcut.validationError == nil,
                   !restored.values.contains(shortcut) { restored[action.rawValue] = shortcut }
            }
            shortcuts = restored
        } else {
            shortcuts = Dictionary(uniqueKeysWithValues: HotkeyAction.allCases.map { ($0.rawValue, $0.defaultShortcut) })
        }
    }
    func shortcut(for action: HotkeyAction) -> HotkeyShortcut? { shortcuts[action.rawValue] }
    @discardableResult func set(_ shortcut: HotkeyShortcut?, for action: HotkeyAction) -> String? {
        if let shortcut {
            if let error = shortcut.validationError { return error }
            if let conflict = HotkeyAction.allCases.first(where: { $0 != action && self.shortcut(for: $0) == shortcut }) {
                return "这个快捷键已用于“\(conflict.title)”。请先清除该项，或选择其他组合。"
            }
        }
        shortcuts[action.rawValue] = shortcut
        persistAndNotify()
        return nil
    }
    func restoreDefaults() {
        shortcuts = Dictionary(uniqueKeysWithValues: HotkeyAction.allCases.map { ($0.rawValue, $0.defaultShortcut) })
        persistAndNotify()
    }
    private func persistAndNotify() {
        if let data = try? JSONEncoder().encode(shortcuts) { defaults.set(data, forKey: Self.storageKey) }
        onChange?()
    }
}
