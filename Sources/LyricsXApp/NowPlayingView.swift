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
                            CoverArtwork(artwork: model.artwork, animated: !model.preferences.reduceMotion && !reduceMotion).frame(width: 64)
                            ZStack(alignment: .leading) {
                                CompactTrackMetadata(track: model.session.track).id(model.session.trackRevision)
                                    .transition(reduceMotion || model.preferences.reduceMotion ? .identity : .artworkBlur)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                                .animation(reduceMotion || model.preferences.reduceMotion ? nil : .easeInOut(duration: 0.45), value: model.session.trackRevision)
                            playbackButtons(compact: true)
                        }
                        PlaybackProgressView(model: model)
                        LyricsScrollView(model: model)
                    }.padding(.horizontal, 22).padding(.top, 8)
                } else { expandedPlayer(geometry.size) }
            }

        }
    }
    private func expandedPlayer(_ size: CGSize) -> some View {
        let columnWidth = min(330, max(220, size.width * 0.31))
        return HStack(spacing: 0) {
            PlayerColumnLayout {
                CoverArtwork(artwork: model.artwork, animated: !model.preferences.reduceMotion && !reduceMotion)
                    .shadow(color: .black.opacity(0.35), radius: 30, y: 20)
                    .scaleEffect(model.session.isPlaying ? 1 : 0.94)
                    .animation(model.preferences.reduceMotion || reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.8), value: model.session.isPlaying)
                ZStack(alignment: .topLeading) {
                    TrackMetadata(track: model.session.track).id(model.session.trackRevision)
                        .transition(model.preferences.reduceMotion || reduceMotion ? .identity : .artworkBlur)
                }
                    .animation(model.preferences.reduceMotion || reduceMotion ? nil : .easeInOut(duration: 0.45), value: model.session.trackRevision)
                VStack(spacing: 12) {
                    PlaybackProgressView(model: model)
                    playbackButtons(compact: false).frame(maxWidth: .infinity)
                }
            }.frame(width: columnWidth, height: max(0, size.height - 40))
                .padding(.horizontal, 28).padding(.vertical, 20)
            Rectangle().fill(LinearGradient(colors: [.clear, Color.primary.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom)).frame(width: 1).padding(.vertical, 30)
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
                    }).tint(Color.primary.opacity(0.8)).controlSize(.mini).disabled((model.session.track?.duration ?? 0) <= 0)
                        .accessibilityLabel("播放进度")
                        .onChange(of: model.session.trackRevision) { _, _ in scrubPosition = nil }
                    HStack {
                        Text(timeString(position))
                        Spacer()
                        Text("−" + timeString(max(0, (model.session.track?.duration ?? 0) - position)))
                    }.font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(Color.primary.opacity(0.35))
        }
    }
}

struct LyricsScrollView: View {
    let model: AppModel
    private struct ContentID: Hashable, Sendable {
        var track: UInt64
        var document: UUID?
    }
    var body: some View {
        // Browsing, pending return timers and native scroll offsets belong to
        // this song/version. Line changes keep the same view and animation.
        LyricsScrollContent(model: model)
            .id(ContentID(track: model.session.trackRevision, document: model.session.document?.id))
            // Metadata and lyrics arrive in separate observations during a
            // track change. Animate the surface once for the playback item;
            // rebuilding for the later document still resets scrolling, but
            // must not replay a second full-window blur.
            .lyricArrival(trigger: model.session.trackRevision,
                reduced: model.preferences.reduceMotion, distance: 5, visible: { model.mainWindowVisible })
    }
}

