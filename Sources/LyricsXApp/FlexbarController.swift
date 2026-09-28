import Foundation
import Observation
import LyricsXCore

struct FlexbarPlaybackGate {
    static func shouldBuild(force: Bool, presentationChanged: Bool,
                            previous: FlexbarSnapshot.Clock?, now: Double,
                            position: Double, isPlaying: Bool) -> Bool {
        guard let previous else { return true }
        let elapsed = max(0, now - previous.hostUptime)
        let predicted = previous.position + elapsed * previous.rate
        return force || presentationChanged || abs(position - predicted) > 0.05
            || (isPlaying && elapsed >= 5)
    }
}

@Observable @MainActor final class FlexbarController {
    private struct PresentationKey: Equatable {
        let trackRevision: UInt64
        let documentRevision: UInt64
        let lineIndex: Int?
        let title: String?
        let artist: String?
        let duration: Double?
        let phase: LyricsPhase
        let isSearching: Bool
        let isPlaying: Bool
        let placeholder: Bool
        let offsetMilliseconds: Int?
        let conversion: String
    }

    private(set) var subscriberCount = 0
    private(set) var status = "未启用"
    @ObservationIgnored private let server: FlexbarServer
    @ObservationIgnored private weak var model: AppModel?
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var started = false
    @ObservationIgnored private var sleeping = false
    @ObservationIgnored private var observing = false
    @ObservationIgnored private var sessionID = UUID()
    @ObservationIgnored private var revision: UInt64 = 0
    @ObservationIgnored private var last: FlexbarSnapshot?
    @ObservationIgnored private var lastPresentationKey: PresentationKey?
    @ObservationIgnored private var presentationGeneration: UInt64 = 0
    @ObservationIgnored private(set) var snapshotBuildCount = 0

    init(socketURL: URL = FlexbarServer.defaultURL) { server = FlexbarServer(socketURL: socketURL) }
    var hasConsumers: Bool { subscriberCount > 0 && !sleeping }
    var isRunning: Bool { server.isRunning }
    var bufferedOutputBytes: Int { server.bufferedOutputBytes }

    func start(model: AppModel) {
        guard !started else { return }
        started = true; sleeping = false; self.model = model
        server.onSubscriberCount = { [weak self] count in self?.consumersChanged(count) }
        server.onFirstSnapshot = { [weak self] in
            guard let self else { return nil }
            guard var value = self.currentSnapshot() else { return nil }
            if self.last?.hasSamePresentation(as: value) != true { self.assignRevision(&value) }
            // Only the first consumer can establish a private initial baseline;
            // later arrivals must not consume pending broadcasts for existing peers.
            if self.subscriberCount == 1 {
                self.last = value
                self.lastPresentationKey = self.presentationKey()
            }
            return value
        }
        observeEnabled()
    }

