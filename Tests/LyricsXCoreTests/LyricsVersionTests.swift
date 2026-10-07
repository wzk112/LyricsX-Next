import Foundation
import Testing
@testable import LyricsXCore

@Test func lyricVersionChecksTextAndWordTimingRatherThanOnlySongOrDocumentIDs() {
    let original = LyricsDocument(title: "Song", source: "Source", lines: [
        .init(id: 20, time: 1, text: "Word", translation: "Translation", words: [.init(text: "Word", start: 1, end: 2)])
    ], providerID: "song:1")
    var other = original
    other.id = UUID(); other.source = "本地"; other.offsetMilliseconds = 300
    #expect(original.representsSameVersion(as: other))
    other.lines[0].words[0].end = 3
    #expect(!original.representsSameVersion(as: other))
    other = original; other.lines[0].translation = "Corrected"
    #expect(!original.representsSameVersion(as: other))
    other = original; other.providerID = "song:2"
    #expect(!original.representsSameVersion(as: other))
}
@Test func previewLineIdentityUsesTheDocumentsIDsAndItsOwnOffset() {
    var document = LyricsDocument(lines: [.init(id: 0, time: 1, text: "First"), .init(id: 1, time: 3, text: "Next")], offsetMilliseconds: 500)
    // A decoded or revised document can preserve IDs that differ from indices.
    document.lines[0].id = 20; document.lines[1].id = 80
    #expect(document.lineID(at: 0) == nil)
    #expect(document.lineID(at: 0.5) == 20)
    #expect(document.lineID(at: 2.5) == 80)
}
