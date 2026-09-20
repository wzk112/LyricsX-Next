import AppKit
import SwiftUI
import Testing
@testable import LyricsXApp

/// Sharp edges expose a stranded blur without depending on font rasterization.
@Suite(.serialized) @MainActor struct OverlayBlurLifecycleTests {
    @Test func contentTransitionSettlesAfterVisibilityAndIdentityChanges() async throws {
        _ = NSApplication.shared
        let panel = DraggableOverlayPanel(contentRect: .init(x: 40, y: 60, width: 180, height: 100),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        func view(_ id: String, visible: Bool = true, preparing: Double? = nil, tint: Color = .white) -> some View {
            Rectangle().fill(tint).frame(width: 60, height: 40)
                .modifier(OverlayContentTransition(identity: .init(track: id), visible: visible, preparingSince: preparing))
                .frame(width: 180, height: 100).background(.black)
        }
        let host = NSHostingView(rootView: view("initial"))
        panel.contentView = host; panel.orderFrontRegardless()
        defer { panel.orderOut(nil); panel.contentView = nil }
        func assertSharp(_ phase: String) throws {
            host.layoutSubtreeIfNeeded()
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let y = bitmap.pixelsHigh / 2, edge = bitmap.pixelsWide / 3
            let inside = try #require(bitmap.colorAt(x: edge + 1, y: y)?.usingColorSpace(.sRGB))
            let outside = try #require(bitmap.colorAt(x: edge - 2, y: y)?.usingColorSpace(.sRGB))
            #expect(inside.redComponent > 0.95 && outside.redComponent < 0.05, "\(phase): edge remained blurred \(inside.redComponent), \(outside.redComponent)")
        }
        try await Task.sleep(for: .milliseconds(750))
        try assertSharp("initial")
        for index in 0..<4 {
            host.rootView = view("song\(index)")
            try await Task.sleep(for: .milliseconds(40))
            // Hover, visibility interruption and a palette refresh overlap.
            host.rootView = view("song\(index)", visible: false)
            try await Task.sleep(for: .milliseconds(30))
            host.rootView = view("song\(index)", tint: .init(red: 1, green: 0.6, blue: 0.7))
            try await Task.sleep(for: .milliseconds(750))
            try assertSharp("visibility \(index)")
        }
        host.rootView = view("interrupted")
        try await Task.sleep(for: .milliseconds(70))
        func suspendFrames(_ view: NSView) {
            (view as? LyricFrameView)?.stop()
            view.subviews.forEach(suspendFrames)
        }
        suspendFrames(host)
        try await Task.sleep(for: .milliseconds(700))
        try assertSharp("display delivery interrupted")
        let preparing = ProcessInfo.processInfo.systemUptime
        host.rootView = view("song3", preparing: preparing)
        try await Task.sleep(for: .milliseconds(180))
        host.rootView = view("new")
        try await Task.sleep(for: .milliseconds(750))
        try assertSharp("handover")
    }
}

@Test func overlayBlurDeadlinesAndInterruptedHandoverAlwaysHaveASharpEnd() {
    var state = OverlayContentAnimation()
    func request(_ track: String, visible: Bool = true, preparing: Double? = nil) -> OverlayContentAnimation.Request {
        .init(identity: .init(track: track), reduced: false, visible: visible, preparingSince: preparing)
    }
    state.update(request("first"), at: 10, incremental: false, lineDuration: 1, animateInitial: true)
    #expect(state.frame(at: 10).blur > 0)
    #expect(state.frame(at: 11) == .init()) // Even before completion is delivered.
    state.update(request("next"), at: 11, incremental: false, lineDuration: 1, animateInitial: true)
    state.finish(10) // A delayed completion cannot cancel the next song.
    #expect(state.startedAt == 11)
    state.update(request("next", visible: false), at: 11.1, incremental: false, lineDuration: 1, animateInitial: true)
    state.update(request("next"), at: 11.2, incremental: false, lineDuration: 1, animateInitial: true)
    #expect(state.frame(at: 11.2) == .init())
    state.update(request("next", preparing: 12), at: 12, incremental: false, lineDuration: 1, animateInitial: true)
    #expect(state.startedAt == nil)
    #expect(state.frame(at: 12.08) == .init())
    #expect(state.frame(at: 13) == .init())
    state.finish(12)
    #expect(state.frame(at: 13) == .init())
    state.update(request("new"), at: 13, incremental: false, lineDuration: 1, animateInitial: true)
    #expect(state.frame(at: 13).blur > 0)
    #expect(state.frame(at: 14) == .init())
}

@Test func metadataAndArtworkRefinementsDoNotReplayTheSongTransition() {
    let firstArtwork = NSObject(), secondArtwork = NSObject()
    let initial = OverlayContentIdentity(track: "7", primary: "2", compact: true,
        artwork: ObjectIdentifier(firstArtwork)).songScope
    let refined = OverlayContentIdentity(track: "7", primary: "2", compact: true,
        artwork: ObjectIdentifier(secondArtwork)).songScope
    #expect(initial == refined)
    #expect(OverlayBlurStyle.change(from: initial, to: refined, incremental: false, lineDuration: 1) == .init())
}

@Test func waitingLyricsAndSongCardModesDoNotReplayTheSongTitleTransition() {
    let waiting = OverlayContentIdentity(track: "8", primary: "waiting", compact: true).songScope
    let lyrics = OverlayContentIdentity(track: "8", document: UUID(), primary: "line", compact: false).songScope
    let songCard = OverlayContentIdentity(track: "8", primary: "song", compact: true).songScope
    #expect(waiting == lyrics)
    #expect(lyrics == songCard)
    #expect(waiting != OverlayContentIdentity(track: "9").songScope)
}
