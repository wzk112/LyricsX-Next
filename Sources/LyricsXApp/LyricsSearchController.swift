import Foundation
import Observation
import LyricsXCore
import LyricsXServices

/// One owner for search cancellation, result retention and preview selection.
/// Displaying a candidate never mutates the production lyrics or cache.
@Observable @MainActor final class LyricsSearchController {
    typealias Updates = @Sendable (SourceSearchStatus) -> Void
    typealias Search = @Sendable (Track, String, Bool, @escaping Updates) -> AsyncThrowingStream<LyricCandidate, Error>
    var query = ""
    var completeSearch = false
    private(set) var results: [LyricCandidate] = []
    private(set) var searching = false
    private(set) var retainedPreviousResults = false
    private(set) var sourceStatuses: [SourceSearchStatus] = []
    private(set) var error: String?
    private(set) var previewCandidate: LyricCandidate?
    private(set) var trackRevision: UInt64?
    @ObservationIgnored private let model: AppModel
    @ObservationIgnored private let read: Search
    @ObservationIgnored private let compactTimeout: Duration
    @ObservationIgnored private let completeTimeout: Duration
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var deadline: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()
    private struct Context: Equatable {
        let query: String
        let complete: Bool
        let configuration: String
        let revision: UInt64?
    }
    @ObservationIgnored private var previous: Context?

    init(model: AppModel, read: Search? = nil, compactTimeout: Duration = .seconds(22), completeTimeout: Duration = .seconds(44)) {
        self.model = model
        let store = model.store
        self.read = read ?? { store.search(track: $0, keyword: $1, complete: $2, onSourceUpdate: $3) }
        self.compactTimeout = compactTimeout; self.completeTimeout = completeTimeout
    }
    private var currentRevision: UInt64? { model.session.track.map { _ in model.session.trackRevision } }
    private var currentQuery: String { [model.session.track?.title, model.session.track?.artist].compactMap { $0 }.joined(separator: " ") }
    func open() {
        query = currentQuery; trackRevision = currentRevision
        results = model.session.candidates
        search()
    }
    func cancel() {
        requestID = UUID(); task?.cancel(); deadline?.cancel()
        task = nil; deadline = nil; searching = false
        settleStatuses()
    }
    func trackChanged() {
        cancel(); previous = nil; trackRevision = currentRevision
        query = currentQuery; results = []; sourceStatuses = []; previewCandidate = nil
        retainedPreviousResults = false; error = "歌曲已切换，请重新搜索。"
    }
    func preview(_ candidate: LyricCandidate) {
        guard !retainedPreviousResults, results.contains(where: { $0.id == candidate.id }) else { return }
        previewCandidate = candidate
    }
    var previewIsApplied: Bool {
        guard let previewCandidate, let document = model.session.document else { return false }
        return previewCandidate.document.representsSameVersion(as: document)
    }
    var canApplyPreview: Bool {
        previewCandidate != nil && !previewIsApplied && !retainedPreviousResults
            && trackRevision != nil && currentRevision == trackRevision
    }
    func applyPreview() {
        guard canApplyPreview, let candidate = previewCandidate,
              model.applySearchCandidate(candidate, forTrackRevision: trackRevision) else {
            error = "歌曲或预览已变更，请重新选择歌词。"; return
        }
        error = nil
    }
    func search() {
        cancel()
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let configuration = model.preferences.sourceConfigurationReader.read()
        let context = Context(query: text, complete: completeSearch, configuration: configuration.selectionKey, revision: currentRevision)
        let replacing = previous != context
        // Disabled sources disappear immediately, even if the new request fails.
        results.removeAll { !configuration.enabled.contains(SourceConfiguration.sourceKey($0.document.source)) && $0.document.source != "本地" }
        retainedPreviousResults = replacing && !results.isEmpty
        if replacing { previewCandidate = nil }
        previous = context; trackRevision = currentRevision
        let id = UUID(); requestID = id; searching = true; error = nil; sourceStatuses = []
        let track = model.session.track ?? Track(playerID: "search", playerName: "搜索", title: text)
        task = Task { [weak self, read] in
            var received = false
            do {
                for try await candidate in read(track, text, context.complete, { [weak self] status in
                    Task { @MainActor [weak self] in self?.update(status, request: id, configuration: configuration) }
                }) {
                    guard let self, !Task.isCancelled, self.requestID == id else { return }
                    if replacing && !received { self.results = []; self.retainedPreviousResults = false }
                    received = true
                    if let index = self.results.firstIndex(where: {
                        $0.id == candidate.id || $0.document.representsSameVersion(as: candidate.document)
                            || ($0.document.source == candidate.document.source && $0.document.providerID != nil
                                && $0.document.providerID == candidate.document.providerID)
                    }) {
                        let old = self.results[index]
                        self.results[index] = candidate
                        if self.previewCandidate?.id == old.id { self.previewCandidate = candidate }
                    } else { self.results.append(candidate) }
                    self.results = configuration.orderedManualResults(self.results, complete: context.complete)
                }
                guard let self, !Task.isCancelled, self.requestID == id else { return }
                if replacing && !received { self.results = []; self.retainedPreviousResults = false }
            } catch {
                guard let self, !Task.isCancelled, self.requestID == id else { return }
                self.error = error.localizedDescription
                if replacing && !received { self.results = []; self.retainedPreviousResults = false }
            }
            guard let self, self.requestID == id else { return }
            self.searching = false; self.deadline?.cancel(); self.deadline = nil; self.task = nil
            self.settleStatuses()
        }
        deadline = Task { [weak self, compactTimeout, completeTimeout] in
            do { try await Task.sleep(for: context.complete ? completeTimeout : compactTimeout) } catch { return }
            guard let self, self.requestID == id else { return }
            self.cancel()
            if self.retainedPreviousResults { self.results = []; self.retainedPreviousResults = false }
            self.error = self.results.isEmpty ? "歌词源响应超时，请重试。" : "部分来源响应超时，已保留读取到的版本。"
        }
    }
    private func update(_ status: SourceSearchStatus, request: UUID, configuration: SourceConfiguration) {
        guard requestID == request else { return }
        let value = SourceSearchStatus(source: status.source, count: status.count, isSearching: searching && status.isSearching, issue: status.issue)
        if let index = sourceStatuses.firstIndex(where: { $0.source == value.source }) { sourceStatuses[index] = value }
        else { sourceStatuses.append(value) }
        let order = SourceConfiguration.normalizedOrder(configuration.sourceOrder)
        sourceStatuses.sort { (order.firstIndex(of: $0.source) ?? 99) < (order.firstIndex(of: $1.source) ?? 99) }
    }
    private func settleStatuses() {
        sourceStatuses = sourceStatuses.map { .init(source: $0.source, count: $0.count, isSearching: false, issue: $0.issue) }
    }
}
