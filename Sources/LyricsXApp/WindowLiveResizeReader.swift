import AppKit
import SwiftUI

/// Report the two resize boundaries, not a new SwiftUI observation per pixel.
struct WindowLiveResizeReader: NSViewRepresentable {
    var changed: (Bool) -> Void
    func makeNSView(context: Context) -> ResizeView {
        let view = ResizeView(); view.changed = changed; return view
    }
    func updateNSView(_ view: ResizeView, context: Context) { view.changed = changed }
    static func dismantleNSView(_ view: ResizeView, coordinator: ()) {
        view.stop(); view.changed = nil
    }

    final class ResizeView: NSView {
        var changed: ((Bool) -> Void)?
        private var reported: Bool?
        private var attachment: UInt64 = 0
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop(); reported = nil
            guard let window else { return }
            NotificationCenter.default.addObserver(self, selector: #selector(started),
                name: NSWindow.willStartLiveResizeNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(ended),
                name: NSWindow.didEndLiveResizeNotification, object: window)
            let token = attachment
            DispatchQueue.main.async { [weak self] in
                guard let self, self.attachment == token else { return }
                self.report(self.window?.inLiveResize == true)
            }
        }
        @objc private func started() { report(true) }
        @objc private func ended() { report(false) }
        private func report(_ value: Bool) {
            guard reported != value else { return }
            reported = value; changed?(value)
        }
        func stop() {
            attachment &+= 1
            NotificationCenter.default.removeObserver(self)
        }
    }
}
