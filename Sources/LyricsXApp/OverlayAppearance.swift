import Foundation

enum OverlayAppearance: String, CaseIterable, Identifiable {
    case glass, frosted

    static let transparencyRange = 0.2...0.8
    static let glassTintRange = 0.0...1.0
    static let defaultTransparency = 0.26
    static let defaultGlassTintTransparency = 0.60
    static let frostRange = 0.0...1.0
    var defaultFrost: Double { self == .glass ? 0.55 : 0.82 }
    var id: String { rawValue }
    var title: String { self == .glass ? "Liquid Glass" : "磨砂阅读" }
    var detail: String {
        self == .glass ? "高透原生玻璃与折射亮边，统一外观，歌词带对比保护。"
            : "柔化后方细节，配合较浅底色，让歌词更容易阅读。"
    }

    init(savedValue: String?) {
        // Previous glass and the local petGlass experiment share this option.
        self = ["frosted", "dark"].contains(savedValue ?? "") ? .frosted : .glass
    }

    static func clampedTransparency(_ value: Double) -> Double {
        value.isFinite ? min(transparencyRange.upperBound, max(transparencyRange.lowerBound, value)) : defaultTransparency
    }
    static func migratedGlassTint(_ legacyTransparency: Double) -> Double {
        // Keep the build-262 gradient strength on first launch. Reading glass
        // retains its independent saved opacity and its existing 20–80% range.
        let strength = (transparencyRange.upperBound - clampedTransparency(legacyTransparency)) /
            (transparencyRange.upperBound - transparencyRange.lowerBound)
        return 1 - 0.34 * strength / 0.60
    }
    func clampedMaterialTransparency(_ value: Double) -> Double {
        guard self == .glass else { return Self.clampedTransparency(value) }
        return value.isFinite ? min(1, max(0, value)) : Self.defaultGlassTintTransparency
    }
    func clampedFrost(_ value: Double) -> Double { value.isFinite ? min(1, max(0, value)) : defaultFrost }
    func materialOpacity(transparency: Double, frost: Double) -> Double {
        // Alpha blending native glass overlays undistorted desktop pixels on
        // the refracted result. Keep the optical surface intact at every slider
        // value; only its independent contrast gradient changes for this style.
        guard self == .frosted else { return 1 }
        let transparency = Self.clampedTransparency(transparency)
        return 1 - transparency + transparency * 0.45 * clampedFrost(frost)
    }
    func migratedFrost(transparency: Double) -> Double {
        // Preserve legacy saved values for reading glass and rollback.
        let transparency = Self.clampedTransparency(transparency)
        let previousOpacity = self == .glass ? min(0.9, 1 - transparency + 0.14) : 0.96 - transparency * 0.18
        return clampedFrost((previousOpacity - (1 - transparency)) / (transparency * (self == .glass ? 0.7 : 0.9)))
    }
    func shadeOpacities(transparency: Double, dark: Bool = true) -> [Double] {
        let opacity = 1 - Self.clampedTransparency(transparency)
        if self == .glass {
            // A useful tint range without fading the native optical surface.
            // The clear lower edge retains AppKit's highlight and refraction.
            let shade = 0.60 * (1 - clampedMaterialTransparency(transparency))
            // Light ink needs a pale backing through the translation row too.
            // Reuse the same gradient and leave the refractive lower edge clear.
            return dark ? [shade, shade * 0.66, shade * 0.28, 0] : [shade, shade, shade * 0.85, 0]
        }
        return [0.14 + opacity * 0.6, 0.12 + opacity * 0.58,
                0.11 + opacity * 0.56, 0.10 + opacity * 0.55]
    }
}
