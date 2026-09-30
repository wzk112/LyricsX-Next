import AppKit

struct ArtworkTheme: Equatable, Sendable {
    let accent: String
    let sung: String
    let unsung: String
    let secondary: String
    /// Distinct artwork colors, in order of visual prominence. Empty preserves
    /// the previous gradient for hand-created themes and the neutral fallback.
    var palette: [String] = []
    var secondaryAccent: String { palette.dropFirst().first ?? accent }
    var waveformColors: [String] {
        if palette.isEmpty { return [sung, accent, secondary] }
        return palette.count == 1 ? [palette[0], palette[0]] : palette
    }
    static let neutral = ArtworkTheme(accent: "BFC7D5", sung: "FFFFFF", unsung: "757575", secondary: "FFFFFF")
}

/// CPU-only 64×64 sampling, once per artwork change. The dominant color owns
/// the main lyric; smaller distinct hues supply the secondary ink and waveform.
/// Black/white borders and nearly transparent pixels don't wash out the result.
actor ArtworkThemeExtractor {
    static let shared = ArtworkThemeExtractor()
    private var last: (CGImage, ArtworkTheme)?
    func theme(for image: CGImage) -> ArtworkTheme {
        if let last, last.0 === image { return last.1 }
        let theme = Self.extract(image)
        last = (image, theme)
        return theme
    }
    private struct RGB {
        var red: Double, green: Double, blue: Double
        var channels: [Double] { [red, green, blue] }
        var hue: Double {
            let high = max(red, green, blue), delta = high - min(red, green, blue)
            guard delta > 0 else { return 0 }
            let sector = high == red ? (green - blue) / delta
                : high == green ? 2 + (blue - red) / delta : 4 + (red - green) / delta
            return (sector / 6 + 1).truncatingRemainder(dividingBy: 1)
        }
        var hex: String {
            channels.map { String(format: "%02X", Int((min(1, max(0, $0)) * 255).rounded())) }.joined()
        }
        func map(_ transform: (Double) -> Double) -> RGB {
            .init(red: transform(red), green: transform(green), blue: transform(blue))
        }
        var brightInk: RGB {
            // White tint also lifts blue's luminance, which HSV value alone can't.
            let peak = max(red, green, blue, 0.01)
            return map { 0.72 + 0.28 * $0 / peak }
        }
        var waveformInk: RGB {
            // Keep genuine hue variation, but lift dark colors enough to remain
            // visible against the shaded lyric surface.
            func linear(_ channel: Double) -> Double {
                channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            let luminance = linear(red) * 0.2126 + linear(green) * 0.7152 + linear(blue) * 0.0722
            guard luminance < 0.22 else { return self }
            let tint = (0.22 - luminance) / (1 - luminance)
            return map { channel in
                let lifted = linear(channel) + (1 - linear(channel)) * tint
                return lifted <= 0.0031308 ? lifted * 12.92 : 1.055 * pow(lifted, 1 / 2.4) - 0.055
            }
        }
    }
    private struct Bucket {
        var weight = 0.0, red = 0.0, green = 0.0, blue = 0.0
        var color: RGB { .init(red: red / weight, green: green / weight, blue: blue / weight) }
        mutating func add(_ color: RGB, weight: Double) {
            self.weight += weight
            red += color.red * weight; green += color.green * weight; blue += color.blue * weight
        }
        mutating func merge(_ other: Bucket) {
            weight += other.weight; red += other.red; green += other.green; blue += other.blue
        }
    }
    private static func hueDistance(_ first: Double, _ second: Double) -> Double {
        let distance = abs(first - second)
        return min(distance, 1 - distance)
    }
    static func extract(_ image: CGImage) -> ArtworkTheme {
        let side = 64
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
        var buckets = [Bucket](repeating: .init(), count: 36)
        for y in 0..<side {
            for x in 0..<side {
                let i = (y * side + x) * 4
                let alpha = Double(pixels[i + 3]) / 255
                guard alpha > 0.05 else { continue }
                let color = RGB(red: Double(pixels[i]) / 255 / alpha,
                    green: Double(pixels[i + 1]) / 255 / alpha,
                    blue: Double(pixels[i + 2]) / 255 / alpha).map { min(1, $0) }
                let high = max(color.red, color.green, color.blue), low = min(color.red, color.green, color.blue)
                let saturation = high > 0 ? (high - low) / high : 0
                guard saturation > 0.12, high > 0.10 else { continue }
                let index = min(35, Int(color.hue * 36))
                let border = x < 6 || y < 6 || x >= side - 6 || y >= side - 6
                let weight = alpha * (border ? 0.35 : 1) * (0.35 + saturation * 0.65) * (0.4 + high * 0.6)
                buckets[index].add(color, weight: weight)
            }
        }
        // Merge nearby hue buckets, including across red's 0/1 boundary. That
        // prevents a broad dominant hue from losing to one narrow accent bucket.
        var candidates: [Bucket] = []
        for bucket in buckets.filter({ $0.weight > 0 }).sorted(by: { $0.weight > $1.weight }) {
            if let nearest = candidates.indices.min(by: {
                hueDistance(candidates[$0].color.hue, bucket.color.hue) < hueDistance(candidates[$1].color.hue, bucket.color.hue)
            }), hueDistance(candidates[nearest].color.hue, bucket.color.hue) < 0.065 {
                candidates[nearest].merge(bucket)
            } else { candidates.append(bucket) }
        }
        candidates.sort { $0.weight > $1.weight }
        guard let primary = candidates.first, primary.weight > 4 else { return .neutral }
        let totalWeight = candidates.reduce(0) { $0 + $1.weight }
        // A visible ~1% accent can contribute without a lone compression pixel
        // becoming a new palette color. Population still chooses the main ink.
        candidates = candidates.filter { $0.weight >= max(6, totalWeight * 0.012) }
        var selected = [primary]
        while selected.count < 4 {
            let remaining = candidates.filter { candidate in
                selected.allSatisfy { hueDistance(candidate.color.hue, $0.color.hue) >= 0.065 }
            }
            guard let next = remaining.max(by: { first, second in
                func score(_ candidate: Bucket) -> Double {
                    let distance = selected.map { hueDistance(candidate.color.hue, $0.color.hue) }.min() ?? 0
                    return pow(candidate.weight / totalWeight, 0.4) * distance
                }
                return score(first) < score(second)
            }) else { break }
            selected.append(next)
        }
        let bright = primary.color.brightInk
        let secondary = (selected.dropFirst().first?.color ?? primary.color).brightInk.map { 0.15 + $0 * 0.85 }
        return .init(accent: primary.color.hex, sung: bright.hex,
            unsung: bright.map { $0 * 0.43 }.hex, secondary: secondary.hex,
            palette: selected.map { $0.color.waveformInk.hex })
    }
}
