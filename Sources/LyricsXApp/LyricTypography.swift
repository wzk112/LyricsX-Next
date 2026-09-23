import AppKit
import SwiftUI

struct LyricTypography: Equatable {
    var fontName = ""
    var primaryHex = "FFFFFF"
    var secondaryHex = "FFFFFF"
    var wordColors: LyricWordColors?

    static func normalizedHex(_ value: String) -> String {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        return text.count == 6 && UInt32(text, radix: 16) != nil ? text.uppercased() : "FFFFFF"
    }
    static func color(_ hex: String) -> Color {
        let rgb = UInt32(normalizedHex(hex), radix: 16) ?? 0xFFFFFF
        return Color(.sRGB, red: Double((rgb >> 16) & 255) / 255,
                     green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255, opacity: 1)
    }
    static func hex(_ color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return "FFFFFF" }
        func byte(_ value: CGFloat) -> Int { Int((min(1, max(0, value)) * 255).rounded()) }
        return String(format: "%02X%02X%02X", byte(rgb.redComponent), byte(rgb.greenComponent), byte(rgb.blueComponent))
    }
    /// Display-only palettes keep cue states distinct even when both custom
    /// colors are black, white, or have nearly identical brightness. The stored
    /// palette and the real cue clock are never changed.
    func adaptedForGlass(dark: Bool) -> Self {
        let sungRange = dark ? 0.70...1.0 : 0.0...0.01
        let unsungRange = dark ? 0.20...0.28 : 0.085...0.095
        let primary = Self.readableInk(primaryHex, luminance: sungRange)
        let secondary = Self.readableInk(secondaryHex, luminance: dark ? 0.60...1.0 : 0.0...0.015)
        let sungSeed = wordColors.map { Self.hex($0.sung) } ?? primaryHex
        let unsungSeed = wordColors.map { Self.hex($0.unsung) } ?? primaryHex
        let plainSeed = wordColors.map { Self.hex($0.plain) } ?? primaryHex
        return .init(fontName: fontName, primaryHex: primary, secondaryHex: secondary,
            wordColors: .init(
                sung: Self.color(Self.readableInk(sungSeed, luminance: sungRange)),
                unsung: Self.color(Self.readableInk(unsungSeed, luminance: unsungRange)),
                plain: Self.color(Self.readableInk(plainSeed, luminance: sungRange)),
                glow: dark ? nil : LyricGlowInk(hex: Self.readableInk(sungSeed, luminance: 0.16...0.28))))
    }
    static func linearRGB(_ hex: String) -> [Double] {
        let value = UInt32(normalizedHex(hex), radix: 16) ?? 0xFFFFFF
        return [Double((value >> 16) & 255), Double((value >> 8) & 255), Double(value & 255)].map {
            let channel = $0 / 255
            return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
    }
    static func luminance(_ hex: String) -> Double {
        let rgb = linearRGB(hex)
        return rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722
    }
    private static func readableInk(_ hex: String, luminance range: ClosedRange<Double>) -> String {
        let linear = linearRGB(hex)
        let value = luminance(hex)
        let target = min(range.upperBound, max(range.lowerBound, value))
        guard abs(value - target) > 0.0001 else { return normalizedHex(hex) }
        let bytes = linear.map { channel -> Int in
            let adjusted = target < value ? channel * target / max(value, 0.0001)
                : channel + (1 - channel) * (target - value) / max(1 - value, 0.0001)
            let encoded = adjusted <= 0.0031308 ? 12.92 * adjusted : 1.055 * pow(adjusted, 1 / 2.4) - 0.055
            return Int((min(1, max(0, encoded)) * 255).rounded())
        }
        return String(format: "%02X%02X%02X", bytes[0], bytes[1], bytes[2])
    }
    func nativeFont(size: Double, weight: NSFont.Weight) -> NSFont {
        if !fontName.isEmpty, let font = NSFont(name: fontName, size: size) {
            return font
        }
        return .systemFont(ofSize: size, weight: weight)
    }
    @MainActor func reservationSize(_ size: Double, weight: NSFont.Weight = .semibold) -> Double {
        fontName.isEmpty ? size : lineHeight(size: size, weight: weight) / 1.4
    }
    @MainActor private static let lineHeights: NSCache<NSFont, NSNumber> = {
        let cache = NSCache<NSFont, NSNumber>()
        cache.countLimit = 128
        return cache
    }()
    @MainActor func lineHeight(size: Double, weight: NSFont.Weight = .semibold) -> Double {
        let font = nativeFont(size: size, weight: weight)
        let metric: Double
        if let cached = Self.lineHeights.object(forKey: font) { metric = cached.doubleValue }
        else {
            metric = NSLayoutManager().defaultLineHeight(for: font)
            Self.lineHeights.setObject(NSNumber(value: metric), forKey: font)
        }
        return ceil(max(size * 1.4, metric))
    }
    func font(size: Double, weight: NSFont.Weight = .semibold) -> Font { Font(nativeFont(size: size, weight: weight)) }
    var primary: Color { Self.color(primaryHex) }
    var secondary: Color { Self.color(secondaryHex) }
}

struct LyricWordColors: Equatable {
    var sung: Color
    var unsung: Color
    var plain: Color
    var glow: LyricGlowInk? = nil
}

/// Linear components are cached with the palette, not resolved for every glyph.
struct LyricGlowInk: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    init(hex: String) {
        let rgb = LyricTypography.linearRGB(hex)
        red = rgb[0]; green = rgb[1]; blue = rgb[2]
    }
    func color(brightness: Double) -> Color {
        let value = HDRBrightness.clamped(brightness)
        // Dark SDR ink gives the halo contrast on white glass. Multiplying that
        // ink by EDR headroom still leaves neutral palettes below SDR white.
        // Use a separate, lightly tinted emitter; the opaque dark glyph is
        // painted over it by HeldNoteRenderer, preserving the karaoke wipe.
        guard value > 1 else { return Color(.sRGBLinear, red: red, green: green, blue: blue, opacity: 1) }
        let peak = max(red, green, blue, 0.001)
        func emission(_ channel: Double) -> Double { (0.78 + 0.22 * channel / peak) * value }
        return Color(.sRGBLinear, red: emission(red), green: emission(green), blue: emission(blue), opacity: 1).headroom(value)
    }
}
private struct LyricWordColorsKey: EnvironmentKey { static let defaultValue: LyricWordColors? = nil }
extension EnvironmentValues {
    var lyricWordColors: LyricWordColors? {
        get { self[LyricWordColorsKey.self] }
        set { self[LyricWordColorsKey.self] = newValue }
    }
}
