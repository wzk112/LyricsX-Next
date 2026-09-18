import SwiftUI
import LyricsXCore

struct NowPlayingView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 780 || geometry.size.height < 430
            Group {
                if compact {
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            CoverArtwork(artwork: model.artwork).frame(width: 64)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(model.session.track?.title ?? "未在播放").font(.headline).lineLimit(1)
                                Text(model.session.track?.artist ?? "打开播放器并播放歌曲").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            playbackButtons(compact: true)
                        }
                        PlaybackProgressView(model: model)
                        LyricsScrollView(model: model)
                    }.padding(.horizontal, 22).padding(.top, 8)
                } else { expandedPlayer(geometry.size) }
            }
            .lyricArrival(trigger: model.session.track?.id, reduced: reduceMotion || model.preferences.reduceMotion,
                          distance: 8, visible: { model.mainWindowVisible })
        }
    }
    private func expandedPlayer(_ size: CGSize) -> some View {
        let columnWidth = min(330, max(220, size.width * 0.31))
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                CoverArtwork(artwork: model.artwork)
                    .frame(width: min(columnWidth, max(150, size.height - 230)))
                    .shadow(color: .black.opacity(0.35), radius: 30, y: 20)
                    .scaleEffect(model.session.isPlaying ? 1 : 0.94)
                    .animation(model.preferences.reduceMotion || reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.8), value: model.session.isPlaying)
                    .padding(.bottom, 20)
                Text(model.session.track?.title ?? "还没有音乐在播放")
                    .font(.system(size: 24, weight: .bold)).lineLimit(2).textSelection(.enabled)
                Text(model.session.track?.artist.isEmpty == false ? model.session.track!.artist : "打开播放器并播放歌曲")
                    .font(.system(size: 15)).foregroundStyle(.white.opacity(0.55)).padding(.top, 6).lineLimit(2)
                HStack(spacing: 5) {
                    Image(systemName: "music.note")
                    if let album = model.session.track?.album, !album.isEmpty { Text(album) }
                }.font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.32)).lineLimit(1).padding(.top, 14)
                Spacer(minLength: 18)
                PlaybackProgressView(model: model)
                playbackButtons(compact: false).frame(maxWidth: .infinity).padding(.top, 12)
            }.frame(width: columnWidth).padding(.horizontal, 28).padding(.vertical, 20)
            Rectangle().fill(LinearGradient(colors: [.clear, .white.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom)).frame(width: 1).padding(.vertical, 30)
            LyricsScrollView(model: model)
        }
    }
    private func playbackButtons(compact: Bool) -> some View {
                HStack(spacing: compact ? 12 : 30) {
                    Button { model.skip(next: false) } label: { Image(systemName: "backward.fill").font(.system(size: 23)) }.accessibilityLabel("上一首")
                    Button { model.playPause() } label: { Image(systemName: model.session.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 27)).contentTransition(.symbolEffect(.replace)).frame(width: 40, height: 42) }.accessibilityLabel(model.session.isPlaying ? "暂停" : "播放")
                    Button { model.skip(next: true) } label: { Image(systemName: "forward.fill").font(.system(size: 23)) }.accessibilityLabel("下一首")
                }.buttonStyle(.plain).disabled(model.session.track == nil)
    }
}

private struct PlaybackProgressView: View {
    let model: AppModel
    @State private var scrubPosition: Double?
    private var position: Double { scrubPosition ?? model.playbackControlPosition }
    var body: some View {
        VStack(spacing: 4) {
                    Slider(value: Binding(get: { position }, set: { scrubPosition = $0 }), in: 0...max(1, model.session.track?.duration ?? 1), onEditingChanged: { editing in
                        if !editing, let position = scrubPosition { model.seek(position); scrubPosition = nil }
                    }).tint(.white.opacity(0.8)).controlSize(.mini).disabled((model.session.track?.duration ?? 0) <= 0)
                        .accessibilityLabel("播放进度")
                        .onChange(of: model.session.track?.id) { _, _ in scrubPosition = nil }
                    HStack {
                        Text(timeString(position))
                        Spacer()
                        Text("−" + timeString(max(0, (model.session.track?.duration ?? 0) - position)))
                    }.font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.35))
        }
    }
}

struct LyricsScrollView: View {
    let model: AppModel
    private struct ContentID: Hashable {
        var track: String?
        var document: UUID?
    }
    var body: some View {
        // Browsing, pending return timers and native scroll offsets belong to
        // this song/version. Line changes keep the same view and animation.
        LyricsScrollContent(model: model)
            .id(ContentID(track: model.session.track?.id, document: model.session.document?.id))
    }
}

