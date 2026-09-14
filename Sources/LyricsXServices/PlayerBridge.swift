import Foundation
import AppKit
import LyricsXCore
@preconcurrency import MediaRemoteAdapter

public enum PlayerMode: String, CaseIterable, Sendable, Identifiable {
    case automatic, appleMusic, spotify
    public var id: String { rawValue }
    public var title: String {
        switch self { case .automatic: "自动 · 音乐播放器"; case .appleMusic: "Apple Music"; case .spotify: "Spotify" }
    }
    var bundleID: String? { switch self { case .automatic: nil; case .appleMusic: "com.apple.Music"; case .spotify: "com.spotify.client" } }
}
public enum PlayerCommand: Sendable, Equatable { case toggle, next, previous, seek(Double) }

public struct SystemMediaPayload: Decodable, Sendable {
    public var title: String?
    public var artist: String?
    public var album: String?
    public var isPlaying: Bool?
    public var durationMicros: Double?
    public var elapsedTimeMicros: Double?
    public var applicationName: String?
    public var bundleIdentifier: String?
    public var parentApplicationBundleIdentifier: String?
    public var processIdentifier: Int32?
    public var artworkDataBase64: String?
    public var timestampEpochMicros: Double?

    public func snapshot(now: Double, wallTime: Double = Date().timeIntervalSince1970, isIOSApp: Bool = false) -> PlaybackSnapshot {
        guard var title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return PlaybackSnapshot(track: nil, position: 0, isPlaying: isPlaying == true, sampledAt: now,
                                    positionIsReliable: false, playbackStateIsReliable: isPlaying != nil)
        }
        var artist = artist ?? ""
        if isIOSApp {
            // Restrict ticker recovery to iOS-on-Mac; legitimate native song titles may contain an em dash.
            for text in [title, artist] {
                if let range = text.range(of: " — ") {
                    title = String(text[..<range.lowerBound]); artist = String(text[range.upperBound...]); break
                }
            }
        }
        let playerID = parentApplicationBundleIdentifier ?? bundleIdentifier ?? "system"
        let duration = (durationMicros ?? 0) / 1_000_000
        // Metadata identity is stable even if a source rotates its numeric ID with every lyric.
        let track = Track(playerID: playerID, playerName: applicationName ?? "正在播放", title: title, artist: artist, album: album ?? "",
                          duration: duration, artworkData: artworkDataBase64.flatMap(Self.decodeArtwork))
        var position = max(0, (elapsedTimeMicros ?? 0) / 1_000_000)
        if isPlaying == true, let timestampEpochMicros {
            let anchorAge = max(0, wallTime - timestampEpochMicros / 1_000_000)
            // MediaRemote returns a position anchored at its timestamp. The
            // timestamp can legitimately be much older than three seconds.
            // Clamp only to the track boundary, not to an arbitrary age.
            position += duration > 0 ? min(anchorAge, max(0, duration - position)) : anchorAge
        }
        return PlaybackSnapshot(
            track: track,
            position: position,
            isPlaying: isPlaying == true,
            sampledAt: now,
            positionIsReliable: elapsedTimeMicros != nil,
            playbackStateIsReliable: isPlaying != nil
        )
    }

    func matchingMusicArtwork(title: String, artist: String, album: String) -> Data? {
        // Never borrow another player's image or a stale track's artwork.
        guard (parentApplicationBundleIdentifier ?? bundleIdentifier) == "com.apple.Music",
              self.title == title, self.artist == artist,
              album.isEmpty || self.album == album,
              let encoded = artworkDataBase64,
              let data = Self.decodeArtwork(encoded), !data.isEmpty, data.count < 8_000_000 else { return nil }
        return data
    }

    private static func decodeArtwork(_ value: String) -> Data? {
        let payload: String
        if let separator = value.firstIndex(of: ","), value[..<separator].contains("base64") {
            payload = String(value[value.index(after: separator)...])
        } else {
            payload = value
        }
        return Data(base64Encoded: payload, options: [.ignoreUnknownCharacters])
    }
}

