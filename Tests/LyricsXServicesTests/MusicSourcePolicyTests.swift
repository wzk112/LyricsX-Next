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

@Test(arguments: [
    "org.Petrichor", "org.Petrichor.debug", "com.swinsian.Swinsian",
    "co.brushedtype.doppler-macos", "org.cogx.cog", "com.foobar2000.mac",
    "com.coppertino.Vox", "com.digipine.pineplayer", "com.digipine.pineplayer.pro",
    "com.digipine.pineplayer.origin", "gaborhargitai.colibri", "org.tordini.flavio.musique",
    "org.strawberrymusicplayer.strawberry", "com.listen1.listen1",
    "cn.toside.music.desktop", "fun.upup.musicfree",
])
func additionalMusicPlayersDoNotRequireMusicCategory(bundleID: String) {
    // Some independent players omit or change their category. Their verified
    // identity must work through both discovery and MediaRemote's ID-only path.
    #expect(MusicSourcePolicy.accepts(bundleID: bundleID))
    #expect(MusicSourcePolicy.accepts(bundleID: bundleID.uppercased(), category: "public.app-category.entertainment"))
    // A recognized app must not grant an arbitrary suffix / prefix the same identity.
    #expect(!MusicSourcePolicy.accepts(bundleID: bundleID + ".unverified"))
    #expect(!MusicSourcePolicy.accepts(bundleID: "unverified." + bundleID))
}

@Test func musicNamesAndUnverifiedAliasesDoNotGrantPlayerIdentity() {
    for id in ["com.catalystwo.cog", "com.simnetiq.vpnreact", "social.colibri.app",
               "com.pinkmusic.app", "Apple Music Downloader", "com.electron.unverifiedmusic",
               "org.petrichor-preview", "com.swinsian.Swinsian-Quick-Controller"] {
        #expect(!MusicSourcePolicy.accepts(bundleID: id))
    }
    for id in ["com.apple.Safari.WebApp.org.Petrichor", "com.google.Chrome.com.listen1.listen1",
               "company.thebrowser.Browser.fun.upup.musicfree"] {
        #expect(!MusicSourcePolicy.accepts(bundleID: id, category: "public.app-category.music"))
    }
    // Preserve the existing fallback for an uncatalogued music app and the
    // signed iOS-on-Mac variants already supported by QQ Music / NetEase Music.
    #expect(MusicSourcePolicy.accepts(bundleID: "unlisted.local.player", category: "public.app-category.music"))
    #expect(MusicSourcePolicy.accepts(bundleID: "com.netease.163music.D5Q73692VW"))
    #expect(!MusicSourcePolicy.accepts(bundleID: "com.netease.163musical.D5Q73692VW"))
    #expect(!MusicSourcePolicy.accepts(bundleID: ""))
    #expect(!MusicSourcePolicy.accepts(bundleID: nil, category: "public.app-category.music"))
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

@Test @MainActor func resumeRetargetsAnAlreadySleepingPausedPollLoop() async throws {
    var reads = 0, emissions = 0
    var playing = false
    let track = Track(playerID: "com.apple.Music", playerName: "Music", title: "Resume fixture", duration: 120)
    let bridge = PlayerBridge(snapshotReader: {
        reads += 1
        return .init(track: track, position: Double(reads), isPlaying: playing)
    }, artworkReader: { _ in nil })
    bridge.onSnapshot = { _ in emissions += 1 }
    defer { bridge.stop() }
    func wait(until condition: () -> Bool, seconds: Double) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(seconds))
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
        #expect(condition())
    }
    bridge.start()
    // After the second automatic paused read the loop has entered its real
    // five-second sleep, rather than merely reporting a five-second policy.
    try await wait(until: { emissions >= 2 }, seconds: 2)
    let pausedReads = reads
    playing = true
    bridge.refresh() // the same path used by the player's resume notification
    try await wait(until: { emissions > pausedReads }, seconds: 0.5)
    let resumedReads = reads
    #expect(bridge.pollInterval == 1)
    try await wait(until: { reads > resumedReads }, seconds: 1.8)
    // The fresh sample must precede PlaybackTimeline's three-second stale
    // cutoff; waiting out the former paused deadline would freeze both views.
    #expect(reads == resumedReads + 1)
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
