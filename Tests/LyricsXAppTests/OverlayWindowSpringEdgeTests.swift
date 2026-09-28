import AppKit
import Testing
@testable import LyricsXApp

@MainActor @Test func springResizeNearSideAndBottomMovesAnchorOnlyWhenCurrentSizeNeedsClamping() throws {
    let bounds = try #require(NSScreen.main?.visibleFrame)
    #expect(bounds.width > 400 && bounds.height > 300)
    let logical = NSPoint(x: bounds.maxX - 80, y: bounds.minY + 100)
    let small = NSSize(width: 100, height: 80)
    let large = NSSize(width: 300, height: 180)
    let initial = OverlayAnchor(topCenter: logical).frame(size: small, in: bounds)
    let destination = OverlayAnchor(topCenter: logical).frame(size: large, in: bounds)
    #expect(initial.midX != destination.midX && initial.maxY != destination.maxY)
    let window = NSPanel(contentRect: initial, styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    defer { window.close() }
    let motion = OverlayWindowMotion(window: window)
    let now = ProcessInfo.processInfo.systemUptime
    var completions: [String] = []
    motion.start(to: destination, logicalTopCenter: logical, visibleFrame: bounds,
                 duration: 0.4, frameRateLimit: 60) { completions.append("expand") }
    motion.advance(at: now + 0.016)
    let first = window.frame
    #expect(first.width > initial.width && first.height > initial.height)
    #expect(abs(first.midX - initial.midX) <= 1)
    #expect(abs(first.maxY - initial.maxY) <= 1,
            "A small first frame must keep the logical anchor, not jump to the large clamped frame")
    motion.advance(at: now + 0.08)
    let beforeReverse = window.frame
    motion.start(to: initial, logicalTopCenter: logical, visibleFrame: bounds,
                 duration: 0.4, frameRateLimit: 60) { completions.append("reverse") }
    #expect(window.frame == beforeReverse)
    motion.advance(at: now + 0.096)
    #expect(abs(window.frame.midX - beforeReverse.midX) < 25)
    #expect(abs(window.frame.maxY - beforeReverse.maxY) < 25)
    for step in 7...100 {
        motion.advance(at: now + Double(step) * 0.016)
        let frame = window.frame
        #expect(frame.minX >= bounds.minX - 1 && frame.maxX <= bounds.maxX + 1)
        #expect(frame.minY >= bounds.minY - 1 && frame.maxY <= bounds.maxY + 1)
    }
    #expect(window.frame == initial && completions == ["reverse"])
    #expect(motion.displayLinkCreations == 1)
}