    private func observeEnabled() {
        guard started, let model else { return }
        let token = generation
        var enabled = false
        withObservationTracking { enabled = model.preferences.flexbarEnabled } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.started, self.generation == token else { return }
                self.observeEnabled()
            }
        }
        reconcileEnabled(enabled)
    }

    private func reconcileEnabled(_ enabled: Bool) {
        if enabled && !sleeping {
            guard !server.isRunning else { return }
            do {
                try server.start(); sessionID = UUID(); revision = 0; last = nil; lastPresentationKey = nil
                status = "等待 Flexbar 插件连接"
            } catch { status = error.localizedDescription }
        } else {
            server.stop(); observing = false; presentationGeneration &+= 1; last = nil; lastPresentationKey = nil
            status = sleeping ? "睡眠中" : "未启用"
        }
    }

    private func consumersChanged(_ count: Int) {
        subscriberCount = count
        if count > 0 {
            status = "已连接 · \(count)"
            if !observing { observing = true; observePresentation(publish: false) }
        } else {
            observing = false; presentationGeneration &+= 1
            status = server.isRunning ? "等待 Flexbar 插件连接" : status
        }
    }

    private func observePresentation(publish: Bool = true) {
        guard started, !sleeping, hasConsumers, let model else { return }
        let token = presentationGeneration
        withObservationTracking {
            _ = model.session.trackRevision
            _ = model.session.track?.title; _ = model.session.track?.artist
            _ = model.session.documentRevision
            _ = model.session.currentLineIndex
            _ = model.session.isPlaying; _ = model.session.phase; _ = model.session.isSearching
            _ = model.preferences.conversion
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.started, self.presentationGeneration == token, self.observing else { return }
                self.observePresentation()
            }
        }
        if publish, var value = currentSnapshot(), last?.hasSamePresentation(as: value) != true {
            assignRevision(&value)
            last = value; lastPresentationKey = presentationKey(); server.publish(value)
        }
    }

    private func presentationKey() -> PresentationKey? {
        guard let model else { return nil }
        let session = model.session
        return .init(trackRevision: session.trackRevision, documentRevision: session.documentRevision,
                     lineIndex: session.currentLineIndex, title: session.track?.title,
                     artist: session.track?.artist, duration: session.track?.duration,
                     phase: session.phase, isSearching: session.isSearching,
                     isPlaying: session.isPlaying, placeholder: session.documentIsPlaceholder,
                     offsetMilliseconds: session.document?.offsetMilliseconds,
                     conversion: model.preferences.conversion)
    }

    private func currentSnapshot() -> FlexbarSnapshot? {
        guard let model else { return nil }
        snapshotBuildCount += 1
        let session = model.session
        let doc = session.document
        let index = session.currentLineIndex
        let line = index.flatMap { doc?.lines.indices.contains($0) == true ? doc?.lines[$0] : nil }
        let nextIndex = (index ?? -1) + 1
        let following = doc?.lines.dropFirst(nextIndex)
        let next = following?.first { FlexbarSnapshot.isDisplayableLyric($0.text) }
        let nextCue = following?.first
        var value = FlexbarSnapshot.project(sessionID: sessionID, trackRevision: session.trackRevision,
            documentRevision: session.documentRevision, title: session.track?.title, artist: session.track?.artist,
            phase: session.phase, isSearching: session.isSearching, isPlaying: session.isPlaying,
            instrumental: doc?.isInstrumental == true || session.documentIsPlaceholder, synced: doc?.isSynced == true,
            current: line, next: next, showTranslation: true, transform: model.preferences.text)
        value.suspended = sleeping
        let uptime = ProcessInfo.processInfo.systemUptime
        value.clock = .init(hostUptime: uptime, position: session.presentationPosition(at: uptime),
                            rate: session.isPlaying && !sleeping ? 1 : 0)
        if value.state == .lyrics, let line {
            var location = 0
            let words = TimedLyricFragment.make(line: line, text: model.preferences.text(line.text)).compactMap { fragment -> FlexbarSnapshot.TimedRange? in
                defer { location += fragment.text.count }
                guard let cue = fragment.cue, location + fragment.text.count <= value.primary.count,
                      cue.start.isFinite, cue.end.isFinite else { return nil }
                return .init(location: location, length: fragment.text.count, start: cue.start, end: cue.end)
            }
            let end = nextCue?.time ?? max(line.time, words.map(\.end).max() ?? line.time,
                                        (session.track?.duration ?? 0) + Double(doc?.offsetMilliseconds ?? 0) / 1000)
            value.timing = .init(start: line.time, end: end, offsetMilliseconds: doc?.offsetMilliseconds ?? 0, words: words)
        }
        value.revision = revision
        // The caller controls broadcast; connection snapshots are immediate even while paused.
        return value
    }

    private func assignRevision(_ value: inout FlexbarSnapshot) { revision &+= 1; value.revision = revision }

    /// Called by player snapshots and explicit seeks, never by the lyric ticker.
    func synchronizePlayback(force: Bool = false) {
        guard hasConsumers, let model else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard FlexbarPlaybackGate.shouldBuild(force: force,
            presentationChanged: presentationKey() != lastPresentationKey,
            previous: last?.clock, now: now,
            position: model.session.presentationPosition(at: now), isPlaying: model.session.isPlaying) else { return }
        guard let value = currentSnapshot() else { return }
        var updated = value
        let shouldPublish = force || last?.hasSamePresentation(as: updated) != true
                || FlexbarPlaybackGate.shouldBuild(force: false, presentationChanged: false,
                    previous: last?.clock, now: updated.clock?.hostUptime ?? now,
                    position: updated.clock?.position ?? 0, isPlaying: updated.isPlaying)
        lastPresentationKey = presentationKey()
        guard shouldPublish else { return }
        assignRevision(&updated)
        last = updated; server.publish(updated)
    }

    func sleep() {
        guard started else { return }
        sleeping = true
        if var value = currentSnapshot() { value.suspended = true; assignRevision(&value); server.publish(value) }
        server.stop(); observing = false; presentationGeneration &+= 1; status = "睡眠中"
    }
    func wake() { guard started, let model else { return }; sleeping = false; reconcileEnabled(model.preferences.flexbarEnabled) }
    func stop() {
        started = false; generation &+= 1; presentationGeneration &+= 1; observing = false
        server.stop(); last = nil; lastPresentationKey = nil; model = nil; status = "未启用"
    }
}
