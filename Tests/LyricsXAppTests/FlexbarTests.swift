import Foundation
import Darwin
import Testing
import LyricsXCore
@testable import LyricsXApp

private struct FlexbarIdleRepository: LyricsRepository {
    func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
    func save(_ document: LyricsDocument, for track: Track) async throws {}
}

private final class FlexbarTestPeer {
    let fd: Int32
    private var input = Data()
    init(path: String) throws {
        fd = socket(AF_UNIX, SOCK_STREAM, 0)
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        guard path.utf8.count < MemoryLayout.size(ofValue: address.sun_path) else { close(fd); throw FlexbarServer.Failure.pathTooLong }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: Array(path.utf8) + [0]) }
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard result == 0 else { close(fd); throw FlexbarServer.Failure.system(errno) }
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        var enabled: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size))
    }
    func send(_ value: String) { send(Data(value.utf8)) }
    func send(_ value: Data) { _ = value.withUnsafeBytes { write(fd, $0.baseAddress!, value.count) } }
    func frames() -> [Data] {
        var bytes = [UInt8](repeating: 0, count: 8192)
        while true {
            let count = read(fd, &bytes, bytes.count)
            guard count > 0 else { break }
            input.append(contentsOf: bytes.prefix(count))
        }
        var frames: [Data] = []
        while let end = input.firstIndex(of: 10) {
            frames.append(Data(input.prefix(upTo: end))); input.removeSubrange(...end)
        }
        return frames
    }
    deinit { close(fd) }
}

@MainActor private func eventually(_ condition: () -> Bool) async throws {
    for _ in 0..<100 {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(2))
    }
    #expect(condition())
}

@MainActor private func testSocketURL() -> URL {
    URL(fileURLWithPath: "/tmp").appendingPathComponent("lx-flex-\(UUID().uuidString)").appendingPathComponent("bridge.sock")
}

@MainActor private func testModel(path: URL) throws -> (AppModel, UserDefaults, String) {
    let suite = "LyricsXFlexbarTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    let preferences = Preferences(defaults: defaults)
    let model = AppModel(repository: FlexbarIdleRepository(), preferences: preferences, flexbarSocketURL: path)
    return (model, defaults, suite)
}

private func sampleSnapshot(_ revision: UInt64 = 1, text: String = "Hello") -> FlexbarSnapshot {
    .init(sessionID: UUID(), revision: revision, state: .lyrics, trackRevision: 1, documentRevision: 1,
          title: "Song", artist: "Artist", primary: text, isPlaying: true)
}

@Test @MainActor func flexbarDefaultDisabledAndPreferenceLifecycle() async throws {
    let path = testSocketURL()
    let (model, defaults, suite) = try testModel(path: path)
    defer { model.stop(); defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: path.deletingLastPathComponent()) }
    #expect(!model.preferences.flexbarEnabled)
    model.flexbar.start(model: model)
    #expect(!model.flexbar.isRunning)
    model.preferences.flexbarEnabled = true
    try await eventually { model.flexbar.isRunning }
    #expect(FileManager.default.fileExists(atPath: path.path))
    model.preferences.flexbarEnabled = false
    try await eventually { !model.flexbar.isRunning }
    #expect(!FileManager.default.fileExists(atPath: path.path))
}

