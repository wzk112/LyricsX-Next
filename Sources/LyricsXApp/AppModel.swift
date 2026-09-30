import AppKit
import SwiftUI
import UniformTypeIdentifiers
import LyricsXCore
import LyricsXServices

@Observable @MainActor
final class AppModel {
    var preferences: Preferences
    let session: LyricsSession
    let store: LyricsStore
    let displays = HDRDisplayMonitor()
    let bridge = PlayerBridge()
    let dockVisibility: DockVisibilityController
    let flexbar: FlexbarController
    var playerError: String?
    var message: String?
    var showSearch = false
    var showLibrary = false
    var mainWindowVisible = false { didSet { updateMainLyricSelection() } }
    private(set) var mainLyricIndex: Int?
    let mainLyricPresentation = MainLyricPresentation()
    private(set) var playbackControlPosition = 0.0
    var artwork: NSImage? {
        didSet {
            if artwork !== oldValue && !publishingArtwork { updateArtworkTheme() }
        }
    }
    @ObservationIgnored private var publishingArtwork = false
    private(set) var artworkLoading = false
    @ObservationIgnored private var artworkHandover = ArtworkHandover()
    @ObservationIgnored private var artworkHandoverTask: Task<Void, Never>?
    @ObservationIgnored private var artworkGeneration: UInt64 = 0
    @ObservationIgnored private var artworkThemeTask: Task<Void, Never>?
    var library: [LyricsCache.Entry] = []
    var libraryLoading = false
    @ObservationIgnored private var libraryGeneration = 0
    @ObservationIgnored private var libraryTask: Task<Void, Never>?
    @ObservationIgnored var showMainWindow: (() -> Void)?
    @ObservationIgnored var showSettingsWindow: (() -> Void)?
    @ObservationIgnored var showPreviewWindow: (() -> Void)?
    @ObservationIgnored var showFeatureGuide: ((Bool) -> Void)?
    @ObservationIgnored var overlay: OverlayController?
    @ObservationIgnored private var ticker: PlaybackTicker?
    @ObservationIgnored private var artworkTask: Task<Void, Never>?
    @ObservationIgnored private let artworkLoader: @Sendable (Data?, URL?) async -> CGImage?
    @ObservationIgnored private var artworkIdentity: String?
    @ObservationIgnored private var artworkBytes: Data?
    @ObservationIgnored private var wakeObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var presentationStopped = false

