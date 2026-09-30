import AppKit
import Carbon
import Foundation
import Testing
@testable import LyricsXApp

@Suite @MainActor struct HotkeyTests {
    private func defaults() throws -> (UserDefaults, String) {
        let suite = "LyricsXHotkeyTests-" + UUID().uuidString
        return (try #require(UserDefaults(suiteName: suite)), suite)
    }
    @Test func existingUsersKeepDefaultsAndClearedBindingsSurviveRelaunch() throws {
        let (defaults, suite) = try defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        let settings = preferences.globalHotkeys
        #expect(settings.shortcut(for: .toggleOverlay) == HotkeyAction.toggleOverlay.defaultShortcut)
        #expect(settings.shortcut(for: .showMainWindow) == HotkeyAction.showMainWindow.defaultShortcut)
        #expect(settings.shortcut(for: .toggleOverlay)?.display.hasPrefix("⌥⌘") == true)
        settings.set(nil, for: .toggleOverlay)
        let restored = HotkeyPreferences(defaults: defaults)
        #expect(restored.shortcut(for: .toggleOverlay) == nil)
        #expect(restored.shortcut(for: .showMainWindow) == HotkeyAction.showMainWindow.defaultShortcut)
        restored.set(nil, for: .showMainWindow)
        #expect(HotkeyPreferences(defaults: defaults).shortcuts.isEmpty)
        restored.restoreDefaults()
        #expect(HotkeyPreferences(defaults: defaults).shortcuts.count == 2)
    }
    @Test func customBindingsPersistAndDuplicateAssignmentsKeepOriginal() throws {
        let (defaults, suite) = try defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = HotkeyPreferences(defaults: defaults)
        let custom = HotkeyShortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | optionKey))
        #expect(settings.set(custom, for: .toggleOverlay) == nil)
        #expect(settings.set(custom, for: .showMainWindow) != nil)
        #expect(settings.shortcut(for: .showMainWindow) == HotkeyAction.showMainWindow.defaultShortcut)
        #expect(HotkeyPreferences(defaults: defaults).shortcut(for: .toggleOverlay) == custom)
    }
    @Test func plainTypingAndSystemOperationsAreRejected() {
        for flags in [0, shiftKey, optionKey, cmdKey, controlKey, optionKey | shiftKey] {
            #expect(HotkeyShortcut(keyCode: UInt32(kVK_ANSI_L), modifiers: UInt32(flags)).validationError != nil)
        }
        for (key, flags) in [(kVK_Space, cmdKey | optionKey), (kVK_Tab, cmdKey | shiftKey),
            (kVK_ANSI_Q, cmdKey | shiftKey), (kVK_ANSI_Q, cmdKey | controlKey),
            (kVK_Escape, cmdKey | optionKey), (kVK_Delete, cmdKey | optionKey)] {
            #expect(HotkeyShortcut(keyCode: UInt32(key), modifiers: UInt32(flags)).validationError != nil)
        }
        #expect(HotkeyShortcut(keyCode: 0xFFFF, modifiers: UInt32(cmdKey | optionKey)).validationError != nil)
        #expect(HotkeyShortcut(keyCode: UInt32(kVK_ANSI_L), modifiers: UInt32(cmdKey | optionKey)).validationError == nil)
    }
    @Test func unsafeOrDuplicateSavedSettingsDoNotRegister() throws {
        let (defaults, suite) = try defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let saved = Dictionary(uniqueKeysWithValues: HotkeyAction.allCases.map { ($0.rawValue, HotkeyAction.toggleOverlay.defaultShortcut) })
        defaults.set(try JSONEncoder().encode(saved), forKey: HotkeyPreferences.storageKey)
        #expect(HotkeyPreferences(defaults: defaults).shortcuts.count == 1)
        defaults.set(try JSONEncoder().encode([HotkeyAction.toggleOverlay.rawValue:
            HotkeyShortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: 0)]), forKey: HotkeyPreferences.storageKey)
        #expect(HotkeyPreferences(defaults: defaults).shortcuts.isEmpty)
        defaults.set(Data("corrupt".utf8), forKey: HotkeyPreferences.storageKey)
        #expect(HotkeyPreferences(defaults: defaults).shortcuts.isEmpty)
    }
    @Test func registrationFailuresAreVisibleAndReconfigurationCleansUp() throws {
        let (defaults, suite) = try defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        let model = AppModel(preferences: prefs)
        var registrations: [(HotkeyShortcut, UInt32)] = []
        var unregistrations: [EventHotKeyRef] = []
        let token = try #require(EventHotKeyRef(bitPattern: 0x1234))
        let backend = HotkeyRegistration(register: { shortcut, id in
            registrations.append((shortcut, id))
            return id == 1 ? (noErr, token) : (OSStatus(eventHotKeyExistsErr), nil)
        }, unregister: { unregistrations.append($0) })
        let hotkeys = GlobalHotkeys(model: model, registration: backend, installHandler: false)
        defer { hotkeys.stop(); model.stop() }
        #expect(registrations.count == 2)
        #expect(prefs.globalHotkeys.registrationErrors[.toggleOverlay] == nil)
        #expect(prefs.globalHotkeys.registrationErrors[.showMainWindow] != nil)
        prefs.globalHotkeys.isRecording = true
        #expect(unregistrations.count == 1)
        #expect(prefs.globalHotkeys.registrationErrors.isEmpty)
        prefs.globalHotkeys.set(nil, for: .showMainWindow)
        #expect(registrations.count == 2)
        prefs.globalHotkeys.isRecording = false
        #expect(registrations.count == 3)
        #expect(prefs.globalHotkeys.registrationErrors.isEmpty)
        prefs.globalHotkeys.set(nil, for: .toggleOverlay)
        #expect(unregistrations.count == 2)
        hotkeys.stop()
        prefs.globalHotkeys.restoreDefaults()
        #expect(registrations.count == 3)
    }
}
