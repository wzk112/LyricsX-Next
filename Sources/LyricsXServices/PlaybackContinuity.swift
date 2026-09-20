import Foundation
import LyricsXCore

/// Reconcile incomplete player reads before any UI, artwork, or lyric search
/// observes them. A confirmed new track is delivered immediately; an empty
/// response needs repeated observations, rather than an error-label timer.
struct PlaybackContinuity {
    private(set) var latest: PlaybackSnapshot?
    private var emptySince: Double?
    private var emptyCount = 0
    private var failureSince: Double?
    private var failureCount = 0

    mutating func accept(_ sample: PlaybackSnapshot, now: Double) -> PlaybackSnapshot? {
        failureSince = nil; failureCount = 0
        var sample = sample
        guard var track = sample.track else {
            emptyCount += 1
            if emptySince == nil { emptySince = now }
            if latest?.track != nil, emptyCount < 2 || now - (emptySince ?? now) < 2 {
                // A pause notification can lack metadata yet still carry a
                // reliable playback state. Apply that state to the known track.
                if sample.playbackStateIsReliable, var retained = latest {
                    retained.isPlaying = sample.isPlaying
                    retained.sampledAt = sample.sampledAt
                    retained.positionIsReliable = false
                    retained.playbackStateIsReliable = true
                    latest = retained
                    return retained
                }
                return nil
            }
            sample.positionIsReliable = true
            sample.playbackStateIsReliable = true
            latest = sample
            return sample
        }
        emptySince = nil; emptyCount = 0
        if let previous = latest?.track, previous.representsSamePlaybackItem(as: track) {
            // IDs absent from MediaRemote must not restart the same song when
            // the Apple Events fallback supplies a persistent ID (or vice versa).
            if !previous.persistentID.isEmpty { track.persistentID = previous.persistentID }
            if track.title.isEmpty { track.title = previous.title }
            if track.artist.isEmpty { track.artist = previous.artist }
            if track.album.isEmpty { track.album = previous.album }
            if track.duration <= 0 { track.duration = previous.duration }
            if track.artworkData == nil, track.artworkURL == nil {
                track.artworkData = previous.artworkData
                track.artworkURL = previous.artworkURL
            }
            if track.embeddedLyrics == nil { track.embeddedLyrics = previous.embeddedLyrics }
            if track.localFileURL == nil { track.localFileURL = previous.localFileURL }
        }
        sample.track = track
        latest = sample
        return sample
    }

    mutating func shouldReportFailure(now: Double) -> Bool {
        emptySince = nil; emptyCount = 0
        failureCount += 1
        if failureSince == nil { failureSince = now }
        return failureCount >= 3 && now - (failureSince ?? now) >= 2
    }
}
