import SwiftUI
import LyricsXCore

/// Preview owns no player bridge, cache or production lyrics session.
struct LyricsPreviewView: View {
    let preferences: Preferences
    @State private var anchor = Date()
    @State private var visible = false
    @State private var sample = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let reduced = reduceMotion || preferences.reduceMotion
        let doc = sample == 1 ? LyricPreviewSamples.heldNotes : sample == 2 ? LyricPreviewSamples.incremental : DemoContent.document
        return HStack(spacing: 36) {
            CoverArtwork(artwork: nil, demo: true).frame(width: 250)
            LyricRenderTimeline(running: visible && !reduced, sampledTime: Date().timeIntervalSince(anchor),
                                preciseTime: { Date().timeIntervalSince(anchor) }) { elapsed in
                let time = elapsed.truncatingRemainder(dividingBy: sample == 0 ? 96 : 12)
                let index = doc.index(at: time) ?? 0
                VStack(alignment: .leading, spacing: 20) {
                    Text("动效预览").font(.headline).foregroundStyle(.secondary)
                    Text("演示内容仅在此窗口显示").font(.caption).foregroundStyle(.secondary)
                    OverlayLyricsContent(preferences: preferences, document: doc, index: index,
                                         lyricTime: { time }, secondaryMode: .both)
                        .frame(minHeight: 170)
                    Picker("预览内容", selection: $sample) {
                        Text("逐字歌词").tag(0)
                        Text("慢唱与长音").tag(1)
                        Text("高速增量").tag(2)
                    }.onChange(of: sample) { anchor = Date() }
                    Button("重新播放预览") { anchor = Date() }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(40).frame(minWidth: 680, minHeight: 380)
            .background(Color(white: 0.08)).preferredColorScheme(.dark)
            .hdrDisplayScope(requested: preferences.lyricEmphasis.usesHDR)
            .background(WindowVisibilityReader { visible = $0 })
    }
}

private enum LyricPreviewSamples {
    static let incremental: LyricsDocument = {
        let phrases = ["Light comes alive", "让光慢慢亮起来", "A new day begins", "声音一字一字浮现"]
        var lines: [LyricLine] = []
        for (index, text) in phrases.enumerated() {
            for count in 1...text.count {
                let time = Double(index) * 3 + Double(count - 1) * 0.08
                lines.append(.init(id: lines.count, time: time, text: String(text.prefix(count)),
                                   translation: "每 80 毫秒增加一个字符"))
            }
        }
        return .init(title: "增量预览", source: "原创演示歌词", duration: 12, lines: lines)
    }()
    static let heldNotes = LyricsDocument(title: "长音预览", source: "原创演示歌词", duration: 12, lines: [
        .init(id: 0, time: 0, text: "Stay in the light", translation: "让光停留在这一刻", words: [
            .init(text: "Stay", start: 0.2, end: 2.8), .init(text: "in", start: 2.9, end: 3.2),
            .init(text: "the", start: 3.2, end: 3.5), .init(text: "light", start: 3.5, end: 5.7)
        ]),
        .init(id: 1, time: 6, text: "让光慢慢停留", translation: "Let the light linger", words: [
            .init(text: "让", start: 6.2, end: 6.5), .init(text: "光", start: 6.5, end: 8.4),
            .init(text: "慢", start: 8.4, end: 8.7), .init(text: "慢", start: 8.7, end: 9),
            .init(text: "停", start: 9, end: 9.4), .init(text: "留", start: 9.4, end: 11.7)
        ])
    ])
}

struct WindowRenderActivity {
    static let notifications: [Notification.Name] = [NSWindow.didChangeOcclusionStateNotification,
        NSWindow.willMiniaturizeNotification, NSWindow.didMiniaturizeNotification,
        NSWindow.didDeminiaturizeNotification, NSWindow.willCloseNotification, NSWindow.didBecomeKeyNotification]
    private var leaving = false
    mutating func update(event: Notification.Name?, visible: Bool, miniaturized: Bool, exposed: Bool, floating: Bool = false) -> Bool {
        if event == NSWindow.willMiniaturizeNotification || event == NSWindow.willCloseNotification { leaving = true }
        else if !visible || event == NSWindow.didMiniaturizeNotification || event == NSWindow.didDeminiaturizeNotification || event == NSWindow.didBecomeKeyNotification { leaving = false }
        return !leaving && visible && !miniaturized && (floating || exposed)
    }
}

struct WindowVisibilityReader: NSViewRepresentable {
    var changed: (Bool) -> Void
    func makeNSView(context: Context) -> VisibilityView { let view = VisibilityView(); view.changed = changed; return view }
    func updateNSView(_ view: VisibilityView, context: Context) { view.changed = changed }

    static func dismantleNSView(_ view: VisibilityView, coordinator: ()) {
        NotificationCenter.default.removeObserver(view)
        view.changed = nil
    }
    final class VisibilityView: NSView {
        var changed: ((Bool) -> Void)?
        private var activity = WindowRenderActivity()
        private var reported: Bool?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            activity = WindowRenderActivity()
            reported = nil
            if let window {
                for name in WindowRenderActivity.notifications {
                    NotificationCenter.default.addObserver(self, selector: #selector(updateVisibility(_:)), name: name, object: window)
                }
            }
            DispatchQueue.main.async { [weak self] in self?.updateVisibility(nil) }
        }
        @objc private func updateVisibility(_ notification: Notification?) {
            let visible = activity.update(event: notification?.name, visible: window?.isVisible == true,
                miniaturized: window?.isMiniaturized == true, exposed: window?.occlusionState.contains(.visible) == true,
                floating: window is DraggableOverlayPanel)
            guard visible != reported else { return }
            reported = visible; changed?(visible)
        }
    }
}
