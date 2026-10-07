import Foundation
import LyricsXCore

/// Binary artwork needs an Apple Event descriptor; JXA does not expose its
/// bytes reliably. Keep every read pinned to the same Music PID as metadata.
enum MusicArtworkReader {
    static func read(track: Track, processIdentifier: Int32) async -> Data? {
        let task = Task.detached(priority: .utility) {
            let deadline = ProcessInfo.processInfo.systemUptime + 4
            return try? read(track: track, processIdentifier: processIdentifier) { event in
                try Task.checkCancellation()
                let remaining = deadline - ProcessInfo.processInfo.systemUptime
                guard remaining > 0 else { throw CancellationError() }
                return try event.sendEvent(options: [.waitForReply, .neverInteract], timeout: min(2, remaining))
            }
        }
        return await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
    }

    static func read(track: Track, processIdentifier: Int32,
                     send: (NSAppleEventDescriptor) throws -> NSAppleEventDescriptor) throws -> Data? {
        func get(_ specifier: NSAppleEventDescriptor) throws -> NSAppleEventDescriptor? {
            try Task.checkCancellation()
            let event = NSAppleEventDescriptor(eventClass: code("core"), eventID: code("getd"),
                targetDescriptor: NSAppleEventDescriptor(processIdentifier: processIdentifier), returnID: -1, transactionID: 0)
            event.setParam(specifier, forKeyword: code("----"))
            let reply = try send(event)
            guard reply.paramDescriptor(forKeyword: code("errn"))?.int32Value ?? 0 == 0 else { return nil }
            return reply.paramDescriptor(forKeyword: code("----"))
        }
        func currentTrack() throws -> NSAppleEventDescriptor? {
            try get(property("pTrk", of: .null()))
        }
        func matches(_ item: NSAppleEventDescriptor) throws -> Bool {
            if !track.persistentID.isEmpty,
               try get(property("pPIS", of: item))?.stringValue != track.persistentID { return false }
            for (key, expected) in [("pnam", track.title), ("pArt", track.artist), ("pAlb", track.album)] {
                guard try get(property(key, of: item))?.stringValue == expected else { return false }
            }
            return true
        }
        guard let item = try currentTrack(), try matches(item),
              let raw = try get(property("pRaw", of: artwork(of: item))),
              !raw.data.isEmpty, raw.data.count < 8_000_000,
              let end = try currentTrack(), try matches(end) else { return nil }
        return raw.data
    }

    private static func property(_ key: String, of container: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
        specifier(want: "prop", form: "prop", selection: .init(typeCode: code(key)), container: container)
    }
    private static func artwork(of container: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
        specifier(want: "cArt", form: "indx", selection: .init(int32: 1), container: container)
    }
    private static func specifier(want: String, form: String, selection: NSAppleEventDescriptor,
                                  container: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(.init(typeCode: code(want)), forKeyword: code("want"))
        record.setDescriptor(.init(enumCode: code(form)), forKeyword: code("form"))
        record.setDescriptor(selection, forKeyword: code("seld"))
        record.setDescriptor(container, forKeyword: code("from"))
        return record.coerce(toDescriptorType: code("obj "))!
    }
    static func code(_ value: String) -> UInt32 {
        value.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }
}