private struct LyricsScrollContent: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var browsing = false
    @State private var position = ScrollPosition(edge: .top)
    @State private var returnTask: Task<Void, Never>?
    @Environment(\.openWindow) private var openWindow
    private var reduced: Bool { systemReduceMotion || model.preferences.reduceMotion }
    var body: some View {
        ZStack(alignment: .bottom) {
            if let doc = model.session.document {
                if model.session.documentIsPlaceholder {
                    trackTitlePlaceholder
                } else if doc.isSynced {
                    syncedLyrics(doc)
                } else {
                    ScrollView { Text(doc.plainText ?? "").font(model.preferences.typography.font(size: 26)).foregroundStyle(model.preferences.typography.primary).lineSpacing(16).frame(maxWidth: .infinity, alignment: .leading).padding(45).textSelection(.enabled) }
                        .scrollPosition($position)
                        .safeAreaInset(edge: .top) { Text("此歌词暂无时间轴").font(.caption).foregroundStyle(.secondary).padding(12) }
                }
            } else if model.session.track == nil {
                VStack(spacing: 22) {
                    emptyState(symbol: "waveform", title: "未在播放", detail: "打开播放器并播放歌曲。")
                        .frame(height: 175)
                    HStack(spacing: 12) {
                        Button("打开 Apple Music") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Music.app")) }.buttonStyle(.glass)
                        Button("预览动效") { openWindow(id: "preview") }.buttonStyle(.glass)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                trackTitlePlaceholder
            }
            if browsing {
                Button { browsing = false } label: { Label("回到当前歌词", systemImage: "location.fill") }
                    .buttonStyle(.glass).padding(.bottom, 20).transition(.opacity)
            }
        }.onDisappear { returnTask?.cancel(); returnTask = nil }
    }
    private var trackTitlePlaceholder: some View {
        VStack(spacing: 18) {
            Text(model.session.track?.title ?? "LyricsX Next")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9)).lineLimit(2).multilineTextAlignment(.center)
                .accessibilityLabel("当前歌曲：\(model.session.track?.title ?? "LyricsX Next")")
            if model.session.isSearching {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在加载歌词…").font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }
        }.padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyState(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: symbol).font(.system(size: 42, weight: .ultraLight)).foregroundStyle(.white.opacity(0.4))
            Text(title).font(.system(size: 23, weight: .medium))
            Text(detail).font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func syncedLyrics(_ doc: LyricsDocument) -> some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    ForEach(doc.lines) { line in
                        lyricRow(line, doc: doc, width: geometry.size.width).id(line.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, geometry.size.width < 440 ? 22 : 36)
                .padding(.vertical, geometry.size.height * 0.38)
            }
            .scrollPosition($position)
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, phase in
                if phase == .interacting {
                    browsing = true; returnTask?.cancel()
                } else if phase == .idle, browsing {
                    returnTask = Task { do { try await Task.sleep(for: .seconds(5)) } catch { return }; browsing = false }
                }
            }
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.13), .init(color: .black, location: 0.83), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
            .onChange(of: model.mainLyricIndex) { _, _ in
                guard !browsing else { return }
                follow(doc, animated: true)
            }
            .onChange(of: browsing) { _, browsing in
                if !browsing { follow(doc, animated: true) }
            }
            .onChange(of: model.mainWindowVisible, initial: true) { _, visible in
                returnTask?.cancel(); returnTask = nil
                browsing = false
                if visible { follow(doc, animated: false) }
            }
        }
    }
    private func follow(_ doc: LyricsDocument, animated: Bool) {
        guard model.mainWindowVisible else { return }
        // A newly loaded document can arrive before the cached UI selection.
        // Resolve once against its own timeline, including the prelude (nil).
        let index = doc.index(at: model.session.position)
        withAnimation(animated && !reduced && index != nil ? LyricMotion.following(lines: doc.lines, index: index) : nil) {
            if let index { position.scrollTo(id: doc.lines[index].id, anchor: .center) }
            else { position.scrollTo(edge: .top) }
        }
    }
    private func lyricRow(_ line: LyricLine, doc: LyricsDocument, width: Double) -> some View {
        let active = line.id == model.mainLyricIndex
        let distance = abs(line.id - (model.mainLyricIndex ?? 0))
        return Button {
            model.seek(doc.seekPosition(for: line)); browsing = false
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                LiveLyricText(session: model.session, line: line, document: doc, active: active, rendering: { model.mainWindowVisible },
                              text: line.text.isEmpty ? "•••" : model.preferences.text(line.text), effects: model.preferences.lyricEmphasis)
                    .environment(\.lyricWordColors, model.preferences.typography.wordColors)
                    .font(model.preferences.typography.font(size: model.preferences.mainLyricFontSize * min(1, max(0.8, width / 480)), weight: .bold)).tracking(-0.4).fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(model.preferences.typography.primary.opacity(active ? 1 : browsing ? 0.55 : distance <= 1 ? 0.25 : 0.15))
                if model.preferences.showTranslation, let translation = line.translation {
                    Text(model.preferences.text(translation)).font(model.preferences.typography.font(size: model.preferences.mainTranslationFontSize, weight: .medium)).foregroundStyle(model.preferences.typography.secondary.opacity(active ? 0.65 : 0.25)).fixedSize(horizontal: false, vertical: true)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
                .scaleEffect(active ? 1 : 0.96, anchor: .leading)
                .blur(radius: reduced || browsing || active ? 0 : min(2.05, Double(distance) * 0.7))
                .animation(reduced ? nil : LyricMotion.following(lines: doc.lines, index: model.mainLyricIndex), value: distance)
                .contentShape(.rect)
        }.buttonStyle(.plain).accessibilityLabel(line.text.isEmpty ? "间奏" : line.text)
            .accessibilityHint("跳转到 " + timeString(doc.seekPosition(for: line)))
    }
}
