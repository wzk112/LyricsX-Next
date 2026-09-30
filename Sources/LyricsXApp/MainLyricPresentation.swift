import AppKit
import Observation
import LyricsXCore

struct MainLyricSnapshot {
    let track: Track?
    let trackRevision: UInt64
    let document: LyricsDocument?
    let placeholder: Bool
    let index: Int?
    let position: Double
    let searching: Bool
    var arrivalIdentity: MainLyricArrivalIdentity {
        .init(track: trackRevision, ready: document != nil)
    }

    @MainActor init(model: AppModel) {
        track = model.session.track
        trackRevision = model.session.trackRevision
        document = model.session.document
        placeholder = model.session.documentIsPlaceholder
        index = model.mainLyricIndex
        // Sample the ignored presentation clock; do not subscribe the whole
        // lyric viewport to the session's per-tick position updates.
        position = model.session.presentationPosition()
        searching = model.session.isSearching
    }
}

/// Candidate upgrades for one song can have different document IDs. Only the
/// first ready document participates in the song's viewport arrival animation.
struct MainLyricArrivalIdentity: Equatable, Sendable {
    let track: UInt64
    let ready: Bool
}

/// Keep a coherent departing document across the short metadata/cache gap.
/// The first deadline belongs to the whole burst of rapid skips.
@Observable @MainActor final class MainLyricPresentation {
    nonisolated static let handoverDuration = 0.16
    private(set) var held: MainLyricSnapshot?
    @ObservationIgnored private var last: MainLyricSnapshot?
    @ObservationIgnored private var deadline: Double?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation: UInt64 = 0

    func update(model: AppModel, at now: Double = ProcessInfo.processInfo.systemUptime) {
        let live = MainLyricSnapshot(model: model)
        let needsHandover = live.track != nil && live.document == nil && live.searching
            && live.trackRevision != last?.trackRevision
        guard model.mainWindowVisible, !model.preferences.reduceMotion,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              needsHandover, let last, last.track != nil else {
            stop(); self.last = live; return
        }
        guard deadline == nil else { return }
        held = last
        deadline = now + Self.handoverDuration
        generation &+= 1
        let token = generation
        task = Task { [weak self, weak model] in
            do { try await Task.sleep(for: .seconds(Self.handoverDuration)) } catch { return }
            guard let self, let model, self.generation == token else { return }
            self.finishIfDue(model: model, at: ProcessInfo.processInfo.systemUptime)
        }
    }

    func finishIfDue(model: AppModel, at now: Double) {
        guard let deadline, now >= deadline else { return }
        last = MainLyricSnapshot(model: model)
        stop()
    }
    func stop() {
        generation &+= 1; task?.cancel(); task = nil; deadline = nil
        if held != nil { held = nil }
    }
}
