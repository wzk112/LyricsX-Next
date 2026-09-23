import AppKit
import Metal
import QuartzCore

/// A window-local output declaration, outside SwiftUI's text/filter caches.
/// Extended text pixels alone do not activate display headroom reliably in a
/// nonactivating panel. A visible CAMetalLayer explicitly opts this window into
/// EDR. Its single transparent drawable changes no pixels or glass optics.
/// Submit only on activation/recovery, never on the lyric's display-link tick.
@MainActor final class WindowEDRSurface {
    let layer = CAMetalLayer()
    private var queue: (any MTLCommandQueue)?
    private(set) var requestedHeadroom = 1.0
    private(set) var presentationCount = 0
    private var hasPresented = false

    init() {
        layer.isOpaque = false
        layer.pixelFormat = .rgba16Float
        layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        layer.drawableSize = CGSize(width: 1, height: 1)
        layer.maximumDrawableCount = 2
        layer.allowsNextDrawableTimeout = true
    }

    func update(headroom: Double, visible: Bool, redraw: Bool = false) {
        let target = visible && headroom.isFinite ? max(1, headroom) : 1
        guard target != requestedHeadroom || (target > 1 && (redraw || !hasPresented)) else { return }
        requestedHeadroom = target
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.contentsHeadroom = target
        layer.preferredDynamicRange = target > 1 ? .high : .standard
        // This is CAMetalLayer's supported EDR switch (not the deprecated
        // CALayer property). Headroom bounds the system's output request.
        layer.wantsExtendedDynamicRangeContent = target > 1
        CATransaction.commit()
        guard target > 1 else { hasPresented = false; return }
        if queue == nil {
            let device = MTLCreateSystemDefaultDevice()
            layer.device = device
            queue = device?.makeCommandQueue()
        }
        guard let queue, let drawable = layer.nextDrawable(),
              let command = queue.makeCommandBuffer() else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.endEncoding()
        command.present(drawable)
        command.commit()
        hasPresented = true
        presentationCount += 1
    }

    func stop() {
        update(headroom: 1, visible: false)
        layer.removeFromSuperlayer()
        hasPresented = false
        queue = nil
        layer.device = nil
    }
}
