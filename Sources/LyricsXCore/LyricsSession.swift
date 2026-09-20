import Foundation
import Observation

@Observable @MainActor
public final class LyricsSession {
    public private(set) var track: Track?
    public private(set) var document: LyricsDocument? {
        didSet {
            documentRevision &+= 1
            documentHasWordTiming = document?.hasWordTiming == true
            documentIsPlaceholder = document?.isLikelyInstrumentalPlaceholder == true
        }
    }
    // Candidate upgrades can retain their UUID and active line index.
    public private(set) var documentRevision: UInt64 = 0
    public private(set) var documentHasWordTiming = false
    public private(set) var documentIsPlaceholder = false
    public private(set) var phase: LyricsPhase = .idle
    public private(set) var position = 0.0
    public private(set) var isPlaying = false
    public private(set) var isSearching = false
    public private(set) var currentLineIndex: Int?
    public private(set) var candidates: [LyricCandidate] = []
    public private(set) var persistenceError: String?
    public private(set) var searchGeneration: UInt64 = 0
    @ObservationIgnored private var timeline = PlaybackTimeline()
    @ObservationIgnored private let repository: any LyricsRepository
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var deadlineTask: Task<Void, Never>?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var bestScore = -Double.infinity
    @ObservationIgnored private var bestIsProvisional = false
    @ObservationIgnored private let searchTimeout: Duration
    @ObservationIgnored private var seekProtectionUntil = 0.0
    @ObservationIgnored private var pendingSeekTarget: Double?

