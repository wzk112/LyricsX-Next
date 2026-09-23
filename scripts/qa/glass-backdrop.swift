// A separate-process fixture for opt-in native overlay QA. Not shipped in LyricsX.
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let values = CommandLine.arguments.dropFirst()
let frame = NSRect(x: Double(values[1])!, y: Double(values[2])!,
                   width: Double(values[3])!, height: Double(values[4])!)
let surface = values[5]
let ready = values[6]
let window = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
window.title = "LyricsX glass QA backdrop"
let captureLevel: NSWindow.Level = ProcessInfo.processInfo.environment["LYRICSX_CONTROL_QA_FOREGROUND"] == "1" ? .statusBar : .floating
window.level = NSWindow.Level(rawValue: captureLevel.rawValue - 1)
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
window.hidesOnDeactivate = false
let dark = surface == "dark" || surface == "reference-dark"
window.backgroundColor = dark ? NSColor(white: 0.04, alpha: 1) : .white
let scene = NSView(frame: NSRect(origin: .zero, size: frame.size))
scene.wantsLayer = true
if surface == "color" {
    let colors: [NSColor] = [.systemBlue, .systemTeal, .systemOrange, .systemPink]
    for i in 0..<16 {
        let band = CALayer()
        band.frame = NSRect(x: Double(i) * frame.width / 16, y: 0,
                            width: frame.width / 16, height: frame.height)
        band.backgroundColor = colors[(i / 4) % colors.count].withAlphaComponent(i.isMultiple(of: 2) ? 1 : 0.65).cgColor
        scene.layer?.addSublayer(band)
    }
}
if surface.hasPrefix("reference-") {
    scene.layer?.backgroundColor = (dark ? NSColor(white: 0.08, alpha: 1)
        : NSColor(red: 1, green: 0.89, blue: 0.69, alpha: 1)).cgColor
    for row in 0..<8 {
        let stripe = CALayer()
        stripe.frame = NSRect(x: 0, y: Double(row) * 34, width: frame.width, height: 17)
        stripe.backgroundColor = (dark ? NSColor.systemTeal.withAlphaComponent(0.22)
            : NSColor.white.withAlphaComponent(0.55)).cgColor
        scene.layer?.addSublayer(stripe)
    }
}
if surface == "text" || surface.hasPrefix("reference-") {
    for row in 0..<8 {
        let label = NSTextField(labelWithString: "Background text · 后方文字 · 0123456789     Background text · 后方文字")
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = dark ? .white : .black
        label.frame = NSRect(x: 12, y: Double(row) * 30, width: frame.width - 24, height: 22)
        scene.addSubview(label)
    }
}
window.contentView = scene
window.orderFrontRegardless()
DispatchQueue.main.async {
    window.displayIfNeeded()
    try? Data("ready".utf8).write(to: URL(fileURLWithPath: ready))
}
app.run()
