import AppKit
import Foundation
import Observation
import WebKit

/// Credentials stay inside this app's dedicated persistent website data store.
/// No credentials are exported, logged, copied into preferences, or sent to a proxy.
@Observable @MainActor public final class AppleMusicCloudSession: NSObject, WKUIDelegate, WKNavigationDelegate, NSWindowDelegate {
    public static let shared = AppleMusicCloudSession()
    public private(set) var status = "未连接"
    public private(set) var isSigningOut = false
    @ObservationIgnored private var signOutTask: Task<Void, Never>?
    @ObservationIgnored private var page: WKWebView?
    @ObservationIgnored private var popups: [WKWebView: NSWindow] = [:]
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var store: WKWebsiteDataStore?
    @ObservationIgnored private var loginVisible = false
    @ObservationIgnored private var foreground = true
    @ObservationIgnored private var activeRequests = 0
    @ObservationIgnored private var idleTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var scripts: [UUID: ScriptCall] = [:]
    @ObservationIgnored private var mediaPolicies: [ObjectIdentifier: Bool] = [:]
    @ObservationIgnored private let idleTimeout: Duration
    @ObservationIgnored private let loadPage: @MainActor (WKWebView) -> Void
    @ObservationIgnored private let storeID: UUID
    @ObservationIgnored private let requiresMediaGesture: Bool
    private static let defaultStoreID = UUID(uuidString: "5FA3E3B4-A8E6-4B5C-A19D-241490202607")!
    public override init() {
        storeID = Self.defaultStoreID
        requiresMediaGesture = true
        idleTimeout = .seconds(15)
        loadPage = { $0.load(URLRequest(url: URL(string: "https://music.apple.com")!)) }
        super.init()
    }
    init(idleTimeout: Duration, storeID: UUID = UUID(), requiresMediaGesture: Bool = true,
         loadPage: @escaping @MainActor (WKWebView) -> Void) {
        self.storeID = storeID; self.requiresMediaGesture = requiresMediaGesture
        self.idleTimeout = idleTimeout; self.loadPage = loadPage; super.init()
    }
    public var hasLoadedPage: Bool { page != nil }
    var pendingScriptCount: Int { scripts.count }

