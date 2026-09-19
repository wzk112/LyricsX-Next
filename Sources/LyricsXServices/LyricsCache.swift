import Foundation
import CryptoKit
import LyricsXCore

public enum CacheLocation {
    public static func resolve(modern: UserDefaults = .standard, legacy: UserDefaults? = UserDefaults(suiteName: "com.JH.LyricsX")) -> URL {
        if let bookmark = modern.data(forKey: "ModernLyricsDirectoryBookmark") {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI], bookmarkDataIsStale: &stale) { return url }
        }
        if let path = modern.string(forKey: "ModernLyricsDirectory") { return URL(fileURLWithPath: path, isDirectory: true) }
        for defaults in [legacy, UserDefaults(suiteName: "com.ddddxxx.LyricsX"), UserDefaults(suiteName: "dev.JH.LyricsX")].compactMap({ $0 }) {
            if defaults.integer(forKey: "LyricsSavingPathPopUpIndex") != 0,
               let bookmark = defaults.data(forKey: "LyricsCustomSavingPathBookmark") {
                var stale = false
                if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI], bookmarkDataIsStale: &stale) {
                    // Stale bookmarks still yield a valid URL; do not silently switch cache directories.
                    return url
                }
            }
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/LyricsX", isDirectory: true)
    }
}