    init(repository: (any LyricsRepository)? = nil, preferences: Preferences = Preferences(), flexbarSocketURL: URL = FlexbarServer.defaultURL,
         artworkLoader: @escaping @Sendable (Data?, URL?) async -> CGImage? = { await ArtworkDecoder.shared.load(data: $0, url: $1) }) {
        self.preferences = preferences
        self.artworkLoader = artworkLoader
        flexbar = FlexbarController(socketURL: flexbarSocketURL)
        dockVisibility = DockVisibilityController(shouldShow: { preferences.showDockIcon })
        let configurationReader = preferences.sourceConfigurationReader
        store = LyricsStore(cache: LyricsCache(directory: preferences.directory), configuration: { configurationReader.read() })
        session = LyricsSession(repository: repository ?? store)
        bridge.onSnapshot = { [weak self] snapshot in
            guard let self else { return }
            self.session.accept(snapshot, shouldSearch: !self.lyricsBlocked(for: snapshot.track))
            self.updateMainLyricSelection()
            self.mainLyricPresentation.update(model: self)
            self.ticker?.scheduleEarlier(self.lyricClockInterval())
            self.updateArtwork(self.session.track)
            self.flexbar.synchronizePlayback()
        }
        bridge.onError = { [weak self] error in
            self?.playerError = error
        }
        bridge.onCommandResult = { [weak self] command, succeeded in
            guard case .seek = command, !succeeded else { return }
            self?.session.rejectPendingSeek()
            self?.bridge.refresh()
        }
        observeMainLyricPresentation()
    }
    private static let gapCharacters = CharacterSet(charactersIn: ".·•…⋯・。 \t\n")
    var overlayPresentationMode: OverlayPresentationMode {
        guard let document = session.document else { return session.isSearching && !lyricsBlocked ? .waiting : .song }
        guard document.isSynced, !document.isInstrumental, !session.documentIsPlaceholder else { return .song }
        guard let index = session.currentLineIndex, document.lines.indices.contains(index) else { return .waiting }
        let text = document.lines[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty || text.unicodeScalars.allSatisfy(Self.gapCharacters.contains) ? .waiting : .lyrics
    }
    var overlayUsesCompactPresentation: Bool { overlayPresentationMode != .lyrics }
    var menubarText: String {
        let fallback = session.track?.title ?? "LyricsX Next"
        var text = fallback
        if overlayPresentationMode == .lyrics, let doc = session.document,
           let index = session.currentLineIndex, doc.lines.indices.contains(index) {
            text = preferences.text(doc.lines[index].text)
        }
        let singleLine = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return singleLine.isEmpty ? "LyricsX Next" : String(singleLine.prefix(36)) + (singleLine.count > 36 ? "…" : "")
    }
    func updateMainLyricSelection() {
        guard mainWindowVisible else { return }
        if mainLyricIndex != session.currentLineIndex { mainLyricIndex = session.currentLineIndex }
        if abs(session.position - playbackControlPosition) >= 0.2 || !session.isPlaying {
            playbackControlPosition = session.position
        }
    }

    func start() {
        guard ticker == nil else { return }
        let wasStopped = presentationStopped
        presentationStopped = false
        if wasStopped { observeMainLyricPresentation() }
        displays.start()
        dockVisibility.start()
        observeDockVisibility()
        flexbar.start(model: self)
        overlay = OverlayController(model: self)
        bridge.mode = preferences.playerMode
        bridge.start()
        wakeObservers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in guard let self, !self.presentationStopped else { return }; self.bridge.restart(); self.flexbar.wake(); self.overlay?.resumeWaveform(); self.overlay?.restoreOnScreen() }
        })
        wakeObservers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.presentationStopped else { return }
                self.overlay?.suspendWaveform(); self.flexbar.sleep(); self.bridge.stop(); self.session.freeze()
            }
        })
        startLyricClock()
    }
    var isLyricClockRunning: Bool { ticker?.running == true }
    var lyricClockNextFireAt: Double? { ticker?.nextFireAt }
    func lyricClockInterval() -> Double {
        guard session.isPlaying else { return 500 }
        let preciseSurface = mainWindowVisible || overlay?.needsPreciseLyricTicks == true
        // The menu bar only changes at cue boundaries. Its label has no
        // frame-by-frame animation, so wake near the next line instead.
        let ui = preferences.showMenubarLyrics && !preciseSurface
            ? FlexbarCueCadence.milliseconds(document: session.document, position: session.position)
            : LyricTickCadence.milliseconds(playing: session.isPlaying, visible: preciseSurface,
                                            document: session.document, position: session.position)
        return flexbar.hasConsumers
            ? min(ui, FlexbarCueCadence.milliseconds(document: session.document, position: session.position))
            : ui
    }
    func startLyricClock() {
        guard ticker == nil else { return }
        ticker = PlaybackTicker { [weak self] in
            guard let self else { return nil }
            guard self.session.isPlaying else { return nil }
            self.session.tick()
            self.updateMainLyricSelection()
            return self.lyricClockInterval()
        }
        observeTickerActivity()
    }
    private func observeTickerActivity() {
        guard !presentationStopped else { return }
        var playing = false
        withObservationTracking {
            playing = session.isPlaying
            _ = session.documentRevision
            _ = mainWindowVisible
            _ = preferences.overlayVisible
            _ = preferences.showMenubarLyrics
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeTickerActivity() }
        }
        session.tick()
        updateMainLyricSelection()
        if playing {
            ticker?.start()
            ticker?.scheduleEarlier(lyricClockInterval())
        } else { ticker?.stop() }
    }
    private func observeMainLyricPresentation() {
        guard !presentationStopped else { return }
        withObservationTracking {
            _ = session.trackRevision
            _ = session.documentRevision
            _ = session.isSearching
            _ = mainLyricIndex
            _ = mainWindowVisible
            _ = preferences.reduceMotion
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeMainLyricPresentation() }
        }
        mainLyricPresentation.update(model: self)
    }
    func stop() {
        ticker?.stop(); ticker = nil; artworkTask?.cancel(); artworkTask = nil; presentationStopped = true
        artworkThemeTask?.cancel(); artworkThemeTask = nil
        artworkHandoverTask?.cancel(); artworkHandoverTask = nil
        artworkLoading = false; artworkHandover.finish()
        mainLyricPresentation.stop()
        displays.stop()
        flexbar.stop()
        dockVisibility.stop()
        overlay?.stop(); overlay = nil; bridge.stop(); session.stop()
        unloadLibrary()
        for token in wakeObservers { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        wakeObservers.removeAll()
    }
    func playPause() {
        bridge.send(.toggle)
    }

    private func observeDockVisibility() {
        guard !presentationStopped else { return }
        withObservationTracking {
            dockVisibility.reconcile()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeDockVisibility() }
        }
    }
    func seek(_ time: Double) {
        applyLocalSeek(time)
        bridge.send(.seek(time))
        flexbar.synchronizePlayback(force: true)
    }
    func applyLocalSeek(_ time: Double) {
        session.seek(to: time)
        updateMainLyricSelection()
        ticker?.scheduleEarlier(lyricClockInterval())
        playbackControlPosition = session.position
    }

    func setOverlayVisible(_ visible: Bool) {
        preferences.overlayVisible = visible
        overlay?.setUserVisible(visible)
    }
    func setOverlayLocked(_ locked: Bool) {
        preferences.overlayLocked = locked
        if !locked { preferences.overlayClickThrough = false }
    }
    func setOverlayClickThrough(_ enabled: Bool) {
        preferences.overlayClickThrough = enabled
        if enabled { preferences.overlayLocked = true }
    }
    func skip(next: Bool) {
        bridge.send(next ? .next : .previous)
    }
    /// Keep the search sheet and its results alive while changing the applied
    /// version. A stale search may never write lyrics to the next song.
    func applySearchCandidate(_ candidate: LyricCandidate, forTrackID trackID: String?) -> Bool {
        applyLyrics(candidate.document, forTrackID: trackID)
    }
    func applySearchCandidate(_ candidate: LyricCandidate, forTrackRevision revision: UInt64?) -> Bool {
        applyLyrics(candidate.document, forTrackRevision: revision)
    }
    @discardableResult
    func applyLyrics(_ document: LyricsDocument, forTrackID trackID: String?) -> Bool {
        guard let trackID, let track = session.track, track.id == trackID else { return false }
        return applyLyrics(document, to: track)
    }
    @discardableResult
    func applyLyrics(_ document: LyricsDocument, forTrackRevision revision: UInt64?) -> Bool {
        guard let revision, revision == session.trackRevision, let track = session.track else { return false }
        return applyLyrics(document, to: track)
    }
    private func applyLyrics(_ document: LyricsDocument, to track: Track) -> Bool {
        // An explicit choice overrides an earlier “wrong lyrics” mark. Keep an
        // album-wide exclusion for other songs, with a persistent per-song exception.
        preferences.blockedTracks.removeAll { $0 == track.cacheIdentity }
        if preferences.blockedAlbums.contains(albumKey(track)) {
            preferences.manualLyricOverrides[track.cacheIdentity] = albumKey(track)
        }
        session.use(document)
        updateMainLyricSelection()
        return true
    }
    func refreshLyrics() { if !lyricsBlocked { session.reload(forceRefresh: true) } }
    var lyricsBlocked: Bool {
        lyricsBlocked(for: session.track)
    }
    private func lyricsBlocked(for track: Track?) -> Bool {
        guard let track else { return false }
        if preferences.blockedTracks.contains(track.cacheIdentity) { return true }
        let key = albumKey(track)
        return preferences.blockedAlbums.contains(key) && preferences.manualLyricOverrides[track.cacheIdentity] != key
    }
    private func albumKey(_ track: Track) -> String { [track.artist, track.album].map { "\($0.utf8.count):\($0)" }.joined() }
    func markWrongLyrics() {
        guard let track = session.track else { return }
        preferences.manualLyricOverrides.removeValue(forKey: track.cacheIdentity)
        if !preferences.blockedTracks.contains(track.cacheIdentity) { preferences.blockedTracks.append(track.cacheIdentity) }
        session.suppressLyrics()
    }
    func toggleAlbumSuppression() {
        guard let track = session.track, !track.album.isEmpty else { return }
        let key = albumKey(track)
        preferences.manualLyricOverrides = preferences.manualLyricOverrides.filter { $0.value != key }
        if preferences.blockedAlbums.contains(key) { preferences.blockedAlbums.removeAll { $0 == key }; session.reload() }
        else { preferences.blockedAlbums.append(key); session.suppressLyrics() }
    }
    var albumSuppressed: Bool { session.track.map { preferences.blockedAlbums.contains(albumKey($0)) } ?? false }
    func restoreLyricsSearch() {
        guard let track = session.track else { return }
        preferences.blockedTracks.removeAll { $0 == track.cacheIdentity }
        let key = albumKey(track)
        preferences.blockedAlbums.removeAll { $0 == key }
        preferences.manualLyricOverrides = preferences.manualLyricOverrides.filter { $0.value != key }
        session.reload(forceRefresh: true)
    }
    func revealLyrics() {
        guard let track = session.track else { return }
        Task {
            if let url = await store.cache.existingURL(for: track) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            else { NSWorkspace.shared.open(preferences.directory) }
        }
    }
    func writeLyricsToMusic() {
        guard let track = session.track, let document = session.document else { return }
        Task {
            do { try await bridge.writeLyrics(LyricsCodec.export(document, plain: true), to: track); message = "歌词已写入 Apple Music。" }
            catch { message = error.localizedDescription }
        }
    }
    @ObservationIgnored private var checkingUpdates = false
    func checkForUpdates() {
        guard !checkingUpdates else { return }
        checkingUpdates = true
        Task {
            defer { checkingUpdates = false }
            do {
                var request = URLRequest(url: URL(string: "https://api.github.com/repos/wzk112/LyricsX-Next/releases/latest")!)
                request.timeoutInterval = 10
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                struct Release: Decodable { let tag_name: String; let html_url: URL }
                let release = try JSONDecoder().decode(Release.self, from: data)
                let alert = NSAlert()
                alert.messageText = "LyricsX Next 最新版本：\(release.tag_name)"
                alert.informativeText = "当前版本：\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知")。打开项目发布页查看更新说明与下载。"
                alert.addButton(withTitle: "打开发布页"); alert.addButton(withTitle: "关闭")
                NSApp.activate()
                if alert.runModal() == .alertFirstButtonReturn, release.html_url.host == "github.com" { NSWorkspace.shared.open(release.html_url) }
            } catch { message = "检查更新失败：\(error.localizedDescription)" }
        }
    }
    func importLyrics() {
        let expectedTrackRevision = session.track.map { _ in session.trackRevision }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "lrc") ?? .data, UTType(filenameExtension: "lrcx") ?? .data]
        panel.message = "为当前歌曲选择 LRC、LRCX 或文本歌词"
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard response == .OK, let url = panel.url, let self else { return }
                guard self.session.track.map({ _ in self.session.trackRevision }) == expectedTrackRevision else {
                    self.message = "歌曲已经切换，请为当前歌曲重新选择歌词。"
                    return
                }
                self.importLyrics(url)
            }
        }
    }
    func importLyrics(_ url: URL) {
        guard session.track != nil else { message = "请先播放一首歌曲，再导入对应歌词。"; return }
        do {
            let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            applyLyrics(try LyricsCodec.read(url), forTrackRevision: session.track.map { _ in session.trackRevision })
        } catch { message = error.localizedDescription }
    }
    func exportLyrics(plain: Bool = false) {
        guard let doc = session.document else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = (session.track?.title ?? "歌词") + (plain ? ".txt" : ".lrcx")
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard response == .OK, let url = panel.url else { return }
                do { try LyricsCodec.export(doc, plain: plain).write(to: url, atomically: true, encoding: .utf8) }
                catch { self?.message = error.localizedDescription }
            }
        }
    }
    func loadLibrary() {
        libraryTask?.cancel()
        libraryGeneration += 1; let generation = libraryGeneration; libraryLoading = true
        libraryTask = Task { [weak self, cache = store.cache] in
            do {
                let entries = try await cache.entries()
                guard !Task.isCancelled, let self, generation == self.libraryGeneration else { return }
                self.library = entries; self.libraryLoading = false; self.libraryTask = nil
            } catch {
                guard !Task.isCancelled, let self, generation == self.libraryGeneration else { return }
                self.message = error.localizedDescription; self.libraryLoading = false; self.libraryTask = nil
            }
        }
    }
    func unloadLibrary() {
        libraryGeneration += 1
        libraryTask?.cancel(); libraryTask = nil
        library = []; libraryLoading = false
    }
    func chooseCacheDirectory() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.directoryURL = preferences.directory; panel.message = "选择现有的 LyricsX 歌词文件夹，直接复用已有歌词。"
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard response == .OK, let url = panel.url, let self else { return }
                self.preferences.chooseDirectory(url); await self.store.cache.setDirectory(url)
                self.session.reload(); if self.showLibrary { self.loadLibrary() }
            }
        }
    }
    private func updateArtwork(_ track: Track?) {
        guard !presentationStopped else { return }
        let identity = "\(session.trackRevision):" + (track?.artworkURL?.absoluteString ?? "")
        guard identity != artworkIdentity || track?.artworkData != artworkBytes else { return }
        artworkIdentity = identity; artworkBytes = track?.artworkData; artworkTask?.cancel()
        artworkThemeTask?.cancel(); artworkHandoverTask?.cancel()
        artworkGeneration &+= 1
        let generation = artworkGeneration
        guard track != nil else {
            artworkTask = nil; artworkHandoverTask = nil; artworkLoading = false
            artworkHandover.finish(); artwork = nil
            return
        }
        let hasSource = track?.artworkData != nil || track?.artworkURL != nil
        artworkLoading = true
        let deadline = artworkHandover.begin(at: ProcessInfo.processInfo.systemUptime)
        // Track metadata often arrives before bytes or an artwork URL. Keep
        // one bounded hold across both observations and across rapid skips.
        artworkHandoverTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(max(0, deadline - ProcessInfo.processInfo.systemUptime))) } catch { return }
            guard !Task.isCancelled, let self, !self.presentationStopped, self.artworkGeneration == generation else { return }
            self.artwork = nil
            // While a known source is loading, a quiet surface avoids an
            // incorrect default-note flash. No-source songs settle at expiry.
            if !hasSource { self.artworkLoading = false }
            self.artworkHandoverTask = nil
        }
        guard hasSource else { artworkTask = nil; return }
        let data = track?.artworkData, url = track?.artworkURL
        artworkTask = Task { [weak self, loader = artworkLoader] in
            let decoded = await loader(data, url)
            let theme = if let decoded { await ArtworkThemeExtractor.shared.theme(for: decoded) } else { ArtworkTheme?.none }
            // Cancellation also covers a newer byte payload for the same track
            // and URL, which an identity-only check cannot distinguish.
            guard !Task.isCancelled, let self, !self.presentationStopped,
                  self.artworkIdentity == identity, self.artworkGeneration == generation else { return }
            self.artworkHandoverTask?.cancel(); self.artworkHandoverTask = nil
            self.artworkLoading = false
            if let decoded {
                // The cover and its lyric palette publish in one main-actor
                // turn; the palette must not arrive as a second visual update.
                self.artworkThemeTask?.cancel(); self.artworkThemeTask = nil
                self.publishingArtwork = true
                self.artwork = NSImage(cgImage: decoded, size: .zero)
                if self.preferences.artworkTheme != theme { self.preferences.artworkTheme = theme }
                self.publishingArtwork = false
                self.artworkHandover.finish()
            } else { self.artwork = nil }
            self.artworkTask = nil
        }
    }
    private func updateArtworkTheme() {
        artworkThemeTask?.cancel()
        let source = artwork?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        artworkThemeTask = Task { [weak self] in
            let theme: ArtworkTheme?
            if let source { theme = await ArtworkThemeExtractor.shared.theme(for: source) }
            else {
                // Match the cover handover grace period; do not flash white
                // during a brief gap between track metadata and artwork.
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                theme = nil
            }
            guard !Task.isCancelled, let self, !self.presentationStopped else { return }
            if self.preferences.artworkTheme != theme { self.preferences.artworkTheme = theme }
        }
    }

}