@Test @MainActor func flexbarInitialSnapshotPauseDedupUpgradeSeekAndConversion() async throws {
    let path = testSocketURL()
    let (model, defaults, suite) = try testModel(path: path)
    defer { model.stop(); defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: path.deletingLastPathComponent()) }
    model.preferences.flexbarEnabled = true
    let track = Track(playerID: "test", playerName: "Test", title: "Song", artist: "Artist", duration: 30)
    model.session.accept(.init(track: track, position: 1, isPlaying: true), shouldSearch: false)
    var doc = LyricsDocument(lines: [.init(id: 0, time: 0, text: "歌词", translation: "translation", words: [.init(text: "歌", start: 0, end: 2)]), .init(id: 1, time: 10, text: "Next")])
    model.session.use(doc)
    model.flexbar.start(model: model)
    let peer = try FlexbarTestPeer(path: path.path)
    peer.send("{\"version\":1,\"kind\":\"subscribe\",\"clientTime\":123,\"nonce\":\"abc\"}\n")
    try await eventually { model.flexbar.subscriberCount == 1 }
    var frames = peer.frames()
    #expect(frames.count == 2)
    let sync = try #require(try JSONSerialization.jsonObject(with: frames[0]) as? [String: Any])
    #expect(sync["kind"] as? String == "clockSync")
    #expect(sync["echoClientTime"] as? Double == 123)
    let initial = try JSONDecoder().decode(FlexbarSnapshot.self, from: frames[1])
    #expect(initial.primary == "歌词" && initial.translation == "translation")
    #expect(initial.timing?.words.count == 1 && initial.clock?.rate == 1)
    model.preferences.showTranslation = false
    try await Task.sleep(for: .milliseconds(15))
    #expect(peer.frames().isEmpty)
    for _ in 0..<100 { model.session.tick() }
    try await Task.sleep(for: .milliseconds(15))
    #expect(peer.frames().isEmpty)
    model.session.accept(.init(track: track, position: 1, isPlaying: false))
    try await Task.sleep(for: .milliseconds(15))
    frames = peer.frames()
    #expect(frames.count == 1)
    let paused = try JSONDecoder().decode(FlexbarSnapshot.self, from: try #require(frames.first))
    #expect(paused.primary == "歌词" && paused.state == .lyrics && !paused.isPlaying && paused.clock?.rate == 0)
    try await Task.sleep(for: .milliseconds(15))
    #expect(peer.frames().isEmpty)
    doc.lines[0].translation = "upgraded"
    model.session.use(doc)
    try await Task.sleep(for: .milliseconds(15))
    let upgrade = try JSONDecoder().decode(FlexbarSnapshot.self, from: try #require(peer.frames().first))
    #expect(upgrade.translation == "upgraded" && upgrade.documentRevision > paused.documentRevision)
    model.preferences.conversion = "繁體"
    try await Task.sleep(for: .milliseconds(15))
    let converted = try JSONDecoder().decode(FlexbarSnapshot.self, from: try #require(peer.frames().first))
    #expect(converted.primary == "歌詞" && converted.timing?.words.count == 1)
    model.session.seek(to: 2)
    model.flexbar.synchronizePlayback(force: true)
    let seek = try JSONDecoder().decode(FlexbarSnapshot.self, from: try #require(peer.frames().first))
    #expect(seek.clock?.position == 2 && seek.revision > converted.revision)
    model.session.adjustOffset(by: 1000)
    try await Task.sleep(for: .milliseconds(15))
    let offset = try JSONDecoder().decode(FlexbarSnapshot.self, from: try #require(peer.frames().first))
    #expect(offset.timing?.offsetMilliseconds == 1000)
    model.session.accept(.init(track: track, position: 3, isPlaying: false))
    model.flexbar.synchronizePlayback()
    let externalSeek = try JSONDecoder().decode(FlexbarSnapshot.self, from: try #require(peer.frames().first))
    #expect(externalSeek.clock?.position == 3 && !externalSeek.isPlaying)
    model.flexbar.synchronizePlayback()
    try await Task.sleep(for: .milliseconds(15))
    #expect(peer.frames().isEmpty)
}

@Test func flexbarPlaybackGateHonorsDriftAndFiveSecondHeartbeat() {
    let anchor = FlexbarSnapshot.Clock(hostUptime: 100, position: 12, rate: 1)
    #expect(!FlexbarPlaybackGate.shouldBuild(force: false, presentationChanged: false,
        previous: anchor, now: 104.9, position: 16.9, isPlaying: true))
    #expect(FlexbarPlaybackGate.shouldBuild(force: false, presentationChanged: false,
        previous: anchor, now: 105, position: 17, isPlaying: true))
    #expect(!FlexbarPlaybackGate.shouldBuild(force: false, presentationChanged: false,
        previous: anchor, now: 105, position: 17, isPlaying: false))
    #expect(FlexbarPlaybackGate.shouldBuild(force: false, presentationChanged: false,
        previous: anchor, now: 101, position: 14, isPlaying: true))
    #expect(FlexbarPlaybackGate.shouldBuild(force: false, presentationChanged: true,
        previous: anchor, now: 101, position: 13, isPlaying: true))
    #expect(FlexbarPlaybackGate.shouldBuild(force: true, presentationChanged: false,
        previous: anchor, now: 101, position: 13, isPlaying: true))
}

