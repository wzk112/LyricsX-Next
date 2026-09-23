import AppKit
import SwiftUI

/// Window-scoped overrides keep the player and floating panel independent.
enum InterfaceTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { self == .system ? "跟随系统" : self == .light ? "浅色" : "深色" }
    var colorScheme: ColorScheme? { self == .system ? nil : self == .light ? .light : .dark }
    var appearance: NSAppearance? {
        colorScheme.map { NSAppearance(named: $0 == .dark ? .darkAqua : .aqua)! }
    }
    @MainActor var resolvedScheme: ColorScheme {
        colorScheme ?? (NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light)
    }
}

struct InterfaceThemePicker: View {
    let title: String
    let detail: String
    @Binding var selection: InterfaceTheme
    var body: some View {
        SettingRow(title: title, detail: detail) {
            Picker(title, selection: $selection) {
                ForEach(InterfaceTheme.allCases) { Text($0.title).tag($0) }
            }.labelsHidden().pickerStyle(.segmented).frame(width: 224)
        }
    }
}

/// Bind native-hosted content explicitly as well as its window. Hosting views
/// can otherwise inherit a different scheme while AppKit updates appearance.
/// Keep this wrapper's identity stable so changing colors never resets lyrics.
struct OverlayThemedRoot<Content: View>: View {
    let preferences: Preferences
    let content: Content
    @Environment(\.colorScheme) private var inheritedScheme
    var body: some View {
        content.environment(\.colorScheme, preferences.overlayEffectiveTheme.colorScheme ?? inheritedScheme)
    }
}