enum DemoContent {
    static let track = Track(playerID: "lyricsx.demo", playerName: "动效预览", title: "慢慢亮起来", artist: "LyricsX Studio", album: "夜航 · NIGHTFALL", duration: 100)
    static let document: LyricsDocument = {
        let texts = ["把今天的喧嚣轻轻放下", "让晚风经过你的耳旁", "城市的灯 像远处的海", "我们沿着声音 去流浪", "每一个平凡的瞬间", "都在慢慢亮起来", "让这一刻 留在眼前", "让每一句 都有回响", "不必急着 抵达远方", "月光会落在你的肩膀", "把未说完的故事唱出来", "让心事 随着节拍舒展", "每一个平凡的瞬间", "都在慢慢亮起来", "等最后一颗星落下", "我们还在同一片光里"]
        let translations = ["Set the noise of the day aside", "Let the evening breeze pass by", "City lights, a distant sea", "We wander where the sound leads", "Every ordinary moment", "Is slowly coming into light", "Keep this moment in your sight", "Let every word resonate", "There is no need to hurry", "Moonlight rests upon your shoulder", "Sing the stories left untold", "Let your thoughts unfold in rhythm", "Every ordinary moment", "Is slowly coming into light", "When the last star falls", "We remain in the same light"]
        let rows = texts.enumerated().map { i, text in
            let time = Double(i) * 6
            let words = Array(text).enumerated().map { j, char in WordCue(text: String(char), start: time + Double(j) * 4.5 / Double(text.count), end: time + Double(j + 1) * 4.5 / Double(text.count)) }
            return LyricLine(id: i, time: time, text: text, translation: translations[i], words: words)
        }
        return LyricsDocument(title: track.title, artist: track.artist, album: track.album, source: "原创演示歌词", duration: 100, lines: rows)
    }()
}