/// Reads and writes the original LyricsX directory, using its existing filenames.
/// No second lyrics database or JSON copy is created.
public actor LyricsCache {
    public struct Entry: Sendable, Identifiable {
        public var url: URL
        public var track: Track
        public var document: LyricsDocument
        public var savedAt: Date
        public var id: String { url.path }
    }
    public private(set) var directory: URL
    private var loadedPaths: [String: URL] = [:]
    private var searches: [String: (id: UUID, mayCheckpoint: Bool)] = [:]
    private struct Checkpoint: Codable {
        var title: String; var artist: String; var album: String; var source: String
        var duration: Double; var providerID: String?; var score: Double; var configuration: String
    }
    private static let checkpointPrefix = "[lxcheckpoint:"
    public init(directory: URL = CacheLocation.resolve()) { self.directory = directory }
    public func setDirectory(_ url: URL) { directory = url; loadedPaths = [:]; searches = [:] }
    public func existingURL(for track: Track) -> URL? {
        if let loaded = loadedPaths[track.cacheIdentity], FileManager.default.fileExists(atPath: loaded.path) { return loaded }
        loadedPaths.removeValue(forKey: track.cacheIdentity)
        _ = load(for: track)
        return loadedPaths[track.cacheIdentity]
    }
    public nonisolated static func filename(for track: Track) -> String {
        let name = "\(track.title) - \(track.artist)".replacingOccurrences(of: "/", with: ":")
            .replacingOccurrences(of: "\u{0000}", with: "").replacingOccurrences(of: "\n", with: " ")
        if name.utf8.count <= 220 { return name }
        let hash = SHA256.hash(data: Data(name.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        return String(name.prefix(45)) + "-" + hash
    }
    public func load(for track: Track) -> LyricsDocument? {
        loadEntry(for: track)?.document
    }
    /// A checkpoint is useful immediately, but must never become a score-1000
    /// final/manual selection merely because it was read from disk.
    func automaticCandidate(for track: Track, configuration: String) -> LyricCandidate? {
        guard let entry = loadEntry(for: track) else { return nil }
        let score = entry.checkpoint.map { $0.configuration == configuration ? $0.score : 1 } ?? 1000
        return .init(document: entry.document, score: score, isProvisional: entry.checkpoint != nil)
    }
    func beginSearch(for track: Track) -> UUID {
        let id = UUID()
        let existing = loadEntry(for: track)
        searches[Self.filename(for: track)] = (id, existing == nil || existing?.checkpoint != nil)
        return id
    }
    func endSearch(for track: Track, id: UUID) {
        let key = Self.filename(for: track)
        if searches[key]?.id == id { searches.removeValue(forKey: key) }
    }
    func saveCheckpoint(_ candidate: LyricCandidate, for track: Track, searchID: UUID, configuration: String) throws {
        guard !Task.isCancelled, candidate.score >= 60,
              let search = searches[Self.filename(for: track)], search.id == searchID, search.mayCheckpoint else { return }
        let doc = candidate.document
        let state = Checkpoint(title: doc.title, artist: doc.artist, album: doc.album, source: doc.source,
                               duration: doc.duration, providerID: doc.providerID, score: candidate.score, configuration: configuration)
        try write(doc, for: track, checkpoint: state)
    }
    private func readEntry(_ url: URL) -> (document: LyricsDocument, checkpoint: Checkpoint?)? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 4_000_000 else { return nil }
        guard let text = try? LyricsCodec.readText(url) else { return nil }
        // Put the small marker on its own line; do not modify any lyric/tt line.
        if text.hasPrefix(Self.checkpointPrefix),
           let end = text.firstIndex(of: "\n") {
            let header = String(text[..<end])
            let encoded = String(header.dropFirst(Self.checkpointPrefix.count).dropLast())
            if header.hasSuffix("]"), let data = Data(base64Encoded: encoded),
               let state = try? JSONDecoder().decode(Checkpoint.self, from: data), state.score.isFinite,
               var doc = try? LyricsCodec.parse(String(text[text.index(after: end)...]), source: state.source) {
                doc.title = state.title; doc.artist = state.artist; doc.album = state.album
                doc.duration = state.duration; doc.providerID = state.providerID
                return (doc, state)
            }
        }
        return (try? LyricsCodec.parse(text)).map { ($0, nil) }
    }
    private func loadEntry(for track: Track) -> (document: LyricsDocument, checkpoint: Checkpoint?)? {
        let scoped = directory.startAccessingSecurityScopedResource()
        defer { if scoped { directory.stopAccessingSecurityScopedResource() } }
        for ext in ["lrcx", "lrc", "txt"] {
            let url = directory.appendingPathComponent(Self.filename(for: track)).appendingPathExtension(ext)
            if var entry = readEntry(url) {
                loadedPaths[track.cacheIdentity] = url
                if entry.document.title.isEmpty { entry.document.title = track.title }
                if entry.document.artist.isEmpty { entry.document.artist = track.artist }
                return entry
            }
        }
        return nil
    }
    public func save(_ document: LyricsDocument, for track: Track) throws {
        searches.removeValue(forKey: Self.filename(for: track))
        try write(document, for: track, checkpoint: nil)
    }
    private func write(_ document: LyricsDocument, for track: Track, checkpoint: Checkpoint?) throws {
        let scoped = directory.startAccessingSecurityScopedResource()
        defer { if scoped { directory.stopAccessingSecurityScopedResource() } }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // LRCX remains the default so word-level timing and provider attachments
        // survive every cache write. Existing LRC files remain interoperable and
        // are updated in place when explicitly loaded.
        let ext = document.isSynced || document.isInstrumental ? "lrcx" : "txt"
        // A manual/forced search may save before this process has loaded the old
        // file. Resolve it on disk too, so a user-managed cache is not duplicated.
        let existing = loadedPaths[track.cacheIdentity] ?? existingURL(for: track)
        let url = existing ?? directory.appendingPathComponent(Self.filename(for: track)).appendingPathExtension(ext)
        var doc = document
        doc.title = track.title; doc.artist = track.artist
        var value = LyricsCodec.export(doc).components(separatedBy: .newlines)
            .filter { !$0.hasPrefix(Self.checkpointPrefix) }.joined(separator: "\n")
        if let checkpoint {
            value = Self.checkpointPrefix + (try JSONEncoder().encode(checkpoint)).base64EncodedString() + "]\n" + value
        }
        if let old = try? String(contentsOf: url, encoding: .utf8), old == value { return }
        try value.write(to: url, atomically: true, encoding: .utf8)
        loadedPaths[track.cacheIdentity] = url
    }
    public func entries() throws -> [Entry] {
        let scoped = directory.startAccessingSecurityScopedResource()
        defer { if scoped { directory.stopAccessingSecurityScopedResource() } }
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { ["lrcx", "lrc", "txt"].contains($0.pathExtension.lowercased()) }.compactMap { url in
                guard let doc = readEntry(url)?.document else { return nil }
                let parts = url.deletingPathExtension().lastPathComponent.components(separatedBy: " - ")
                let title = doc.title.isEmpty ? parts.first ?? "未命名" : doc.title
                let artist = doc.artist.isEmpty ? parts.dropFirst().joined(separator: " - ") : doc.artist
                return Entry(url: url, track: Track(playerID: "library", playerName: "资料库", title: title, artist: artist), document: doc,
                             savedAt: (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
            }.sorted { $0.savedAt > $1.savedAt }
    }
}
