import SwiftUI
import LyricsXCore

/// Candidate preview samples the real playback clock without changing the
/// session document, exclusions or cache. Only Apply commits the selection.
struct SearchLyricPreview: View {
    let model: AppModel
    let document: LyricsDocument?
    let isPreview: Bool
    @State private var visible = false
    @Environment(\.accessibilityReduceMotion) private var systemReduced
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(isPreview ? "歌词预览" : "当前歌词", systemImage: isPreview ? "eye" : "text.quote")
                Spacer()
                if model.session.track != nil { Text(model.session.isPlaying ? "同步播放" : "已暂停").foregroundStyle(.secondary) }
            }.font(.caption.weight(.medium))
            if let document {
                Text([document.title, document.source].filter { !$0.isEmpty }.joined(separator: " · ")).lineLimit(2).font(.caption).foregroundStyle(.secondary)
                if document.isSynced {
                    synced(document)
                } else {
                    ScrollView {
                        Text(model.preferences.text(document.plainText ?? "纯音乐"))
                            .font(model.preferences.typography.font(size: 18))
                            .foregroundStyle(model.preferences.typography.primary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                    }
                }
            } else {
                ContentUnavailableView("选择一个版本", systemImage: "text.quote", description: Text("点击左侧“预览”，在这里查看歌词。"))
            }
        }.padding(16).frame(maxHeight: .infinity)
            .background(Color(white: 0.075), in: .rect(cornerRadius: 16))
            .preferredColorScheme(.dark)
            .hdrDisplayScope(requested: model.preferences.lyricEmphasis.usesHDR)
            .background(WindowVisibilityReader { visible = $0 })
            .onDisappear { visible = false }
    }
    private func synced(_ document: LyricsDocument) -> some View {
        let currentIndex = document.index(at: model.session.position)
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(document.lines) { line in
                        let active = currentIndex == line.id
                        VStack(alignment: .leading, spacing: 7) {
                            LiveLyricText(session: model.session, line: line, document: document,
                                active: active, rendering: { visible },
                                text: line.text.isEmpty ? "•••" : model.preferences.text(line.text), effects: model.preferences.lyricEmphasis)
                                .font(model.preferences.typography.font(size: 21))
                                .environment(\.lyricWordColors, model.preferences.typography.wordColors)
                                .foregroundStyle(model.preferences.typography.primary.opacity(active ? 1 : 0.55))
                            if model.preferences.showTranslation, let translation = line.translation {
                                Text(model.preferences.text(translation))
                                    .font(model.preferences.typography.font(size: 12, weight: .medium))
                                    .foregroundStyle(model.preferences.typography.secondary.opacity(active ? 0.8 : 0.45))
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).id(line.id)
                    }
                }.padding(.vertical, 12)
            }.onChange(of: currentIndex, initial: true) { _, index in
                guard let id = index ?? document.lines.first?.id else { return }
                withAnimation(systemReduced || model.preferences.reduceMotion ? nil : .smooth(duration: 0.35)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }.id(document.id)
    }
}
