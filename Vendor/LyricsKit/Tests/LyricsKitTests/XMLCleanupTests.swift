import Foundation
import Testing
@testable import LyricsService

struct XMLCleanupTests {
    // Retained only as an equivalence/performance oracle for the previous code.
    private func oldCleanup(_ content: String) -> String {
        var text = content, i = 0, left = 0
        while i < text.count {
            let index = text.index(text.startIndex, offsetBy: i)
            if text[index] == "<" { left = i }
            if i > 0, text[index] == ">", text[text.index(before: index)] == "/" {
                let start = text.index(text.startIndex, offsetBy: left), end = text.index(after: index)
                let part = String(text[start..<end])
                if let equal = part.firstIndex(of: "="), equal == part.lastIndex(of: "="),
                   !part[..<equal].trimmingCharacters(in: .whitespaces).contains(" ") {
                    text.removeSubrange(start..<end); i = 0; continue
                }
            }
            i += 1
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    @Test func cleanupPreservesUnicodeValidAttributesAndLegacyRepairs() {
        let cases = ["", "  歌词 e\u{301} 👩🏽‍🚀 ", "<root><bad=value/><good attr=\"中文\"/></root>",
            "<root><a=b/><c=d/>正文</root>", "<root><node a=\"x=y\"/></root>", "<root>abc &amp; def</root>",
            "<QrcInfos><LyricInfo LyricCount=\"1\"><Lyric_1 LyricType=\"1\" LyricContent=\"[0,4000]风(0,2000)随(2000,2000)\"/></LyricInfo></QrcInfos>"]
        for content in cases { #expect(XMLUtils.removeIllegalContent(content) == oldCleanup(content)) }
    }
    @Test func longMultilingualLyricsDoNotRepeatedlyScanTheWholeString() {
        let content = "<root><content>" + String(repeating: "[100,900]风が吹く music 👩🏽‍🚀 e\u{301}\n", count: 400) + "</content></root>"
        let startOld = ProcessInfo.processInfo.systemUptime
        let expected = oldCleanup(content)
        let oldTime = ProcessInfo.processInfo.systemUptime - startOld
        let startNew = ProcessInfo.processInfo.systemUptime
        let actual = XMLUtils.removeIllegalContent(content)
        let newTime = ProcessInfo.processInfo.systemUptime - startNew
        #expect(actual == expected)
        print("XML cleanup \(content.utf8.count) bytes: old=\(oldTime * 1000) ms; new=\(newTime * 1000) ms")
    }
}
