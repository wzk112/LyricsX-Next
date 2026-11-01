import AppKit
import SwiftUI
import LyricsXCore

/// The shipping Touch Bar view, with a fixed illustrative lyric and no actions
/// or timers. Opening an introduction does not enable system Touch Bar access.
enum GuideTouchBarExample {
    static let line = LyricLine(id: 0, time: 0, text: "让每一句歌词，跟着音乐前进", words: [
        .init(text: "让每一句", start: 0, end: 2),
        .init(text: "歌词，", start: 2, end: 4),
        .init(text: "跟着音乐", start: 4, end: 7),
        .init(text: "前进", start: 7, end: 9)
    ])
    static let position = 4.8
}

struct GuideTouchBarVisual: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MacBook Pro Touch Bar").font(.headline)
            GuideTouchBarNativeView()
                .frame(height: 30)
                .padding(10)
                .background(.black, in: .rect(cornerRadius: 12))
                .allowsHitTesting(false)
            Text("正式控件 · 固定演示歌词 · 非实体 Touch Bar 画面")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.quaternary.opacity(0.4))
        .accessibilityElement(children: .combine)
    }
}

struct GuideTouchBarNativeView: NSViewRepresentable {
    func makeNSView(context: Context) -> TouchBarContentView { TouchBarContentView() }
    func updateNSView(_ view: TouchBarContentView, context: Context) {
        view.update(line: GuideTouchBarExample.line, text: GuideTouchBarExample.line.text,
                    position: GuideTouchBarExample.position, offset: 0, playing: false,
                    artwork: nil, hasTrack: true)
    }
}
