import AppKit
import Testing
import SwiftUI
@testable import LyricsXApp

@Test func outputHeadroomBelongsOnlyToVisibleHDREmitters() {
    let edr = HDRDisplayCapability(potential: 2, current: 1)
    #expect(LyricHDROutputRequest.headroom(requested: true, visible: true, content: 3.5, capability: edr) == 2)
    #expect(LyricHDROutputRequest.headroom(requested: false, visible: true, content: 3.5, capability: edr) == 1)
    #expect(LyricHDROutputRequest.headroom(requested: true, visible: false, content: 3.5, capability: edr) == 1)
    #expect(LyricHDROutputRequest.headroom(requested: true, visible: true, content: 1, capability: edr) == 1)
    #expect(LyricHDROutputRequest.headroom(requested: true, visible: true, content: .nan, capability: edr) == 1)
    #expect(LyricHDROutputRequest.headroom(requested: true, visible: true, content: 3.5, capability: nil) == 1)
    #expect(LyricHDROutputRequest.headroom(requested: true, visible: true, content: 3.5,
        capability: .init(potential: 1, current: 1)) == 1)
    var combined = LyricHDRContentHeadroomKey.defaultValue
    for value in [1.0, 2.5, 1.6] { LyricHDRContentHeadroomKey.reduce(value: &combined) { value } }
    #expect(combined == 2.5)
}

@Test func edrEligibilityUsesPotentialRatherThanWhetherEDRIsAlreadyActive() {
    #expect(HDRDisplayCapability(potential: 4, current: 1).supported)
    #expect(HDRDisplayCapability(potential: 1.1, current: 1).supported)
    #expect(!HDRDisplayCapability(potential: 1, current: 1).supported)
    #expect(!HDRDisplayCapability(potential: 0, current: 4).supported)
    #expect(!HDRDisplayCapability(potential: .nan, current: 4).supported)
    #expect(!HDRDisplayCapability(potential: .infinity, current: 4).supported)
}

@Test func currentHeadroomIsSanitizedWithoutTreatingItAsEligibility() {
    #expect(HDRDisplayCapability(potential: 16, current: 1, builtIn: true).supported)
    #expect(HDRDisplayCapability(potential: 2, current: 5).currentHeadroom == 2)
    #expect(HDRDisplayCapability(potential: 4, current: .nan).currentHeadroom == 1)
    #expect(HDRDisplayCapability(potential: 1, current: 3).renderHeadroom == 1)
}

@Test func temporaryScreenLossDoesNotDisableEDRButConfirmedSDRDoes() {
    var state = HDRWindowOutput()
    state.refresh(nil)
    #expect(state.capability == nil)
    let edr = HDRDisplayCapability(id: 1, potential: 16, current: 2)
    state.refresh(edr)
    let stable = state
    state.refresh(nil)
    #expect(state == stable)
    state.refresh(.init(id: 1, potential: 16, current: 1))
    #expect(state == stable, "Available brightness must not churn the drawing state")
    state.refresh(nil, redraw: true)
    #expect(state.capability?.supported == true && state.revision == 1)
    state.refresh(.init(id: 2, potential: 1, current: 1))
    #expect(state.capability?.supported == false)
    #expect(state.capability?.renderHeadroom == 1)
    state.refresh(edr)
    #expect(state.capability?.renderHeadroom == 16)
}

@Suite(.serialized) @MainActor struct HDRWindowLifecycleTests {
    @Test func readerPublishesOnAttachmentRecoversAfterFocusAndCancelsOnDetach() async throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: .init(x: 100, y: 100, width: 150, height: 100),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        var received: [HDRWindowOutput] = []
        var reader: HDRWindowReaderView? = HDRWindowReaderView()
        weak let weakReader = reader
        reader?.changed = { received.append($0) }
        window.contentView = reader
        window.orderFrontRegardless()
        try await Task.sleep(for: .milliseconds(260))
        let first = try #require(received.last)
        #expect(first.capability?.supported == HDRDisplayCapability(screen: try #require(window.screen)).supported)
        for name in [NSWindow.didResignKeyNotification, NSWindow.didDeminiaturizeNotification] {
            NotificationCenter.default.post(name: name, object: window)
            try await Task.sleep(for: .milliseconds(260))
            #expect(received.last?.capability == first.capability)
        }
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        try await Task.sleep(for: .milliseconds(260))
        #expect(try #require(received.last).revision > first.revision)
        let afterFocus = received.count
        try await Task.sleep(for: .milliseconds(850))
        #expect(received.count == afterFocus, "Recovery must stop instead of continuously redrawing")
        let revision = try #require(received.last).revision
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: NSApp)
        try await Task.sleep(for: .milliseconds(260))
        #expect(received.last?.revision == revision, "EDR headroom notifications must not feed back into output recovery")
        reader?.contentVisible = false
        reader?.recover()
        try await Task.sleep(for: .milliseconds(260))
        #expect(received.last?.revision == revision, "Hidden content should not request HDR redraws")
        reader?.contentVisible = true
        try await Task.sleep(for: .milliseconds(260))
        #expect(try #require(received.last).revision > revision,
            "Hover reveal must recover without needing a window-focus notification")
        let afterReveal = received.count
        // Detach with both a deferred publication and a recovery still pending.
        reader?.recover()
        window.contentView = nil
        #expect(reader?.observing == false)
        reader = nil
        try await Task.sleep(for: .milliseconds(750))
        #expect(weakReader == nil)
        #expect(received.count == afterReveal)
    }
}
