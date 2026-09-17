import AppKit
import QuartzCore

/// A single native material with a contrast gradient in its supported content
/// view. Edge-only optics leave the reading area at its existing transparency.
@MainActor
final class OverlayGlassBackground: NSView {
    private let glass = OverlayNativeGlassView()
    private let scrim = OverlayGradientView()
    private let opticalMask = CALayer()
    private let opticalEdge = GlassEdgeMask.makeLayer(inverted: false)
    private let shadeMask = GlassEdgeMask.makeLayer(inverted: true)
    private var configuration: Configuration?

    private struct Configuration: Equatable {
        let appearance: OverlayAppearance
        let transparency: Double
        let frostAmount: Double
        let reduceTransparency: Bool
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 24
        layer?.cornerCurve = .continuous
        glass.cornerRadius = 24
        glass.frame = bounds
        glass.autoresizingMask = [.width, .height]
        // The foreground stays white regardless of the desktop appearance.
        glass.appearance = NSAppearance(named: .darkAqua)
        glass.tintColor = nil
        glass.wantsLayer = true
        opticalMask.addSublayer(opticalEdge)
        scrim.wantsLayer = true
        glass.contentView = scrim
        addSubview(glass)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        synchronizeGeometry()
    }

    override func layout() {
        super.layout()
        synchronizeGeometry()
    }

    // Window animation can resize native glass without scheduling layout for
    // its mask layers. Commit every dependent frame in the same transaction.
    func synchronizeGeometry() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if glass.frame != bounds { glass.frame = bounds }
        if scrim.frame != glass.bounds { scrim.frame = glass.bounds }
        if opticalMask.frame != glass.bounds { opticalMask.frame = glass.bounds }
        if opticalEdge.frame != glass.bounds { opticalEdge.frame = glass.bounds }
        if shadeMask.frame != scrim.bounds { shadeMask.frame = scrim.bounds }
        CATransaction.commit()
    }

    func configure(appearance: OverlayAppearance, transparency: Double, frostAmount: Double,
                   reduceTransparency: Bool, reduceMotion: Bool) {
        let next = Configuration(appearance: appearance,
                                 transparency: OverlayAppearance.clampedTransparency(transparency),
                                 frostAmount: appearance.clampedFrost(frostAmount),
                                 reduceTransparency: reduceTransparency)
        guard configuration != next, let gradient = scrim.layer as? CAGradientLayer else { return }
        let animate = configuration != nil && configuration?.appearance != appearance
            && !reduceMotion && !reduceTransparency
        let previousColors = gradient.presentation()?.colors ?? gradient.colors
        let previous = configuration
        configuration = next
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // .regular softens the backdrop more for reading; .clear keeps its
        // texture and refraction. Tint color is not an opacity control.
        let nativeStyle: NSGlassEffectView.Style = appearance == .glass ? .clear : .regular
        if glass.style != nativeStyle { glass.style = nativeStyle }
        // Mix the native optical surface with the actual desktop. Changing
        // only the scrim leaves the full backdrop blur in place at every value.
        let baseOpacity = 1 - next.transparency
        let materialOpacity = appearance.materialOpacity(transparency: next.transparency, frost: next.frostAmount)
        // A little more of the existing native blur softens background detail.
        // Compensate the scrim so this does not also darken the whole panel.
        let shadeScale = appearance == .glass ? baseOpacity / materialOpacity : 1
        if appearance == .glass {
            // Keep the centre's existing blend, revealing more of the native
            // optical surface only in a softly feathered band at the perimeter.
            if glass.alphaValue != 1 { glass.alphaValue = 1 }
            opticalMask.backgroundColor = NSColor.white.withAlphaComponent(materialOpacity).cgColor
            if glass.layer?.mask !== opticalMask { glass.layer?.mask = opticalMask }
            // Compensate the edge's stronger material blend so it doesn't
            // produce a dark band or a bright halo around the reading scrim.
            if previous?.appearance != appearance || previous?.transparency != next.transparency || previous?.frostAmount != next.frostAmount {
                shadeMask.contents = GlassEdgeMask.shadeImage(materialOpacity: materialOpacity)
            }
            if scrim.layer?.mask !== shadeMask { scrim.layer?.mask = shadeMask }
        } else {
            if glass.layer?.mask != nil { glass.layer?.mask = nil }
            if glass.alphaValue != materialOpacity { glass.alphaValue = materialOpacity }
            if scrim.layer?.mask != nil { scrim.layer?.mask = nil }
        }
        glass.needsLayout = true
        scrim.needsLayout = true
        glass.isHidden = reduceTransparency
        layer?.backgroundColor = reduceTransparency ? NSColor(white: 0.12, alpha: 1).cgColor : nil
        gradient.colors = appearance.shadeOpacities(transparency: next.transparency)
            .map { NSColor.black.withAlphaComponent($0 * shadeScale).cgColor }
        CATransaction.commit()
        gradient.removeAnimation(forKey: "appearance")
        if animate, let previousColors {
            let transition = CABasicAnimation(keyPath: "colors")
            transition.fromValue = previousColors
            transition.toValue = gradient.colors
            transition.duration = 0.24
            transition.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0, 0.2, 1)
            gradient.add(transition, forKey: "appearance")
        }
    }

}

