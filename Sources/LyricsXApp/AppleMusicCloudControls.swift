import Foundation
import Observation
import LyricsXCore
import LyricsXServices

/// Login belongs to the web session; the test target belongs to the native
/// player. Keep those lifecycles separate, including when no song is selected.
@Observable @MainActor final class AppleMusicCloudControls {
    private(set) var checking = false
    private(set) var testing = false
    private(set) var clearing = false
    private(set) var result = ""
    @ObservationIgnored private let model: AppModel
    @ObservationIgnored private let cloud: AppleMusicCloudSession
    @ObservationIgnored private var resultTrackRevision: UInt64?
    @ObservationIgnored private let check: @MainActor () async throws -> String
    @ObservationIgnored private let read: @MainActor (Track) async throws -> LyricsDocument?
    @ObservationIgnored private let clear: @MainActor () async -> Void
    @ObservationIgnored private let refresh: @MainActor () -> Void
    @ObservationIgnored private var connectionTask: Task<Void, Never>?
    @ObservationIgnored private var testTask: Task<Void, Never>?
    @ObservationIgnored private var clearTask: Task<Void, Never>?

    init(model: AppModel, cloud: AppleMusicCloudSession = .shared,
         check: (@MainActor () async throws -> String)? = nil,
         read: (@MainActor (Track) async throws -> LyricsDocument?)? = nil,
         clear: (@MainActor () async -> Void)? = nil,
         refresh: (@MainActor () -> Void)? = nil) {
        self.model = model
        self.cloud = cloud
        self.check = check ?? { try await cloud.checkConnection(); return cloud.status }
        self.read = read ?? { try await AppleMusicCloudLyricsSource().document(for: $0) }
        self.clear = clear ?? { await cloud.signOut() }
        self.refresh = refresh ?? { model.bridge.refresh() }
    }
    var targetDescription: String {
        if let track = model.session.track, track.playerID == "com.apple.Music" {
            return "测试歌曲：\(track.title) — \(track.artist)（Mac 音乐）"
        }
        return "尚未识别到 Mac 音乐的当前歌曲。请在“音乐”应用中选择歌曲；暂停状态也可以测试。"
    }
    var canOpenLogin: Bool { model.preferences.appleMusicCloudEnabled && !clearing && !cloud.isSigningOut && !checking && !testing }
    var canCheckLogin: Bool { canOpenLogin }
    var canTestCurrentTrack: Bool { canOpenLogin }
    var canClearLogin: Bool { !clearing && !cloud.isSigningOut }
    func loginDidClose() {
        guard model.preferences.appleMusicCloudEnabled else { return }
        refresh()
        checkLogin()
    }
    func checkLogin() {
        guard canCheckLogin else { return }
        connectionTask?.cancel()
        resultTrackRevision = nil
        checking = true; result = "正在检查登录会话，无需在网页播放歌曲…"
        connectionTask = Task {
            defer { if !Task.isCancelled { checking = false } }
            do {
                let message = try await check()
                if !Task.isCancelled { result = message }
            } catch { if !Task.isCancelled { result = error.localizedDescription } }
        }
    }
    func testCurrentTrack() {
        guard canTestCurrentTrack else { return }
        guard let track = model.session.track, track.playerID == "com.apple.Music" else {
            refresh()
            result = "登录与选歌是两件事。请先在 Mac 的“音乐”应用中选择歌曲，再点击测试；无需在网页登录页播放。"
            return
        }
        connectionTask?.cancel(); checking = false
        let revision = model.session.trackRevision
        resultTrackRevision = revision
        testing = true; result = "正在读取《\(track.title)》，测试不会替换歌词…"
        testTask?.cancel()
        testTask = Task {
            defer { if !Task.isCancelled { testing = false } }
            do {
                let document = try await read(track)
                guard !Task.isCancelled, model.session.trackRevision == revision else { return }
                if let document {
                    let words = document.lines.reduce(0) { $0 + $1.words.count }
                    result = document.hasWordTiming ? "《\(track.title)》读取成功：\(document.lines.count) 行，\(words) 个逐字词段。"
                        : document.isSynced ? "《\(track.title)》读取成功：\(document.lines.count) 行逐行歌词，此版本没有逐字时间。"
                        : "《\(track.title)》读取成功：纯文本歌词，没有时间轴。"
                } else { result = "未找到同一录音版本的云端歌词，其他来源仍可使用。" }
            } catch { if !Task.isCancelled { result = error.localizedDescription } }
        }
    }
    func previewCurrentTrack() {
        guard canOpenLogin else { return }
        guard model.session.track?.playerID == "com.apple.Music" else {
            refresh(); result = "请先在 Mac 的“音乐”应用中选择歌曲，再打开搜索预览。"
            return
        }
        model.showMainWindow?(); model.showSearch = true
    }
    func clearLogin() {
        guard canClearLogin else { return }
        cancel()
        clearing = true; result = "正在清除本机登录会话…"
        clearTask = Task {
            await clear()
            if !Task.isCancelled { clearing = false; result = "已清除本机登录会话" }
        }
    }
    func trackChanged() {
        if resultTrackRevision != nil {
            testTask?.cancel(); testTask = nil; testing = false
            resultTrackRevision = nil; result = "歌曲已切换，请重新测试。"
        }
    }
    func cancel() {
        connectionTask?.cancel(); testTask?.cancel()
        connectionTask = nil; testTask = nil
        // Removing website data is not cancellable. Closing the card must not
        // offer a new login while the existing sign-out is still deleting it.
        checking = false; testing = false; resultTrackRevision = nil; result = ""
    }
}
