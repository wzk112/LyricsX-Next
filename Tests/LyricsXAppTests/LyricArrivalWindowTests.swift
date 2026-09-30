import AppKit
import SwiftUI
import Testing
@testable import LyricsXApp

@Observable @MainActor private final class ArrivalWindowState {
    var visible = true
    var track = 0
}

@MainActor private final class ArrivalRenderCounter {
    var bodies = 0
}

private struct ArrivalCountedContent: View {
    let counter: ArrivalRenderCounter
    var body: some View {
        counter.bodies += 1
        return Text("A lyric viewport with a resting arrival")
    }
}

private struct ArrivalWindowHost: View {
    let state: ArrivalWindowState
    let counter: ArrivalRenderCounter
    var body: some View {
        ArrivalCountedContent(counter: counter)
            .lyricArrival(trigger: state.track, reduced: false, visible: { state.visible })
    }
}

@Suite(.serialized) @MainActor struct LyricArrivalWindowTests {
    @Test func hidingARestingArrivalDoesNotInvalidateItsLyricContent() async throws {
        _ = NSApplication.shared
        let state = ArrivalWindowState()
        let counter = ArrivalRenderCounter()
        let window = NSPanel(contentRect: .init(x: 20, y: 20, width: 400, height: 120),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ArrivalWindowHost(state: state, counter: counter))
        window.orderFrontRegardless()
        defer { window.close() }
        func settle() async throws {
            for _ in 0..<10 {
                NSApp.updateWindows()
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        try await settle()
        let initial = counter.bodies
        #expect(initial > 0)
        state.visible = false
        try await settle()
        #expect(counter.bodies == initial,
            "Hiding the main window must not rebuild an idle lyric viewport")
        // A song arriving while hidden must remain at rest, without a queued
        // display-rate animation when the window reopens.
        state.track = 1
        try await settle()
        let hidden = counter.bodies
        state.visible = true
        try await settle()
        #expect(counter.bodies == hidden)
    }
}