private struct LyricsScrollContent: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.colorScheme) private var colorScheme
    private var typography: LyricTypography { model.preferences.mainTypography(colorScheme: colorScheme) }
    @State private var browsing = false
    @State private var position = ScrollPosition(edge: .top)
    @State private var followState = MainLyricFollowState()
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
                    ScrollView { Text(model.preferences.text(doc.plainText ?? "")).font(typography.font(size: 26)).foregroundStyle(typography.primary).lineSpacing(16).frame(maxWidth: .infinity, alignment: .leading).padding(45).textSelection(.enabled) }
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
                .foregroundStyle(Color.primary.opacity(0.9)).lineLimit(2).multilineTextAlignment(.center)
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
            Image(systemName: symbol).font(.system(size: 42, weight: .ultraLight)).foregroundStyle(Color.primary.opacity(0.4))
            Text(title).font(.system(size: 23, weight: .medium))
            Text(detail).font(.system(size: 12)).foregroundStyle(Color.primary.opacity(0.4))
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
                if !browsing { follow(doc, animated: false, force: true) }
            }
            .modifier(MainLyricVisibility(model: model) { visible in
                returnTask?.cancel(); returnTask = nil
                if visible { browsing = false; follow(doc, animated: false, force: true) }
            })
        }
    }
    private func follow(_ doc: LyricsDocument, animated: Bool, force: Bool = false) {
        guard model.mainWindowVisible else { return }
        // A newly loaded document can arrive before the cached UI selection.
        // Resolve once against its own timeline, including the prelude (nil).
        let index = doc.index(at: model.session.position)
        guard let request = followState.request(index: index, lines: doc.lines, animated: animated && !reduced, force: force) else { return }
        let animation = request.duration.map { Animation.timingCurve(0.22, 0, 0.18, 1, duration: $0) }
        withAnimation(animation) {
            if let index { position.scrollTo(id: doc.lines[index].id, anchor: .center) }
            else { position.scrollTo(edge: .top) }
        }
    }
    private func lyricRow(_ line: LyricLine, doc: LyricsDocument, width: Double) -> some View {
        let appearance = MainLyricRowAppearance(index: line.id, current: model.mainLyricIndex, browsing: browsing, reduced: reduced)
        return Button {
            model.seek(doc.seekPosition(for: line)); browsing = false
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                LiveLyricText(session: model.session, line: line, document: doc, active: appearance.active, rendering: { model.mainWindowVisible && !model.showSearch && !model.showLibrary },
                              text: line.text.isEmpty ? "•••" : model.preferences.text(line.text), effects: model.preferences.lyricEmphasis)
                    .environment(\.lyricWordColors, typography.wordColors)
                    .font(typography.font(size: model.preferences.mainLyricFontSize * min(1, max(0.8, width / 480)), weight: .bold)).tracking(-0.4).fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(typography.primary.opacity(appearance.primaryOpacity))
                if model.preferences.showTranslation, let translation = line.translation {
                    Text(model.preferences.text(translation)).font(typography.font(size: model.preferences.mainTranslationFontSize, weight: .medium)).foregroundStyle(typography.secondary.opacity(appearance.translationOpacity)).fixedSize(horizontal: false, vertical: true)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
                .modifier(MainLyricRowMotion(appearance: appearance,
                    duration: LyricMotion.followResponse(lines: doc.lines, index: model.mainLyricIndex), reduced: reduced))
                .contentShape(.rect)
        }.buttonStyle(.plain).accessibilityLabel(line.text.isEmpty ? "间奏" : line.text)
            .accessibilityHint("跳转到 " + timeString(doc.seekPosition(for: line)))
    }
}

/// The transport owns the bottom anchor. Measure metadata first, then fit the
/// artwork into the remaining space, even while both transition views exist.
struct PlayerColumnLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions(by: .init(width: 300, height: 560))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let fullWidth = ProposedViewSize(width: bounds.width, height: nil)
        let metadata = subviews[1].sizeThatFits(fullWidth)
        let transport = subviews[2].sizeThatFits(fullWidth)
        let artwork = max(0, min(bounds.width, bounds.height - metadata.height - transport.height - 38))
        subviews[0].place(at: bounds.origin, anchor: .topLeading,
                          proposal: .init(width: artwork, height: artwork))
        subviews[1].place(at: .init(x: bounds.minX, y: bounds.minY + artwork + 20),
                          anchor: .topLeading, proposal: fullWidth)
        subviews[2].place(at: .init(x: bounds.minX, y: bounds.maxY),
                          anchor: .bottomLeading, proposal: fullWidth)
    }
}

struct TrackMetadata: View {
    let track: Track?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(track?.title ?? "还没有音乐在播放")
                    .font(.system(size: 24, weight: .bold)).lineLimit(2).textSelection(.enabled)
                Text(track?.artist.isEmpty == false ? track!.artist : "打开播放器并播放歌曲")
                    .font(.system(size: 15)).foregroundStyle(Color.primary.opacity(0.55)).lineLimit(2)
            }.frame(height: 106, alignment: .topLeading)
            HStack(spacing: 5) {
                Image(systemName: "music.note")
                Text(track?.album.isEmpty == false ? track!.album : " ")
            }.font(.system(size: 10, weight: .medium)).foregroundStyle(Color.primary.opacity(0.32)).lineLimit(1)
                .frame(height: 14, alignment: .leading).padding(.top, 14)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CompactTrackMetadata: View {
    let track: Track?
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(track?.title ?? "未在播放").font(.headline).lineLimit(1)
            Text(track?.artist ?? "打开播放器并播放歌曲").font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}

/// Observing visibility in this modifier avoids rebuilding every lyric row when
/// AppKit closes/minimizes the window. Only the active renderer needs to stop.
private struct MainLyricVisibility: ViewModifier {
    let model: AppModel
    let changed: (Bool) -> Void
    func body(content: Content) -> some View {
        content.onChange(of: model.mainWindowVisible, initial: true) { _, value in changed(value) }
    }
}
