import AppKit
import Foundation
import Testing
import WebKit
@testable import LyricsXServices

@Suite(.serialized) @MainActor
struct AppleMusicCloudWebLifecycleTests {
    private func fixture(idle: Duration = .milliseconds(80), requiresMediaGesture: Bool = true) -> AppleMusicCloudSession {
        AppleMusicCloudSession(idleTimeout: idle, requiresMediaGesture: requiresMediaGesture) { page in
            page.loadHTMLString("""
            <html><body>Offline session fixture<script>
            window.fixtureDelay = 0;
            window.MusicKit = {getInstance: () => ({
                isAuthorized: true, musicUserToken: 'test-fixture',
                api: {music: async () => {
                    await new Promise(resolve => setTimeout(resolve, window.fixtureDelay));
                    return {data: {data: [{id: 'au'}]}};
                }}
            })};
            </script></body></html>
            """, baseURL: URL(string: "https://music.apple.com")!)
        }
    }
    private func loaded(_ session: AppleMusicCloudSession, _ page: WKWebView) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(4))
        while page.isLoading && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        let value = try await session.evaluate("return !!window.MusicKit;", page: page, timeout: .seconds(2))
        #expect(value == .boolean(true))
    }
    private func waitForScript(_ session: AppleMusicCloudSession) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        while session.pendingScriptCount == 0 && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
        #expect(session.pendingScriptCount == 1)
    }

    @Test func closingLoginReleasesIdlePageAndReopeningRetainsWebsiteStorage() async throws {
        let session = fixture()
        var page: WKWebView? = session.loginPage()
        try await loaded(session, try #require(page))
        let key = UUID().uuidString
        _ = try await session.evaluate("localStorage.setItem(key, 'retained'); return true;", arguments: ["key": key], page: try #require(page), timeout: .seconds(2))
        try await Task.sleep(for: .milliseconds(120))
        #expect(session.hasLoadedPage) // An open login window is never collected for being idle.
        session.dismissLoginPage(); page = nil
        try await Task.sleep(for: .milliseconds(180))
        #expect(!session.hasLoadedPage && session.status.contains("登录会话保留"))
        let reopened = session.loginPage()
        try await loaded(session, reopened)
        let value = try await session.evaluate("return localStorage.getItem(key);", arguments: ["key": key], page: reopened, timeout: .seconds(2))
        #expect(value == .string("retained"))
        await session.signOut() // Isolated fixture store; never the installed app's login.
    }

    @Test func activeRequestSurvivesIdleDeadlineThenReleasesItsPage() async throws {
        let session = fixture()
        let page = session.loginPage()
        try await loaded(session, page)
        _ = try await session.evaluate("window.fixtureDelay = 300; return true;", page: page, timeout: .seconds(2))
        let request = Task { try await session.request("/v1/me/storefront") }
        try await waitForScript(session)
        session.dismissLoginPage()
        try await Task.sleep(for: .milliseconds(160))
        #expect(session.hasLoadedPage)
        let data = try await request.value
        #expect(String(decoding: data, as: UTF8.self).contains("au"))
        try await Task.sleep(for: .milliseconds(180))
        #expect(!session.hasLoadedPage && session.pendingScriptCount == 0)
        await session.signOut()
    }

    @Test func stalledJavaScriptHasABoundedDeadlineAndCancellationDoesNotWaitForWebKit() async throws {
        let session = fixture(idle: .seconds(10))
        let page = session.loginPage()
        defer { session.suspend() }
        try await loaded(session, page)
        do {
            _ = try await session.evaluate("return new Promise(() => {});", page: page, timeout: .milliseconds(40))
            Issue.record("A stalled page unexpectedly returned")
        } catch AppleMusicCloudError.timeout { }
        #expect(session.pendingScriptCount == 0)
        let request = Task { @MainActor in
            _ = try await session.evaluate("return new Promise(resolve => setTimeout(() => resolve('late'), 150));", page: page, timeout: .seconds(5))
        }
        try await waitForScript(session)
        request.cancel()
        do { try await request.value; Issue.record("A cancelled script unexpectedly returned") }
        catch is CancellationError { }
        #expect(session.pendingScriptCount == 0)
        try await Task.sleep(for: .milliseconds(200)) // A late WebKit reply must not resume the caller a second time.
        #expect(session.pendingScriptCount == 0)
        await session.signOut()
    }

    @Test func suspendingOrLosingTheWebProcessCancelsPendingWorkAndCanReconnect() async throws {
        let session = fixture(idle: .seconds(10))
        let page = session.loginPage()
        try await loaded(session, page)
        let request = Task { @MainActor in
            _ = try await session.evaluate("return new Promise(() => {});", page: page, timeout: .seconds(5))
        }
        try await waitForScript(session)
        session.suspend()
        do { try await request.value; Issue.record("Suspended page kept its caller alive") }
        catch is CancellationError { }
        #expect(!session.hasLoadedPage && session.pendingScriptCount == 0)
        let reopened = session.loginPage()
        try await loaded(session, reopened)
        session.webViewWebContentProcessDidTerminate(reopened)
        #expect(session.hasLoadedPage) // Restore the web view already hosted by the login sheet.
        try await loaded(session, reopened)
        session.dismissLoginPage()
        session.webViewWebContentProcessDidTerminate(reopened)
        #expect(!session.hasLoadedPage)
        let data = try await session.request("/v1/me/storefront")
        #expect(String(decoding: data, as: UTF8.self).contains("au"))
        await session.signOut()
    }

    @Test func appleLoginPopupsAllowBlankOAuthBootstrapAndRejectOtherOrigins() {
        #expect(AppleMusicCloudSession.allowsLoginPopup(nil, openerHost: "music.apple.com"))
        #expect(AppleMusicCloudSession.allowsLoginPopup(URL(string: "about:blank"), openerHost: "music.apple.com"))
        #expect(AppleMusicCloudSession.allowsLoginPopup(URL(string: "https://idmsa.apple.com/appleauth/auth/signin"), openerHost: "music.apple.com"))
        for url in ["https://apple.com.evil.test", "http://idmsa.apple.com", "musics://music.apple.com", "https://example.com"] {
            #expect(!AppleMusicCloudSession.allowsLoginPopup(URL(string: url), openerHost: "music.apple.com"))
        }
        #expect(!AppleMusicCloudSession.allowsLoginPopup(URL(string: "about:blank"), openerHost: "example.com"))
    }

    @Test func backgroundAndClosedLoginPauseNativeWebKitMediaWithoutBlockingLyricsRequests() async throws {
        // Autoplay is permitted only in this isolated silent fixture, so the test
        // verifies native suspension rather than merely WebKit's gesture requirement.
        let session = fixture(idle: .seconds(10), requiresMediaGesture: false)
        let page = session.loginPage()
        let window = NSWindow(contentRect: .init(x: 20, y: 20, width: 320, height: 180),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.title = "Cloud media test"
        window.contentView = page; window.orderFront(nil)
        defer { window.close(); window.contentView = nil; session.suspend() }
        try await loaded(session, page)
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: NSApplication.shared)
        try await Task.sleep(for: .milliseconds(30))
        await withCheckedContinuation { continuation in
            page.setAllMediaPlaybackSuspended(false) { continuation.resume() }
        }
        // Half a second of silent PCM, looped and muted: no audible playback or network access.
        var wave = Data("RIFF".utf8)
        func number(_ value: UInt32, bytes: Int) { wave.append(contentsOf: (0..<bytes).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }) }
        number(8036, bytes: 4); wave.append(Data("WAVEfmt ".utf8)); number(16, bytes: 4)
        number(1, bytes: 2); number(1, bytes: 2); number(8000, bytes: 4); number(16000, bytes: 4)
        number(2, bytes: 2); number(16, bytes: 2); wave.append(Data("data".utf8)); number(8000, bytes: 4)
        wave.append(Data(repeating: 0, count: 8000))
        let started = try await session.evaluate("""
        window.fixtureAudio = new Audio('data:audio/wav;base64,' + sample);
        fixtureAudio.loop = true; fixtureAudio.muted = true;
        await fixtureAudio.play(); return !fixtureAudio.paused;
        """, arguments: ["sample": wave.base64EncodedString()], page: page, timeout: .seconds(2))
        #expect(started == .boolean(true))
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApplication.shared)
        try await Task.sleep(for: .milliseconds(60))
        let paused = try await session.evaluate("return fixtureAudio.paused;", page: page, timeout: .seconds(2))
        #expect(paused == .boolean(true))
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: NSApplication.shared)
        try await Task.sleep(for: .milliseconds(30))
        let stayedPaused = try await session.evaluate("return fixtureAudio.paused;", page: page, timeout: .seconds(2))
        #expect(stayedPaused == .boolean(true)) // Returning to the app does not restart an interrupted song.
        session.dismissLoginPage()
        let data = try await session.request("/v1/me/storefront")
        #expect(String(decoding: data, as: UTF8.self).contains("au"))
        let stillPaused = try await session.evaluate("return fixtureAudio.paused;", page: page, timeout: .seconds(2))
        #expect(stillPaused == .boolean(true))
        await session.signOut()
    }
}
