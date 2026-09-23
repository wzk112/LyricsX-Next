import AppKit
import ObjectiveC

/// Opt-in appearance compatibility for the experimental native glass style.
/// AppKit has no public NSGlassEffectView equivalent of NSVisualEffectView.state.
/// These undocumented window queries affect material appearance only: the panel
/// remains nonactivating and never becomes key merely to retain its optics.
/// Keep this isolated so it can be removed if a future macOS changes the hooks.
@MainActor
class OverlayMaterialPanel: NSPanel {
    var keepsGlassAppearanceActive = false

    @objc(_hasActiveAppearance)
    private func glassActiveAppearance() -> Bool {
        keepsGlassAppearanceActive || systemAppearance(for: NSSelectorFromString("_hasActiveAppearance"))
    }

    @objc(_hasActiveAppearanceIgnoringKeyFocus)
    private func glassActiveAppearanceIgnoringKeyFocus() -> Bool {
        keepsGlassAppearanceActive || systemAppearance(for: NSSelectorFromString("_hasActiveAppearanceIgnoringKeyFocus"))
    }

    private func systemAppearance(for selector: Selector) -> Bool {
        guard let method = class_getInstanceMethod(NSPanel.self, selector) else { return NSApp.isActive }
        typealias Query = @convention(c) (AnyObject, Selector) -> Bool
        return unsafeBitCast(method_getImplementation(method), to: Query.self)(self, selector)
    }
}
