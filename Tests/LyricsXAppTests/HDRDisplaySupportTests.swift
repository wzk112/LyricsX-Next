import AppKit
import Testing
import SwiftUI
@testable import LyricsXApp

@Test func brightnessEntryUsesTheSameNumericRangeAsTheEmitter() {
    #expect(HDRBrightness.parsed("2.6") == 2.6)
    #expect(HDRBrightness.parsed(" 1,8× ") == 1.8)
    #expect(HDRBrightness.parsed("9") == 4)
    #expect(HDRBrightness.parsed("0.3") == 1)
    #expect(HDRBrightness.parsed("2.66") == 2.7)
    for value in ["", "nan", "inf", "abc"] { #expect(HDRBrightness.parsed(value) == nil) }
    for value in [1.0, 1.6, 2.5, 4] {
        let ink = HeldNoteRenderer.hdrWhite(brightness: value).resolveHDR(in: EnvironmentValues())
        #expect(abs(Double(ink.linearRed) - value) < 0.001)
    }
}

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
    @Test func windowOutputRequestsRemainIndependentAndStopOnDetach() async throws {
        _ = NSApplication.shared
        let first = NSPanel(contentRect: .init(x: 100, y: 100, width: 2, height: 2),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let second = NSPanel(contentRect: .init(x: 105, y: 100, width: 2, height: 2),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        first.isReleasedWhenClosed = false; second.isReleasedWhenClosed = false
        defer { first.close(); second.close() }
        let a = HDRWindowReaderView(), b = HDRWindowReaderView()
        a.requestedHeadroom = 2; b.requestedHeadroom = 3
        first.contentView = a; second.contentView = b
        first.orderFrontRegardless(); second.orderFrontRegardless()
        try await Task.sleep(for: .milliseconds(750))
        #expect(a.edrSurface.requestedHeadroom == 2)
        #expect(b.edrSurface.requestedHeadroom == 3)
        let secondSubmissions = b.edrSurface.presentationCount
        first.orderOut(nil)
        try await Task.sleep(for: .milliseconds(300))
        #expect(a.edrSurface.requestedHeadroom == 1)
        #expect(!a.edrSurface.layer.wantsExtendedDynamicRangeContent)
        #expect(b.edrSurface.requestedHeadroom == 3)
        #expect(b.edrSurface.presentationCount == secondSubmissions)
        first.orderFrontRegardless()
        try await Task.sleep(for: .milliseconds(750))
        #expect(a.edrSurface.requestedHeadroom == 2)
        b.contentVisible = false
        #expect(b.edrSurface.requestedHeadroom == 1)
        b.contentVisible = true
        try await Task.sleep(for: .milliseconds(260))
        #expect(b.edrSurface.requestedHeadroom == 3)
        second.contentView = nil
        #expect(b.edrSurface.requestedHeadroom == 1)
        #expect(b.edrSurface.layer.device == nil)
        #expect(!b.observing)
    }

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
