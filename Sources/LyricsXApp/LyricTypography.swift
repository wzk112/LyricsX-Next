import AppKit
import SwiftUI

struct LyricTypography: Equatable {
    var fontName = ""
    var primaryHex = "FFFFFF"
    var secondaryHex = "FFFFFF"

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
    func nativeFont(size: Double, weight: NSFont.Weight) -> NSFont {
        if !fontName.isEmpty, let font = NSFont(name: fontName, size: size) { return font }
        return .systemFont(ofSize: size, weight: weight)
    }
    func font(size: Double, weight: NSFont.Weight = .semibold) -> Font { Font(nativeFont(size: size, weight: weight)) }
    var primary: Color { Self.color(primaryHex) }
    var secondary: Color { Self.color(secondaryHex) }
}