@MainActor
public final class PlayerBridge {
    public var onSnapshot: ((PlaybackSnapshot) -> Void)?
    public var onError: ((String?) -> Void)?
    public var onCommandResult: ((PlayerCommand, Bool) -> Void)?
    public var mode: PlayerMode = .automatic { didSet { if mode != oldValue { continuity = .init(); scriptTarget = nil; restart() } } }
    private var loop: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var revision: UInt64 = 0
    private var commandTask: Task<Void, Never>?
    private var commandQueue: [PlayerCommand] = []
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var latestScriptID = ""
    private var latestScriptTarget = ""
    private var artworkCacheID = ""
    private var artworkCacheData: Data?
    private var scriptTarget: String?
    private var refreshPending = false
    private var continuity = PlaybackContinuity()
    private var artworkAttempts = 0
    private var nextArtworkAttempt: Double = 0
    private var snapshotReader: (@MainActor () async throws -> PlaybackSnapshot)?
    private var commandExecutor: (@MainActor (PlayerCommand) async throws -> Void)?
    private var now: @MainActor () -> Double = { ProcessInfo.processInfo.systemUptime }
    public init() {}
    init(snapshotReader: @escaping @MainActor () async throws -> PlaybackSnapshot,
         commandExecutor: (@MainActor (PlayerCommand) async throws -> Void)? = nil,
         now: @escaping @MainActor () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        self.snapshotReader = snapshotReader; self.commandExecutor = commandExecutor; self.now = now
    }
    public func start() {
        guard loop == nil else { return }
        for name in ["com.apple.iTunes.playerInfo", "com.spotify.client.PlaybackStateChanged"] {
            observers.append(DistributedNotificationCenter.default().addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                Task { @MainActor in
                    guard let app else { return }
                    MusicSourcePolicy.invalidate(app)
                    guard MusicSourcePolicy.accepts(app) else { return }
                    self?.refresh()
                }
            })
        }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                do { try await Task.sleep(for: .seconds(self?.pollInterval ?? 1)) } catch { return }
            }
        }
    }
    var pollInterval: Double {
        guard let latest = continuity.latest else { return 1 }
        if latest.track == nil { return 5 }
        // Only players with a direct pause/resume notification get the longer
        // paused interval. Other music apps retain one-second discovery.
        if !latest.isPlaying, ["com.apple.Music", "com.spotify.client"].contains(latest.track?.playerID ?? "") { return 5 }
        return 1
    }
    public func stop() {
        revision &+= 1; loop?.cancel(); loop = nil; pollTask?.cancel(); pollTask = nil
        refreshPending = false
        commandTask?.cancel(); commandTask = nil; commandQueue.removeAll()
        for token in observers { DistributedNotificationCenter.default().removeObserver(token) }; observers = []
        for token in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(token) }; workspaceObservers = []
    }
    public func restart() { stop(); latestScriptID = ""; artworkCacheID = ""; artworkCacheData = nil; start() }
    public func refresh() {
        guard pollTask == nil, commandTask == nil else { refreshPending = true; return }
        let generation = revision
        pollTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.revision == generation {
                    self.pollTask = nil
                    if self.refreshPending { self.refreshPending = false; self.refresh() }
                }
            }
            await self.poll(generation: generation)
        }
    }
    private func poll(generation: UInt64) async {
        // Retry gaps promptly; notifications arriving during a poll are queued.
        // A command invalidates the old read before a new result can publish.
        for attempt in 0..<3 {
            do {
                let raw: PlaybackSnapshot
                if let snapshotReader { raw = try await snapshotReader() }
                else { raw = try await readSnapshot() }
                guard !Task.isCancelled, revision == generation else { return }
                if let snapshot = continuity.accept(raw, now: now()) {
                    onError?(nil); onSnapshot?(snapshot)
                }
                if raw.track != nil || attempt == 2 { return }
            } catch {
                guard !Task.isCancelled, revision == generation else { return }
                if let error = error as? BridgeError, error == .automation || error == .bundle {
                    onError?(error.localizedDescription); return
                }
                if continuity.shouldReportFailure(now: now()) { onError?(error.localizedDescription) }
                if attempt == 2 { return }
            }
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
        }
    }
    public func send(_ command: PlayerCommand) {
        if case .seek = command {
            commandQueue.removeAll { if case .seek = $0 { true } else { false } }
        }
        commandQueue.append(command)
        drainCommandsIfNeeded()
    }
    public func writeLyrics(_ lyrics: String, to track: Track) async throws {
        guard track.playerID == "com.apple.Music" else { throw BridgeError.wrongTrack }
        let source = """
        function run(argv) {
          const app = Application('com.apple.Music');
          if (!app.running()) throw new Error('Player unavailable');
          const t = app.currentTrack();
          if (t.name() !== argv[0] || t.artist() !== argv[1] || t.album() !== argv[2]) throw new Error('Track changed');
          if (argv[3] && String(t.persistentID()) !== argv[3]) throw new Error('Track changed');
          t.lyrics = argv[4];
        }
        """
        let result = try await ProcessRunner.run("/usr/bin/osascript", arguments: ["-l", "JavaScript", "-e", source, track.title, track.artist, track.album, track.persistentID, lyrics])
        guard result.status == 0 else { throw BridgeError.lyricsWrite }
    }
    private func drainCommandsIfNeeded() {
        guard commandTask == nil, !commandQueue.isEmpty else { return }
        revision &+= 1
        pollTask?.cancel()
        pollTask = nil
        commandTask = Task { [weak self] in
            guard let self else { return }
            let generation = self.revision
            while !self.commandQueue.isEmpty, !Task.isCancelled {
                let command = self.commandQueue.removeFirst()
                do {
                    try await self.execute(command)
                    guard self.revision == generation, !Task.isCancelled else { return }
                    self.onCommandResult?(command, true)
                } catch {
                    guard self.revision == generation, !Task.isCancelled else { return }
                    self.onError?(error.localizedDescription)
                    self.onCommandResult?(command, false)
                }
            }
            guard self.revision == generation, !Task.isCancelled else { return }
            self.commandTask = nil
            self.refresh()
        }
    }
    private func execute(_ command: PlayerCommand) async throws {
        if let commandExecutor { try await commandExecutor(command); return }
        if let target = mode.bundleID ?? scriptTarget {
            let operation: String
            switch command {
            case .toggle: operation = "app.playpause()"
            case .next: operation = "app.nextTrack()"
            case .previous: operation = "app.previousTrack()"
            case .seek(let time): operation = "app.playerPosition = \(max(0, time.isFinite ? time : 0))"
            }
            let result = try await ProcessRunner.run("/usr/bin/osascript", arguments: ["-l", "JavaScript", "-e", "const app = Application('\(target)'); if (app.running()) { \(operation); }"])
            guard result.status == 0 else { throw BridgeError.automation }
        } else {
            // Do not send a stale music control to a browser that has taken
            // over system playback since the last sample.
            guard let current = try await readSnapshot().track else { throw BridgeError.excludedSource }
            if scriptTarget != nil { try await execute(command); return }
            guard current.playerID == continuity.latest?.track?.playerID else { throw BridgeError.excludedSource }
            let args: [String]
            switch command {
            case .toggle: args = ["toggle_play_pause"]
            case .next: args = ["next_track"]
            case .previous: args = ["previous_track"]
            case .seek(let time): args = ["set_time", String(max(0, time.isFinite ? time : 0))]
            }
            let result = try await runMedia(args)
            guard result.status == 0 else { throw BridgeError.unavailable }
        }
    }
    private func readSnapshot() async throws -> PlaybackSnapshot {
        if let target = mode.bundleID { scriptTarget = target; return try await readScript(target) }
        let previousScriptTarget = scriptTarget
        let musicApps = NSWorkspace.shared.runningApplications.filter { MusicSourcePolicy.accepts($0) }
        guard !musicApps.isEmpty else {
            scriptTarget = nil
            return PlaybackSnapshot(track: nil, position: 0, isPlaying: false)
        }
        // If only one music app exists, querying the system adapter first
        // cannot discover a different eligible player. Avoid that subprocess.
        if musicApps.count == 1, let target = musicApps.first?.bundleIdentifier,
           ["com.apple.Music", "com.spotify.client"].contains(target) {
            scriptTarget = target
            return try await readScript(target)
        }
        do {
            let result = try await runMedia(["update_player_state"])
            guard result.status == 0 else { throw BridgeError.unavailable }
            struct Envelope: Decodable { var notificationName: String; var payload: SystemMediaPayload }
            for line in String(decoding: result.data, as: UTF8.self).split(separator: "\n").reversed() {
                guard let item = try? JSONDecoder().decode(Envelope.self, from: Data(line.utf8)), item.notificationName.contains("NowPlayingInfoDidChange") else { continue }
                let running = item.payload.processIdentifier.flatMap { NSRunningApplication(processIdentifier: $0) }
                let ownerID = item.payload.parentApplicationBundleIdentifier ?? item.payload.bundleIdentifier ?? running?.bundleIdentifier
                let owner = musicApps.first { $0.bundleIdentifier == ownerID }
                guard MusicSourcePolicy.accepts(bundleID: ownerID) || owner != nil else { throw BridgeError.excludedSource }
                let isIOS = MediaController.isiOSAppOnMac(runningApp: running)
                let snapshot = item.payload.snapshot(now: ProcessInfo.processInfo.systemUptime, isIOSApp: isIOS)
                guard let track = snapshot.track else { throw BridgeError.unavailable }
                // Use the same metadata source during playback and pause, so
                // falling back does not alternate persistent song identities.
                if ["com.apple.Music", "com.spotify.client"].contains(track.playerID) {
                    scriptTarget = track.playerID
                    return try await readScript(track.playerID)
                }
                scriptTarget = nil
                return snapshot
            }
            throw BridgeError.unavailable
        } catch {
            // Public Apple Events remain usable if the system adapter changes on a macOS update.
            let runningIDs = ["com.apple.Music", "com.spotify.client"].filter {
                !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty
            }
            var snapshots: [(id: String, value: PlaybackSnapshot)] = []
            for id in runningIDs {
                if let value = try? await readScript(id), value.track != nil {
                    snapshots.append((id, value))
                }
            }
            if let active = snapshots.first(where: { $0.value.isPlaying }) {
                scriptTarget = active.id
                return active.value
            }
            if let previous = snapshots.first(where: { $0.id == previousScriptTarget }) {
                scriptTarget = previous.id
                return previous.value
            }
            if let first = snapshots.first {
                scriptTarget = first.id
                return first.value
            }
            if runningIDs.isEmpty, (error as? BridgeError) == .excludedSource {
                scriptTarget = nil
                return PlaybackSnapshot(track: nil, position: 0, isPlaying: false)
            }
            if runningIDs.isEmpty, continuity.latest?.track.map({ NSRunningApplication.runningApplications(withBundleIdentifier: $0.playerID).isEmpty }) != false {
                return PlaybackSnapshot(track: nil, position: 0, isPlaying: false)
            }
            throw error
        }
    }
    private func runMedia(_ command: [String]) async throws -> ProcessRunner.Output {
        guard let script = Bundle.main.url(forResource: "run", withExtension: "pl") else { throw BridgeError.bundle }
        let library = Bundle.main.bundleURL.appendingPathComponent("Contents/Frameworks/libMediaRemoteAdapter.dylib")
        guard FileManager.default.fileExists(atPath: library.path) else { throw BridgeError.bundle }
        return try await ProcessRunner.run("/usr/bin/perl", arguments: [script.path, library.path] + command)
    }
    struct ScriptRecord: Decodable {
        var title: String?; var artist: String?; var album: String?; var id: String?; var duration: Double?
        var position: Double?; var playing: Bool?; var artwork: String?; var lyrics: String?; var location: String?
        var coherent: Bool?
    }
    private func readScript(_ target: String) async throws -> PlaybackSnapshot {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: target).isEmpty else {
            return PlaybackSnapshot(track: nil, position: 0, isPlaying: false)
        }
        let spotify = target == "com.spotify.client"
        let source = """
        function run(argv) {
          const app = Application('\(target)');
          function safe(f, d) { try { const v = f(); return v == null ? d : v; } catch(e) { return d; } }
          if (!app.running()) return '{}';
          const t = safe(() => app.currentTrack(), null);
          const id = String(safe(() => t.\(spotify ? "id" : "persistentID")(), ''));
          const state = safe(() => app.playerState(), null);
          const same = id.length > 0 && id === argv[0];
          const result = {title:safe(() => t.name(), ''),artist:safe(() => t.artist(), ''),album:safe(() => t.album(), ''),id:id,
            duration:safe(() => t.duration(),0)/\(spotify ? "1000" : "1"),position:safe(() => app.playerPosition(),null),
            playing:state === 'playing' ? true : state === 'paused' || state === 'stopped' ? false : null,
            artwork:\(spotify ? "same ? null : safe(() => t.artworkUrl(), '')" : "''"),lyrics:\(spotify ? "''" : "same ? null : safe(() => t.lyrics(), '')"),location:\(spotify ? "''" : "same ? null : safe(() => t.location().toString(), '')")};
          const endID = String(safe(() => app.currentTrack().\(spotify ? "id" : "persistentID")(), ''));
          result.coherent = id === endID;
          return JSON.stringify(result);
        }
        """
        let started = ProcessInfo.processInfo.systemUptime
        let output = try await ProcessRunner.run("/usr/bin/osascript", arguments: ["-l", "JavaScript", "-e", source, latestScriptTarget == target ? latestScriptID : ""])
        guard output.status == 0 else {
            throw output.error.contains("-1743") ? BridgeError.automation : BridgeError.unavailable
        }
        let item = try JSONDecoder().decode(ScriptRecord.self, from: output.data)
        guard item.coherent != false else { throw BridgeError.unavailable }
        let sampleTime = (started + ProcessInfo.processInfo.systemUptime) / 2
        guard let title = item.title, !title.isEmpty else {
            return PlaybackSnapshot(track: nil, position: 0, isPlaying: item.playing == true, sampledAt: sampleTime,
                                    positionIsReliable: false, playbackStateIsReliable: item.playing != nil)
        }
        let persistentID = (item.id?.isEmpty == false ? item.id! : [title, item.artist ?? "", item.album ?? ""].joined(separator: "\u{1f}"))
        if artworkCacheID != persistentID {
            artworkCacheID = persistentID; artworkCacheData = nil; artworkAttempts = 0; nextArtworkAttempt = 0
        }
        if !spotify, artworkCacheData == nil, ProcessInfo.processInfo.systemUptime >= nextArtworkAttempt {
            artworkAttempts += 1
            var data = await readMusicArtwork(expectedID: item.id ?? "")
            if data == nil { data = await readSystemMusicArtwork(title: title, artist: item.artist ?? "", album: item.album ?? "") }
            nextArtworkAttempt = ProcessInfo.processInfo.systemUptime + (artworkAttempts < 3 ? 3 : 30)
            try Task.checkCancellation()
            artworkCacheData = data
        }
        try Task.checkCancellation()
        latestScriptID = persistentID
        latestScriptTarget = target
        let track = Track(playerID: target, playerName: spotify ? "Spotify" : "Apple Music", persistentID: item.id ?? "", title: title,
                          artist: item.artist ?? "", album: item.album ?? "", duration: item.duration ?? 0,
                          artworkData: spotify ? nil : artworkCacheData,
                          artworkURL: item.artwork.flatMap(URL.init(string:)), localFileURL: Self.fileURL(item.location), embeddedLyrics: item.lyrics)
        return PlaybackSnapshot(
            track: track,
            position: item.position ?? 0,
            isPlaying: item.playing ?? false,
            sampledAt: sampleTime,
            positionIsReliable: item.position != nil,
            playbackStateIsReliable: item.playing != nil
        )
    }
    private static func fileURL(_ value: String?) -> URL? {
        guard let value, !value.isEmpty else { return nil }
        if value.hasPrefix("file://") { return URL(string: value) }
        return URL(fileURLWithPath: value)
    }
    private func readSystemMusicArtwork(title: String, artist: String, album: String) async -> Data? {
        guard let result = try? await runMedia(["update_player_state"]), result.status == 0 else { return nil }
        struct Envelope: Decodable { var notificationName: String; var payload: SystemMediaPayload }
        for line in String(decoding: result.data, as: UTF8.self).split(separator: "\n").reversed() {
            guard let event = try? JSONDecoder().decode(Envelope.self, from: Data(line.utf8)),
                  event.notificationName.contains("NowPlayingInfoDidChange"),
                  let data = event.payload.matchingMusicArtwork(title: title, artist: artist, album: album) else { continue }
            return data
        }
        return nil
    }
    private func readMusicArtwork(expectedID: String) async -> Data? {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("lyricsx-artwork-\(UUID().uuidString).bin")
        let source = #"""
        on run argv
          set outputPath to item 1 of argv
          set expectedID to item 2 of argv
          tell application "Music"
            if not running then return ""
            set currentTrack to current track
            try
              if expectedID is not "" and (persistent ID of currentTrack as text) is not expectedID then return ""
            end try
            if (count of artworks of currentTrack) is 0 then return ""
            set rawData to raw data of artwork 1 of currentTrack
            set outputFile to open for access (POSIX file outputPath) with write permission
            try
              set eof outputFile to 0
              write rawData to outputFile
              close access outputFile
            on error
              try
                close access outputFile
              end try
            end try
          end tell
        end run
        """#
        defer { try? FileManager.default.removeItem(at: outputURL) }
        guard let result = try? await ProcessRunner.run("/usr/bin/osascript", arguments: ["-e", source, outputURL.path, expectedID]), result.status == 0,
              let data = try? Data(contentsOf: outputURL), !data.isEmpty, data.count < 8_000_000 else { return nil }
        return data
    }
    enum BridgeError: LocalizedError, Equatable {
        case unavailable, automation, bundle, wrongTrack, lyricsWrite, excludedSource
        var errorDescription: String? {
            switch self {
            case .excludedSource: "当前来源不是音乐播放器。"
            case .unavailable: "暂时无法读取系统播放状态。可在设置中切换到 Apple Music 或 Spotify。"
            case .automation: "请在系统设置 → 隐私与安全性 → 自动化中允许 LyricsX Next 控制播放器。"
            case .bundle: "播放器组件未就绪，请使用打包后的 LyricsX Next.app。"
            case .wrongTrack: "只有当前 Apple Music 歌曲支持写入歌词。"
            case .lyricsWrite: "歌词未能写入。请确认歌曲未切换、已加入音乐资料库，并已允许自动化控制。"
            }
        }
    }
}