/// Material and content frames settle at different points during native window
/// resizing. Each view owns its mask layout after its own bounds have updated.
@MainActor private final class OverlayNativeGlassView: NSGlassEffectView {
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let mask = layer?.mask {
            if mask.frame != bounds { mask.frame = bounds }
            mask.sublayers?.forEach { if $0.frame != bounds { $0.frame = bounds } }
        }
        CATransaction.commit()
    }
}

/// AppKit resizes this backing gradient with the material's content view.
@MainActor private final class OverlayGradientView: NSView {
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let mask = layer?.mask, mask.frame != bounds { mask.frame = bounds }
        CATransaction.commit()
    }

    override func makeBackingLayer() -> CALayer {
        let gradient = CAGradientLayer()
        gradient.startPoint = CGPoint(x: 0.5, y: 1)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        gradient.locations = [0, 0.38, 0.76, 1]
        gradient.cornerRadius = 24
        gradient.cornerCurve = .continuous
        gradient.masksToBounds = true
        return gradient
    }
}

/// Small alpha textures blend the native optics at the perimeter.
/// Nine-slice stretching keeps the feather width constant through window resizes.
/// These do not draw highlights or sample/copy the desktop. AppKit supplies the
/// actual refraction and final continuous-corner silhouette.
@MainActor private enum GlassEdgeMask {
    private static let edge = image(inverted: false)
    private static let shades: NSCache<NSNumber, CGImage> = {
        let cache = NSCache<NSNumber, CGImage>()
        cache.countLimit = 8
        cache.totalCostLimit = 128 * 128 * 4 * 8
        return cache
    }()

    static func makeLayer(inverted: Bool) -> CALayer {
        let layer = CALayer()
        layer.contents = inverted ? nil : edge
        layer.contentsScale = 2
        layer.contentsCenter = CGRect(x: 30.0 / 64, y: 30.0 / 64, width: 4.0 / 64, height: 4.0 / 64)
        return layer
    }

    static func shadeImage(materialOpacity: Double) -> CGImage? {
        let key = NSNumber(value: materialOpacity)
        if let cached = shades.object(forKey: key) { return cached }
        guard let result = image(inverted: true, materialOpacity: materialOpacity) else { return nil }
        shades.setObject(result, forKey: key, cost: 128 * 128 * 4)
        return result
    }

    // Compute geometry once. Slider changes only remap this tiny profile;
    // lyric frames and window resizing never regenerate its pixels.
    private static let profile: [Double] = (0..<(128 * 128)).map { index in
        let x = index % 128, y = index / 128
        let qx = abs((Double(x) + 0.5) / 2 - 32) - 8
        let qy = abs((Double(y) + 0.5) / 2 - 32) - 8
        let depth = 24 - hypot(max(qx, 0), max(qy, 0)) - min(max(qx, qy), 0)
        let t = min(1, max(0, (depth - 1) / 21))
        return 1 - t * t * (3 - 2 * t)
    }

    private static func image(inverted: Bool, materialOpacity: Double = 1) -> CGImage? {
        let side = 128
        var pixels = [UInt8](repeating: 255, count: side * side * 4)
        for (index, edge) in profile.enumerated() {
            let optics = materialOpacity + (1 - materialOpacity) * edge
            let alpha = inverted ? materialOpacity / optics * (1 - 0.06 * edge) : edge
            pixels[index * 4 + 3] = UInt8((alpha * 255).rounded())
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
