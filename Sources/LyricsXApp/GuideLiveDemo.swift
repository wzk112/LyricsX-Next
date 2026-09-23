import SwiftUI
import LyricsXCore

/// A private playback session drives the production views. It never starts a
/// player bridge, searches, saves lyrics, or changes the user's preferences.
@Observable @MainActor final class GuideDemoSession {
    private struct Repository: LyricsRepository {
        func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
        func save(_ document: LyricsDocument, for track: Track) async throws {}
    }
    let suite = "LyricsXGuideDemo-" + UUID().uuidString
    let model: AppModel
    let viewport = OverlayViewport(width: 520)
    private(set) var alternate = false
    private(set) var floating = false
    private var panel: OverlayController?
    private var stopped = false
    @ObservationIgnored private var startedAt = ProcessInfo.processInfo.systemUptime
    private static let artwork = [0.0, 110.0].map { hue in
        ImageRenderer(content: AnyView(CoverArtwork(artwork: nil, demo: true)
            .frame(width: 256, height: 256).hueRotation(.degrees(hue)))).nsImage
    }
    static let document = LyricsDocument(title: "材质与动效演示", source: "原创示例", duration: 12, lines: [
        .init(id: 0, time: 0, text: "让光随音乐流动", translation: "材质、逐字与辉光实时渲染", words: [
            .init(text: "让", start: 0, end: 0.6), .init(text: "光", start: 0.6, end: 3.2),
            .init(text: "随音乐", start: 3.2, end: 4.2), .init(text: "流动", start: 4.2, end: 5.8)]),
        .init(id: 1, time: 6, text: "每一句，清楚呈现", translation: "使用与正式悬浮窗相同的渲染", words: [
            .init(text: "每一句，", start: 6, end: 7.4), .init(text: "清楚", start: 7.4, end: 8.8),
            .init(text: "呈现", start: 8.8, end: 11.8)])
    ])
    init(reduced: Bool) {
        let prefs = Preferences(defaults: UserDefaults(suiteName: suite)!)
        prefs.overlayWidth = 520; prefs.overlayVisible = false
        prefs.overlayLocked = true; prefs.hideOverlayOnHover = false
        prefs.hideWhenPaused = false; prefs.reduceMotion = reduced
        prefs.overlaySecondaryMode = .translation
        prefs.lyricHDRBrightness = 3; prefs.overlayTheme = .dark
        model = AppModel(repository: Repository(), preferences: prefs)
        selectTrack()
    }
    var height: Double {
        OverlayTextMeasure.height(document: Self.document, index: model.session.currentLineIndex ?? 0,
                                 preferences: model.preferences, maximumWidth: 520)
    }
    func selectTrack(now: Double = ProcessInfo.processInfo.systemUptime) {
        startedAt = now
        let track = Track(playerID: "guide-demo", playerName: "演示", title: alternate
            ? "更长的歌名，也保持播放控件的位置" : "材质与动效演示", artist: alternate ? "LyricsX Next · 独立演示" : "LyricsX Next",
            album: alternate ? "不同长度的专辑信息" : "原创示例", duration: 12)
        model.session.accept(.init(track: track, position: 0, isPlaying: !model.preferences.reduceMotion, sampledAt: now), now: now, shouldSearch: false)
        model.session.use(Self.document, persist: false)
        model.artwork = Self.artwork[alternate ? 1 : 0]
        model.updateMainLyricSelection()
    }
    func nextTrack() { alternate.toggle(); selectTrack() }
    func tick(now: Double = ProcessInfo.processInfo.systemUptime) {
        guard !stopped, let track = model.session.track else { return }
        // Production playback deliberately stops extrapolating a stale player
        // after three seconds. Supply fresh samples from our own monotonic
        // demo clock; merely calling session.tick would freeze the first line.
        let playing = !model.preferences.reduceMotion
        let position = playing ? max(0, now - startedAt).truncatingRemainder(dividingBy: 12) : 0
        model.session.accept(.init(track: track, position: position, isPlaying: playing, sampledAt: now), now: now)
        model.updateMainLyricSelection()
    }
    func toggleFloating() {
        if floating {
            panel?.stop(); panel = nil; floating = false
            model.preferences.overlayVisible = false
        } else {
            model.preferences.overlayVisible = true
            panel = OverlayController(model: model, frameAutosaveName: nil)
            floating = true
        }
    }
    func stop() {
        guard !stopped else { return }
        stopped = true
        panel?.stop(); panel = nil; floating = false
        model.stop()
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }
}

struct GuideLiveDemo: View {
    let kind: String
    let reduced: Bool
    var viewportHeight: CGFloat = 600
    @State private var demo: GuideDemoSession?
    @State private var visible = false
    @State private var inViewport = true
    @Environment(\.accessibilityReduceMotion) private var systemReduced

