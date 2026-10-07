import SwiftUI
import LyricsXCore

struct SearchLyricFollowState {
    private var documentID: UUID?
    private var follow = MainLyricFollowState()

    mutating func request(document: LyricsDocument, index: Int?, reduced: Bool, browsing: Bool = false, force: Bool = false) -> MainLyricFollowState.Request? {
        if documentID != document.id {
            documentID = document.id
            follow = MainLyricFollowState()
        }
        guard !browsing, let request = follow.request(index: index, lines: document.lines, animated: !reduced, force: force) else { return nil }
        return .init(index: request.index, duration: request.duration.map { min(0.35, $0) })
    }
}

/// Candidate preview samples the real playback clock without changing the
/// session document, exclusions or cache. Only Apply commits the selection.
struct SearchLyricPreview: View {
    let model: AppModel
    let document: LyricsDocument?
    let isPreview: Bool
    @Environment(\.colorScheme) private var colorScheme
    private var typography: LyricTypography { model.preferences.mainTypography(colorScheme: colorScheme) }
    @State private var visible = false
    @State private var followState = SearchLyricFollowState()
    @State private var browsing = false
    @Environment(\.accessibilityReduceMotion) private var systemReduced
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(isPreview ? "歌词预览" : "当前歌词", systemImage: isPreview ? "eye" : "text.quote")
                Spacer()
                if model.session.track != nil, document?.isSynced == true { Text(model.session.isPlaying ? "同步播放" : "已暂停").foregroundStyle(.secondary) }
            }.font(.caption.weight(.medium))
            if let document {
                Text([document.title, document.source].filter { !$0.isEmpty }.joined(separator: " · ")).lineLimit(2).font(.caption).foregroundStyle(.secondary)
                if document.isSynced {
                    synced(document)
                } else {
                    ScrollView {
                        Text(model.preferences.text(document.plainText ?? (document.isInstrumental ? "纯音乐" : "暂无可显示歌词")))
                            .font(typography.font(size: 18))
                            .foregroundStyle(typography.primary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                    }
                }
            } else {
                ContentUnavailableView("选择一个版本", systemImage: "text.quote", description: Text("点击左侧“预览”，在这里查看歌词。"))
            }
        }.padding(16).frame(maxHeight: .infinity)
            .background(Color(white: colorScheme == .dark ? 0.075 : 0.97), in: .rect(cornerRadius: 16))
            .hdrDisplayScope(requested: model.preferences.lyricEmphasis.usesHDR)
            .background(WindowVisibilityReader { visible = $0 })
            .onDisappear { visible = false }
            .onChange(of: document?.id) { _, _ in browsing = false }
    }
    private func synced(_ document: LyricsDocument) -> some View {
        let currentIndex = document.index(at: model.session.position)
        let currentID = document.lineID(at: model.session.position)
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(document.lines) { line in
                        let active = currentID == line.id
                        VStack(alignment: .leading, spacing: 7) {
                            LiveLyricText(session: model.session, line: line, document: document,
                                active: active, rendering: { visible && !browsing },
                                text: line.text.isEmpty ? "•••" : model.preferences.text(line.text), effects: model.preferences.lyricEmphasis)
                                .font(typography.font(size: 21))
                                .environment(\.lyricWordColors, typography.wordColors)
                                .foregroundStyle(typography.primary.opacity(active ? 1 : 0.55))
                            if model.preferences.showTranslation, let translation = line.translation {
                                Text(model.preferences.text(translation))
                                    .font(typography.font(size: 12, weight: .medium))
                                    .foregroundStyle(typography.secondary.opacity(active ? 0.8 : 0.45))
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).id(line.id)
                    }
                }.padding(.vertical, 12)
            }.onScrollPhaseChange { _, phase in
                if phase == .interacting || phase == .tracking || phase == .decelerating { browsing = true }
            }.onChange(of: currentIndex, initial: true) { _, index in
                follow(document, index: index, proxy: proxy)
            }.onChange(of: document.id, initial: true) { _, _ in
                // The new document can have the same current numeric index.
                follow(document, index: currentIndex, proxy: proxy)
            }
            .onChange(of: document.lines) { _, _ in
                followState = SearchLyricFollowState(); browsing = false
                follow(document, index: currentIndex, proxy: proxy, force: true)
            }
            .overlay(alignment: .bottomTrailing) {
                if browsing {
                    Button { browsing = false; follow(document, index: currentIndex, proxy: proxy, force: true) }
                    label: { Label("回到当前歌词", systemImage: "location.fill") }
                        .buttonStyle(.glass).controlSize(.small)
                }
            }
        }.id(document.id)
    }

    private func follow(_ document: LyricsDocument, index: Int?, proxy: ScrollViewProxy, force: Bool = false) {
        guard let request = followState.request(document: document, index: index,
                                               reduced: systemReduced || model.preferences.reduceMotion,
                                               browsing: browsing, force: force) else { return }
        let id = index.flatMap { document.lines.indices.contains($0) ? document.lines[$0].id : nil }
            ?? document.lines.first?.id
        guard let id else { return }
        withAnimation(request.duration.map { .smooth(duration: $0) }) {
            proxy.scrollTo(id, anchor: .center)
        }
    }
}
