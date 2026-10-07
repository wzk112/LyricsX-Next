import AppKit
import Foundation
import Testing
import LyricsXCore
@testable import LyricsXServices

@Test func closedPlayerSkipsTheScriptEntirely() async throws {
    let result = try await RunningPlayerScript.runJavaScript(bundleID: "test.lyricsx.absent-player",
        body: "throw new Error('A closed player must never be queried');")
    #expect(result == nil)
}

@Test func aDeadProcessTargetFailsWithoutResolvingAnApplicationByName() async throws {
    let result = try await RunningPlayerScript.runJavaScript(processIdentifier: Int32.max, bundleID: "com.apple.Music",
        body: "return app.name();")
    #expect(result.status != 0)
}

private let quitTrack = Track(playerID: "com.apple.Music", playerName: "Apple Music", persistentID: "track-1",
                              title: "Song", artist: "Artist", album: "Album")

@Test func artworkReadsOnlyTheCapturedProcessAndReturnsOriginalBinaryBytes() throws {
    let bytes = Data([0x89, 0x50, 0x4e, 0x47, 1, 2, 3])
    var replies = [NSAppleEventDescriptor(string: "track-reference"), .init(string: "track-1"),
                   .init(string: "Song"), .init(string: "Artist"), .init(string: "Album"),
                   NSAppleEventDescriptor(descriptorType: MusicArtworkReader.code("PNGf"), data: bytes)!,
                   .init(string: "track-reference"), .init(string: "track-1"),
                   .init(string: "Song"), .init(string: "Artist"), .init(string: "Album")]
    var events: [NSAppleEventDescriptor] = []
    let result = try MusicArtworkReader.read(track: quitTrack, processIdentifier: 12345) { event in
        events.append(event)
        let target = try #require(event.attributeDescriptor(forKeyword: MusicArtworkReader.code("addr")))
        #expect(target.descriptorType == MusicArtworkReader.code("kpid"))
        #expect(target.data == NSAppleEventDescriptor(processIdentifier: 12345).data)
        let reply = NSAppleEventDescriptor.record()
        reply.setParam(replies.removeFirst(), forKeyword: MusicArtworkReader.code("----"))
        return reply
    }
    #expect(result == bytes)
    #expect(replies.isEmpty)
    // The raw bytes come from artwork 1 of the captured track reference.
    let raw = try #require(events[5].paramDescriptor(forKeyword: MusicArtworkReader.code("----")))
    let artwork = try #require(raw.forKeyword(MusicArtworkReader.code("from")))
    #expect(artwork.forKeyword(MusicArtworkReader.code("want"))?.typeCodeValue == MusicArtworkReader.code("cArt"))
    #expect(artwork.forKeyword(MusicArtworkReader.code("seld"))?.int32Value == 1)
}

@Test func artworkRejectsASongSwitchDuringTheBinaryRead() throws {
    var replies = [NSAppleEventDescriptor(string: "track-reference"), .init(string: "track-1"),
                   .init(string: "Song"), .init(string: "Artist"), .init(string: "Album"),
                   NSAppleEventDescriptor(descriptorType: MusicArtworkReader.code("PNGf"), data: Data([1, 2, 3]))!,
                   .init(string: "other-track"), .init(string: "track-2")]
    let result = try MusicArtworkReader.read(track: quitTrack, processIdentifier: 12345) { _ in
        let reply = NSAppleEventDescriptor.record()
        reply.setParam(replies.removeFirst(), forKeyword: MusicArtworkReader.code("----"))
        return reply
    }
    #expect(result == nil)
    #expect(replies.isEmpty)
}

@Test func artworkMissingOrTerminatedPlayerReturnsNoImage() throws {
    let result = try MusicArtworkReader.read(track: quitTrack, processIdentifier: 12345) { _ in
        let reply = NSAppleEventDescriptor.record()
        reply.setParam(.init(int32: -600), forKeyword: MusicArtworkReader.code("errn"))
        return reply
    }
    #expect(result == nil)
}

/// Opt-in: closes/reopens Music only when it is stopped, restores its initial
/// running state, and never changes tracks, playback, lyrics, or the library.
@Test(.enabled(if: ProcessInfo.processInfo.environment["LYRICSX_MUSIC_QUIT_TEST"] == "1"))
@MainActor func musicCanStayClosedAndQuitRepeatedlyWhileTheBridgeIsRunning() async throws {
    let original = RunningPlayerScript.processIdentifier(for: "com.apple.Music")
    if original != nil {
        let state = try await RunningPlayerScript.runJavaScript(bundleID: "com.apple.Music", body: "if (!app.running()) throw new Error('Running Music was not detected'); return app.playerState();")
        try #require(String(decoding: state!.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) == "stopped")
    }
    func launch() async throws -> NSRunningApplication {
        let config = NSWorkspace.OpenConfiguration(); config.activates = false
        return try await NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Music.app"), configuration: config)
    }
    func waitForExit(_ app: NSRunningApplication) async throws {
        for _ in 0..<80 {
            if app.isTerminated { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        Issue.record("Music did not terminate")
    }
    let bridge = PlayerBridge()
    var samples = 0
    var errors: [String] = []
    bridge.onSnapshot = { _ in samples += 1 }
    bridge.onError = { if let message = $0 { errors.append(message) } }
    bridge.mode = .appleMusic
    defer { bridge.stop() }
    do {
        if let original, let app = NSRunningApplication(processIdentifier: original) {
            #expect(app.terminate()); try await waitForExit(app)
        }
        for iteration in 0..<3 {
            // Cover both explicit Music selection and automatic discovery.
            bridge.mode = iteration == 1 ? .automatic : .appleMusic
            bridge.refresh()
            _ = try? await AppleMusicLyricsSource.readSongField(quitTrack)
            try await Task.sleep(for: .seconds(1))
            #expect(RunningPlayerScript.processIdentifier(for: "com.apple.Music") == nil)
            let app = try await launch()
            let pid = app.processIdentifier
            let before = samples
            bridge.refresh()
            for _ in 0..<30 {
                if samples > before { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            #expect(samples > before, "The running Music bridge must still publish samples")
            #expect(errors.isEmpty)
            let marker = FileManager.default.temporaryDirectory.appendingPathComponent("lyricsx-quit-ready-\(UUID())")
            defer { try? FileManager.default.removeItem(at: marker) }
            let path = String(data: try JSONEncoder().encode(marker.path), encoding: .utf8)!
            let query = Task {
                try await RunningPlayerScript.runJavaScript(processIdentifier: pid, bundleID: "com.apple.Music", body: """
                  if (!app.running()) throw new Error('Running Music was not detected');
                  const state = app.playerState();
                  ObjC.import('Foundation');
                  $(state).writeToFileAtomicallyEncodingError(\(path), true, $.NSUTF8StringEncoding, null);
                  delay(1.5);
                  return app.playerState();
                """)
            }
            for _ in 0..<50 {
                if FileManager.default.fileExists(atPath: marker.path) { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            try #require(FileManager.default.fileExists(atPath: marker.path))
            #expect(app.terminate()); try await waitForExit(app)
            _ = try? await query.value
            #expect(await MusicArtworkReader.read(track: quitTrack, processIdentifier: pid) == nil)
            bridge.refresh()
            try await Task.sleep(for: .seconds(2))
            #expect(RunningPlayerScript.processIdentifier(for: "com.apple.Music") == nil, "Quit cycle \(iteration)")
        }
        if original != nil { _ = try await launch() }
    } catch {
        if original != nil, RunningPlayerScript.processIdentifier(for: "com.apple.Music") == nil { _ = try? await launch() }
        throw error
    }
}
