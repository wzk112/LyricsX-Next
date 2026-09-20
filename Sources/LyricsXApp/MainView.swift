import SwiftUI
import LyricsXCore

struct MainView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            MainAmbientBackground(model: model)
            VStack(spacing: 0) {
                header
                NowPlayingView(model: model)
                footer
            }
        }.foregroundStyle(.white).preferredColorScheme(.dark)
            .frame(minWidth: 520, minHeight: 420)
            .background(WindowVisibilityReader { model.mainWindowVisible = $0 })
            .onAppear {
                model.showMainWindow = { [openWindow] in openWindow(id: "main"); NSApp.activate() }
            }
            .sheet(isPresented: $model.showSearch) { SearchView(model: model) }
            .sheet(isPresented: $model.showLibrary) { LibraryView(model: model) }
            .alert("LyricsX Next", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) { Button("好") { model.message = nil } } message: { Text(model.message ?? "") }
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first, ["lrc", "lrcx", "txt"].contains(url.pathExtension.lowercased()) else { return false }
                model.importLyrics(url); return true
            }
    }
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "quote.bubble.fill").font(.system(size: 19)).foregroundStyle(.white.opacity(0.85))
            Text("LyricsX Next").font(.system(size: 16, weight: .semibold)).tracking(-0.3)
            Spacer()
            HStack(spacing: 9) {
                SymbolButton(symbol: "magnifyingglass", help: "搜索歌词 ⌘F") { model.showSearch = true }
                SymbolButton(symbol: "books.vertical", help: "歌词资料库") { model.showLibrary = true }
                SymbolButton(symbol: "rectangle.on.rectangle", help: "显示或隐藏悬浮歌词", active: model.preferences.overlayVisible) { model.setOverlayVisible(!model.preferences.overlayVisible) }
                SymbolButton(symbol: "slider.horizontal.3", help: "设置 ⌘,") { openSettings(); NSApp.activate() }
            }
        }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 10)
    }
    private var footer: some View {
        HStack(spacing: 7) {
            MainPlayingIndicator(model: model).foregroundStyle(Color(red: 0.97, green: 0.50, blue: 0.57))
            Text(model.session.track?.playerName ?? "等待播放").font(.system(size: 10, weight: .medium))
            if model.session.track != nil {
                Text("·").foregroundStyle(.white.opacity(0.2))
                Text(model.session.isPlaying ? "实时同步" : "已暂停").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            if model.session.isSearching {
                ProgressView().controlSize(.mini)
                Text(model.session.document == nil ? "正在加载歌词…" : "正在加载更多版本…")
                    .font(.system(size: 10)).lineLimit(1).foregroundStyle(.white.opacity(0.6))
            } else if let error = model.playerError ?? model.session.persistenceError {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange).help(error)
                Text(error).font(.system(size: 10)).lineLimit(1).foregroundStyle(.white.opacity(0.6)).frame(maxWidth: 290)
            } else if let doc = model.session.document {
                Text(doc.source).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                if doc.hasWordTiming { Text("逐字").font(.system(size: 9, weight: .medium)).padding(.horizontal, 6).padding(.vertical, 3).background(.white.opacity(0.07), in: .capsule) }
            }
            if let doc = model.session.document, doc.isSynced {
                Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 14).padding(.horizontal, 12)
                Button { model.session.adjustOffset(by: -100) } label: { Image(systemName: "minus").frame(width: 32, height: 32).contentShape(.rect) }
                    .help("歌词延后 0.1 秒").accessibilityLabel("歌词延后 0.1 秒")
                Button { model.session.resetOffset() } label: { Text(String(format: "%+.1f s", Double(doc.offsetMilliseconds) / 1000)).monospacedDigit().frame(width: 50, height: 32).contentShape(.rect) }.help("重置偏移；正值让歌词提前")
                Button { model.session.adjustOffset(by: 100) } label: { Image(systemName: "plus").frame(width: 32, height: 32).contentShape(.rect) }
                    .help("歌词提前 0.1 秒").accessibilityLabel("歌词提前 0.1 秒")
            }
        }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(.white.opacity(0.55))
            .padding(.horizontal, 20).padding(.vertical, 8)
            .background(.black.opacity(0.1))
    }
}

private struct MainPlayingIndicator: View {
    let model: AppModel
    var body: some View { PlayingIndicator(playing: model.mainWindowVisible && model.session.isPlaying) }
}

/// Window visibility affects background activity, not the entire main hierarchy.
private struct MainAmbientBackground: View {
    let model: AppModel
    var body: some View {
        AmbientBackground(artwork: model.artwork, reduced: model.preferences.reduceMotion || !model.mainWindowVisible)
    }
}
