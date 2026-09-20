import AppKit
import Observation
import LyricsXCore

enum OverlayPresentationMode: Int {
    case lyrics, waiting, song
    static let waitingHeight = 96.0
}

/// A short handover owns a coherent old frame, never a mix of the new title
/// and the previous song's lyrics. No player or cache state is modified.
struct OverlayDisplaySnapshot {
    let track: Track?
    let trackRevision: UInt64
    let document: LyricsDocument?
    let documentRevision: UInt64
    let index: Int?
    let artwork: NSImage?
    let mode: OverlayPresentationMode
    var compact: Bool { mode != .lyrics }
    let searching: Bool
    var position: Double
    var playing: Bool
    let sampledAt: Double

    @MainActor init(model: AppModel, at now: Double) {
        track = model.session.track; trackRevision = model.session.trackRevision
        document = model.session.document
        documentRevision = model.session.documentRevision
        index = model.session.currentLineIndex; artwork = model.artwork
        mode = model.overlayPresentationMode; searching = model.session.isSearching
        position = model.session.presentationPosition(at: now)
        playing = model.session.isPlaying; sampledAt = now
    }
    func frozen(at now: Double) -> Self {
        var value = self
        if playing { value.position += max(0, now - sampledAt) }
        if let duration = track?.duration, duration > 0 { value.position = min(duration, value.position) }
        value.playing = false
        return value
    }
}

@Observable @MainActor final class OverlayPresentation {
    nonisolated static let handoverDuration = 0.16
    private(set) var held: OverlayDisplaySnapshot?
    private(set) var preparingSince: Double?
    @ObservationIgnored private var last: OverlayDisplaySnapshot?
    @ObservationIgnored private var pendingSearch: UInt64?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation: UInt64 = 0

    func update(model: AppModel, at now: Double = ProcessInfo.processInfo.systemUptime) {
        let live = OverlayDisplaySnapshot(model: model, at: now)
        let searchingForSong = live.track != nil && live.document == nil && live.searching
        let enteringCard = live.compact && last?.compact == false
        guard !model.preferences.reduceMotion, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              searchingForSong || enteringCard, let last, last.document != nil else {
            stop(); self.last = live
            return
        }
        let search = model.session.searchGeneration
        guard pendingSearch != search else { return }
        pendingSearch = search
        // Rapid skips share the first deadline, so the old frame cannot linger.
        let beginning = preparingSince ?? now
        held = last.frozen(at: beginning); preparingSince = beginning
        generation &+= 1
        let token = generation
        task?.cancel()
        task = Task { [weak self, weak model] in
            do { try await Task.sleep(for: .seconds(max(0, beginning + Self.handoverDuration - now))) }
            catch { return }
            guard let self, let model, self.generation == token else { return }
            self.finishIfDue(model: model, at: ProcessInfo.processInfo.systemUptime)
        }
    }
    func finishIfDue(model: AppModel, at now: Double) {
        guard let preparingSince, now >= preparingSince + Self.handoverDuration else { return }
        last = OverlayDisplaySnapshot(model: model, at: now)
        stop()
    }
    func stop() {
        task?.cancel(); task = nil; generation &+= 1
        if held != nil { held = nil }
        if preparingSince != nil { preparingSince = nil }
        pendingSearch = nil
    }
}