    public init(repository: any LyricsRepository, searchTimeout: Duration = .seconds(28)) {
        self.repository = repository; self.searchTimeout = searchTimeout
    }
    public func accept(_ snapshot: PlaybackSnapshot, now: Double = ProcessInfo.processInfo.systemUptime, shouldSearch: Bool = true) {
        // A selected player can briefly return no metadata while it commits a
        // seek. Treat an explicitly unreliable empty snapshot as a transport
        // gap, not as a song change that clears the whole presentation.
        if snapshot.track == nil, track != nil,
           !snapshot.positionIsReliable, !snapshot.playbackStateIsReliable {
            tick(now: now)
            return
        }
        let changed = track?.id != snapshot.track?.id
        if track != snapshot.track { track = snapshot.track }
        if changed {
            seekProtectionUntil = 0
            pendingSeekTarget = nil
            timeline = PlaybackTimeline()
            position = 0
            isPlaying = false
        }
        if let target = pendingSeekTarget,
           snapshot.positionIsReliable,
           snapshot.track?.id == track?.id,
           abs(snapshot.position - target) <= 2.5 {
            seekProtectionUntil = 0
            pendingSeekTarget = nil
        }
        var clockSample = snapshot
        if now < seekProtectionUntil { clockSample.positionIsReliable = false }
        timeline.accept(clockSample)
        if isPlaying != timeline.isPlaying { isPlaying = timeline.isPlaying }
        tick(now: now)
        if !shouldSearch {
            if changed || phase != .notFound { suppressLyrics() }
        } else if changed { reload() }
    }
    public func tick(now: Double = ProcessInfo.processInfo.systemUptime) {
        let newPosition = timeline.position(at: now)
        if position != newPosition { position = newPosition }
        let newIndex = document?.index(at: position)
        if currentLineIndex != newIndex { currentLineIndex = newIndex }
    }
    /// Display frames sample the same bounded monotonic clock directly. They
    /// never mutate playback or wait for the lower-frequency UI/session tick.
    public func presentationPosition(at now: Double = ProcessInfo.processInfo.systemUptime) -> Double {
        isPlaying ? timeline.presentationPosition(at: now) : position
    }
    public func freeze(now: Double = ProcessInfo.processInfo.systemUptime) {
        timeline.freeze(at: now); isPlaying = false; tick(now: now)
    }
    public func seek(to value: Double, now: Double = ProcessInfo.processInfo.systemUptime) {
        timeline.seek(to: value, at: now)
        pendingSeekTarget = value
        seekProtectionUntil = now + 4
        tick(now: now)
    }
    public func rejectPendingSeek() {
        pendingSeekTarget = nil
        seekProtectionUntil = 0
    }
    public func reload(forceRefresh: Bool = false) {
        invalidateSearch()
        guard let track else { document = nil; candidates = []; phase = .idle; currentLineIndex = nil; return }
        if !forceRefresh { document = nil; currentLineIndex = nil }
        candidates = []; bestScore = -Double.infinity; bestIsProvisional = false; phase = .loading; isSearching = true
        let generation = searchGeneration
        let stream = repository.lyrics(for: track, forceRefresh: forceRefresh)
        searchTask = Task { [weak self] in
            do {
                for try await candidate in stream {
                    guard !Task.isCancelled, let self, self.searchGeneration == generation, self.track?.id == track.id else { return }
                    self.candidates.removeAll { $0.id == candidate.id }
                    self.candidates.append(candidate)
                    self.candidates.sort { $0.score > $1.score }
                    if candidate.score > self.bestScore || (candidate.id == self.document?.id && candidate.score == self.bestScore) {
                        self.bestScore = candidate.score; self.document = candidate.document
                        self.bestIsProvisional = candidate.isProvisional
                        self.phase = .ready; self.tick()
                    }
                }
                guard !Task.isCancelled, let self, self.searchGeneration == generation else { return }
                self.deadlineTask?.cancel(); self.isSearching = false
                self.phase = self.document == nil ? .notFound : .ready
                if self.bestScore < 999 && !self.bestIsProvisional { self.persist() }
            } catch {
                guard !Task.isCancelled, let self, self.searchGeneration == generation else { return }
                self.deadlineTask?.cancel(); self.isSearching = false
                self.phase = self.document == nil ? .failed(error.localizedDescription) : .ready
                if self.bestScore.isFinite && self.bestScore < 999 && !self.bestIsProvisional { self.persist() }
            }
        }
        deadlineTask = Task { [weak self, searchTimeout] in
            do { try await Task.sleep(for: searchTimeout) } catch { return }
            guard let self, self.searchGeneration == generation else { return }
            self.searchTask?.cancel(); self.searchGeneration &+= 1; self.isSearching = false
            self.phase = self.document == nil ? .failed("歌词源响应超时，请重试。") : .ready
            if !self.bestIsProvisional { self.persist() }
        }
    }
    public func use(_ document: LyricsDocument, persist shouldPersist: Bool = true) {
        invalidateSearch(); self.document = document; phase = .ready; tick()
        if shouldPersist { persist() }
    }
    public func suppressLyrics() {
        invalidateSearch()
        document = nil; candidates = []; currentLineIndex = nil; phase = .notFound
    }
    public func adjustOffset(by milliseconds: Int) {
        guard let document else { return }
        let (value, overflow) = document.offsetMilliseconds.addingReportingOverflow(milliseconds)
        setOffset(overflow ? (milliseconds >= 0 ? 300_000 : -300_000) : value)
    }
    public func resetOffset() { setOffset(0) }
    private func setOffset(_ value: Int) {
        guard var updated = document else { return }
        invalidateSearch(); phase = .ready
        updated.offsetMilliseconds = min(300_000, max(-300_000, value))
        document = updated
        tick(); persist()
    }
    public func stop() { invalidateSearch(); freeze() }
    // Saves deliberately finish in order; abandoned searches and their deadline
    // must not stay alive just because a provider has not yielded yet.
    isolated deinit { searchTask?.cancel(); deadlineTask?.cancel() }
    private func invalidateSearch() {
        isSearching = false
        searchGeneration &+= 1; searchTask?.cancel(); deadlineTask?.cancel()
        searchTask = nil; deadlineTask = nil
    }
    private func persist() {
        guard let document, let track else { return }
        let previous = saveTask
        // Preserve write order so a slower old offset save can never overwrite the latest one.
        saveTask = Task { [weak self, repository] in
            await previous?.value
            do { try await repository.save(document, for: track); self?.persistenceError = nil }
            catch { self?.persistenceError = "歌词未能保存：\(error.localizedDescription)" }
        }
    }
}
