import Testing
import AppKit
import LyricsXCore
@testable import LyricsXServices

@Test func automaticSourcePolicyAcceptsMusicAndRejectsBrowserHelpers() {
    for id in ["com.apple.Music", "com.spotify.client", "com.netease.163music", "com.tencent.QQMusicMac", "com.tencent.QQMusic.D5Q73692VW"] {
        #expect(MusicSourcePolicy.accepts(bundleID: id))
    }
    for id in ["com.apple.Safari", "com.apple.Safari.WebApp.example", "com.google.Chrome.helper", "com.microsoft.edgemac", "org.mozilla.firefox", "company.thebrowser.Browser", "com.lyricsx.modern"] {
        #expect(!MusicSourcePolicy.accepts(bundleID: id, category: "public.app-category.music"))
    }
    #expect(!MusicSourcePolicy.accepts(bundleID: nil))
    #expect(!MusicSourcePolicy.accepts(bundleID: "unknown.player"))
    #expect(MusicSourcePolicy.accepts(bundleID: "another.musicplayer", category: "public.app-category.music"))
    #expect(!MusicSourcePolicy.accepts(bundleID: "another.browser", category: "public.app-category.productivity"))
}

@Test @MainActor func pausedNotifyingPlayersBackOffButManualRefreshWakesImmediately() async throws {
    var reads = 0
    var playing = false
    let track = Track(playerID: "com.apple.Music", playerName: "Music", title: "Test", artist: "Test", duration: 120)
    let bridge = PlayerBridge(snapshotReader: {
        reads += 1
        return .init(track: track, position: 10, isPlaying: playing)
    })
    defer { bridge.stop() }
    bridge.refresh()
    for _ in 0..<100 where reads == 0 { try await Task.sleep(for: .milliseconds(2)) }
    #expect(bridge.pollInterval == 5)
    playing = true
    bridge.refresh()
    for _ in 0..<100 where reads < 2 { try await Task.sleep(for: .milliseconds(2)) }
    #expect(reads == 2)
    #expect(bridge.pollInterval == 1)
}

@Test @MainActor func musicDiscoveryCachesEmptyAndPopulatedSnapshotsUntilInvalidated() {
    var reads = 0
    var running: [NSRunningApplication] = []
    var terminated = false
    var snapshot = MusicApplicationSnapshot(discover: { reads += 1; return running }, isTerminated: { _ in terminated })
    for _ in 0..<100 { #expect(snapshot.applications().isEmpty) }
    #expect(reads == 1)
    running = [NSRunningApplication.current]
    snapshot.invalidate() // launch / wake / restart
    for _ in 0..<100 { #expect(snapshot.applications().count == 1) }
    #expect(reads == 2)
    terminated = true // catches termination even before its notification is delivered
    #expect(snapshot.applications().isEmpty)
    #expect(reads == 3)
    running = []
    snapshot.invalidate() // stop
    #expect(snapshot.applications().isEmpty)
    #expect(reads == 4)
}

@Test @MainActor func stoppedBridgeIgnoresQueuedDiscoveryAndReleasesLoop() async throws {
    var reads = 0
    var bridge: PlayerBridge? = PlayerBridge(snapshotReader: {
        reads += 1; return .init(track: nil, position: 0, isPlaying: false)
    })
    weak var reference = bridge
    bridge?.start()
    NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didLaunchApplicationNotification, object: nil, userInfo: [NSWorkspace.applicationUserInfoKey: NSRunningApplication.current])
    bridge?.stop()
    bridge = nil
    try await Task.sleep(for: .milliseconds(50))
    #expect(reference == nil)
    #expect(reads == 0)
}