    public func loginPage() -> WKWebView {
        loginVisible = true; idleTask?.cancel()
        let page = ensurePage()
        updateMediaPolicy()
        return page
    }
    public func dismissLoginPage() {
        loginVisible = false
        for window in Array(popups.values) { window.close() }
        updateMediaPolicy(); scheduleIdleRelease()
    }
    private func ensurePage() -> WKWebView {
        if let page { return page }
        let configuration = WKWebViewConfiguration()
        let store = WKWebsiteDataStore(forIdentifier: storeID)
        self.store = store
        configuration.websiteDataStore = store
        let version = ProcessInfo.processInfo.operatingSystemVersion
        // Keep WebKit's own desktop UA, adding Safari's compatibility suffix.
        configuration.applicationNameForUserAgent = "Version/\(version.majorVersion).\(version.minorVersion) Safari/605.1.15"
        configuration.mediaTypesRequiringUserActionForPlayback = requiresMediaGesture ? .all : []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.uiDelegate = self; view.navigationDelegate = self
        page = view
        observeApplication()
        updateMediaPolicy()
        status = "正在加载 Apple Music 网页"
        loadPage(view)
        return view
    }
    private func observeApplication() {
        guard observers.isEmpty else { return }
        foreground = NSApplication.shared.isActive
        for (name, active) in [(NSApplication.didBecomeActiveNotification, true),
                               (NSApplication.didResignActiveNotification, false), (NSApplication.didHideNotification, false)] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.foreground = active; self?.updateMediaPolicy() }
            })
        }
    }
    private func updateMediaPolicy() {
        let suspend = !loginVisible || !foreground
        for view in [page].compactMap({ $0 }) + Array(popups.keys) {
            applyMediaPolicy(to: view, suspended: suspend)
        }
    }
    private func applyMediaPolicy(to view: WKWebView, suspended: Bool) {
        let id = ObjectIdentifier(view)
        guard mediaPolicies[id] != suspended else { return }
        mediaPolicies[id] = suspended
        if suspended { view.pauseAllMediaPlayback(completionHandler: nil) }
        view.setAllMediaPlaybackSuspended(suspended, completionHandler: nil)
    }
    private func scheduleIdleRelease() {
        idleTask?.cancel()
        guard page != nil, !loginVisible, activeRequests == 0 else { return }
        let revision = generation
        idleTask = Task { [weak self, idleTimeout] in
            do { try await Task.sleep(for: idleTimeout) } catch { return }
            guard let self, self.generation == revision, !self.loginVisible, self.activeRequests == 0 else { return }
            self.releasePage()
            self.status = "空闲连接已暂停，登录会话保留；下次读取会自动连接"
        }
    }
    private func releasePage() {
        generation &+= 1; idleTask?.cancel(); idleTask = nil
        for id in Array(scripts.keys) { finishScript(id, result: .failure(CancellationError())) }
        if let page { applyMediaPolicy(to: page, suspended: true) }
        page?.stopLoading(); page?.uiDelegate = nil; page?.navigationDelegate = nil; page = nil
        for window in Array(popups.values) { window.close() }
        popups.removeAll(); mediaPolicies.removeAll(); store = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
    }

    public func suspend() {
        loginVisible = false; releasePage()
        status = "已停止连接，登录会话保留在本机"
    }
    public func signOut() async {
        if let signOutTask { await signOutTask.value; return }
        isSigningOut = true
        suspend()
        let store = self.store ?? WKWebsiteDataStore(forIdentifier: storeID)
        let task = Task { await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) }
        signOutTask = task
        await task.value
        signOutTask = nil; isSigningOut = false
        status = "已清除本机登录会话"
    }
    public func checkConnection() async throws {
        _ = try await request("/v1/me/storefront")
        status = "登录会话有效；请测试当前歌曲确认歌词读取"
    }

    func request(_ path: String) async throws -> Data {
        try Task.checkCancellation()
        guard !isSigningOut else { throw AppleMusicCloudError.signInRequired }
        guard Self.validPath(path) else { throw AppleMusicCloudError.response }
        idleTask?.cancel(); activeRequests += 1
        defer { activeRequests -= 1; scheduleIdleRelease() }
        let page = ensurePage(), revision = generation
        if !loginVisible, page.url?.host != "music.apple.com", !page.isLoading {
            loadPage(page)
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(12))
        var ready = false
        while ContinuousClock.now < deadline {
            try Task.checkCancellation()
            guard revision == generation else { throw CancellationError() }
            if page.url?.host == "music.apple.com", !page.isLoading,
               let result = try? await evaluate("return typeof MusicKit !== 'undefined' && !!MusicKit.getInstance()?.api?.music;", page: page, timeout: .seconds(3)),
               result == .boolean(true) { ready = true; break }
            try await Task.sleep(for: .milliseconds(250))
        }
        guard ready else { status = "网页未就绪，请打开登录窗口"; throw AppleMusicCloudError.pageNotReady }
        let script = """
        const music = MusicKit.getInstance();
        if (!music.isAuthorized || !music.musicUserToken) return JSON.stringify({code:401});
        let timer;
        try {
            const response = await Promise.race([
                music.api.music(path),
                new Promise((_, reject) => { timer = setTimeout(() => reject({status:408}), 10000); })
            ]);
            const payload = response?.data ?? response;
            const body = Array.isArray(payload) ? {data:payload} : payload;
            const error = body?.errors?.[0];
            if (error) return JSON.stringify({code:Number(error.status) || 500});
            return JSON.stringify({code:200, body:JSON.stringify(body)});
        } catch (error) {
            return JSON.stringify({code:Number(error?.status ?? error?.response?.status) || 500});
        } finally { clearTimeout(timer); }
        """
        let value: ScriptValue
        do { value = try await evaluate(script, arguments: ["path": path], page: page, timeout: .seconds(14)) }
        catch {
            try Task.checkCancellation()
            guard revision == generation else { throw CancellationError() }
            if let error = error as? AppleMusicCloudError { throw error }
            throw AppleMusicCloudError.network
        }
        try Task.checkCancellation()
        guard revision == generation, page.url?.host == "music.apple.com" else { throw CancellationError() }
        struct Envelope: Decodable { let code: Int; let body: String? }
        guard case .string(let text) = value, text.utf8.count <= 6_000_000,
              let envelope = try? JSONDecoder().decode(Envelope.self, from: Data(text.utf8)) else { throw AppleMusicCloudError.response }
        switch envelope.code {
        case 200:
            guard let body = envelope.body, body.utf8.count <= 4_000_000 else { throw AppleMusicCloudError.response }
            status = "网页已连接"
            return Data(body.utf8)
        case 401: status = "需要登录或会话已失效"; throw AppleMusicCloudError.signInRequired
        case 403: status = "云端访问被拒绝，请检查订阅或重新登录"; throw AppleMusicCloudError.forbidden
        case 404: throw AppleMusicCloudError.noLyrics
        case 408: throw AppleMusicCloudError.timeout
        default: throw AppleMusicCloudError.network
        }
    }
    enum ScriptValue: Sendable, Equatable { case boolean(Bool), string(String), null }
    private final class ScriptCall {
        let continuation: CheckedContinuation<ScriptValue, any Error>
        var timeout: Task<Void, Never>?
        init(_ continuation: CheckedContinuation<ScriptValue, any Error>) { self.continuation = continuation }
    }
    /// WKWebView's async JavaScript API does not itself honor task cancellation.
    /// Resume each caller once, even if WebKit or the page stops responding.
    func evaluate(_ script: String, arguments: [String: Any] = [:], page: WKWebView, timeout: Duration) async throws -> ScriptValue {
        try Task.checkCancellation()
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ScriptValue, any Error>) in
                guard !Task.isCancelled else { continuation.resume(throwing: CancellationError()); return }
                let call = ScriptCall(continuation)
                scripts[id] = call
                call.timeout = Task { [weak self] in
                    do { try await Task.sleep(for: timeout) } catch { return }
                    self?.finishScript(id, result: .failure(AppleMusicCloudError.timeout))
                }
                page.callAsyncJavaScript(script, arguments: arguments, in: nil, in: .page, completionHandler: { [weak self] result in
                    self?.finishScript(id, result: result.flatMap { value in
                        if let text = value as? String { return .success(.string(text)) }
                        if let flag = value as? Bool { return .success(.boolean(flag)) }
                        if value is NSNull { return .success(.null) }
                        return .failure(AppleMusicCloudError.response)
                    })
                })
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finishScript(id, result: .failure(CancellationError())) }
        }
    }
    private func finishScript(_ id: UUID, result: Result<ScriptValue, any Error>) {
        guard let call = scripts.removeValue(forKey: id) else { return }
        call.timeout?.cancel(); call.continuation.resume(with: result)
    }
    static func validPath(_ path: String) -> Bool {
        guard path.hasPrefix("/v1/"), !path.contains(".."), !path.contains("#"),
              let url = URL(string: "https://amp-api.music.apple.com" + path), url.host == "amp-api.music.apple.com" else { return false }
        return path == "/v1/me/storefront" || url.path.range(of: "^/v1/catalog/[A-Za-z]{2}/(?:search|songs/[0-9]+/(?:syllable-lyrics|lyrics))$", options: .regularExpression) != nil
    }

    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                        for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard loginVisible, navigationAction.targetFrame == nil,
              Self.allowsLoginPopup(navigationAction.request.url, openerHost: navigationAction.sourceFrame.securityOrigin.host) else { return nil }
        let popup = WKWebView(frame: .zero, configuration: configuration)
        popup.uiDelegate = self; popup.navigationDelegate = self
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 680, height: 700),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.delegate = self
        window.title = "登录 Apple Music"
        window.contentView = popup
        popups[popup] = window
        updateMediaPolicy()
        window.center(); window.makeKeyAndOrderFront(nil)
        return popup
    }
    public func webViewDidClose(_ webView: WKWebView) { popups[webView]?.close() }
    public func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let view = popups.first(where: { $0.value === window })?.key else { return }
        popups.removeValue(forKey: view)
        applyMediaPolicy(to: view, suspended: true); mediaPolicies.removeValue(forKey: ObjectIdentifier(view))
        view.stopLoading()
        view.uiDelegate = nil; view.navigationDelegate = nil; window.contentView = nil
    }
    static func allowsLoginPopup(_ url: URL?, openerHost: String) -> Bool {
        guard isAppleHost(openerHost) else { return false }
        // OAuth commonly opens about:blank first, then assigns the auth URL.
        guard let url else { return true }
        return url.absoluteString == "about:blank" || (url.scheme == "https" && isAppleHost(url.host ?? ""))
    }
    private static func isAppleHost(_ host: String) -> Bool {
        let host = host.lowercased()
        return host == "apple.com" || host.hasSuffix(".apple.com")
    }
    public func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard action.targetFrame?.isMainFrame != false, let url = action.request.url else { return .allow }
        if url.absoluteString == "about:blank" || (url.scheme == "https" && Self.isAppleHost(url.host ?? "")) { return .allow }
        if action.navigationType == .linkActivated, url.scheme == "https" { NSWorkspace.shared.open(url) }
        return .cancel
    }
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        if (error as NSError).code != NSURLErrorCancelled { status = "网页登录加载失败，请重新打开登录窗口或检查网络" }
    }
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard webView === page else { webViewDidClose(webView); return }
        generation &+= 1
        for id in Array(scripts.keys) { finishScript(id, result: .failure(AppleMusicCloudError.pageNotReady)) }
        if loginVisible {
            status = "正在恢复 Apple Music 网页"
            loadPage(webView); updateMediaPolicy()
        } else {
            releasePage()
            status = "网页连接已释放，登录保留；下次读取会重新连接"
        }
    }
    isolated deinit {
        idleTask?.cancel()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        for call in scripts.values { call.timeout?.cancel(); call.continuation.resume(throwing: CancellationError()) }
    }
}