    init(kind: String, reduced: Bool, viewportHeight: CGFloat = 600, session: GuideDemoSession? = nil) {
        self.kind = kind; self.reduced = reduced; self.viewportHeight = viewportHeight
        _demo = State(initialValue: session)
    }

    var body: some View {
        VStack(spacing: 10) {
            if let demo {
                controls(demo)
                GeometryReader { geometry in
                    ZStack {
                        LinearGradient(colors: [.init(red: 0.14, green: 0.43, blue: 0.57),
                                                .init(red: 0.74, green: 0.40, blue: 0.30)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        if kind == "livePlayer" {
                            MainView(model: demo.model)
                                .environment(\.colorScheme, .dark)
                                .hdrDisplayScope(requested: demo.model.preferences.lyricEmphasis.usesHDR,
                                                 visible: visible && inViewport)
                                .frame(width: 1000, height: 660)
                                .scaleEffect(min(geometry.size.width / 1000, geometry.size.height / 660))
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .allowsHitTesting(false).accessibilityHidden(true)
                        } else {
                            HStack(spacing: 28) {
                                ForEach(0..<8) { _ in Rectangle().fill(.white.opacity(0.24)).frame(width: 18) }
                            }.rotationEffect(.degrees(25))
                            OverlayThemedRoot(preferences: demo.model.preferences,
                                content: OverlayView(model: demo.model, viewport: demo.viewport))
                                .frame(width: 520, height: demo.height)
                                .background {
                                    OverlayMaterialPreview(appearance: demo.model.preferences.overlayAppearance,
                                        transparency: demo.model.preferences.overlayMaterialTransparency,
                                        frostAmount: demo.model.preferences.overlayFrostAmount,
                                        colorScheme: demo.model.preferences.overlayEffectiveTheme.resolvedScheme)
                                        .padding(6)
                                }
                                .scaleEffect(min(1, (geometry.size.width - 16) / 520))
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }.clipShape(.rect(cornerRadius: 14))
                }
                HStack {
                    Text("实时演示 · 独立于正在播放的音乐").font(.caption2).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Button("切换演示歌曲") { demo.nextTrack() }
                    Button(demo.floating ? "关闭演示悬浮窗" : "打开演示悬浮窗") { demo.toggleFloating() }
                }.controlSize(.small)
            }
        }.padding(12).background(.quaternary.opacity(0.25))
            .background(WindowVisibilityReader { visible = $0 })
            // The guide uses a regular ScrollView, not a scroll-target list.
            // Scroll-visibility callbacks can stay false for this nested card.
            .onGeometryChange(for: Bool.self) { geometry in
                let rect = geometry.frame(in: .named("guideContent"))
                return rect.maxY > 0 && rect.minY < viewportHeight
            } action: { inViewport = $0 }
            .onAppear { if demo == nil { demo = GuideDemoSession(reduced: reduced || systemReduced) } }
            .onDisappear { demo?.stop(); demo = nil }
            .task(id: (visible && inViewport && demo != nil) || demo?.floating == true) {
                demo?.viewport.rendering = visible && inViewport
                guard (visible && inViewport || demo?.floating == true), !reduced, !systemReduced else { return }
                while !Task.isCancelled {
                    demo?.tick()
                    do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
                }
            }
    }
    @ViewBuilder private func controls(_ demo: GuideDemoSession) -> some View {
        @Bindable var prefs = demo.model.preferences
        if kind == "livePlayer" {
            HStack {
                Label("主窗口 · 实际切歌与排版", systemImage: "play.rectangle")
                Spacer()
                Text("点击下方切歌查看").foregroundStyle(.secondary)
            }.font(.caption)
        } else {
        HStack(spacing: 10) {
            Picker("演示材质", selection: $prefs.overlayAppearance) {
                ForEach(OverlayAppearance.allCases) { Text($0.title).tag($0) }
            }.labelsHidden().pickerStyle(.segmented).frame(maxWidth: 230)
            if prefs.overlayAppearance == .frosted {
                Picker("演示外观", selection: $prefs.overlayTheme) {
                    Text("浅色").tag(InterfaceTheme.light)
                    Text("深色").tag(InterfaceTheme.dark)
                }.labelsHidden().pickerStyle(.segmented).frame(maxWidth: 130)
            } else {
                Text("透明度").font(.caption)
                Slider(value: $prefs.overlayGlassTintTransparency, in: 0...1)
                    .accessibilityLabel("演示透明度")
                Text(prefs.overlayGlassTintTransparency, format: .percent.precision(.fractionLength(0)))
                    .font(.caption).monospacedDigit().frame(width: 36)
            }
        }.controlSize(.small)
        }
    }
}
