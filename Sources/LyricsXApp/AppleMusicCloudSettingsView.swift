import AppKit
import SwiftUI
import WebKit
import LyricsXServices

struct AppleMusicCloudSettingsView: View {
    @Bindable var model: AppModel
    private let cloud = AppleMusicCloudSession.shared
    @State private var controls: AppleMusicCloudControls
    @State private var showLogin = false

    init(model: AppModel, controls: AppleMusicCloudControls? = nil) {
        self.model = model
        _controls = State(initialValue: controls ?? AppleMusicCloudControls(model: model))
    }

    var body: some View {
        SettingsCard(title: "Apple Music 云端歌词") {
            SettingToggle(title: "启用云端歌词", detail: "读取当前 Apple Music 歌曲的在线歌词，支持逐字、逐行和纯文本。默认关闭。",
                value: Binding(get: { model.preferences.appleMusicCloudEnabled },
                               set: { model.preferences.setAppleMusicCloudEnabled($0) }))
            VStack(alignment: .leading, spacing: 12) {
                Text("需要登录 Apple Music 并有有效订阅。歌词格式取决于歌曲和账号地区；读取失败时会继续使用其他来源。")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button("登录 Apple Music…") { showLogin = true }
                        .disabled(!controls.canOpenLogin)
                    Button(controls.checking ? "检查中…" : "检查登录") { controls.checkLogin() }
                        .disabled(!controls.canCheckLogin)
                    Spacer(minLength: 8)
                    Button(controls.clearing ? "正在清除…" : "清除登录") { controls.clearLogin() }
                        .disabled(!controls.canClearLogin)
                }
                Text(controls.result.isEmpty ? cloud.status : controls.result).font(.caption).foregroundStyle(.secondary)
                    .textSelection(.enabled).accessibilityLabel("Apple Music 云端状态：" + (controls.result.isEmpty ? cloud.status : controls.result))
                if !controls.result.isEmpty && controls.result != cloud.status {
                    Text("连接状态：" + cloud.status).font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                Text(controls.targetDescription).font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button(controls.testing ? "正在测试…" : "测试当前歌曲") { controls.testCurrentTrack() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!controls.canTestCurrentTrack)
                    Button("打开搜索并预览歌词") { controls.previewCurrentTrack() }
                        .disabled(!controls.canOpenLogin)
                }
                Text("网页登录只用于取得歌词，不需要播放网页歌曲。点击完成后会检查登录并刷新 Mac 音乐的曲目状态。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("登录信息只保留在本机网页会话中。测试不会替换当前歌词；云端与内嵌歌词共用来源列表中的 Apple Music 开关和优先级。已有缓存仍会优先复用。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(14)
        }
        .sheet(isPresented: $showLogin, onDismiss: { controls.loginDidClose() }) { AppleMusicCloudLoginView(cloud: cloud) }
        .onChange(of: model.preferences.appleMusicCloudEnabled) { _, enabled in
            if !enabled { showLogin = false; controls.cancel(); cloud.suspend() }
        }
        .onChange(of: model.session.trackRevision) { _, _ in
            controls.trackChanged()
        }
        .onDisappear { controls.cancel() }
    }
}

struct AppleMusicCloudLoginView: View {
    let cloud: AppleMusicCloudSession
    @Environment(\.dismiss) private var dismiss
    @State private var checking = false
    @State private var checkTask: Task<Void, Never>?
    @State private var message = "请在 Apple 官方页面登录。完成后点击检查登录。"
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("登录 Apple Music").font(.headline)
                Spacer()
                Button(checking ? "检查中…" : "检查登录") {
                    checking = true
                    checkTask = Task {
                        defer { checking = false }
                        do { try await cloud.checkConnection(); if !Task.isCancelled { message = cloud.status } }
                        catch { if !Task.isCancelled { message = error.localizedDescription } }
                    }
                }.disabled(checking)
                Button("完成") { dismiss() }
            }.padding(16)
            Text(message).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.bottom, 12)
            Divider()
            AppleMusicLoginWebView(cloud: cloud)
        }.frame(minWidth: 820, minHeight: 620)
        .onDisappear { checkTask?.cancel() }
    }
}

private struct AppleMusicLoginWebView: NSViewRepresentable {
    let cloud: AppleMusicCloudSession
    func makeCoordinator() -> AppleMusicCloudSession { cloud }
    func makeNSView(context: Context) -> WKWebView { cloud.loginPage() }
    func updateNSView(_ view: WKWebView, context: Context) {}
    static func dismantleNSView(_ view: WKWebView, coordinator: AppleMusicCloudSession) { coordinator.dismissLoginPage() }
}