@Test @MainActor func flexbarSkipsExpensiveProjectionUntilPlaybackOrPresentationChanges() async throws {
    let path = testSocketURL()
    let (model, defaults, suite) = try testModel(path: path)
    defer { model.stop(); defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: path.deletingLastPathComponent()) }
    model.preferences.flexbarEnabled = true
    let track = Track(playerID: "test", playerName: "Test", title: "Song", artist: "", duration: 30)
    model.session.accept(.init(track: track, position: 1, isPlaying: true), shouldSearch: false)
    let doc = LyricsDocument(lines: [.init(id: 0, time: 0, text: "歌词", words: [.init(text: "歌词", start: 0, end: 5)]),
                                    .init(id: 1, time: 20, text: "Next")])
    model.session.use(doc, persist: false)
    model.flexbar.start(model: model)
    let peer = try FlexbarTestPeer(path: path.path)
    peer.send("{\"version\":1,\"kind\":\"subscribe\"}\n")
    try await eventually { model.flexbar.subscriberCount == 1 }
    _ = peer.frames()
    let initialBuilds = model.flexbar.snapshotBuildCount
    for _ in 0..<200 { model.flexbar.synchronizePlayback() }
    #expect(model.flexbar.snapshotBuildCount == initialBuilds)
    #expect(peer.frames().isEmpty)

    model.session.seek(to: 5)
    model.flexbar.synchronizePlayback()
    let seek = try JSONDecoder().decode(FlexbarSnapshot.self, from: try #require(peer.frames().last))
    #expect(abs((seek.clock?.position ?? 0) - 5) < 0.01)
    var completed = track; completed.artist = "Artist"
    model.session.accept(.init(track: completed, position: 5, isPlaying: true), shouldSearch: false)
    model.flexbar.synchronizePlayback()
    let metadata = try JSONDecoder().decode(FlexbarSnapshot.self, from: try #require(peer.frames().last))
    #expect(metadata.artist == "Artist" && metadata.trackRevision == seek.trackRevision)
    model.session.use(doc, persist: false)
    model.flexbar.synchronizePlayback()
    let replacement = try JSONDecoder().decode(FlexbarSnapshot.self, from: try #require(peer.frames().last))
    #expect(replacement.documentRevision > metadata.documentRevision)
    model.preferences.conversion = "繁體"
    model.flexbar.synchronizePlayback()
    let converted = try JSONDecoder().decode(FlexbarSnapshot.self, from: try #require(peer.frames().last))
    #expect(converted.primary == "歌詞")
    model.session.adjustOffset(by: 1000)
    model.flexbar.synchronizePlayback()
    let offset = try JSONDecoder().decode(FlexbarSnapshot.self, from: try #require(peer.frames().last))
    #expect(offset.timing?.offsetMilliseconds == 1000)
    model.session.accept(.init(track: completed, position: 6, isPlaying: false), shouldSearch: false)
    model.flexbar.synchronizePlayback()
    let paused = try JSONDecoder().decode(FlexbarSnapshot.self, from: try #require(peer.frames().last))
    #expect(!paused.isPlaying && paused.clock?.rate == 0 && paused.clock?.position == 6)
    #expect(model.flexbar.snapshotBuildCount > initialBuilds)
}

@Test @MainActor func flexbarSplitSubscribeAndNewConsumerDoesNotRebroadcast() async throws {
    let path = testSocketURL(), server = FlexbarServer(socketURL: testSocketURL())
    defer { server.stop(); try? FileManager.default.removeItem(at: server.socketURL.deletingLastPathComponent()); try? FileManager.default.removeItem(at: path.deletingLastPathComponent()) }
    server.onFirstSnapshot = { sampleSnapshot() }
    try server.start()
    let first = try FlexbarTestPeer(path: server.socketURL.path)
    first.send("{\"version\":1,")
    try await Task.sleep(for: .milliseconds(10))
    #expect(server.subscriberCount == 0)
    first.send("\"kind\":\"subscribe\"}\n")
    try await eventually { server.subscriberCount == 1 }
    #expect(first.frames().count == 1)
    var second: FlexbarTestPeer? = try FlexbarTestPeer(path: server.socketURL.path)
    second?.send("{\"version\":1,\"kind\":\"subscribe\"}\n")
    try await eventually { server.subscriberCount == 2 }
    #expect(second?.frames().count == 1)
    #expect(first.frames().isEmpty)
    second = nil
    try await eventually { server.subscriberCount == 1 }
    server.stop()
    #expect(server.subscriberCount == 0)
    #expect(!FileManager.default.fileExists(atPath: server.socketURL.path))
    try server.start()
    #expect(server.isRunning)
}

@Test @MainActor func flexbarMalformedOversizedAndRepeatedFramesDisconnect() async throws {
    let path = testSocketURL(), server = FlexbarServer(socketURL: path)
    defer { server.stop(); try? FileManager.default.removeItem(at: path.deletingLastPathComponent()) }
    try server.start()
    for message in ["garbage\n", "{\"version\":2,\"kind\":\"subscribe\"}\n", String(repeating: "x", count: 65_537),
                    "{\"version\":1,\"kind\":\"subscribe\"}\n{\"version\":1,\"kind\":\"subscribe\"}\n"] {
        let peer = try FlexbarTestPeer(path: path.path)
        peer.send(message)
        try await Task.sleep(for: .milliseconds(20))
        #expect(server.subscriberCount == 0)
    }
}

@Test @MainActor func flexbarPermissionsLiveInstanceAndSymlinkProtection() async throws {
    let path = testSocketURL(), server = FlexbarServer(socketURL: path)
    defer { server.stop(); try? FileManager.default.removeItem(at: path.deletingLastPathComponent()) }
    try server.start()
    var info = stat()
    #expect(lstat(path.path, &info) == 0 && info.st_mode & 0o777 == 0o600)
    #expect(lstat(path.deletingLastPathComponent().path, &info) == 0 && info.st_mode & 0o777 == 0o700)
    let second = FlexbarServer(socketURL: path)
    #expect(throws: FlexbarServer.Failure.self) { try second.start() }
    second.stop()
    #expect(FileManager.default.fileExists(atPath: path.path))
    server.stop()
    let target = path.deletingLastPathComponent().appendingPathComponent("target")
    try "keep".write(to: target, atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(at: path, withDestinationURL: target)
    #expect(throws: FlexbarServer.Failure.self) { try server.start() }
    #expect(try String(contentsOf: target, encoding: .utf8) == "keep")
}

@Test @MainActor func flexbarSlowReaderHasBoundedOutput() async throws {
    let path = testSocketURL(), server = FlexbarServer(socketURL: path)
    defer { server.stop(); try? FileManager.default.removeItem(at: path.deletingLastPathComponent()) }
    try server.start()
    let peer = try FlexbarTestPeer(path: path.path)
    peer.send("{\"version\":1,\"kind\":\"subscribe\"}\n")
    try await eventually { server.subscriberCount == 1 }
    for revision in 1...2000 { server.publish(sampleSnapshot(UInt64(revision), text: String(repeating: "大", count: 4096))) }
    #expect(server.bufferedOutputBytes <= 2 * (FlexbarServer.maximumFrameBytes + 1))
    #expect(server.bufferedOutputBytes > 0)
}

@Test @MainActor func flexbarSleepRestartInvalidatesObserversAndSessionIdentity() async throws {
    let path = testSocketURL()
    let (model, defaults, suite) = try testModel(path: path)
    defer { model.stop(); defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: path.deletingLastPathComponent()) }
    model.preferences.flexbarEnabled = true
    model.flexbar.start(model: model)
    let first = try FlexbarTestPeer(path: path.path)
    first.send("{\"version\":1,\"kind\":\"subscribe\"}\n")
    try await eventually { model.flexbar.subscriberCount == 1 }
    let old = try JSONDecoder().decode(FlexbarSnapshot.self, from: try #require(first.frames().first))
    model.flexbar.sleep()
    #expect(!model.flexbar.isRunning && model.flexbar.subscriberCount == 0)
    let sleep = try JSONDecoder().decode(FlexbarSnapshot.self, from: try #require(first.frames().first))
    #expect(sleep.suspended)
    model.flexbar.wake()
    let second = try FlexbarTestPeer(path: path.path)
    second.send("{\"version\":1,\"kind\":\"subscribe\"}\n")
    try await eventually { model.flexbar.subscriberCount == 1 }
    let new = try JSONDecoder().decode(FlexbarSnapshot.self, from: try #require(second.frames().first))
    #expect(new.sessionID != old.sessionID && !new.suspended)
    model.stop()
    model.preferences.flexbarEnabled = false
    try await Task.sleep(for: .milliseconds(10))
    #expect(!model.flexbar.isRunning)
}

@Test func flexbarProjectionIsBoundedAndExcludesPrivateData() throws {
    let snapshot = FlexbarSnapshot.project(sessionID: UUID(), trackRevision: 1, documentRevision: 2,
        title: "Song", artist: "Artist", phase: .ready, isSearching: false, isPlaying: false,
        instrumental: false, synced: true, current: .init(id: 0, time: 0, text: String(repeating: "👩🏽‍🚀", count: 5000)),
        next: nil, showTranslation: true)
    #expect(snapshot.primary.count <= 4096 && snapshot.primary.utf8.count <= 8192)
    let object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
    #expect(object["position"] == nil && object["artwork"] == nil && object["document"] == nil)
    var changed = snapshot; changed.revision = 99; changed.sessionID = UUID()
    #expect(snapshot.hasSamePresentation(as: changed))
    let controls = sampleSnapshot(text: String(repeating: "\u{0000}", count: 4000))
    #expect(try JSONEncoder().encode(controls).count < 65_536)
}

@Test func flexbarCueCadenceDoesNotUseDesktopAnimationRate() {
    let doc = LyricsDocument(lines: [.init(id: 0, time: 0, text: "First"), .init(id: 1, time: 3, text: "Next")])
    #expect(FlexbarCueCadence.milliseconds(document: doc, position: 0.1) == 250)
    #expect(FlexbarCueCadence.milliseconds(document: doc, position: 2.95) < 51)
    #expect(FlexbarCueCadence.milliseconds(document: doc, position: 5) == 250)
}

@Test @MainActor func flexbarTimeoutConnectionLimitAndPathLength() async throws {
    let path = testSocketURL(), server = FlexbarServer(socketURL: path, handshakeSeconds: 0.1)
    defer { server.stop(); try? FileManager.default.removeItem(at: path.deletingLastPathComponent()) }
    try server.start()
    var peers: [FlexbarTestPeer] = []
    for count in 1...4 {
        let peer = try FlexbarTestPeer(path: path.path)
        peer.send("{\"version\":1,\"kind\":\"subscribe\"}\n")
        peers.append(peer)
        try await eventually { server.subscriberCount == count }
    }
    peers.append(try FlexbarTestPeer(path: path.path))
    try await Task.sleep(for: .milliseconds(5))
    #expect(server.connectionCount == 4)
    peers.removeAll()
    try await eventually { server.connectionCount == 0 }
    let idle = try FlexbarTestPeer(path: path.path)
    try await eventually { server.connectionCount == 1 }
    try await eventually { server.connectionCount == 0 }
    #expect(idle.frames().isEmpty)
    let long = FlexbarServer(socketURL: URL(fileURLWithPath: "/tmp/" + String(repeating: "a", count: 110)))
    #expect(throws: FlexbarServer.Failure.self) { try long.start() }
}

@Test @MainActor func flexbarWriterCancellationAndFastReconnect() async throws {
    let path = testSocketURL(), server = FlexbarServer(socketURL: path)
    defer { server.stop(); try? FileManager.default.removeItem(at: path.deletingLastPathComponent()) }
    try server.start()
    for _ in 0..<12 {
        var peer: FlexbarTestPeer? = try FlexbarTestPeer(path: path.path)
        peer?.send("{\"version\":1,\"kind\":\"subscribe\"}\n")
        try await eventually { server.subscriberCount == 1 }
        for revision in 1...60 { server.publish(sampleSnapshot(UInt64(revision), text: String(repeating: "大", count: 4096))) }
        #expect(server.bufferedOutputBytes > 0)
        peer = nil
        try await eventually { server.connectionCount == 0 }
        #expect(server.bufferedOutputBytes == 0)
        server.stop(); try server.start()
    }
}

@Test @MainActor func flexbarStaleSocketAndParentSymlinkProtection() throws {
    let path = testSocketURL(), server = FlexbarServer(socketURL: path)
    defer { server.stop(); try? FileManager.default.removeItem(at: path.deletingLastPathComponent()) }
    try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: Array(path.path.utf8) + [0]) }
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    let result = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    #expect(result == 0); close(fd)
    try server.start()
    #expect(server.isRunning)
    server.stop()
    let app = path.deletingLastPathComponent().appendingPathComponent("LyricsX Next")
    let target = path.deletingLastPathComponent().appendingPathComponent("target")
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
    try FileManager.default.createSymbolicLink(at: app, withDestinationURL: target)
    let unsafe = FlexbarServer(socketURL: app.appendingPathComponent("Flexbar/bridge.sock"))
    #expect(throws: FlexbarServer.Failure.self) { try unsafe.start() }
    #expect(!FileManager.default.fileExists(atPath: target.appendingPathComponent("Flexbar").path))
}

@Test @MainActor func flexbarSecondConsumerCannotConsumePendingBroadcast() async throws {
    let path = testSocketURL()
    let (model, defaults, suite) = try testModel(path: path)
    defer { model.stop(); defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: path.deletingLastPathComponent()) }
    model.preferences.flexbarEnabled = true
    let track = Track(playerID: "test", playerName: "Test", title: "Song")
    model.session.accept(.init(track: track, position: 0, isPlaying: true), shouldSearch: false)
    model.session.use(.init(lines: [.init(id: 0, time: 0, text: "First"), .init(id: 1, time: 10, text: "Second")]))
    model.flexbar.start(model: model)
    let first = try FlexbarTestPeer(path: path.path)
    first.send("{\"version\":1,\"kind\":\"subscribe\"}\n")
    try await eventually { model.flexbar.subscriberCount == 1 }
    _ = first.frames()
    model.session.accept(.init(track: track, position: 10, isPlaying: false))
    let second = try FlexbarTestPeer(path: path.path)
    second.send("{\"version\":1,\"kind\":\"subscribe\"}\n")
    try await eventually { model.flexbar.subscriberCount == 2 }
    let oldPeerFrames = first.frames().compactMap { try? JSONDecoder().decode(FlexbarSnapshot.self, from: $0) }
    let newPeerFrames = second.frames().compactMap { try? JSONDecoder().decode(FlexbarSnapshot.self, from: $0) }
    #expect(oldPeerFrames.last?.primary == "Second" && oldPeerFrames.last?.isPlaying == false)
    #expect(newPeerFrames.last?.primary == "Second" && newPeerFrames.last?.isPlaying == false)
}

@Test @MainActor func flexbarClockHandshakeDisconnectCannotUnderflowConsumers() async throws {
    let path = testSocketURL(), server = FlexbarServer(socketURL: path)
    defer { server.stop(); try? FileManager.default.removeItem(at: path.deletingLastPathComponent()) }
    var observed: [Int] = []
    server.onSubscriberCount = { observed.append($0) }
    try server.start()
    let stable = try FlexbarTestPeer(path: path.path)
    stable.send("{\"version\":1,\"kind\":\"subscribe\"}\n")
    try await eventually { server.subscriberCount == 1 }
    for _ in 0..<20 {
        var peer: FlexbarTestPeer? = try FlexbarTestPeer(path: path.path)
        peer?.send("{\"version\":1,\"kind\":\"subscribe\",\"clientTime\":123}\n")
        peer = nil
        try await Task.sleep(for: .milliseconds(2))
        #expect(server.subscriberCount == 1)
    }
    #expect(observed.allSatisfy { $0 >= 1 })
}

@Test @MainActor func flexbarNativeSocketInteroperatesWithActualNodeClient() async throws {
    let path = testSocketURL()
    let (model, defaults, suite) = try testModel(path: path)
    let process = Process(), output = Pipe(), errors = Pipe()
    defer {
        if process.isRunning { process.terminate() }
        model.stop(); defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: path.deletingLastPathComponent())
    }
    model.preferences.flexbarEnabled = true
    let track = Track(playerID: "test", playerName: "Test", title: "Interop", duration: 30)
    model.session.accept(.init(track: track, position: 1, isPlaying: true), shouldSearch: false)
    model.session.use(.init(lines: [.init(id: 0, time: 0, text: "Interop歌词", translation: "Interop translation"), .init(id: 1, time: 20, text: "Next")]))
    model.flexbar.start(model: model)
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["node", root.appendingPathComponent("Integrations/Flexbar/tools/native-interop.mjs").path, path.path]
    process.standardOutput = output; process.standardError = errors
    try process.run()
    for _ in 0..<200 where model.flexbar.subscriberCount == 0 { try await Task.sleep(for: .milliseconds(5)) }
    #expect(model.flexbar.subscriberCount == 1)
    try await Task.sleep(for: .milliseconds(15))
    model.session.accept(.init(track: track, position: 2, isPlaying: false))
    try await Task.sleep(for: .milliseconds(15))
    model.session.seek(to: 3); model.flexbar.synchronizePlayback(force: true)
    try await Task.sleep(for: .milliseconds(20))
    model.flexbar.sleep(); model.flexbar.wake()
    for _ in 0..<600 where process.isRunning { try await Task.sleep(for: .milliseconds(10)) }
    #expect(!process.isRunning)
    if process.isRunning { process.terminate(); return }
    let data = output.fileHandleForReading.readDataToEndOfFile()
    let diagnostics = errors.fileHandleForReading.readDataToEndOfFile()
    #expect(process.terminationStatus == 0, "\(String(decoding: diagnostics, as: UTF8.self))")
    let record = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(record["nonceVerified"] as? Bool == true)
    let events = try #require(record["events"] as? [[String: Any]])
    #expect(events.map { $0["event"] as? String } == ["initial", "pause", "seek", "reconnect"])
    #expect(events[0]["text"] as? String == "Interop歌词")
    #expect(events[1]["rate"] as? Double == 0)
    #expect(events[2]["position"] as? Double == 3)
    #expect(events[3]["changedSession"] as? Bool == true)
    print("Flexbar Swift/Node interop: \(String(decoding: data, as: UTF8.self))")
}
