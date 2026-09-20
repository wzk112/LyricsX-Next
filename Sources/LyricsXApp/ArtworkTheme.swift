import AppKit

struct ArtworkTheme: Equatable, Sendable {
    let accent: String
    let sung: String
    let unsung: String
    let secondary: String
    static let neutral = ArtworkTheme(accent: "BFC7D5", sung: "FFFFFF", unsung: "757575", secondary: "FFFFFF")
}

/// CPU-only 32×32 sampling, once per artwork change. Hue populations keep a
/// small saturated logo from dominating; black/white borders don't wash out
/// the result. Output is deliberately light, for our shaded lyric surfaces.
actor ArtworkThemeExtractor {
    static let shared = ArtworkThemeExtractor()
    private var last: (CGImage, ArtworkTheme)?
    func theme(for image: CGImage) -> ArtworkTheme {
        if let last, last.0 === image { return last.1 }
        let theme = Self.extract(image)
        last = (image, theme)
        return theme
    }
    static func extract(_ image: CGImage) -> ArtworkTheme {
        let side = 32
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: side, height: side,
                bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.interpolationQuality = .low
            context.draw(image, in: .init(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return .neutral }
        struct Bucket {
            var weight = 0.0, red = 0.0, green = 0.0, blue = 0.0
        }
        var buckets = [Bucket](repeating: .init(), count: 18)
        for y in 0..<side {
            for x in 0..<side {
                let i = (y * side + x) * 4
                let a = Double(pixels[i + 3]) / 255
                guard a > 0.75 else { continue }
                let r = Double(pixels[i]) / 255 / a, g = Double(pixels[i + 1]) / 255 / a, b = Double(pixels[i + 2]) / 255 / a
                let maxRGB = max(r, g, b), minRGB = min(r, g, b), delta = maxRGB - minRGB
                let saturation = maxRGB > 0 ? delta / maxRGB : 0
                guard saturation > 0.12, maxRGB > 0.10 else { continue }
                var hue: Double
                if maxRGB == r { hue = (g - b) / delta }
                else if maxRGB == g { hue = 2 + (b - r) / delta }
                else { hue = 4 + (r - g) / delta }
                hue = (hue / 6 + 1).truncatingRemainder(dividingBy: 1)
                let index = min(17, Int(hue * 18))
                let border = x < 3 || y < 3 || x >= side - 3 || y >= side - 3
                let weight = (border ? 0.35 : 1) * (0.35 + saturation * 0.65) * (0.4 + maxRGB * 0.6)
                buckets[index].weight += weight
                buckets[index].red += r * weight
                buckets[index].green += g * weight
                buckets[index].blue += b * weight
            }
        }
        guard let best = buckets.max(by: { $0.weight < $1.weight }), best.weight > 4 else { return .neutral }
        let rgb = [best.red, best.green, best.blue].map { $0 / best.weight }
        func hex(_ values: [Double]) -> String {
            values.map { String(format: "%02X", Int((min(1, max(0, $0)) * 255).rounded())) }.joined()
        }
        // Tint toward white rather than simply increasing HSV value: saturated
        // blue's luminance stays too low even at maximum HSV brightness.
        let peak = rgb.max() ?? 1
        let normalized = rgb.map { $0 / max(0.01, peak) }
        let bright = normalized.map { 0.72 + 0.28 * $0 }
        return .init(accent: hex(rgb), sung: hex(bright),
                     unsung: hex(bright.map { $0 * 0.43 }),
                     secondary: hex(bright.map { 0.15 + $0 * 0.85 }))
    }
}
